<#
.SYNOPSIS
    Known-Folder-correct path resolution for install.ps1.
.DESCRIPTION
    Resolve-DocumentsPath / Test-RootedPath / Get-NativeProfilePaths — used
    only by install.ps1 (dot-sourced from there, not part of the
    profile-loading chain and not auto-loaded like core/*.ps1). OneDrive can
    redirect Documents away from a naive $HOME\Documents assumption; the 4
    native $PROFILE paths install.ps1 injects a bootstrap snippet into all
    live under Documents, so getting this right matters there specifically.
    (~/.config/powershell and ~/Projects/tools are NOT Known-Folder
    redirection targets — OneDrive only redirects
    Desktop/Documents/Pictures/Music/Videos — so nothing else in this
    ecosystem needs this.)

    Every Documents-source candidate is validated with Test-RootedPath
    before use — a real-world corrupted Known Folder registry value
    (`User Shell Folders\Personal` = `%C:\Users\x%\Documents`, seen on a
    machine with a broken OneDrive Known Folder Move migration) survives
    ExpandEnvironmentVariables unchanged and would otherwise crash Join-Path
    with "Cannot find drive" further down the chain.
.NOTES
    Cesta: ~/.config/powershell/profile/lib/paths.ps1
#>

<#
.SYNOPSIS
    Resolves the real (possibly OneDrive-redirected) Documents folder.
.DESCRIPTION
    Reuses PowerShell's own already-correct $PROFILE.CurrentUserAllHosts —
    the engine itself resolves Documents internally to compute $PROFILE, so
    this piggybacks on that instead of re-implementing Known-Folder lookup.
    Falls back to .NET's SpecialFolder API, then a direct registry read, for
    the rare case $PROFILE isn't populated (should not normally happen —
    it's always set by the engine, even non-interactively).
#>
function Resolve-DocumentsPath {
    [CmdletBinding()]
    param()
    $fallback = Join-Path $HOME 'Documents'

    $candidate = $null
    if ($PROFILE -and $PROFILE.CurrentUserAllHosts) {
        # .../Documents/PowerShell/... (PS7) or .../Documents/WindowsPowerShell/... (PS5.1)
        $candidate = Split-Path (Split-Path $PROFILE.CurrentUserAllHosts -Parent) -Parent
    }
    if (-not (Test-RootedPath $candidate)) {
        try {
            $p = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
            if (Test-RootedPath $p) { $candidate = $p }
        } catch { }
    }
    if (-not (Test-RootedPath $candidate)) {
        try {
            $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Personal -ErrorAction Stop).Personal
            # Expand a well-formed %VAR%\... template; a still-unrooted result here
            # (e.g. a malformed literal like '%C:\Users\x%\Documents' — seen in the
            # wild from broken OneDrive Known Folder Move migrations, where
            # ExpandEnvironmentVariables can't match anything and returns it
            # unchanged) falls through to the plain $HOME\Documents fallback below.
            if ($v) { $v = [Environment]::ExpandEnvironmentVariables($v) }
            if (Test-RootedPath $v) { $candidate = $v }
        } catch { }
    }
    if (Test-RootedPath $candidate) { return $candidate }
    return $fallback
}

<#
.SYNOPSIS
    True if $Path is a real rooted filesystem path (drive-letter or UNC) —
    not $null/empty and not a leftover '%...%' placeholder that Known-Folder
    resolution failed to expand.
#>
function Test-RootedPath {
    param([string]$Path)
    return $Path -and ($Path -match '^[A-Za-z]:\\' -or $Path -match '^\\\\') -and ($Path -notmatch '%')
}

<#
.SYNOPSIS
    Returns the 4 native $PROFILE paths install.ps1 injects a bootstrap
    snippet into, built from the real (Known-Folder-correct) Documents path.
#>
function Get-NativeProfilePaths {
    [CmdletBinding()]
    param()
    $docs = Resolve-DocumentsPath
    $ps7Dir = Join-Path $docs 'PowerShell'
    $ps5Dir = Join-Path $docs 'WindowsPowerShell'
    @(
        Join-Path $ps7Dir 'Microsoft.PowerShell_profile.ps1'
        Join-Path $ps7Dir 'Microsoft.VSCode_profile.ps1'
        Join-Path $ps5Dir 'Microsoft.PowerShell_profile.ps1'
        Join-Path $ps5Dir 'Microsoft.VSCode_profile.ps1'
    )
}
