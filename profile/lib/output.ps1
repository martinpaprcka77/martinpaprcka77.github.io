<#
.SYNOPSIS
    Sdílené konzolové výstupní funkce pro install.ps1 a update.ps1.
.DESCRIPTION
    Write-Step/Ok/Skip/Fail/Warn — jednotný vizuální styl hlášení pro
    standalone orchestrační skripty. Tyto skripty běží mimo profilovou
    session (často předtím, než profil vůbec existuje), takže nemohou
    spoléhat na core/*.ps1 — proto je toto lib/, ne core/.
.NOTES
    Cesta: ~/.config/powershell/profile/lib/output.ps1
#>

function Write-Step { param([string]$M) Write-Host "==> $M" -ForegroundColor Cyan }
function Write-Ok   { param([string]$M) Write-Host "  [+] $M" -ForegroundColor Green }
function Write-Skip { param([string]$M) Write-Host "  [=] $M" -ForegroundColor Gray }
function Write-Fail { param([string]$M) Write-Host "  [x] $M" -ForegroundColor Red }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }
# ⚠️ CANONICAL SOURCE. Keep in sync with toolkit/lib/common.ps1 (the module's convenience copy).
