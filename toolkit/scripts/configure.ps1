<#
.SYNOPSIS
    Interaktivní průvodce nastavením dotfiles ekosystému.
.DESCRIPTION
    Krok za krokem provede uživatele konfigurací:
    - Výběr menu položek k zobrazení
    - Barevné schéma
    - Povolení/zakázání systémových kontrol
    - Nastavení editoru
    Výsledek uloží do configs/settings.json.
.PARAMETER Reset
    Vrátí konfiguraci na výchozí hodnoty.
.EXAMPLE
    .\configure.ps1
    .\configure.ps1 -Reset
.NOTES
    Cesta: ~/.config/powershell/toolkit/scripts/configure.ps1
#>
[CmdletBinding()]
param(
    [switch]$Reset
)

$modulePath = Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1'
if (Test-Path $modulePath) { Import-Module $modulePath -Force }

Write-Host "`n  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host   "  ║   DOTFILES CONFIGURATION WIZARD      ║" -ForegroundColor Cyan
Write-Host   "  ╚══════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($Reset) {
    if (-not (Confirm-Action "This overwrites configs/settings.json with defaults, discarding your current settings. Continue?")) {
        Write-Host "Reset cancelled." -ForegroundColor Yellow
        return
    }
    $default = @{
        menu   = @{ theme = 'default'; showHeader = $true; colorScheme = 'cyan' }
        docker = @{ defaultCommand = 'ps'; autoRefresh = $false }
        system = @{ checkDisks = $true; checkServices = $true; checkNetwork = $true; checkProcesses = $true }
    }
    Save-ToolkitConfig -Config $default
    Write-Host "Configuration reset to defaults." -ForegroundColor Green
    return
}

$cfg = Get-ToolkitConfig

# ── Step 1: Color scheme ──────────────────────────────────────
Write-Host "1. Color scheme:" -ForegroundColor White
$schemes = @('cyan', 'green', 'magenta', 'blue', 'yellow', 'white')
for ($i = 0; $i -lt $schemes.Count; $i++) {
    $marker = if ($schemes[$i] -eq $cfg.menu.colorScheme) { ' (*)' } else { '' }
    Write-Host "   $($i+1). $($schemes[$i])$marker"
}
$choice = Read-Host "   Choice (1-$($schemes.Count), Enter=keep)"
if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $schemes.Count) {
    $cfg.menu.colorScheme = $schemes[[int]$choice - 1]
}

# ── Step 2: Menu header ───────────────────────────────────────
$choice = Read-Host "`n2. Show menu header? (y/N, Enter=keep)"
if ($choice -eq 'y') { $cfg.menu.showHeader = $true }
elseif ($choice -eq 'n') { $cfg.menu.showHeader = $false }

# ── Step 3: System checks ─────────────────────────────────────
Write-Host "`n3. Enable system checks:" -ForegroundColor White
$checks = @('checkDisks', 'checkServices', 'checkNetwork', 'checkProcesses')
$labels = @('Disks', 'Services', 'Network', 'Processes')
for ($i = 0; $i -lt $checks.Count; $i++) {
    $current = if ($cfg.system[$checks[$i]]) { 'Y' } else { 'N' }
    $choice = Read-Host "   $($labels[$i])? (y/N, Enter=$current)"
    if ($choice -eq 'y') { $cfg.system[$checks[$i]] = $true }
    elseif ($choice -eq 'n') { $cfg.system[$checks[$i]] = $false }
}

# ── Step 4: Editor ────────────────────────────────────────────
$currentEditor = if ($env:EDITOR) { $env:EDITOR } else { 'not detected' }
$choice = Read-Host "`n4. Default editor (current: $currentEditor, Enter=keep)"
if ($choice) { $env:EDITOR = $choice }

# ── Step 5: Prompt theme (oh-my-posh) ────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $choice = Read-Host "`n5. Enable oh-my-posh prompt? (y/N, Enter=keep)"
    if ($choice -eq 'y') {
        $env:TOOLKIT_OMP_ENABLED = 'true'
        Write-Host "   Enabled. Restart to apply." -ForegroundColor Green
    }
    elseif ($choice -eq 'n') {
        $env:TOOLKIT_OMP_ENABLED = 'false'
    }
}

# ── Save ──────────────────────────────────────────────────────
Save-ToolkitConfig -Config $cfg
Write-Host "`nConfiguration saved! Restart your session to apply." -ForegroundColor Green
