<#
.SYNOPSIS
    Installs all dependencies for the PowerShell Dotfiles Ecosystem via winget.
.DESCRIPTION
    Idempotent — skips already-installed packages. Installs: Git, PowerShell 7,
    Windows Terminal, VS Code, oh-my-posh, Cascadia Code Nerd Font,
    PSReadLine, Terminal-Icons, PSFzf, Pester, and more.
.PARAMETER WhatIf
    Pouze zobrazí, co by se nainstalovalo.
.PARAMETER Minimal
    Nainstaluje pouze nezbytné minimum (Git, PowerShell 7, WT).
.EXAMPLE
    .\deps.ps1
    .\deps.ps1 -Minimal
    .\deps.ps1 -WhatIf
.NOTES
    Cesta: ~/.config/powershell/toolkit/scripts/deps.ps1
    Vyžaduje winget (součást Windows 10 1809+ / Windows 11).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Minimal
)

# Cross-platform guard — winget is Windows-only
if ($PSVersionTable.PSVersion.Major -ge 6 -and ($IsLinux -or $IsMacOS)) {
    Write-Error "deps.ps1 requires Windows (winget). This is a Linux/macOS system."
    exit 1
}

$ErrorActionPreference = 'Continue'
$script:installed = 0; $script:skipped = 0; $script:failed = 0

function Write-Step { param([string]$M) Write-Host "==> $M" -ForegroundColor Cyan }
function Write-Ok   { param([string]$M) Write-Host "  [+] $M" -ForegroundColor Green;  $script:installed++ }
function Write-Skip { param([string]$M) Write-Host "  [=] $M" -ForegroundColor Gray;   $script:skipped++ }
function Write-Fail { param([string]$M) Write-Host "  [x] $M" -ForegroundColor Red;    $script:failed++ }

function Install-Pkg {
    param([string]$Id, [string]$Name, [string]$ExtraArgs)
    Write-Step "$Name ($Id)..."
    # Local var named distinctly from $script:installed (the summary counter
    # Write-Ok increments) — same name here previously shadowed it, harmless
    # but confusing since $script:installed++ still worked via explicit scope.
    $found = winget list --id $Id --exact 2>&1 | Select-String $Id
    if ($found) {
        Write-Skip "Already installed: $Name"
        return
    }
    if ($PSCmdlet.ShouldProcess($Id, "winget install")) {
        $wingetArgs = @('install', '--id', $Id, '--exact', '--silent', '--accept-source-agreements', '--accept-package-agreements')
        if ($ExtraArgs) { $wingetArgs += $ExtraArgs.Split(' ') }
        winget @wingetArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Installed: $Name" }
        else { Write-Fail "Failed: $Name — try manually: winget install --id $Id" }
    }
}

# ── Core tools (always) ────────────────────────────────────────
Write-Host "`n--- CORE TOOLS ---" -ForegroundColor Magenta
Install-Pkg -Id 'Git.Git'                 -Name 'Git'
Install-Pkg -Id 'Microsoft.PowerShell'    -Name 'PowerShell 7'
Install-Pkg -Id 'Microsoft.WindowsTerminal' -Name 'Windows Terminal'

if ($Minimal) {
    Write-Host "`n=== DEPENDENCIES SUMMARY ===" -ForegroundColor Magenta
    Write-Host "  Installed: $script:installed  Skipped: $script:skipped  Failed: $script:failed"
    return
}

# ── Development tools ──────────────────────────────────────────
Write-Host "`n--- DEVELOPMENT ---" -ForegroundColor Magenta
Install-Pkg -Id 'Microsoft.VisualStudioCode' -Name 'VS Code'

# ── Shell enhancement ──────────────────────────────────────────
Write-Host "`n--- SHELL ENHANCEMENT ---" -ForegroundColor Magenta
Install-Pkg -Id 'Starship.Starship' -Name 'Starship prompt (Rust, cross-shell)'
Install-Pkg -Id 'ajeetdsouza.zoxide' -Name 'zoxide (smart directory jumper)'
# oh-my-posh alternative (fallback): Install-Pkg -Id 'JanDeDobbeleer.OhMyPosh' -Name 'oh-my-posh'

# ── Fonts ──────────────────────────────────────────────────────
Write-Host "`n--- FONTS ---" -ForegroundColor Magenta

$fontName = 'CaskaydiaCove NF'
$fontRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$alreadyInstalled = Get-ItemProperty -Path $fontRegPath -Name "*$fontName*" -ErrorAction SilentlyContinue

if ($alreadyInstalled) {
    Write-Skip "Cascadia Code Nerd Font already installed"
} else {
    Write-Step "Installing Cascadia Code Nerd Font (Caskaydia Cove NF)..."
    if ($PSCmdlet.ShouldProcess('Cascadia Code Nerd Font', 'Download and install')) {
        try {
            $fontZip = Join-Path $env:TEMP 'CascadiaCodeNF.zip'
            $fontDir = Join-Path $env:TEMP 'CascadiaCodeNF'

            # Download latest Nerd Font patched Cascadia Code
            $nfUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip'
            Write-Host "  Downloading from $nfUrl ..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $nfUrl -OutFile $fontZip -UseBasicParsing

            # Extract
            Expand-Archive -Path $fontZip -DestinationPath $fontDir -Force

            # Install all .ttf files
            $ttfFiles = Get-ChildItem -Path $fontDir -Filter '*.ttf' -Recurse
            $fontCollection = New-Object -ComObject Shell.Application
            foreach ($ttf in $ttfFiles) {
                $fontCollection.Namespace(0x14).CopyHere($ttf.FullName, 0x10)
            }
            Write-Ok "Installed $($ttfFiles.Count) font files (Cascadia Code Nerd Font)"
        } catch {
            Write-Fail "Font install failed: $_"
            Write-Host "  Manual install: https://github.com/ryanoasis/nerd-fonts/releases/latest" -ForegroundColor Yellow
        } finally {
            # finally (not just the happy-path cleanup that used to sit inside
            # try) — otherwise a throw from Invoke-WebRequest/Expand-Archive
            # leaves the temp zip/dir behind.
            Remove-Item $fontZip -ErrorAction SilentlyContinue
            Remove-Item $fontDir -Recurse -ErrorAction SilentlyContinue
        }
    }
}

# ── PowerShell modules ─────────────────────────────────────────
Write-Host "`n--- POWERSHELL MODULES ---" -ForegroundColor Magenta
$modules = @(
    @{ Name = 'PSReadLine';        MinVersion = '2.3.6' },
    @{ Name = 'Terminal-Icons';    MinVersion = '0.11.0' },
    @{ Name = 'PSFzf';             MinVersion = '2.5.0' },
    @{ Name = 'Pester';            MinVersion = '5.7.0' }
)

foreach ($m in $modules) {
    $existing = Get-Module -ListAvailable -Name $m.Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($existing -and $existing.Version -ge [version]$m.MinVersion) {
        Write-Skip "Already installed: $($m.Name) v$($existing.Version)"
    } else {
        Write-Step "Installing: $($m.Name)..."
        if ($PSCmdlet.ShouldProcess($m.Name, 'Install module')) {
            try {
                if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
                    Install-PSResource -Name $m.Name -TrustRepository -ErrorAction Stop
                } elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
                    Install-Module -Name $m.Name -Force -Scope CurrentUser -ErrorAction Stop
                } else {
                    throw 'No package manager available. Install PowerShellGet or PSResourceGet.'
                }
                Write-Ok "Installed: $($m.Name)"
            } catch {
                Write-Fail "Failed: $($m.Name) — $_"
            }
        }
    }
}

# ── Summary ────────────────────────────────────────────────────
Write-Host "`n=== DEPENDENCIES SUMMARY ===" -ForegroundColor Magenta
Write-Host "  Installed: $script:installed  Skipped: $script:skipped  Failed: $script:failed"
if ($script:failed -gt 0) {
    Write-Host "  Some items failed. Re-run or install manually." -ForegroundColor Yellow
}
Write-Host "`nNext: run ~/.config/powershell/install.ps1 to set up profiles." -ForegroundColor Cyan
