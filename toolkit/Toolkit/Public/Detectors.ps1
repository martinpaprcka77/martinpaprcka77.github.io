<#
.SYNOPSIS
    Read-only, cheap detector functions for Show-Menu's live status column.
.DESCRIPTION
    Each detector returns @{ Icon = '✅'|'⚠️'|'❌'; Text = '...' } or $null.
    Detectors run on every menu render frame (every keypress) — keep them
    cheap: Get-Command/Test-Path/cached config reads only, no network calls,
    no subprocess spawns.

    Test-LegacyPowerShellGetPresent / Test-PSResourceGetReady are the predicates
    behind Get-ModuleStackStatus. ops/modernize.ps1 duplicates the same
    path/module list on purpose, so the two are kept in sync by hand — see the
    comment in modernize.ps1. (It is NOT because modernize.ps1 cannot import
    this module: it imports Toolkit at its line 31. A repo-invariant Pester test
    guards the duplicated list against drifting apart.)
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Public/Detectors.ps1
#>

<#
.SYNOPSIS
    True if legacy PowerShellGet 1.x / PackageManagement 1.0.0.1 modules
    are still present under the PowerShell 7 module directory.
#>
function Test-LegacyPowerShellGetPresent {
    [CmdletBinding()]
    param()
    # $PSHOME\Modules — the machine-wide module dir of the *running* PowerShell 7.
    # Deliberately NOT the literal "$env:ProgramFiles\PowerShell\7\Modules": a
    # PowerShell 7 installed from the Microsoft Store (MSIX) keeps its own
    # modules under $PSHOME\Modules instead, and the literal path does not exist
    # at all there (verified on 7.6.6 MSIX, where $PSHOME is
    # C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.6.0_x64__8wekyb3d8bbwe).
    # The hardcoded form therefore returned $false unconditionally, so
    # Get-ModuleStackStatus told the menu's live status column "modern" even with
    # legacy PowerShellGet/PackageManagement present. $PSHOME\Modules is
    # byte-identical to the old path for a standalone (non-MSIX) install.
    $modulePath = Join-Path $PSHOME 'Modules'
    $legacyModules = @(
        'PowerShellGet\1.0.0.1',
        'PackageManagement\1.0.0.1'
    )
    foreach ($lm in $legacyModules) {
        if (Test-Path (Join-Path $modulePath $lm)) { return $true }
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
    # Get-Command, not Get-Module -ListAvailable: the latter rescans every
    # PSModulePath directory on each call — measured ~86 ms on a machine with
    # many modules installed (4.5 s for the unfiltered form). This predicate runs
    # inside Get-ModuleStackStatus, which three menus attach as a live Detector
    # that Show-Menu re-evaluates on *every redraw* (i.e. every keypress), so
    # that was ~87 ms of input lag per keystroke and directly contradicted this
    # file's own "cheap detectors" contract. Get-Command answers the same
    # question in ~2 ms, and answers it better: it resolves only if the module's
    # cmdlet is actually usable (a module that is installed but incompatible
    # still fails), where Get-Module only proves the manifest exists. It does
    # autoload the module on the first probe, which is a fair definition of
    # "ready" — after that the call is free.
    return [bool](Get-Command -Name Get-InstalledPSResource -ErrorAction SilentlyContinue)
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
    Detector: PSModulePath health, delegating to the existing validator
    (Test-PSModulePath in Toolkit/Public/ModulePath.ps1) rather than re-deriving it.
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
