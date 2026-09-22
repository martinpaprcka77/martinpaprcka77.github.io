<#
.SYNOPSIS
    Nastavení pro integrovaný terminál VS Code.
.DESCRIPTION
    Potlačení uvítání, nastavení kódování, zkrácený prompt.
.NOTES
    Cesta: ~/.config/powershell/profile/hosts/VSCode.ps1
#>

# Suppress welcome banner in VS Code terminal
# (no welcome message)

# Ensure UTF-8 output
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

# Set VS Code specific env
$env:TERM = 'vscode'
