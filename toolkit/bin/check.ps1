<#
.SYNOPSIS
    Spustí systémovou kontrolu (Invoke-SystemCheck z Toolkit).
.DESCRIPTION
    Wrapper skript v PATH pro rychlou diagnostiku systému.
.NOTES
    Cesta: ~/.config/powershell/toolkit/bin/check.ps1
#>

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

$modulePath = Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1'

if (-not (Test-Path $modulePath)) {
    Write-Error "Toolkit module not found at: $modulePath"
    exit 1
}

Import-Module $modulePath -Force
Invoke-SystemCheck @Arguments
