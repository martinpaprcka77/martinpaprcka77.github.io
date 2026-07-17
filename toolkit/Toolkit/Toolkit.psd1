@{
    # Module manifest for Toolkit
    RootModule        = 'Toolkit.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd5e3f8a1-9b2c-4d7e-8f3a-1c5b9e2d4f6a'
    Author            = 'USER'
    CompanyName       = ''
    Copyright         = '(c) 2026. MIT License.'
    Description       = 'Osobní PowerShell toolbox – menu, diagnostika, pomocné funkce.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Test-Admin',
        'Get-ScriptDirectory',
        'Write-Info',
        'Write-Success',
        'Write-Warn',
        'Write-Err',
        'Confirm-Action',
        'Show-Menu',
        'Start-MainMenu',
        'Show-DockerMenu',
        'Show-GitMenu',
        'Show-TerminalMenu',
        'Show-TerminalTroubleshootingMenu',
        'Show-DotfilesMenu',
        'Show-PwshMenu',
        'Show-VSCodeMenu',
        'Get-DiskStatus',
        'Get-ServiceStatus',
        'Get-NetworkInfo',
        'Get-TopProcesses',
        'Test-NetworkHealth',
        'Invoke-SystemCheck',
        'Get-ToolkitConfig',
        'Save-ToolkitConfig',
        'Merge-Hashtable',
        'Get-PSModulePath',
        'Add-PSModulePath',
        'Remove-PSModulePath',
        'Reset-PSModulePath',
        'Export-PSModulePath',
        'Import-PSModulePath',
        'Test-PSModulePath',
        'Test-LegacyPowerShellGetPresent',
        'Test-PSResourceGetReady',
        'Get-ModuleStackStatus',
        'Get-DotfilesCompanionStatus',
        'Get-ModulePathStatus',
        'Initialize-MenuMenu',
        'Invoke-IfAvailable',
        'Show-Hint',
        'Test-HintShown',
        'Get-HintsConfig',
        'Save-HintsConfig',
        'Reset-Hints'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('tools', 'menu', 'diagnostics', 'powershell')
            LicenseUri = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io/blob/main/LICENSE'
            ProjectUri = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io'
        }
    }
}
