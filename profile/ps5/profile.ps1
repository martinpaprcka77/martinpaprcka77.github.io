<#
.SYNOPSIS
    Specifické nastavení pro Windows PowerShell 5.1.
.DESCRIPTION
    Import starších modulů a nastavení pro PS 5.1.
.NOTES
    Cesta: ~/.config/powershell/profile/ps5/profile.ps1
#>

# PSReadLine for PS5 (older version)
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
}

# Console encoding (PS5 defaults to ASCII)
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# PS5 profile loaded
