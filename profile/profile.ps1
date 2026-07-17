<#
.SYNOPSIS
    Hlavní PowerShell profil (PS7-only, Windows).
.DESCRIPTION
    Dot-sourcuje core/*.ps1, ps7/profile.ps1 a hostitelský profil.
    Nastavuje PSModulePath mimo OneDrive.
.NOTES
    Cesta: ~/.config/powershell/profile/profile.ps1
#>

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

# Fix PSModulePath – add LOCALAPPDATA first to avoid OneDrive.
$localModules = "$env:LOCALAPPDATA\PowerShell\Modules"
$paths = $env:PSModulePath -split [IO.Path]::PathSeparator |
    ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($localModules -notin $paths) {
    $env:PSModulePath = "$localModules$([IO.Path]::PathSeparator)$env:PSModulePath"
}
#endregion

#region Benchmark
# Cheap total-time timer. For a step-by-step breakdown, use Measure-Profile
# (core/perf.ps1). For ETW-level detail (module loads, JIT), use
# Measure-PSCommand (core/diag.ps1, Windows-only).
$profileStart = if ($env:PROFILE_BENCHMARK -eq 'true') { [Diagnostics.Stopwatch]::StartNew() } else { $null }
#endregion

#region Shared path resolution
. (Join-Path $env:DOTFILES_PWSH 'lib\paths.ps1')
#endregion

#region Core modules
$coreDir = Join-Path $env:DOTFILES_PWSH "core"
if (Test-Path $coreDir) {
    Get-ChildItem -Path $coreDir -Filter *.ps1 | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}
#endregion

#region PS7 profile
function Load-Script($path) {
    if (Test-Path $path) { . $path }
}
Load-Script (Join-Path $env:DOTFILES_PWSH "ps7\profile.ps1")
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
