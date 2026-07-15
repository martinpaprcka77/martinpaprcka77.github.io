<#
.SYNOPSIS
    Hlavní PowerShell profil – modulární, verzovaný, přenositelný.
.DESCRIPTION
    Detekuje verzi PowerShellu (5/7) a hostitele (ConsoleHost, VSCode),
    dot-sourcuje odpovídající skripty a nastavuje prostředí mimo OneDrive.
.NOTES
    Cesta: ~/.config/powershell/profile/profile.ps1
#>

#region Environment detection
# Detect once, reuse everywhere below — the PS-version check was previously
# duplicated (once for the PSModulePath fix, once for the ps5/ps7 split).
# Windows Terminal presence ($env:WT_SESSION) is deliberately NOT resolved
# here even though it's a real environment-detection question too: nothing
# at this level branches on it — only hosts/ConsoleHost.ps1 (-> wtprofile.ps1)
# and ps7/profile.ps1 (-> shell-integration.ps1) actually need it, so each
# checks $env:WT_SESSION itself where it's used. See docs/ARCHITECTURE.md for
# the full picture of where each environment check actually happens.
$isPSCore      = $PSVersionTable.PSVersion.Major -ge 6
$isWindowsHost = if ($isPSCore) { $IsWindows } else { $true }  # $IsWindows doesn't exist on PS5.1
#endregion

#region Environment setup
$env:DOTFILES_PWSH = Split-Path -Parent $MyInvocation.MyCommand.Path
# Monorepo: profile/ and toolkit/ are siblings under one root — derive
# DOTFILES_TOOLS from DOTFILES_PWSH's parent instead of a separate clone.
$env:DOTFILES_TOOLS = Join-Path (Split-Path $env:DOTFILES_PWSH -Parent) "toolkit"

# Fix PSModulePath on Windows – add LOCALAPPDATA first to avoid OneDrive.
# Applies to BOTH PS5.1 and PS7: Documents\WindowsPowerShell\Modules (PS5.1)
# is exactly as OneDrive-affected as Documents\PowerShell\Modules (PS7) — a
# previous version of this fix only covered PS7. Separate subfolder names
# per version (PowerShell vs WindowsPowerShell) since PS5.1/PS7 modules
# aren't always cross-compatible; sharing one directory would be wrong.
# Meaningless off-Windows ($env:LOCALAPPDATA doesn't exist there), hence the
# explicit $isWindowsHost guard rather than relying on that being empty.
if ($isWindowsHost) {
    $localModulesSubdir = if ($isPSCore) { 'PowerShell' } else { 'WindowsPowerShell' }
    $localModules = "$env:LOCALAPPDATA\$localModulesSubdir\Modules"
    if ($localModules -notin ($env:PSModulePath -split [IO.Path]::PathSeparator)) {
        $env:PSModulePath = "$localModules$([IO.Path]::PathSeparator)$env:PSModulePath"
    }
}
#endregion

#region Benchmark
# Cheap total-time timer. For a step-by-step breakdown, use Measure-Profile
# (core/perf.ps1). For ETW-level detail (module loads, JIT), use
# Measure-PSCommand (core/diag.ps1, Windows-only).
$profileStart = if ($env:PROFILE_BENCHMARK -eq 'true') { [Diagnostics.Stopwatch]::StartNew() } else { $null }
#endregion

#region Shared path resolution
# Get-NativeProfilePaths (Known-Folder-correct) is used by install.ps1 and
# by core/status.ps1's bootstrap-presence check — load it here so both see
# the same function, rather than each re-deriving Documents paths.
. (Join-Path $env:DOTFILES_PWSH 'lib\paths.ps1')
#endregion

#region Core modules
$coreDir = Join-Path $env:DOTFILES_PWSH "core"
if (Test-Path $coreDir) {
    Get-ChildItem -Path $coreDir -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}
#endregion

#region Version-specific profile
$psVersionDir = if ($isPSCore) { "ps7" } else { "ps5" }
$versionProfile = Join-Path $env:DOTFILES_PWSH "$psVersionDir\profile.ps1"
if (Test-Path $versionProfile) {
    . $versionProfile
}
#endregion

#region Host-specific profile
$hostName = if ($Host.Name -match 'Code') { 'VSCode' } else { 'ConsoleHost' }
$hostProfile = Join-Path $env:DOTFILES_PWSH "hosts\$hostName.ps1"
if (Test-Path $hostProfile) {
    . $hostProfile
}
#endregion

#region Benchmark output
if ($profileStart) {
    $profileStart.Stop()
    Write-Host "Profile loaded in $($profileStart.ElapsedMilliseconds)ms" -ForegroundColor DarkGray
}
#endregion
