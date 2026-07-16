<#
.SYNOPSIS
    Configures Windows system defaults — Explorer, privacy, taskbar, bloatware removal.
.DESCRIPTION
    Sets sensible defaults via registry tweaks. All changes are reversible.
    Idempotent — safe to run multiple times. Requires admin for some operations.
.PARAMETER WhatIf
    Pouze zobrazí, co by se nastavilo.
.PARAMETER SkipPrivacy
    Přeskočí nastavení privacy (telemetrie, reklamy).
.PARAMETER RemoveBloatware
    Odstraní běžný bloatware (Candy Crush, Xbox, Skype, atd.).
.EXAMPLE
    .\windows.ps1
    .\windows.ps1 -WhatIf
    .\windows.ps1 -RemoveBloatware
.NOTES
    Cesta: ~/.config/powershell/toolkit/scripts/windows.ps1
    Některé operace vyžadují administrátorská práva.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipPrivacy,
    [switch]$RemoveBloatware
)

# Cross-platform guard — registry and AppX are Windows-only
if ($IsLinux -or $IsMacOS) {
    Write-Error "windows.ps1 requires Windows (registry + AppX). This is a Linux/macOS system."
    exit 1
}

function Write-Step { param([string]$M) Write-Host "==> $M" -ForegroundColor Cyan }
function Write-Ok   { param([string]$M) Write-Host "  [+] $M" -ForegroundColor Green }
function Write-Skip { param([string]$M) Write-Host "  [=] $M" -ForegroundColor Gray }
function Write-Info { param([string]$M) Write-Host "  [*] $M" -ForegroundColor DarkGray }

# ── Explorer settings ──────────────────────────────────────────
Write-Step "Configuring Explorer..."

$explorerSettings = @(
    # Show hidden files and extensions
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden';         Value = 1;  Type = 'DWord' }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt';    Value = 0;  Type = 'DWord' }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSuperHidden'; Value = 1;  Type = 'DWord' }
    # Show full path in title bar
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'; Name = 'FullPath'; Value = 1; Type = 'DWord' }
    # Launch Explorer to "This PC" instead of "Quick Access"
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo'; Value = 1; Type = 'DWord' }
    # Disable "Recent Files" in Quick Access
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowRecent'; Value = 0; Type = 'DWord' }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowFrequent'; Value = 0; Type = 'DWord' }
    # Show file operations details
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarFileOperationsDetail'; Value = 1; Type = 'DWord' }
)

foreach ($setting in $explorerSettings) {
    $current = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
    if ($current.($setting.Name) -eq $setting.Value) {
        Write-Skip "$($setting.Name) = $($setting.Value) (already set)"
    } else {
        if ($PSCmdlet.ShouldProcess($setting.Path, "Set $($setting.Name) = $($setting.Value)")) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type
            Write-Ok "$($setting.Name) = $($setting.Value)"
        }
    }
}

# ── Taskbar settings ───────────────────────────────────────────
Write-Step "Configuring Taskbar..."
$taskbarSettings = @(
    # Taskbar alignment: left (0 = left, 1 = center)
    # ⚠️ Undocumented registry keys — may change in future Windows builds
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; Value = 0; Type = 'DWord' }
    # Hide search box (0 = hidden, 1 = icon, 2 = box)
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0; Type = 'DWord' }
    # Hide Task View button
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Value = 0; Type = 'DWord' }
    # Hide Widgets
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; Value = 0; Type = 'DWord' }
    # Hide Chat/Copilot taskbar icon
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarMn'; Value = 0; Type = 'DWord' }
)

foreach ($setting in $taskbarSettings) {
    $current = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
    if ($current.($setting.Name) -eq $setting.Value) {
        Write-Skip "$($setting.Name) = $($setting.Value) (already set)"
    } else {
        if ($PSCmdlet.ShouldProcess($setting.Path, "Set $($setting.Name) = $($setting.Value)")) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type
            Write-Ok "$($setting.Name) = $($setting.Value)"
        }
    }
}

# ── Privacy settings ───────────────────────────────────────────
if (-not $SkipPrivacy) {
    Write-Step "Configuring Privacy..."
    $privacySettings = @(
        # Disable telemetry (0 = Security only, 1 = Basic, 2 = Enhanced, 3 = Full)
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord' }
        # Disable advertising ID
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Type = 'DWord' }
        # Disable tailored experiences
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0; Type = 'DWord' }
        # Disable website tracking
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; Type = 'DWord' }
    )
    foreach ($setting in $privacySettings) {
        try {
            $current = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction Stop
            if ($current.($setting.Name) -eq $setting.Value) {
                Write-Skip "Privacy: $($setting.Name) (already set)"
            } else {
                if ($PSCmdlet.ShouldProcess($setting.Path, "Set $($setting.Name) = $($setting.Value)")) {
                    Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -ErrorAction Stop
                    Write-Ok "Privacy: $($setting.Name) = $($setting.Value)"
                }
            }
        } catch {
            Write-Skip "Privacy: $($setting.Name) — requires admin (skip)"
        }
    }
}

# ── Bloatware removal ──────────────────────────────────────────
if ($RemoveBloatware) {
    Write-Step "Removing bloatware..."
    $bloatware = @(
        'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp',
        'Microsoft.Getstarted', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.MixedReality.Portal', 'Microsoft.Office.OneNote', 'Microsoft.People',
        'Microsoft.SkypeApp', 'Microsoft.Wallet', 'Microsoft.WindowsAlarms',
        'Microsoft.WindowsCamera', 'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps',
        'Microsoft.Xbox.TCUI', 'Microsoft.XboxApp', 'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay',
        'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo',
        'king.com.CandyCrushSaga', 'SpotifyAB.SpotifyMusic', 'Disney.37853FC22B2CE'
    )
    foreach ($app in $bloatware) {
        $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
        if ($pkg) {
            if ($PSCmdlet.ShouldProcess($app, 'Remove-AppxPackage')) {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                Write-Ok "Removed: $app"
            }
        } else {
            Write-Skip "Not installed: $app"
        }
    }
}

# ── Done ───────────────────────────────────────────────────────
Write-Host "`nWindows defaults configured!" -ForegroundColor Green
Write-Host "Some changes require Explorer restart or logoff to take effect." -ForegroundColor Yellow
# This prompt is outside every per-setting ShouldProcess check above, so it
# must respect $WhatIfPreference explicitly — a -WhatIf run must never
# actually kill Explorer, even if the user answers 'y' at this prompt.
if ($WhatIfPreference) {
    Write-Host "What if: Restart Explorer now? (skipped — -WhatIf)" -ForegroundColor Cyan
} else {
    $restart = Read-Host "Restart Explorer now? ⚠️ This closes ALL Explorer windows. (y/N)"
    if ($restart -eq 'y') {
        Stop-Process -Name explorer -Force
        Write-Host "Explorer restarted." -ForegroundColor Green
    }
}
