<#
.SYNOPSIS
    Spustí hlavní menu (Start-MainMenu z modulu Toolkit).
.DESCRIPTION
    Wrapper skript v PATH, který importuje Toolkit modul a spustí interaktivní menu.
.NOTES
    Cesta: ~/.config/powershell/toolkit/bin/menu.ps1
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
Start-MainMenu @Arguments
