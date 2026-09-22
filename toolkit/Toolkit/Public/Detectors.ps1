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
    path/module list on purpose (it must not import the module), so the two are
    kept in sync by hand — see the comment in modernize.ps1.
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
    $modulePath = "$env:ProgramFiles\PowerShell\7\Modules"
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
