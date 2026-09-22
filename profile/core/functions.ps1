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
function Import-Profile {
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
# Approved verb; keep the historical name working (rp in core/aliases.ps1 points at it).
Set-Alias -Name Reload-Profile -Value Import-Profile -Force

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
    Windows-only. $IsWindows doesn't exist on PS5.1 (PS6+ automatic variable);
    PS5.1 only ever runs on Windows, so the version check covers it.

    ⚠️ KEEP IN SYNC with toolkit/lib/common.ps1 — that is the canonical source.
    This is a convenience duplicate for profile startup before the module loads.
#>
function Test-Admin {
    [CmdletBinding()]
    param()
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
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

<#
.SYNOPSIS
    Vrátí adresář se značkami už zobrazených nápověd.
.DESCRIPTION
    Stav žije MIMO repozitář — zápis do clone by znečistil pracovní strom a
    rozbil `git pull --ff-only` v update.ps1 (i `git reset --hard` v
    remote-install.ps1). Windows: %LOCALAPPDATA%\dotfiles-powershell\hints;
    jinde $HOME/.local/state/dotfiles-powershell/hints.
.PARAMETER Ensure
    Vytvoří adresář, pokud chybí (Test-HintShown adresář nevytváří).
.EXAMPLE
    Get-HintStateDir -Ensure
#>
function Get-HintStateDir {
    [CmdletBinding()]
    param(
        [switch]$Ensure
    )

    $base = if ($env:LOCALAPPDATA) {
        Join-Path $env:LOCALAPPDATA 'dotfiles-powershell'
    }
    else {
        # Linux/macOS: $env:LOCALAPPDATA doesn't exist. Nest Join-Path rather
        # than passing a multi-segment child path — a single '.local/state'
        # child would be treated as one literal segment off-Windows.
        Join-Path (Join-Path (Join-Path $HOME '.local') 'state') 'dotfiles-powershell'
    }
    $dir = Join-Path $base 'hints'

    if ($Ensure -and -not (Test-Path $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }

    return $dir
}

<#
.SYNOPSIS
    Zjistí, zda už byla daná nápověda zobrazena.
.PARAMETER Name
    Identifikátor nápovědy (např. 'health_check_first_run').
.EXAMPLE
    if (-not (Test-HintShown 'health_check_first_run')) { ... }
.NOTES
    Read-only: nikdy nevytváří adresář se stavem — na čistém systému prostě
    vrátí $false.
#>
function Test-HintShown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    return Test-Path (Join-Path (Get-HintStateDir) "$Name.shown")
}

<#
.SYNOPSIS
    Zobrazí jednorázovou nápovědu a poznamená si, že už byla zobrazena.
.PARAMETER Name
    Identifikátor nápovědy — musí odpovídat názvu použitému v Test-HintShown.
.PARAMETER Title
    Nadpis nápovědy.
.PARAMETER Lines
    Text nápovědy, jeden řádek na prvek.
.PARAMETER Tips
    Volitelné tipy ("co dělat dál"), zobrazené pod textem.
.EXAMPLE
    Show-Hint 'health_check_first_run' 'System Health Check' @('...') @('...')
#>
function Show-Hint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Title,

        [string[]]$Lines = @(),

        [string[]]$Tips = @()
    )

    if ($Title) {
        Write-Host ''
        Write-Host "   $Title" -ForegroundColor Cyan
        Write-Host "   $(('─' * 55))" -ForegroundColor DarkGray
    }
    foreach ($line in $Lines) {
        Write-Host "   $line" -ForegroundColor Gray
    }
    if ($Tips.Count) {
        Write-Host ''
        Write-Host '   Dalsi kroky:' -ForegroundColor DarkGray
        foreach ($tip in $Tips) {
            Write-Host "     - $tip" -ForegroundColor DarkGray
        }
    }
    Write-Host ''

    $dir = Get-HintStateDir -Ensure
    $null = New-Item -ItemType File -Path (Join-Path $dir "$Name.shown") -Force
}
