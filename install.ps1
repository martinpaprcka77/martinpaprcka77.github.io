<#
.SYNOPSIS
    Idempotentní instalace PowerShell Dotfiles ekosystému (profile + toolkit).
.DESCRIPTION
    Aktualizuje repozitář (git pull), vloží bootstrap do všech známých
    profilových souborů, nastaví PATH a nabídne konfiguraci Windows Terminálu.
    Idempotentní — opakované spuštění nezdvojí položky.
.PARAMETER NoTerminal
    Přeskočí nabídku pro nastavení Windows Terminálu.
.PARAMETER NoUpdates
    Přeskočí git pull (použije lokální verzi).
.PARAMETER WhatIf
    Pouze zobrazí, co by se provedlo, beze změn.
.PARAMETER Force
    Přepíše existující bootstrap (výchozí: přeskočí již nainstalované).
.EXAMPLE
    .\install.ps1
    .\install.ps1 -NoTerminal -NoUpdates
    .\install.ps1 -WhatIf
    .\install.ps1 -Force
.NOTES
    Cesta: ~/.config/powershell/install.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoTerminal,
    [switch]$NoUpdates,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'profile\lib\output.ps1')
. (Join-Path $PSScriptRoot 'profile\lib\paths.ps1')
. (Join-Path $PSScriptRoot 'profile\lib\bootstrap.ps1')

$script:Summary = [System.Collections.Generic.List[string]]::new()

# install.ps1 needs a run summary; override the shared writers from lib/output.ps1
# to also record each line. update.ps1 uses the shared writers unmodified — do not
# "simplify" this by removing the overrides, the summary list depends on them.
function Write-Ok   { param([string]$M) Write-Host "  [+] $M" -ForegroundColor Green;  $null = $script:Summary.Add("  [+] $M") }
function Write-Skip { param([string]$M) Write-Host "  [=] $M" -ForegroundColor Gray;   $null = $script:Summary.Add("  [=] $M") }
function Write-Fail { param([string]$M) Write-Host "  [x] $M" -ForegroundColor Red;    $null = $script:Summary.Add("  [x] $M") }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow; $null = $script:Summary.Add("  [!] $M") }

$script:restartNeeded = $false

# install.ps1 always runs FROM the already-cloned repo (that's how it's
# invoked — clone, then run <clone>/install.ps1), so $PSScriptRoot is
# reliably the repo root. No separate default-fallback path is needed here.
$dotfilesPath = $PSScriptRoot

# $IsWindows doesn't exist on PS5.1 (PS6+ automatic variable); PS5.1 only ever
# runs on Windows, so treat that case as Windows too. Use this instead of the
# raw $IsWindows anywhere below.
$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

# ── Preflight ──────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail "git is required but not found on PATH. Install it first: https://git-scm.com/downloads"
    exit 1
}

# ── Git update (self) ──────────────────────────────────────────
Write-Step "Checking for updates..."

if (-not $NoUpdates) {
    if ($PSCmdlet.ShouldProcess($dotfilesPath, 'git pull --ff-only')) {
        try {
            Push-Location $dotfilesPath
            git pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Updated: $dotfilesPath" }
            else { Write-Fail "git pull failed in $dotfilesPath" }
        } catch {
            Write-Fail "Update failed: $_"
        } finally {
            Pop-Location
        }
    }
} else {
    Write-Skip "Skipping update (--NoUpdates): $dotfilesPath"
}

# ── Bootstrap profiles ────────────────────────────────────────
Write-Step "Injecting bootstrap into PowerShell profiles..."
if ($PSCmdlet.ShouldProcess('$PROFILE targets', 'Inject/repair bootstrap')) {
    $script:restartNeeded = (Invoke-BootstrapInjection -Force:$Force) -or $script:restartNeeded
}

# ── PATH setup ─────────────────────────────────────────────────
# [Environment]::...('User') is a Windows registry-backed target — .NET
# throws PlatformNotSupportedException for it on Linux/macOS. Session PATH
# ($env:PATH) still works everywhere; only the persistent part is Windows-only.
Write-Step "Setting user PATH..."

$toolsBin = Join-Path $dotfilesPath 'toolkit\bin'
try {
    $currentUserPath = if ($isWindowsHost) { [Environment]::GetEnvironmentVariable('PATH', 'User') } else { $env:PATH }
    if ($toolsBin -notin ($currentUserPath -split [IO.Path]::PathSeparator)) {
        if ($PSCmdlet.ShouldProcess('User PATH', "Add $toolsBin")) {
            if ($isWindowsHost) {
                [Environment]::SetEnvironmentVariable('PATH', "$toolsBin$([IO.Path]::PathSeparator)$currentUserPath", 'User')
            }
            $env:PATH = "$toolsBin$([IO.Path]::PathSeparator)$env:PATH"
            Write-Ok "Added to PATH: $toolsBin"
            $script:restartNeeded = $true
        }
    }
    else { Write-Skip "Already in PATH: $toolsBin" }
} catch {
    Write-Fail "PATH update failed: $_"
}

# ── Windows Terminal ───────────────────────────────────────────
if (-not $NoTerminal) {
    $wtScript = Join-Path $dotfilesPath 'toolkit\scripts\Add-WTProfiles.ps1'
    if ($isWindowsHost -and (Test-Path $wtScript)) {
        $response = Read-Host "`nRun Add-WTProfiles.ps1 to configure Windows Terminal? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            if ($PSCmdlet.ShouldProcess('Windows Terminal', 'Add profiles')) {
                try { & $wtScript } catch { Write-Fail "WT setup failed: $_" }
            }
        }
    }
    elseif (-not $isWindowsHost) {
        Write-Skip "Windows Terminal setup skipped (non-Windows OS)"
    }
}

# ── Summary ────────────────────────────────────────────────────
Write-Host "`n=== INSTALLATION SUMMARY ===" -ForegroundColor Magenta
$script:Summary | ForEach-Object { Write-Host $_ }
if ($script:restartNeeded) {
    Write-Host "`nRestart your PowerShell session to apply changes." -ForegroundColor Yellow
}
else {
    Write-Host "`nNo restart needed — everything was already configured." -ForegroundColor Green
}
