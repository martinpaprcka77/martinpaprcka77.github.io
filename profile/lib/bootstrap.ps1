<#
.SYNOPSIS
    Shared $PROFILE bootstrap-injection logic for install.ps1 and update.ps1.
.DESCRIPTION
    Invoke-BootstrapInjection — writes/repairs the bootstrap snippet in all 4
    native $PROFILE files. Factored out of install.ps1 so update.ps1 can call
    it too: after the profile/toolkit monorepo restructure, an existing
    machine's real $PROFILE still points at the old flat profile.ps1 path and
    would otherwise silently stop loading until someone thinks to re-run
    install.ps1. Checks content, not just marker presence, so a stale block
    (old path) gets repaired even without -Force — the previous exact-string-
    match approach only ever replaced a block with byte-identical content,
    so a path change never got picked up on repeat runs.
.NOTES
    Cesta: ~/.config/powershell/profile/lib/bootstrap.ps1
#>

function Invoke-BootstrapInjection {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$Force)

    $restartNeeded = $false

    # Hardcoded intentionally, same reasoning as bootstrap.ps1: this snippet
    # runs before profile.ps1 ever executes, so $env:DOTFILES_PWSH doesn't
    # exist yet.
    $bootstrapCode = @'

# Bootstrap: dotfiles-powershell
$dotfilesProfile = Join-Path $HOME '.config\powershell\profile\profile.ps1'
if (Test-Path $dotfilesProfile) { . $dotfilesProfile }
'@

    # Matches any prior version of this block (old flat-path pre-monorepo
    # format included) so it can be replaced wholesale, not just the current
    # exact text — that's what lets a stale target path self-heal.
    $oldBlockPattern = '(?ms)^\s*# Bootstrap: dotfiles-powershell.*?^if \(Test-Path \$dotfilesProfile\) \{ \. \$dotfilesProfile \}\s*$'

    # Known-Folder-correct — not a naive $HOME\Documents guess, which is wrong
    # when OneDrive redirects Documents elsewhere. See lib/paths.ps1.
    $profilePaths = Get-NativeProfilePaths

    foreach ($profilePath in $profilePaths) {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            if ($PSCmdlet.ShouldProcess($profileDir, 'Create directory')) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
        }

        if (Test-Path $profilePath) {
            $existing = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
            $alreadyBootstrapped = $existing -and ($existing -match [regex]::Escape('# Bootstrap: dotfiles-powershell'))
            $upToDate = $alreadyBootstrapped -and ($existing -match [regex]::Escape('profile\profile.ps1'))

            if ($upToDate -and -not $Force) {
                Write-Skip "Already bootstrapped: $profilePath"
            }
            else {
                if ($PSCmdlet.ShouldProcess($profilePath, 'Append/replace bootstrap')) {
                    try {
                        $backup = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                        Copy-Item $profilePath $backup
                        Write-Ok "Backup: $backup"

                        if ($alreadyBootstrapped) {
                            # Normalize line endings before matching — CRLF/LF depends on how
                            # the file was checked out; output stays CRLF (native Windows
                            # profile files).
                            $normalizedExisting = $existing -replace "`r`n", "`n"
                            $newContent = ($normalizedExisting -replace $oldBlockPattern, '').TrimEnd("`n") -replace "`n", "`r`n"
                            $newContent += "`r`n$bootstrapCode"
                            Set-Content -Path $profilePath -Value $newContent -NoNewline
                        } else {
                            Add-Content -Path $profilePath -Value "`r`n$bootstrapCode"
                        }
                        Write-Ok "Updated: $profilePath"
                        $restartNeeded = $true
                    } catch {
                        Write-Fail "Failed: $profilePath — $_"
                    }
                }
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess($profilePath, 'Create with bootstrap')) {
                try {
                    Set-Content -Path $profilePath -Value $bootstrapCode -NoNewline
                    Write-Ok "Created: $profilePath"
                    $restartNeeded = $true
                } catch {
                    Write-Fail "Failed: $profilePath — $_"
                }
            }
        }
    }

    return $restartNeeded
}
