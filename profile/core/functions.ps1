<#
.SYNOPSIS
    Užitečné funkce do PowerShell profilu.
.DESCRIPTION
    Kolekce pomocných funkcí – editace profilu, reload, získávání klíčů.
.NOTES
    Cesta: ~/.config/powershell/profile/core/functions.ps1
#>

<#
.SYNOPSIS
    Otevře hlavní profil v editoru ($env:EDITOR, nebo code, nebo notepad).
#>
function Edit-Profile {
    [CmdletBinding()]
    param()
    $profilePath = Join-Path $env:DOTFILES_PWSH 'profile.ps1'
    $editor = if ($env:EDITOR) { $env:EDITOR } elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code' } else { 'notepad' }
    & $editor $profilePath
}

<#
.SYNOPSIS
    Znovu načte hlavní profil.
#>
function Reload-Profile {
    [CmdletBinding()]
    param()
    $profilePath = Join-Path $env:DOTFILES_PWSH 'profile.ps1'
    if (Test-Path $profilePath) {
        . $profilePath
        Write-Host "Profile reloaded." -ForegroundColor Green
    }
    else {
        Write-Warning "Profile not found: $profilePath"
    }
}

<#
.SYNOPSIS
    Získá tajný klíč z Microsoft.PowerShell.SecretManagement trezoru
    nebo z proměnné prostředí (fallback pro testování).
.DESCRIPTION
    Nejprve zkusí SecretManagement vault; pokud selže, použije $env:VAR.
.PARAMETER Name
    Název klíče (např. 'MyApiKey').
.EXAMPLE
    Get-SecretKey -Name 'MyApiKey'
#>
function Get-SecretKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    try {
        if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
            Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
            return Get-Secret -Name $Name -Vault Default -AsPlainText
        }
    }
    catch {
        Write-Debug "SecretManagement failed: $_"
    }

    $envVar = Get-Item -Path "Env:$Name" -ErrorAction SilentlyContinue
    if ($envVar) {
        return $envVar.Value
    }

    Write-Warning "Key '$Name' not found in vault or environment."
    return $null
}

<#
.SYNOPSIS
    Zjistí, zda je aktuální session spuštěna jako administrátor.
.NOTES
    Windows-only. $IsWindows doesn't exist on PS5.1 (it's a PS6+ automatic
    variable) — PS5.1 only ever runs on Windows, so the version check covers it.
#>
function Test-Admin {
    [CmdletBinding()]
    param()
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
    Vytvoří adresář a vstoupí do něj.
#>
function mkcd {
    [CmdletBinding()]
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}
