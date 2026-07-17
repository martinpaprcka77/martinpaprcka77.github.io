<#
.SYNOPSIS
    Toolkit – osobní PowerShell toolbox modul.
.DESCRIPTION
    Hlavní modul, který dot-sourcuje všechny .ps1 z lib/ a exportuje veřejné funkce.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Toolkit.psm1
#>

# Dot-source all lib scripts
$libDir = Join-Path $PSScriptRoot '..\lib'
if (Test-Path $libDir) {
    Get-ChildItem -Path $libDir -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}

# Dot-source all menu scripts (define Show-*Menu functions)
$menuDir = Join-Path $PSScriptRoot '..\menu'
if (Test-Path $menuDir) {
    Get-ChildItem -Path $menuDir -Filter 'menu-*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

# Export public functions
Export-ModuleMember -Function @(
    # Common
    'Test-Admin',
    'Get-ScriptDirectory',
    'Write-Info',
    'Write-Success',
    'Write-Warn',
    'Write-Err',
    'Confirm-Action',

    # Menu
    'Show-Menu',
    'Start-MainMenu',
    'Show-DockerMenu',
    'Show-GitMenu',
    'Show-TerminalMenu',
    'Show-TerminalTroubleshootingMenu',
    'Show-DotfilesMenu',
    'Show-PwshMenu',
    'Show-VSCodeMenu',

    # Checkers
    'Get-DiskStatus',
    'Get-ServiceStatus',
    'Get-NetworkInfo',
    'Get-TopProcesses',
    'Test-NetworkHealth',
    'Invoke-SystemCheck',

    # Config
    'Get-ToolkitConfig',
    'Save-ToolkitConfig',
    'Merge-Hashtable',

    # ModulePath
    'Get-PSModulePath',
    'Add-PSModulePath',
    'Remove-PSModulePath',
    'Reset-PSModulePath',
    'Export-PSModulePath',
    'Import-PSModulePath',
    'Test-PSModulePath',

    # Detectors (Show-Menu live-status support)
    'Test-LegacyPowerShellGetPresent',
    'Test-PSResourceGetReady',
    'Get-ModuleStackStatus',
    'Get-DotfilesCompanionStatus',
    'Get-ModulePathStatus',
    'Initialize-MenuMenu',
    'Invoke-IfAvailable',

    # Hints (one-time user onboarding)
    'Show-Hint',
    'Test-HintShown',
    'Get-HintsConfig',
    'Save-HintsConfig',
    'Reset-Hints'
)
