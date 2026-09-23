<#
.SYNOPSIS
    Emits a PowerShell 7 startup-health report as JSON for PowerShell-Startup-Map.html.
.DESCRIPTION
    Walks the bootstrap stages documented in docs/00-bootstrap.md (Launcher → Interactive)
    and records, for each stage, a status plus the checkpoint value that proves it ran.

    LOCAL-ONLY: every probe is a local process/registry/filesystem check. This script
    performs NO network I/O — consistent with the repo's diagnostics invariant.

    Status per phase: healthy | warning | failed.
    Output is JSON on stdout; pipe it to a file and load it in the map:
        pwsh -File ops/Get-PowerShellStartupHealth.ps1 | Set-Content pwsh-health.json
.PARAMETER Path
    Optional file path to also write the JSON to.
.EXAMPLE
    pwsh -File ops/Get-PowerShellStartupHealth.ps1
.EXAMPLE
    pwsh -File ops/Get-PowerShellStartupHealth.ps1 -Path ./pwsh-health.json
.NOTES
    Cesta: ~/.config/powershell/toolkit/ops/Get-PowerShellStartupHealth.ps1
#>
[CmdletBinding()]
param(
    [string]$Path
)

$ErrorActionPreference = 'Stop'

function New-Phase {
    param([string]$Label, [string]$Status, [string]$Checkpoint, $Value)
    [ordered]@{
        label      = $Label
        status     = $Status
        checkpoint = $Checkpoint
        value      = [string]$Value
    }
}

# ── Stage 1 — Launcher ─────────────────────────────────────────
$launcher = New-Phase 'Launcher' 'healthy' '$PID' $PID

# ── Stage 2 — Loader / host ────────────────────────────────────
$smaPath = Join-Path $PSHOME 'System.Management.Automation.dll'
$loaderOk = [bool]$PSVersionTable -and (Test-Path -LiteralPath $smaPath)
$loader = New-Phase 'Loader' $(if ($loaderOk) { 'healthy' } else { 'failed' }) '$PSVersionTable' $PSVersionTable.PSVersion.ToString()

# ── Stage 3 — Session state / configuration ────────────────────
$languageMode = [string]$ExecutionContext.SessionState.LanguageMode
$configStatus = if ($languageMode -eq 'FullLanguage') { 'healthy' } else { 'warning' }
$engine = New-Phase 'Engine' $configStatus '$ExecutionContext.SessionState.LanguageMode' $languageMode

$executionPolicy = [string](Get-ExecutionPolicy)
$policyList = Get-ExecutionPolicy -List

# ── Stage 4 — PSModulePath build ───────────────────────────────
$modulePaths = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })
$oneDrivePath = @($modulePaths | Where-Object { $_ -match 'OneDrive' })
$uncPath = @($modulePaths | Where-Object { $_ -match '^\\\\' })
$missingPath = @($modulePaths | Where-Object { -not (Test-Path -LiteralPath $_) })
$moduleStatus = if ($oneDrivePath -or $uncPath -or $missingPath) { 'warning' } else { 'healthy' }
$modules = New-Phase 'Modules' $moduleStatus '$env:PSModulePath' ("{0} entries" -f $modulePaths.Count)

# ── Stage 5 — Profile resolution ───────────────────────────────
$profilePath = [string]$PROFILE
$profileExists = Test-Path -LiteralPath $profilePath
$profileStatus = if (-not $profileExists) { 'warning' }
                 elseif ($executionPolicy -in @('Restricted', 'AllSigned')) { 'warning' }
                 else { 'healthy' }
$profiles = New-Phase 'Profiles' $profileStatus '$PROFILE' $profilePath

# ── Stage 6/7 — Interactive shell ──────────────────────────────
$hostName = [string]$Host.Name
$psReadLine = [bool](Get-Module -Name PSReadLine -ErrorAction SilentlyContinue)
$moduleCount = @(Get-Module -ListAvailable -ErrorAction SilentlyContinue).Count
$autoLoading = [string](Get-Variable -Name PSModuleAutoLoadingPreference -ValueOnly -ErrorAction SilentlyContinue)
$shellStatus = if ($hostName -and $moduleCount -gt 0) { 'healthy' } else { 'warning' }
$shell = New-Phase 'Interactive' $shellStatus '$Host' $hostName

$phases = [ordered]@{
    launcher      = $launcher
    loader        = $loader
    engine        = $engine
    modules       = $modules
    profiles      = $profiles
    shell         = $shell
}

# Local-only weighted score (healthy 100 / warning 50 / failed 0).
$weights = @{ healthy = 100; warning = 50; failed = 0 }
$score = [math]::Round(
    ($phases.Values | ForEach-Object { $weights[$_.status] } | Measure-Object -Average).Average
)

$report = [ordered]@{
    schema      = 2
    generatedAt = (Get-Date -Format 'o')
    machine     = [System.Environment]::MachineName
    user        = [System.Environment]::UserName
    healthScore = $score
}

# Flatten the phase objects to top-level keys (spec: launcher/loader/engine/modules/profiles/shell).
foreach ($name in $phases.Keys) { $report[$name] = $phases[$name] }

$report['checks'] = [ordered]@{
        pid                 = $PID
        host                = $hostName
        psHome              = $PSHOME
        psVersion           = $PSVersionTable.PSVersion.ToString()
        psEdition           = [string]$PSVersionTable.PSEdition
        languageMode        = $languageMode
        executionPolicy     = $executionPolicy
        executionPolicyList = @($policyList | ForEach-Object { [string]$_.Scope + '=' + [string]$_.ExecutionPolicy })
        profileExists       = $profileExists
        profilePath         = $profilePath
        modulePathCount     = $modulePaths.Count
        modulePaths         = $modulePaths
        oneDriveModulePath  = $oneDrivePath
        uncModulePath       = $uncPath
        missingModulePath   = $missingPath
        moduleCount         = $moduleCount
        psReadLineLoaded    = $psReadLine
        moduleAutoLoading   = $autoLoading
}

# Shell/environment snapshot for the map's Environment panel. Uses the module's
# Get-ShellInfo so there is a single implementation (no duplicated PATH/env logic).
$moduleManifest = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'Toolkit') 'Toolkit.psd1'
$shellInfo = $null
if (Test-Path -LiteralPath $moduleManifest) {
    try {
        Import-Module -Name $moduleManifest -Force -ErrorAction Stop
        if (Get-Command -Name Get-ShellInfo -ErrorAction SilentlyContinue) { $shellInfo = Get-ShellInfo }
    }
    catch { Write-Debug "Get-ShellInfo unavailable: $_" }
}
if ($shellInfo) { $report['shellInfo'] = $shellInfo }

$json = $report | ConvertTo-Json -Depth 10
if ($Path) { Set-Content -LiteralPath $Path -Value $json -Encoding utf8 }
$json
