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
function Write-Info { param([string]$M) Write-Host "  [*] $M" -ForegroundColor DarkGray }
# ⚠️ CANONICAL SOURCE for the writer prefixes/colours. The toolkit's copy is
# toolkit/Toolkit/Public/Output.ps1 (Write-TkMessage) — NOT toolkit/lib/common.ps1, which has
# not existed since the rename to Toolkit/Public/*.ps1. The two files cannot share code
# (install.ps1/update.ps1 run before any profile or module exists, and the toolkit must stay
# standalone), so toolkit/tests/Toolkit.Tests.ps1 asserts the two tables are identical and
# fails CI on any drift. Change both, or neither.
