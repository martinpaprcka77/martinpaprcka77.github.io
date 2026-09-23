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
    Cesta: ~/.config/powershell/toolkit/ops/precheck.ps1
#>
[CmdletBinding()]
param()

$script:pass = 0; $script:warn = 0; $script:fail = 0; $script:info = 0

function Check { param([string]$L, [string]$S, [string]$V)
    # Counters must be $script:-scoped: a bare `$pass++` inside a function
    # writes a function-local copy, so the summary always reported 0.
    switch ($S) {
        'OK'    { $script:pass++; $icon = '✅'; $color = 'Green' }
        'WARN'  { $script:warn++; $icon = '⚠️'; $color = 'Yellow' }
        'INFO'  { $script:info++; $icon = 'ℹ️'; $color = 'DarkGray' }
        default { $script:fail++; $icon = '❌'; $color = 'Red' }
    }
    Write-Host "  $icon $L" -ForegroundColor $color -NoNewline
    if ($V) { Write-Host "  → $V" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Section { param([string]$T) Write-Host "`n━━━ $T ━━━" -ForegroundColor Cyan }

# ═══════════════════════════════════════════════════════════════
Write-Host "`n🔍 DOTFILES ECOSYSTEM — PRE-CHECK INVENTORY" -ForegroundColor Magenta
Write-Host "Run before install.ps1 to see what's ready and what needs work.`n"

# ── PowerShell Version ────────────────────────────────────────
Section "PowerShell"
$psv = $PSVersionTable.PSVersion
$psed = $PSVersionTable.PSEdition
$psOK = ($psv.Major -ge 7)
Check 'PowerShell 7+ required' $(if ($psOK) { 'OK' } else { 'FAIL' }) "v$psv ($psed)"

if ($psOK) {
    $modPath = $env:PSModulePath -split [IO.Path]::PathSeparator
    $localMod = "$env:LOCALAPPDATA\PowerShell\Modules"
    if ($localMod -in $modPath) {
        Check 'PSModulePath (LOCALAPPDATA first)' 'OK' "$localMod"
    } else {
        Check 'PSModulePath (LOCALAPPDATA missing)' 'WARN' 'Will be fixed by profile.ps1'
    }
}

# ── Windows Terminal ───────────────────────────────────────────
Section "Windows Terminal"
# Get-AppxPackage comes from the Appx module, which is Windows PowerShell only —
# pwsh has no such cmdlet. An unguarded call printed a red "not recognized"
# error straight into this user-facing report on PS7 *and* then fell through to
# a false "WT not installed" WARN on machines where WT is plainly installed (the
# next check proves it, via WT's own settings.json). Probe Appx where it exists;
# otherwise fall back to the MSIX package directory / the wt.exe shim.
$wtInstalled = $false
if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    $wtInstalled = [bool](Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue)
}
if (-not $wtInstalled) {
    $wtInstalled = (Test-Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe") -or
                   [bool](Get-Command wt.exe -ErrorAction SilentlyContinue)
}
if ($wtInstalled) {
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

# Was $HOME\Projects\tools\.vscode\settings.json — the *pre-merge* dotfiles-tools clone path.
# That directory no longer exists anywhere, so this check reported WARN (and told the user to
# "Clone dotfiles-tools first", a repo that is now archived) on every correct install.
# Resolve it against this repo instead, using the script's own location.
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$vscSettings = Join-Path (Join-Path $repoRoot '.vscode') 'settings.json'
if (Test-Path $vscSettings) {
    Check 'Committed VS Code settings' 'OK'
} else {
    Check 'Committed VS Code settings' 'WARN' "Not found: $vscSettings"
}

# ── Dotfiles Profile State ────────────────────────────────────
Section "Dotfiles Profile"
$profilePaths = @(
    @{ N='PS7'; P="$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" },
    @{ N='PS7-VSCode'; P="$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1" }
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

# The main orchestrator lives at <repo>/profile/profile.ps1 (the monorepo root
# has no profile.ps1 of its own); the injected bootstrap dot-sources exactly
# that path under ~/.config/powershell. The old check looked one level too high
# (…/powershell/profile.ps1, which never exists) and so reported a permanent
# FAIL, with a hint pointing at the long-deleted dotfiles-powershell repo.
$mainProfile = Join-Path (Join-Path (Join-Path $HOME '.config') 'powershell') 'profile\profile.ps1'
if (Test-Path $mainProfile) {
    Check 'Main profile.ps1 exists' 'OK' $mainProfile
} else {
    Check 'Main profile.ps1 missing' 'FAIL' 'Install dotfiles to ~/.config/powershell — see install.ps1'
}

# ── Environment ────────────────────────────────────────────────
Section "Environment"
Check 'DOTFILES_PWSH'  $(if ($env:DOTFILES_PWSH) { 'OK' } else { 'WARN' }) $env:DOTFILES_PWSH
Check 'DOTFILES_TOOLS' $(if ($env:DOTFILES_TOOLS) { 'OK' } else { 'WARN' }) $env:DOTFILES_TOOLS
Check 'EDITOR'         $(if ($env:EDITOR) { 'OK' } else { 'INFO' }) $env:EDITOR

$toolsBin = Join-Path $HOME 'Projects\tools\bin'
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
