<#
.SYNOPSIS
    Pre-install inventory and health check for the PowerShell Dotfiles Ecosystem.
.DESCRIPTION
    Checks PowerShell version, Windows Terminal, VS Code, dotfiles profile state,
    environment variables, PATH, modules, and Git. Produces a color-coded report.
    Run BEFORE install.ps1 to understand what needs attention.
.EXAMPLE
    .\precheck.ps1
.NOTES
    Cesta: ~/.config/powershell/toolkit/scripts/precheck.ps1
#>
[CmdletBinding()]
param()

$pass = 0; $warn = 0; $fail = 0; $info = 0

function Check { param([string]$L, [string]$S, [string]$V)
    $icon = if ($S -eq 'OK') { $pass++; '✅' } elseif ($S -eq 'WARN') { $warn++; '⚠️' } else { $fail++; '❌' }
    $color = if ($S -eq 'OK') { 'Green' } elseif ($S -eq 'WARN') { 'Yellow' } else { 'Red' }
    Write-Host "  $icon $L" -ForegroundColor $color -NoNewline
    if ($V) { Write-Host "  → $V" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Section { param([string]$T) Write-Host "`n━━━ $T ━━━" -ForegroundColor Cyan }

# Self-referential — this script lives in <repo root>/toolkit/scripts/, so
# resolve the monorepo root from $PSScriptRoot rather than assuming
# $env:DOTFILES_PWSH/$env:DOTFILES_TOOLS are already set (precheck.ps1 is
# meant to run standalone, before a profile session necessarily exists).
$dotfilesRoot = if ($env:DOTFILES_PWSH) {
    Split-Path $env:DOTFILES_PWSH -Parent
} else {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Join-Path $dotfilesRoot 'toolkit' }

# ═══════════════════════════════════════════════════════════════
Write-Host "`n🔍 DOTFILES ECOSYSTEM — PRE-CHECK INVENTORY" -ForegroundColor Magenta
Write-Host "Run before install.ps1 to see what's ready and what needs work.`n"

# ── PowerShell Version ────────────────────────────────────────
Section "PowerShell"
$psv = $PSVersionTable.PSVersion
$psed = $PSVersionTable.PSEdition
$psOK = ($psv.Major -ge 7)
Check 'PowerShell version'    $(if ($psOK) { 'OK' } else { 'WARN' }) "v$psv ($psed)"

if ($psv.Major -ge 7) {
    $modPath = $env:PSModulePath -split [IO.Path]::PathSeparator
    $localMod = "$env:LOCALAPPDATA\PowerShell\Modules"
    if ($localMod -in $modPath) {
        Check 'PSModulePath (LOCALAPPDATA first)' 'OK' "$localMod"
    } else {
        Check 'PSModulePath (LOCALAPPDATA missing)' 'WARN' 'Will be fixed by profile.ps1'
    }
}

if ($psv.Major -lt 6) {
    Check 'PS5 — PSReadLine available'    $(if (Get-Module -ListAvailable PSReadLine) { 'OK' } else { 'WARN' })
}

# ── Windows Terminal ───────────────────────────────────────────
Section "Windows Terminal"
$wtPkg = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
if ($wtPkg) {
    Check 'Windows Terminal installed' 'OK'
} else {
    Check 'Windows Terminal installed' 'WARN' 'Run deps.ps1 to install'
}

# Check fragment
$fragmentPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json"
if (Test-Path $fragmentPath) {
    $fragAge = (Get-Date) - (Get-Item $fragmentPath).LastWriteTime
    Check 'WT fragment exists' 'OK' "Updated $($fragAge.Days)d ago"
} else {
    Check 'WT fragment exists' 'WARN' 'Run Add-WTProfiles.ps1'
}

# Check old settings.json profiles
$settingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$settingsFound = $settingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($settingsFound) {
    Check 'WT settings.json found' 'OK' $settingsFound
    $content = Get-Content $settingsFound -Raw
    if ($content -match '11111111-1111-1111-1111-111111111111') {
        Check 'WT — old GUID profiles detected' 'WARN' 'Replace with fragment: Add-WTProfiles.ps1'
    }
}

# ── VS Code ────────────────────────────────────────────────────
Section "VS Code"
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) {
    Check 'VS Code installed' 'OK' $codeCmd.Source
} else {
    Check 'VS Code installed' 'WARN' 'Run deps.ps1 to install'
}

$vscSettings = Join-Path $dotfilesRoot '.vscode\settings.json'
if (Test-Path $vscSettings) {
    Check 'Committed VS Code settings' 'OK'
} else {
    Check 'Committed VS Code settings' 'WARN' 'Clone the dotfiles repo first'
}

# ── Dotfiles Profile State ────────────────────────────────────
Section "Dotfiles Profile"
$profilePaths = @(
    @{ N='PS7'; P="$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ N='PS7-VSCode'; P="$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1" },
    @{ N='PS5'; P="$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ N='PS5-VSCode'; P="$HOME\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1" }
)
$bootstrapped = 0
foreach ($p in $profilePaths) {
    if (Test-Path $p.P) {
        $content = Get-Content $p.P -Raw -ErrorAction SilentlyContinue
        if ($content -match 'Bootstrap: dotfiles-powershell') {
            Check "$($p.N) — bootstrapped" 'OK'
            $bootstrapped++
        } else {
            Check "$($p.N) — exists, NOT bootstrapped" 'WARN' 'Run install.ps1'
        }
    } else {
        Check "$($p.N) — missing" 'INFO'
    }
}

$mainProfile = Join-Path $dotfilesRoot 'profile\profile.ps1'
if (Test-Path $mainProfile) {
    Check 'Main profile.ps1 exists' 'OK' $mainProfile
} else {
    Check 'Main profile.ps1 missing' 'FAIL' 'Clone the dotfiles repo first'
}

# ── Environment ────────────────────────────────────────────────
Section "Environment"
Check 'DOTFILES_PWSH'  $(if ($env:DOTFILES_PWSH) { 'OK' } else { 'WARN' }) $env:DOTFILES_PWSH
Check 'DOTFILES_TOOLS' $(if ($env:DOTFILES_TOOLS) { 'OK' } else { 'WARN' }) $env:DOTFILES_TOOLS
Check 'EDITOR'         $(if ($env:EDITOR) { 'OK' } else { 'INFO' }) $env:EDITOR

$toolsBin = Join-Path $toolsRoot 'bin'
if ($toolsBin -in ($env:PATH -split [IO.Path]::PathSeparator)) {
    Check 'tools/bin in PATH' 'OK'
} else {
    Check 'tools/bin in PATH' 'WARN' 'Will be added by install.ps1'
}

# ── Required Modules ───────────────────────────────────────────
Section "PowerShell Modules"
$requiredModules = @(
    @{ Name = 'PSReadLine';     Min = '2.3.0' },
    @{ Name = 'Terminal-Icons'; Min = '0.10.0' },
    @{ Name = 'PSFzf';          Min = '2.5.0' },
    @{ Name = 'Pester';         Min = '5.5.0' },
    @{ Name = 'Toolkit';        Min = '1.0.0' }
)
foreach ($m in $requiredModules) {
    $existing = Get-Module -ListAvailable -Name $m.Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($existing) {
        $verOK = $existing.Version -ge [version]$m.Min
        Check "$($m.Name)" $(if ($verOK) { 'OK' } else { 'WARN' }) "v$($existing.Version)"
    } else {
        Check "$($m.Name)" 'INFO' 'Not installed'
    }
}

# ── Git ────────────────────────────────────────────────────────
Section "Git"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVer = git --version 2>&1
    Check 'Git installed' 'OK' $gitVer
} else {
    Check 'Git installed' 'FAIL' 'Required — run deps.ps1'
}

# ═══════════════════════════════════════════════════════════════
Write-Host "`n━━━ RESULT ━━━" -ForegroundColor Cyan
$total = $pass + $warn + $fail + $info
Write-Host "  ✅ Pass: $pass  ⚠️ Warn: $warn  ❌ Fail: $fail  ℹ️ Info: $info  (Total: $total checks)" -ForegroundColor White
if ($fail -gt 0) {
    Write-Host "`n  ❌ Fix failures before running install.ps1" -ForegroundColor Red
} elseif ($warn -gt 0) {
    Write-Host "`n  ⚠️ Some items need attention. Run install.ps1 to fix most warnings." -ForegroundColor Yellow
} else {
    Write-Host "`n  ✅ All checks passed. Ready to install!" -ForegroundColor Green
}
