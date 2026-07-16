<#
.SYNOPSIS
    Generates a Windows Terminal JSON fragment extension (2026 recommended approach).
.DESCRIPTION
    Creates a fragment at %LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\
    instead of editing settings.json directly. This is Microsoft's recommended method
    since WT 1.24+. Safe, no comment-stripping needed, supports updates.
.PARAMETER WhatIf
    Pouze zobrazí, co by se provedlo, beze změn.
.PARAMETER Force
    Přepíše existující fragment.
.EXAMPLE
    .\Add-WTProfiles.ps1
    .\Add-WTProfiles.ps1 -WhatIf
    .\Add-WTProfiles.ps1 -Force
.NOTES
    Fragment location: %LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json
    Uses "updates" key to modify built-in PowerShell profiles.
    Cesta: ~/.config/powershell/toolkit/scripts/Add-WTProfiles.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
)

# Cross-platform guard
if ($IsLinux -or $IsMacOS) {
    Write-Error "Add-WTProfiles.ps1 requires Windows. This is a Linux/macOS system."
    exit 1
}

$ErrorActionPreference = 'Stop'

$fragmentDir = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles"
$fragmentPath = Join-Path $fragmentDir 'dotfiles.json'
# $env:DOTFILES_TOOLS is only ever set by the companion profile — this file
# lives inside its own repo root, so fall back to $PSScriptRoot when it isn't
# loaded (same pattern as lib/config.ps1 and menu/*.ps1).
$toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
$iconsDir = Join-Path $toolsRoot 'icons'

# Dot-source shared output helpers from profile/lib/output.ps1
. (Join-Path $PSScriptRoot '..\..\profile\lib\output.ps1')

# ── Check if already installed ─────────────────────────────────
if ((Test-Path $fragmentPath) -and -not $Force) {
    Write-Skip "Fragment already exists at: $fragmentPath"
    Write-Skip "Use -Force to overwrite."
    exit 0
}

# ── Determine icon paths (relative to fragment for WT 1.24+) ──
# WT 1.24+ resolves icons relative to fragment directory. For absolute paths,
# we still use full paths since we're generating from tools/scripts.
$icons = @{
    menu     = if (Test-Path (Join-Path $iconsDir 'menu.png'))     { Join-Path $iconsDir 'menu.png' }     else { $null }
    projects = if (Test-Path (Join-Path $iconsDir 'projects.png')) { Join-Path $iconsDir 'projects.png' } else { $null }
    pwsh7    = if (Test-Path (Join-Path $iconsDir 'pwsh7.png'))    { Join-Path $iconsDir 'pwsh7.png' }    else { $null }
    pwsh5    = if (Test-Path (Join-Path $iconsDir 'pwsh5.png'))    { Join-Path $iconsDir 'pwsh5.png' }    else { $null }
}

# ── WSL profiles (auto-detected) — must be computed BEFORE the
# fragment hashtable literal below, not inside it: PowerShell hashtable
# literals can only contain key=value pairs, not loose statements/control
# flow. (This was the root cause of a parse error that made this whole
# script unable to run at all — see git history.)
$wslProfiles = @()
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $distros = wsl -l -q 2>&1 | Where-Object { $_ -match '\S' -and $_ -notmatch 'Windows Subsystem' }
    foreach ($d in $distros) {
        $d = $d.Trim()
        if ($d) {
            $wslProfiles += @{
                name         = "WSL: $d"
                commandline  = "wsl.exe -d $d"
                startingDirectory = "//wsl$/Ubuntu/home"
                tabTitle     = "🐧 $d"
                font         = @{ face = 'CaskaydiaCove NF'; size = 12 }
                colorScheme  = 'One Half Dark'
                useAtlasEngine = $true
            }
        }
    }
    if ($wslProfiles.Count -gt 0) {
        Write-Host "  ℹ️  Detected $($wslProfiles.Count) WSL distro(s)" -ForegroundColor DarkGray
    }
}

$baseProfiles = @(
    # ── Custom profile: Menu ── (ours — safe to opt into shell integration)
    @{
        name         = 'Menu'
        commandline  = "pwsh.exe -NoExit -Command `"& '$toolsRoot\menu\menu-main.ps1'`""
        startingDirectory = $toolsRoot
        icon         = $icons.menu
        tabTitle     = 'Menu'
        suppressApplicationTitle = $true
        # Shell integration — show command marks in scrollbar. Fine here:
        # this is our own profile, not an override of the user's default.
        showMarksOnScrollbar = $true
        autoMarkPrompts = $true
    }
    # ── Custom profile: Projekty ── (ours — same reasoning)
    @{
        name         = 'Projekty'
        commandline  = 'pwsh.exe -NoExit'
        startingDirectory = Join-Path $HOME 'Projects\work'
        icon         = $icons.projects
        tabTitle     = 'Projekty'
        suppressApplicationTitle = $true
        showMarksOnScrollbar = $true
        autoMarkPrompts = $true
    }
    # ── Built-in profile updates (via "updates") ── deliberately minimal:
    # these entries match WT's actual built-in profile names, so fragment
    # "updates" semantics MERGE these settings into the user's existing
    # default profiles. Don't add shell-integration/cosmetic overrides
    # (font, colorScheme, scrollbar marks, ...) here — the user may have
    # already customized these defaults themselves; only icon/tabTitle are
    # safe, purely-additive identification aids.
    # Updates PowerShell 7 built-in profile
    @{
        name         = 'PowerShell 7'
        commandline  = 'pwsh.exe -NoExit'
        startingDirectory = $HOME
        icon         = $icons.pwsh7
        tabTitle     = 'PS 7'
    }
    # Updates Windows PowerShell 5.1 built-in profile
    @{
        name         = 'Windows PowerShell 5.1'
        commandline  = 'powershell.exe -NoExit'
        startingDirectory = $HOME
        icon         = $icons.pwsh5
        tabTitle     = 'PS 5'
    }
)

# ── Color schemes — read from configs/wt-schemes.json, the single source
# of truth (previously duplicated inline here, which is exactly the kind of
# drift risk that led to two copies going out of sync). Small inline
# fallback set only for the case the config file is missing/unreadable.
$schemesFile = Join-Path $toolsRoot 'configs\wt-schemes.json'
$schemes = if (Test-Path $schemesFile) {
    try {
        # PS5.1 compat: ConvertFrom-Json -AsHashtable is PS6.2+, use PSCustomObject directly
        (Get-Content $schemesFile -Raw | ConvertFrom-Json).schemes
    } catch {
        Write-Warning "Could not parse $schemesFile ($_) — using a minimal built-in fallback."
        $null
    }
}
if (-not $schemes) {
    $schemes = @(
        @{
            name = 'One Half Dark'
            black = '#282c34'; red = '#e06c75'; green = '#98c379'
            yellow = '#e5c07b'; blue = '#61afef'; purple = '#c678dd'
            cyan = '#56b6c2'; white = '#dcdfe4'
            brightBlack = '#282c34'; brightRed = '#e06c75'; brightGreen = '#98c379'
            brightYellow = '#e5c07b'; brightBlue = '#61afef'; brightPurple = '#c678dd'
            brightCyan = '#56b6c2'; brightWhite = '#dcdfe4'
            background = '#000000'; foreground = '#dcdfe4'
        }
    )
}

# ── Build fragment JSON ────────────────────────────────────────
$fragment = @{
    '$schema' = 'https://aka.ms/terminal-profiles-schema'
    profiles  = @($baseProfiles) + $wslProfiles
    schemes   = @($schemes)
}

# ── Save fragment ──────────────────────────────────────────────
if ($PSCmdlet.ShouldProcess($fragmentPath, 'Create JSON fragment')) {
    # Create directory
    if (-not (Test-Path $fragmentDir)) {
        New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
        Write-Ok "Created fragment directory: $fragmentDir"
    }

    # Back up existing fragment
    if (Test-Path $fragmentPath) {
        $backup = "$fragmentPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $fragmentPath $backup
        Write-Ok "Backup: $backup"
    }

    # Write without BOM (UTF-8)
    $json = $fragment | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($fragmentPath, $json, $utf8NoBom)
    Write-Ok "Fragment created: $fragmentPath"

    # Also save copy to scripts/ for reference
    $refPath = Join-Path $PSScriptRoot 'profiles-fragment.json'
    [System.IO.File]::WriteAllText($refPath, $json, $utf8NoBom)
    Write-Ok "Reference copy: $refPath"
}

# ── Result ─────────────────────────────────────────────────────
Write-Host "`nDone! Restart Windows Terminal to see the new profiles." -ForegroundColor Green
Write-Host "Fragment location: $fragmentPath" -ForegroundColor Gray
Write-Host "To remove: delete the fragment file and restart WT." -ForegroundColor Gray
