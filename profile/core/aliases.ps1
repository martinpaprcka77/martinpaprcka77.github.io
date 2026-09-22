<#
.SYNOPSIS
    Aliasy pro každodenní použití.
.DESCRIPTION
    Definice PowerShell aliasů. Načítá se z profile.ps1.
.NOTES
    Cesta: ~/.config/powershell/profile/core/aliases.ps1
#>

# Navigation
Set-Alias -Name ll  -Value Get-ChildItem -Force

# Edit profile
Set-Alias -Name ep  -Value Edit-Profile -Force

# Reload profile
# 'rp' is a built-in AllScope alias (Remove-ItemProperty) on Windows PowerShell 5.1 with
# Options=ReadOnly,AllScope. Set-Alias -Force cannot clear the AllScope option, so on 5.1 it
# throws "The AllScope option cannot be removed from the alias 'rp'" every time the profile
# loads (PS 7 does not mark it AllScope, so the same line was silent there — the bug only
# showed on 5.1). Remove the built-in first, exactly as done for gcm/gps below. This is
# session-scoped and does not change the system default.
Remove-Item Alias:rp -Force -ErrorAction SilentlyContinue
Set-Alias -Name rp  -Value Reload-Profile -Force

# Git shortcuts (if git is available)
if (Get-Command git -ErrorAction SilentlyContinue) {
    # gcm and gps collide with PowerShell's own built-in aliases
    # (Get-Command, Get-Process) — a built-in ALIAS always wins over a
    # same-named FUNCTION in PowerShell's command resolution, so without
    # this, `function gcm {...}`/`function gps {...}` below would silently
    # never be reachable (verified: calling gps invoked Get-Process, not
    # git push, with no error — a real bug that shipped for a while).
    # Removing the built-in alias here only affects this session, not the
    # system-wide default; it's what makes the functions below actually work.
    Remove-Item Alias:gcm -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:gps -Force -ErrorAction SilentlyContinue

    function g {
        [CmdletBinding()]
        param([Parameter(ValueFromRemainingArguments)]$GitArgs)
        git @GitArgs
    }
    function gst { git status @args }
    function gco { git checkout @args }
    function gbr { git branch @args }
    function gcm { git commit -m @args }
    function gpl { git pull @args }
    function gps { git push @args }
    function gdf { git diff @args }
    function glo { git log --oneline --graph --decorate -20 @args }
}

# Kubernetes shortcuts (if kubectl is available)
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    Set-Alias -Name k   -Value kubectl
    Set-Alias -Name kx  -Value kubectx -Force
    Set-Alias -Name kns -Value kubens -Force
}
