<#
.SYNOPSIS
    Read-only, cheap detector functions for Show-Menu's live status column.
.DESCRIPTION
    Each detector returns @{ Icon = '✅'|'⚠️'|'❌'; Text = '...' } or $null.
    Detectors run on every menu render frame (every keypress) — keep them
    cheap: Get-Command/Test-Path/cached config reads only, no network calls,
    no subprocess spawns.

    Test-LegacyPowerShellGetPresent / Test-PSResourceGetReady are also used
    by scripts/modernize.ps1 directly (not just by the menu's detector) —
    this is deliberate: the menu's displayed state and modernize.ps1's
    actual behavior read the same predicates, so they can never disagree.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/detectors.ps1
#>

<#
.SYNOPSIS
    The candidate full paths of legacy PowerShellGet 1.x / PackageManagement
    1.0.0.1 modules under the built-in module directories.
.DESCRIPTION
    Single source of truth for "which legacy-module locations do we care about".
    Test-LegacyPowerShellGetPresent (the menu's live-status predicate) and
    scripts/modernize.ps1 (which actually removes them) both enumerate THIS
    list, so the displayed status and the cleanup action can never disagree.
    Not exported — an internal shared helper; callers dot-source detectors.ps1.
#>
function Get-LegacyModulePath {
    [CmdletBinding()]
    param()
    $modulePaths = @(
        "$env:ProgramFiles\PowerShell\7\Modules",
        "$env:ProgramFiles\WindowsPowerShell\Modules"
    )
    $legacyModules = @(
        'PowerShellGet\1.0.0.1',
        'PackageManagement\1.0.0.1'
    )
    foreach ($mp in $modulePaths) {
        foreach ($lm in $legacyModules) {
            # Nested Join-Path (never 3 positional args — that needs PS6+).
            Join-Path $mp $lm
        }
    }
}

<#
.SYNOPSIS
    True if legacy PowerShellGet 1.x / PackageManagement 1.0.0.1 modules
    are still present under the built-in module directories.
#>
function Test-LegacyPowerShellGetPresent {
    [CmdletBinding()]
    param()
    foreach ($p in Get-LegacyModulePath) {
        if (Test-Path $p) { return $true }
    }
    return $false
}

<#
.SYNOPSIS
    True if the modern PSResourceGet module is installed and available.
#>
function Test-PSResourceGetReady {
    [CmdletBinding()]
    param()
    return [bool](Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Detector: legacy-vs-modern PowerShell module stack status.
#>
function Get-ModuleStackStatus {
    [CmdletBinding()]
    param()
    if (Test-LegacyPowerShellGetPresent) { return @{ Icon = '⚠️'; Text = 'legacy PowerShellGet present' } }
    if (-not (Test-PSResourceGetReady))  { return @{ Icon = '⚠️'; Text = 'PSResourceGet not installed' } }
    return @{ Icon = '✅'; Text = 'PSResourceGet, modern' }
}

<#
.SYNOPSIS
    Detector: is the dotfiles profile loaded in this session?
.DESCRIPTION
    Several menu actions (Status, Performance) call functions that live in
    the companion profile, not this module. This is the
    guard: a graceful "⚠️ not loaded" beats a "term not recognized" crash.
#>
function Get-DotfilesCompanionStatus {
    [CmdletBinding()]
    param()
    if (Get-Command Show-Status -ErrorAction SilentlyContinue) {
        return @{ Icon = '✅'; Text = 'profile loaded' }
    }
    return @{ Icon = '⚠️'; Text = 'not loaded — run install.ps1 or reload profile' }
}

<#
.SYNOPSIS
    Detector: PSModulePath health, delegating to the existing validator
    (Test-PSModulePath in lib/modulepath.ps1) rather than re-deriving it.
#>
function Get-ModulePathStatus {
    [CmdletBinding()]
    param()
    if (-not (Get-Command Test-PSModulePath -ErrorAction SilentlyContinue)) {
        return @{ Icon = '❌'; Text = 'Test-PSModulePath unavailable' }
    }
    $entries = $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ }
    $hasDupes = ($entries | Group-Object | Where-Object { $_.Count -gt 1 })
    $hasOneDrive = ($entries | Where-Object { $_ -match 'OneDrive' })
    if ($hasDupes -or $hasOneDrive) { return @{ Icon = '⚠️'; Text = 'issues found — run Test-PSModulePath' } }
    return @{ Icon = '✅'; Text = "$($entries.Count) entries, clean" }
}

<#
.SYNOPSIS
    Runs Action only if Command is available in this session; otherwise
    warns instead of crashing. Use for menu actions that depend on the
    companion profile being loaded.
.EXAMPLE
    Invoke-IfAvailable -Command 'Show-Status' -Action { Show-Status }
#>
function Invoke-IfAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        & $Action
    } else {
        Write-Warn "Profile function not available (missing: $Command)"
    }
}
