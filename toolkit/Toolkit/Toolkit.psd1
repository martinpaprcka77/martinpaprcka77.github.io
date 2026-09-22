@{
    # Module manifest for Toolkit
    RootModule        = 'Toolkit.psm1'
    ModuleVersion     = '1.5.1'
    GUID              = 'd5e3f8a1-9b2c-4d7e-8f3a-1c5b9e2d4f6a'
    Author            = 'USER'
    CompanyName       = ''
    Copyright         = '(c) 2026. MIT License.'
    Description       = 'Osobní PowerShell toolbox – menu, diagnostika, pomocné funkce.'
    # PowerShellVersion reflects reality: Toolkit/Public/ModulePath.ps1 uses the null
    # coalescing operator (PS7 parse-time) and config.ps1 uses
    # ConvertFrom-Json -AsHashtable (PS6+), so the module cannot load on 5.1.
    PowerShellVersion = '7.0'

    # Single source of the public API. Regenerate with build/Build.ps1 -UpdateManifest.
    FunctionsToExport = @(
        'Add-PSModulePath',
        'Confirm-Action',
        'Export-PSModulePath',
        'Get-DiskStatus',
        'Get-ModulePathStatus',
        'Get-ModuleStackStatus',
        'Get-NetworkInfo',
        'Get-PSModulePath',
        'Get-ServiceStatus',
        'Get-ShellInfo',
        'Get-SystemSummary',
        'Get-ToolkitConfig',
        'Get-TopProcesses',
        'Import-PSModulePath',
        'Invoke-SystemCheck',
        'Merge-Hashtable',
        'Remove-PSModulePath',
        'Reset-PSModulePath',
        'Save-ToolkitConfig',
        'Show-DotfilesMenu',
        'Show-GitMenu',
        'Show-Menu',
        'Show-PwshMenu',
        'Show-StartupMenu',
        'Show-TerminalMenu',
        'Show-VSCodeMenu',
        'Start-MainMenu',
        'Test-LegacyPowerShellGetPresent',
        'Test-NetworkEndpoint',
        'Test-PSModulePath',
        'Test-PSResourceGetReady',
        'Write-Err',
        'Write-Info',
        'Write-Success',
        'Write-TkMessage',
        'Write-Warn'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('tools', 'menu', 'diagnostics', 'powershell')
            LicenseUri = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io/blob/main/toolkit/LICENSE'
            ProjectUri = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io/tree/main/toolkit'
        }
    }
}





