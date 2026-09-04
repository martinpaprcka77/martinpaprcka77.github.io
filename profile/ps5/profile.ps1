<#
.SYNOPSIS
    Windows PowerShell 5.1-specific profile setup.
.DESCRIPTION
    Loads Windows Terminal shell integration for Windows PowerShell sessions.
#>

Set-StrictMode -Version Latest

$shellIntegration = Join-Path $env:DOTFILES_PWSH 'hosts\shell-integration.ps1'
if (Test-Path $shellIntegration) {
    . $shellIntegration
}
