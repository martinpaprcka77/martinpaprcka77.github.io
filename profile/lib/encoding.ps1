<#
.SYNOPSIS
    Idempotently ensures every PowerShell source file with non-ASCII content
    carries a UTF-8 BOM.
.DESCRIPTION
    Windows PowerShell 5.1 (powershell.exe) reads a BOM-less script using the
    system ANSI codepage, not UTF-8. A multi-byte UTF-8 character (an em dash,
    an arrow, an emoji, "…") then decodes into garbage bytes that desync the
    tokenizer and crash the parser ("The string is missing the terminator")
    — field-reported when a file saved from a chat/editor (which typically omit
    the BOM) was run under 5.1.

    Repair-FileEncoding walks all *.ps1/*.psm1/*.psd1 under -Path and, for each
    file that contains a non-ASCII byte but does NOT already start with the
    UTF-8 BOM (EF BB BF), prepends the BOM. The prepend is done at the byte
    level (the existing bytes are already valid UTF-8, just unmarked), so there
    is no decode/re-encode round-trip and no risk of corrupting content. As a
    safety net, a file whose bytes are not valid UTF-8 (e.g. genuinely ANSI-
    encoded) is skipped with a warning rather than mislabeled.

    The step is a no-op when everything is already correct — safe to run on
    every install/update.
.PARAMETER Path
    Repo root to scan. Defaults to the repository root derived from this file's
    location (profile/lib/ -> profile/ -> repo root).
.OUTPUTS
    [int] the number of files repaired (0 when nothing needed changing).
.EXAMPLE
    Repair-FileEncoding -Path $PSScriptRoot
.NOTES
    Cesta: ~/.config/powershell/profile/lib/encoding.ps1
    Shared by install.ps1 (preflight) and update.ps1 (after each pull).
#>
function Repair-FileEncoding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
    )

    if (-not (Test-Path $Path)) {
        Write-Warn "Repair-FileEncoding: path not found: $Path"
        return 0
    }

    $bom = [byte[]](0xEF, 0xBB, 0xBF)
    # throwOnInvalidBytes = $true so genuinely non-UTF-8 (ANSI) files are
    # detected and skipped instead of being mislabeled with a UTF-8 BOM.
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $repaired = 0

    $files = Get-ChildItem -Path $Path -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        } catch {
            Write-Warn "Repair-FileEncoding: cannot read $($file.FullName): $_"
            continue
        }

        if ($bytes.Length -eq 0) { continue }

        # Already has a UTF-8 BOM → nothing to do.
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            continue
        }

        # Pure ASCII → PS5.1 reads it fine without a BOM, leave it alone.
        $hasNonAscii = $false
        foreach ($b in $bytes) { if ($b -gt 0x7F) { $hasNonAscii = $true; break } }
        if (-not $hasNonAscii) { continue }

        # Non-ASCII without a BOM: verify the bytes are valid UTF-8 before we
        # mark them as such. If not, this is an ANSI file we must not mislabel.
        try {
            [void]$strictUtf8.GetString($bytes)
        } catch {
            Write-Warn "Repair-FileEncoding: $($file.Name) has non-ASCII bytes that are not valid UTF-8 — skipped (convert it to UTF-8 manually)."
            continue
        }

        if ($PSCmdlet.ShouldProcess($file.FullName, 'Add UTF-8 BOM')) {
            try {
                [System.IO.File]::WriteAllBytes($file.FullName, $bom + $bytes)
                Write-Ok "BOM added: $($file.FullName.Substring($Path.Length).TrimStart('\','/'))"
                $repaired++
            } catch {
                Write-Fail "Repair-FileEncoding: failed to write $($file.FullName): $_"
            }
        }
    }

    if ($repaired -eq 0) { Write-Skip "File encoding: all source files already UTF-8 (BOM where needed)." }
    else { Write-Ok "File encoding: added BOM to $repaired file(s)." }
    return $repaired
}
