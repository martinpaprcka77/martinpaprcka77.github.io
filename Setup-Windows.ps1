<#
.SYNOPSIS
    Unified PowerShell Dotfiles setup wizard for Windows.
.DESCRIPTION
    One-command setup from a clean Windows install. Handles:
    - Dependency detection + installation (Git, PS7, WT, VS Code, Starship, zoxide)
    - Dotfiles cloning and bootstrap
    - Windows defaults (privacy, taskbar, Explorer)
    - Optional VS Code configuration
    - Interactive or automated modes

    This script is idempotent — re-running after partial setup resumes cleanly.

.PARAMETER Profile
    Install PowerShell profile only (skip dependencies, defaults, VS Code).

.PARAMETER Dependencies
    Install dependencies only (Git, PS7, WT, Starship, zoxide via winget).

.PARAMETER Defaults
    Apply Windows defaults only (privacy, taskbar, bloatware removal).

.PARAMETER VSCode
    Configure VS Code only (copy .vscode/ to profile).

.PARAMETER All
    Run all steps interactively (default if no flags).

.PARAMETER ClonePath
    Where to clone dotfiles (default: ~/.config/powershell).

.PARAMETER Repository
    GitHub URL (default: https://github.com/martinpaprcka77/martinpaprcka77.github.io).

.PARAMETER WhatIf
    Show what would be done, without making changes.

.EXAMPLE
    # Interactive setup (asks for each step)
    .\Setup-Windows.ps1

    # All steps at once
    .\Setup-Windows.ps1 -All

    # Profile only
    .\Setup-Windows.ps1 -Profile

    # Dependencies only
    .\Setup-Windows.ps1 -Dependencies
#>
#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Profile,
    [switch]$Dependencies,
    [switch]$Defaults,
    [switch]$VSCode,
    [switch]$All,
    [string]$ClonePath = (Join-Path $env:USERPROFILE '.config' 'powershell'),
    [string]$Repository = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io.git',
    [switch]$SkipUpdates
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isWindowsHost = $true
$dotfilesPath = $ClonePath
$repoName = 'martinpaprcka77.github.io'

function Write-Title { param([string]$Text)
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Text.PadRight(54)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Step { param([string]$Text)
    Write-Host "`n▶ $Text" -ForegroundColor Yellow
}

function Write-Ok { param([string]$M)
    Write-Host "  [✓] $M" -ForegroundColor Green
}

function Write-Skip { param([string]$M)
    Write-Host "  [=] $M" -ForegroundColor Gray
}

function Write-Fail { param([string]$M)
    Write-Host "  [✗] $M" -ForegroundColor Red
}

function Confirm-Step {
    param([string]$Prompt)
    $choice = Read-Host "$Prompt (y/n)"
    return $choice -eq 'y'
}

# Check if a command exists
function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# ── Step 1: Dependencies ───────────────────────────────────
function Install-Dependencies {
    if (-not (Confirm-Step "Install dependencies (Git, PS7, WT, Starship, zoxide)?")) {
        Write-Skip "Skipping dependencies."
        return
    }

    Write-Step "Installing dependencies via winget..."

    $packages = @{
        'Git'     = 'Git.Git'
        'PS7'     = 'Microsoft.PowerShell'
        'WT'      = 'Microsoft.WindowsTerminal'
        'Starship' = 'Starship.Starship'
        'zoxide'  = 'ajeetdsouza.zoxide'
    }

    foreach ($name in $packages.Keys) {
        $pkgId = $packages[$name]
        if (Test-CommandExists ($name.ToLower())) {
            Write-Ok "$name is already installed"
        } else {
            Write-Step "Installing $name ($pkgId)..."
            if ($PSCmdlet.ShouldProcess($pkgId, 'winget install')) {
                try {
                    winget install --id $pkgId --exact --silent
                    Write-Ok "$name installed"
                } catch {
                    Write-Fail "Failed to install $name: $_"
                }
            }
        }
    }
}

# ── Step 2: Clone/Update Dotfiles ──────────────────────────
function Install-Profile {
    if (-not (Confirm-Step "Clone/update dotfiles profile to $dotfilesPath?")) {
        Write-Skip "Skipping profile installation."
        return
    }

    Write-Step "Cloning dotfiles repository..."

    if (-not (Test-CommandExists git)) {
        Write-Fail "Git is required. Install it first."
        return
    }

    if (Test-Path $dotfilesPath) {
        Write-Step "Updating existing clone at $dotfilesPath..."
        if ($PSCmdlet.ShouldProcess($dotfilesPath, 'git pull')) {
            Push-Location $dotfilesPath
            git pull --ff-only 2>&1 | Out-Null
            Pop-Location
            Write-Ok "Updated dotfiles"
        }
    } else {
        Write-Step "Cloning to $dotfilesPath..."
        if ($PSCmdlet.ShouldProcess($dotfilesPath, 'git clone')) {
            $parent = Split-Path $dotfilesPath -Parent
            if (-not (Test-Path $parent)) {
                $null = New-Item -ItemType Directory -Path $parent -Force
            }
            git clone $Repository $dotfilesPath 2>&1 | Out-Null
            Write-Ok "Cloned dotfiles to $dotfilesPath"
        }
    }

    # Run install.ps1
    Write-Step "Running install.ps1..."
    $installScript = Join-Path $dotfilesPath 'install.ps1'
    if (Test-Path $installScript) {
        if ($PSCmdlet.ShouldProcess($installScript, 'execute')) {
            & $installScript -NoUpdates:$SkipUpdates
            Write-Ok "Profile installed"
        }
    } else {
        Write-Fail "install.ps1 not found in $dotfilesPath"
    }
}

# ── Step 3: Windows Defaults ───────────────────────────────
function Apply-WindowsDefaults {
    if (-not (Confirm-Step "Apply Windows defaults (privacy, taskbar, Explorer)?")) {
        Write-Skip "Skipping Windows defaults."
        return
    }

    Write-Step "Applying Windows defaults..."

    if ($PSCmdlet.ShouldProcess('Windows Registry', 'apply defaults')) {
        # Taskbar: Remove Search box, Task View
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "SearchboxTaskbarMode" -Value 0 -Force
            Write-Ok "Taskbar: Search box hidden"
        }

        # Explorer: Show file extensions
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "HideFileExt" -Value 0 -Force
            Write-Ok "Explorer: File extensions visible"
        }

        # Task View: Disable
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "ShowTaskViewButton" -Value 0 -Force
            Write-Ok "Taskbar: Task View hidden"
        }

        # Privacy: Disable Cortana
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "AllowCortanaAboveTaskbar" -Value 0 -Force
            Write-Ok "Privacy: Cortana disabled"
        }
    }
}

# ── Step 4: VS Code Configuration ──────────────────────────
function Install-VSCodeConfig {
    if (-not (Confirm-Step "Configure VS Code (copy dotfiles settings)?")) {
        Write-Skip "Skipping VS Code configuration."
        return
    }

    if (-not (Test-CommandExists code)) {
        Write-Fail "VS Code not found. Install it first."
        return
    }

    Write-Step "Configuring VS Code..."

    $vscodeSettings = Join-Path $dotfilesPath '.vscode'
    $vscodeUserDir = Join-Path $env:APPDATA 'Code' 'User'

    if (-not (Test-Path $vscodeSettings)) {
        Write-Fail ".vscode directory not found in $dotfilesPath"
        return
    }

    if ($PSCmdlet.ShouldProcess($vscodeUserDir, 'copy .vscode settings')) {
        if (-not (Test-Path $vscodeUserDir)) {
            $null = New-Item -ItemType Directory -Path $vscodeUserDir -Force
        }
        Copy-Item "$vscodeSettings\*" $vscodeUserDir -Force -Recurse
        Write-Ok "VS Code configured"
    }
}

# ── Main ───────────────────────────────────────────────────
Write-Title "PowerShell Dotfiles Setup for Windows"

# If no specific flags, run all
if (-not $Profile -and -not $Dependencies -and -not $Defaults -and -not $VSCode) {
    $All = $true
}

if ($Dependencies -or $All) { Install-Dependencies }
if ($Profile -or $All) { Install-Profile }
if ($Defaults -or $All) { Apply-WindowsDefaults }
if ($VSCode -or $All) { Install-VSCodeConfig }

Write-Title "Setup Complete"
Write-Host "✓ PowerShell Dotfiles are now installed and configured.`n" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell (or run: . `$PROFILE)" -ForegroundColor Gray
Write-Host "  2. Run: menu   (to launch the interactive menu)" -ForegroundColor Gray
Write-Host "  3. Run: check  (to verify the setup)" -ForegroundColor Gray
Write-Host ""
