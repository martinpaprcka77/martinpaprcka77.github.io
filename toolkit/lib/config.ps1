<#
.SYNOPSIS
    Centrální správa konfigurace — merge defaults + JSON + env.
.DESCRIPTION
    Načte výchozí hodnoty, přepíše je z configs/settings.json
    a nakonec z $env:TOOLKIT_* proměnných.
    Výsledek cachuje v $script:Config pro jedno načtení za session.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/config.ps1
#>

$script:Config = $null

<#
.SYNOPSIS
    Vrátí konfigurační hashtable (načte jen jednou za session).
.EXAMPLE
    $cfg = Get-ToolkitConfig
    $cfg.menu.theme          # 'default'
    $cfg.system.checkDisks   # $true
#>
function Get-ToolkitConfig {
    param([switch]$Force)
    if ($script:Config -and -not $Force) { return $script:Config }

    # ── Defaults ──────────────────────────────────────────────
    $defaults = @{
        menu = @{
            theme       = 'default'
            showHeader  = $true
            colorScheme = 'cyan'
        }
        docker = @{
            defaultCommand = 'ps'
            autoRefresh    = $false
        }
        system = @{
            checkDisks     = $true
            checkServices  = $true
            checkNetwork   = $true
            checkProcesses = $true
        }
    }

    # ── File overrides ────────────────────────────────────────
    $toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
    # Nested Join-Path, one segment per call — matches the house style used
    # throughout this repo. (Correction to an earlier comment here: PowerShell's
    # Join-Path actually normalizes '\' to the platform separator even on
    # Linux/macOS, so a single 'configs\settings.json' string was never broken
    # cross-platform; this nesting isn't a bug fix, just the consistent form.)
    $configFile = Join-Path (Join-Path $toolsRoot 'configs') 'settings.json'
    if (Test-Path $configFile) {
        try {
            $fileConfig = Get-Content $configFile -Raw | ConvertFrom-Json
            # PS5.1 compat: ConvertFrom-Json -AsHashtable is PS6.2+, so recurse PSCustomObject → hashtable
            function ConvertTo-HashtableDeep($o) {
                if ($o -is [PSCustomObject]) { $ht = @{}; $o.PSObject.Properties | ForEach-Object { $ht[$_.Name] = ConvertTo-HashtableDeep $_.Value }; $ht }
                elseif ($o -is [System.Collections.IList]) { ,@($o | ForEach-Object { ConvertTo-HashtableDeep $_ }) }
                else { $o }
            }
            $fileConfig = ConvertTo-HashtableDeep $fileConfig
            $defaults = Merge-Hashtable -Base $defaults -Override $fileConfig
        } catch {
            Write-Debug "Config file parse failed: $_"
        }
    }

    # ── Environment overrides (TOOLKIT_*) ─────────────────────
    foreach ($key in @($defaults.Keys)) {
        foreach ($sub in @($defaults[$key].Keys)) {
            $envVar = "TOOLKIT_$($key)_$($sub)".ToUpper()
            $envVal = Get-Item -Path "Env:$envVar" -ErrorAction SilentlyContinue
            if ($envVal) {
                $defaults[$key][$sub] = if ($envVal.Value -eq 'true') { $true }
                                    elseif ($envVal.Value -eq 'false') { $false }
                                    else { $envVal.Value }
            }
        }
    }

    $script:Config = $defaults
    return $script:Config
}

<#
.SYNOPSIS
    Rekurzivně merguje dva hashtables (override přepisuje base).
#>
function Merge-Hashtable {
    param([hashtable]$Base, [hashtable]$Override)
    $result = @{}
    foreach ($key in $Base.Keys) { $result[$key] = $Base[$key] }
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtable -Base $result[$key] -Override $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}

<#
.SYNOPSIS
    Uloží konfigurační hashtable do configs/settings.json.
#>
function Save-ToolkitConfig {
    param([hashtable]$Config)
    $toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
    # Nested Join-Path, one segment per call — matches the house style used
    # throughout this repo. (Correction to an earlier comment here: PowerShell's
    # Join-Path actually normalizes '\' to the platform separator even on
    # Linux/macOS, so a single 'configs\settings.json' string was never broken
    # cross-platform; this nesting isn't a bug fix, just the consistent form.)
    $configFile = Join-Path (Join-Path $toolsRoot 'configs') 'settings.json'
    if (Test-Path $configFile) {
        Copy-Item -Path $configFile -Destination "$configFile.backup" -Force
    }
    $json = $Config | ConvertTo-Json -Depth 5
    Set-Content -Path $configFile -Value $json -Encoding UTF8
    $script:Config = $Config
    Write-Host "[+] Config saved to $configFile" -ForegroundColor Green
}
