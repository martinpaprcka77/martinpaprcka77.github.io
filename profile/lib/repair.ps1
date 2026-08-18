<#
.SYNOPSIS
    Runs every self-heal check the ecosystem knows about in one pass.
.DESCRIPTION
    Invoke-DotfilesRepair is the single entry point for self-healing, so
    install.ps1/update.ps1 (and anyone running it standalone) don't have to
    remember to call each repair primitive individually. Composes:
    - Invoke-BootstrapInjection (profile/lib/bootstrap.ps1) — repairs a stale
      or missing $PROFILE bootstrap snippet.
    - Repair-FileEncoding (profile/lib/encoding.ps1) — adds a UTF-8 BOM to any
      non-ASCII source file (Windows PowerShell 5.1 crashes parsing BOM-less
      UTF-8 as ANSI).
    - Test-PSModulePath / Reset-PSModulePath (toolkit/lib/modulepath.ps1,
      Windows only) — validates PSModulePath and resets it to the modern
      OneDrive-safe baseline if issues are found.

    This function does not itself dot-source Invoke-BootstrapInjection or
    Repair-FileEncoding — like every other profile/lib file, it assumes the
    caller already dot-sourced profile/lib/output.ps1, paths.ps1, bootstrap.ps1,
    and encoding.ps1 first (install.ps1/update.ps1 both do, in that order).
    toolkit/lib/modulepath.ps1 is different: it's a toolkit component, not
    normally reachable from a root script, so this function dot-sources it
    itself, resolved from -Path (never assuming $env:DOTFILES_TOOLS is set —
    same self-referential-path convention toolkit/ scripts already follow).

    -WhatIf cascades automatically to the nested SupportsShouldProcess calls
    (Invoke-BootstrapInjection, Repair-FileEncoding, and — once the caller's
    own ShouldProcess gate around Reset-PSModulePath passes — the reset
    itself) via $WhatIfPreference; no extra plumbing needed.
.PARAMETER Path
    Repo root to repair. Defaults to the repo root derived from this file's
    location (profile/lib/ -> profile/ -> repo root).
.PARAMETER Force
    Forwarded to Invoke-BootstrapInjection (re-writes an already-current
    bootstrap block too, not just a stale one).
.PARAMETER SkipModulePath
    Skip the PSModulePath check/reset step — e.g. when toolkit/lib/modulepath.ps1
    isn't present (a partial checkout) or the caller wants only the
    encoding/bootstrap repairs.
.OUTPUTS
    [hashtable] with RestartNeeded (bool — bootstrap changed, restart PowerShell
    to apply), EncodingRepaired (int — files that got a BOM added),
    ModulePathOk ($null if skipped, else the pre-repair Test-PSModulePath
    result), ModulePathReset (bool — whether Reset-PSModulePath ran).
.EXAMPLE
    Invoke-DotfilesRepair
    Invoke-DotfilesRepair -WhatIf
    Invoke-DotfilesRepair -SkipModulePath
.NOTES
    Cesta: ~/.config/powershell/profile/lib/repair.ps1
    Called by install.ps1 (preflight) and update.ps1 (every run); also usable
    standalone by anyone who wants to force a full self-heal pass.
#>
function Invoke-DotfilesRepair {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
        [switch]$Force,
        [switch]$SkipModulePath
    )

    $summary = @{
        RestartNeeded    = $false
        EncodingRepaired = 0
        ModulePathOk     = $null
        ModulePathReset  = $false
    }

    Write-Step "Repairing bootstrap..."
    $summary.RestartNeeded = Invoke-BootstrapInjection -Force:$Force

    Write-Step "Repairing file encoding..."
    $summary.EncodingRepaired = Repair-FileEncoding -Path $Path

    if (-not $SkipModulePath) {
        # $IsWindows doesn't exist on PS5.1 — same version-guard idiom used
        # throughout this repo (profile.ps1, install.ps1, remote-install.ps1).
        $isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }
        if ($isWindowsHost) {
            # toolkit/lib/modulepath.ps1 isn't normally dot-sourced by a root
            # script — resolved from $Path (repo root), never $env:DOTFILES_TOOLS,
            # so this works even before profile.ps1 has ever set that variable.
            $modulePathLib = Join-Path (Join-Path (Join-Path $Path 'toolkit') 'lib') 'modulepath.ps1'
            if (Test-Path $modulePathLib) {
                Write-Step "Checking PSModulePath..."
                . $modulePathLib
                $summary.ModulePathOk = Test-PSModulePath
                if (-not $summary.ModulePathOk) {
                    if ($PSCmdlet.ShouldProcess('$env:PSModulePath', 'Reset-PSModulePath (modern baseline)')) {
                        Reset-PSModulePath
                        $summary.ModulePathReset = $true
                    }
                }
            } else {
                Write-Skip "PSModulePath repair skipped: toolkit/lib/modulepath.ps1 not found"
            }
        } else {
            Write-Skip "PSModulePath repair skipped (non-Windows)"
        }
    }

    return $summary
}
