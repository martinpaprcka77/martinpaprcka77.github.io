<#
.SYNOPSIS
    Obecné pomocné funkce.
.DESCRIPTION
    Kolekce utilitních funkcí používaných napříč Toolkit modulem.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/common.ps1
#>

<#
.SYNOPSIS
    Zjistí, zda je aktuální session spuštěna jako administrátor.
.NOTES
    Windows-only. $IsWindows doesn't exist on PS5.1 (PS6+ automatic variable);
    PS5.1 only ever runs on Windows, so the version check covers it.

    ⚠️ CANONICAL SOURCE. Keep in sync with profile/core/functions.ps1 (convenience duplicate
    for profile startup before the module loads).
#>
function Test-Admin {
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        Write-Warning "Test-Admin is Windows-only."
        return $false
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Vrátí cestu k adresáři, ve kterém se nachází volající skript.
#>
function Get-ScriptDirectory {
    return Split-Path -Parent $MyInvocation.ScriptName
}

<#
.SYNOPSIS
    Zobrazí barevnou zprávu s prefixem.
#>
function Write-Info {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Zobrazí úspěšnou zprávu.
#>
function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

<#
.SYNOPSIS
    Zobrazí varovnou zprávu.
#>
function Write-Warn {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}
# ⚠️ DUPLICATE of profile/lib/output.ps1 (canonical source — used by install.ps1/update.ps1 standalone).
# Keep in sync if changing the format.

<#
.SYNOPSIS
    Zobrazí chybovou zprávu.
#>
function Write-Err {
    param([string]$Message)
    Write-Host "[x] $Message" -ForegroundColor Red
}

<#
.SYNOPSIS
    Požádá uživatele o potvrzení (Y/N).
.DESCRIPTION
    Vrátí $true pro Y/Yes, $false jinak.
#>
function Confirm-Action {
    param([string]$Prompt)
    $response = Read-Host "$Prompt (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}
