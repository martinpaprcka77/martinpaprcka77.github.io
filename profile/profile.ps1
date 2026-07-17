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
# $PSVersionTable.OS exists in PS5.1 and PS7, and correctly reports non-Windows
# even on PS5.1 running under Wine (the old $isPSCore/{$IsWindows}/else pattern
# would return $true for any PS5.1 regardless of host OS).
$isWindowsHost = $PSVersionTable.OS -match 'Windows'
#endregion

#region Environment setup
# Resolve-Path + ProviderPath canonicalizes symlinks: if the profile repo
# is accessed through a symlink, $MyInvocation.MyCommand.Path gives the
# symlink path, but we want the real target so that relative references
# (..\toolkit\lib, etc.) resolve correctly regardless of how the repo
# was reached.
$env:DOTFILES_PWSH = (Resolve-Path $MyInvocation.MyCommand.Path).ProviderPath |
    Split-Path -Parent
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
    # Trim each entry — PSModulePath can accumulate stray spaces from
    # registry concatenation or manual edits, which silently break -in/-notin.
    $paths = $env:PSModulePath -split [IO.Path]::PathSeparator |
        ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($localModules -notin $paths) {
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
    # Sort-Object Name ensures deterministic load order — Get-ChildItem
    # on some filesystems (FAT, exFAT, network shares) may not return
    # files alphabetically, and function definitions must not race.
    Get-ChildItem -Path $coreDir -Filter *.ps1 | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}
#endregion

#region Version-specific profile
function Load-Script($path) {
    if (Test-Path $path) { . $path }
}
$psVersionDir = if ($isPSCore) { "ps7" } else { "ps5" }
Load-Script (Join-Path $env:DOTFILES_PWSH "$psVersionDir\profile.ps1")
#endregion

#region Host-specific profile
$hostName = if ($Host.Name -match 'Code') { 'VSCode' } else { 'ConsoleHost' }
Load-Script (Join-Path $env:DOTFILES_PWSH "hosts\$hostName.ps1")
#endregion

#region Benchmark output
if ($profileStart) {
    $profileStart.Stop()
    Write-Host "Profile loaded in $($profileStart.ElapsedMilliseconds)ms" -ForegroundColor DarkGray
}
#endregion
