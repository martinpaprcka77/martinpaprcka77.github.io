<#
.SYNOPSIS
    Modernizes the PowerShell module stack — PSResourceGet, cleanup, security baseline.
.DESCRIPTION
    Removes legacy PowerShellGet 1.x and PackageManagement 1.0.0.1,
    sets PSResourceGet as default package provider, configures modern
    PSModulePath, installs baseline modules, and sets security defaults.
    Idempotent — safe to run multiple times.
.PARAMETER WhatIf
    Pouze zobrazí, co by se provedlo, beze změn.
.PARAMETER SkipCleanup
    Přeskočí mazání legacy modulů.
.PARAMETER SecurityOnly
    Pouze nastaví security baseline (ExecutionPolicy + trusted repo).
.EXAMPLE
    .\modernize.ps1
    .\modernize.ps1 -WhatIf
    .\modernize.ps1 -SecurityOnly
.NOTES
    Cesta: ~/Projects/tools/ops/modernize.ps1
    Vyžaduje PowerShell 7.2+. Některé operace vyžadují admin práva.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipCleanup,
    [switch]$SecurityOnly
)

$ErrorActionPreference = 'Continue'

Import-Module (Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1') -Force

function Write-Step { param([string]$M) Write-TkMessage -Level Step -Message $M }
function Write-Ok   { param([string]$M) Write-TkMessage -Level Ok   -Message $M }
function Write-Skip { param([string]$M) Write-TkMessage -Level Skip -Message $M }
function Write-Warn { param([string]$M) Write-TkMessage -Level Warn -Message $M }

Write-Host "`n🧹 POWERSHELL MODULE STACK MODERNIZATION" -ForegroundColor Magenta
Write-Host "   Target: PowerShell 7.6+ ready, PSResourceGet primary`n"

# ═══════════════════════════════════════════════════════════════
# 1. Clean up legacy modules
# ═══════════════════════════════════════════════════════════════
if (-not $SkipCleanup -and -not $SecurityOnly) {
    Write-Step "Removing legacy modules..."

    # Keep in sync with Toolkit/Public/Detectors.ps1's Test-LegacyPowerShellGetPresent —
    # that function checks the SAME path/modules to decide the menu's live
    # status icon; a mismatch here would mean the menu and this script could
    # disagree about whether legacy modules are present.
    $modulePath = "$env:ProgramFiles\PowerShell\7\Modules"

    $legacyModules = @(
        'PowerShellGet\1.0.0.1',
        'PackageManagement\1.0.0.1'
    )

    foreach ($lm in $legacyModules) {
        $full = Join-Path $modulePath $lm
        if (Test-Path $full) {
            if ($PSCmdlet.ShouldProcess($full, 'Remove legacy module')) {
                try {
                    Remove-Item $full -Recurse -Force -ErrorAction Stop
                    Write-Ok "Removed: $full"
                } catch {
                    Write-Warn "Cannot remove $full — may need admin rights"
                }
            }
        } else {
            Write-Skip "Already clean: $lm"
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# 2. PSResourceGet as default package provider
# ═══════════════════════════════════════════════════════════════
if (-not $SecurityOnly) {
    Write-Step "Configuring PSResourceGet as default..."

    # Remove legacy PowerShellGet package source
    try {
        Unregister-PackageSource -Name PSGallery -ProviderName PowerShellGet -ErrorAction SilentlyContinue
        Write-Skip "Legacy PSGallery package source removed"
    } catch { }

    # Register PSResourceGet as trusted
    try {
        if ($PSCmdlet.ShouldProcess('PSGallery', 'Set-PSResourceRepository -Trusted')) {
            Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue
            Write-Ok "PSGallery trusted via PSResourceGet"
        }
    } catch {
        Write-Warn "Could not set PSResourceGet trusted: $_"
    }
}

# ═══════════════════════════════════════════════════════════════
# 3. Modern PSModulePath
# ═══════════════════════════════════════════════════════════════
if (-not $SecurityOnly) {
    Write-Step "Configuring modern PSModulePath..."

    # LOCALAPPDATA, not Documents — Documents is a Known-Folder redirection
    # target (OneDrive) and is exactly the pollution Reset-PSModulePath and
    # Test-PSModulePath warn about. Keep this in sync with Toolkit/Public/ModulePath.ps1.
    $modernPath = @(
        "$env:ProgramFiles\PowerShell\7\Modules",
        "$env:LOCALAPPDATA\PowerShell\Modules"
    ) -join [IO.Path]::PathSeparator

    if ($PSCmdlet.ShouldProcess('PSModulePath', 'Set modern priority')) {
        $env:PSModulePath = $modernPath
        Write-Ok "PSModulePath set (current session)"
        Write-Host "  To persist, add to profile: `$env:PSModulePath = '$modernPath'" -ForegroundColor DarkGray
    }
}

# ═══════════════════════════════════════════════════════════════
# 4. Modern baseline modules
# ═══════════════════════════════════════════════════════════════
if (-not $SecurityOnly) {
    Write-Step "Installing modern baseline modules..."

    $baselineModules = @(
        @{ Name = 'PSReadLine';                           Reason = 'Interactive shell' },
        @{ Name = 'Pester';                               Reason = 'Testing framework' },
        @{ Name = 'Microsoft.PowerShell.PSResourceGet';   Reason = 'Modern package manager' }
    )

    foreach ($m in $baselineModules) {
        $installed = Get-Module -ListAvailable -Name $m.Name -ErrorAction SilentlyContinue
        if ($installed) {
            Write-Skip "$($m.Name) already installed"
        } else {
            if ($PSCmdlet.ShouldProcess($m.Name, "Install-PSResource")) {
                try {
                    Install-PSResource -Name $m.Name -TrustRepository -Scope AllUsers -ErrorAction Stop
                    Write-Ok "Installed: $($m.Name) — $($m.Reason)"
                } catch {
                    Write-Warn "Failed: $($m.Name) — try: Install-PSResource $($m.Name) -TrustRepository"
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# 5. Security baseline
# ═══════════════════════════════════════════════════════════════
Write-Step "Configuring security baseline..."

if ($PSCmdlet.ShouldProcess('ExecutionPolicy', 'Set RemoteSigned')) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    Write-Ok "ExecutionPolicy: RemoteSigned (CurrentUser)"
}

# Ensure PSResourceGet repository is trusted (idempotent)
try {
    Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue
    Write-Skip "PSGallery already trusted"
} catch { }

# Telemetry opt-out for privacy
[System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
Write-Ok "Telemetry: opted out"

# ═══════════════════════════════════════════════════════════════
# 6. Disable legacy PowerShellGet auto-load
# ═══════════════════════════════════════════════════════════════
if (-not $SecurityOnly) {
    Write-Step "Disabling legacy PowerShellGet auto-load..."
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    $legacyGuard = 'Remove-Module PowerShellGet -ErrorAction SilentlyContinue'

    if ($profileContent -and $profileContent -match [regex]::Escape($legacyGuard)) {
        Write-Skip "Legacy guard already in profile"
    } else {
        if ($PSCmdlet.ShouldProcess($PROFILE, 'Add legacy guard')) {
            Add-Content $PROFILE "`n# Disable legacy PowerShellGet`n$legacyGuard"
            Write-Ok "Legacy guard added to profile"
        }
    }
}

# ═══════════════════════════════════════════════════════════════
Write-Host "`n✅ MODERNIZATION COMPLETE" -ForegroundColor Green
Write-Host "   Restart PowerShell to apply all changes." -ForegroundColor Yellow
Write-Host "`n   Verify:  Get-PSResourceRepository" -ForegroundColor DarkGray
Write-Host "   Modules:  Get-InstalledPSResource" -ForegroundColor DarkGray
