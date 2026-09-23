<#
.SYNOPSIS
    Snapshot of the current shell: host, user, environment, PATH, profiles.
.DESCRIPTION
    One local-only object describing how this session is configured:

      Shell       — host, terminal, PowerShell version/edition, $PSHOME
      User        — user name, machine, admin?
      Env         — notable environment variables (EDITOR, DOTFILES_*, TOOLKIT_*)
      Profiles    — the four $PROFILE tiers
      DotSources  — which of those profile files actually exist (get dot-sourced)
      Path        — PATH entry count, duplicates, and missing directories

    No network I/O. Explicit output object; no global state — safe to call from
    tests and from the menus.
.EXAMPLE
    Get-ShellInfo
.EXAMPLE
    (Get-ShellInfo).Path.Duplicates
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/ShellInfo.ps1
#>
function Get-ShellInfo {
    [CmdletBinding()]
    param()

    # ── Shell ──────────────────────────────────────────────────
    $terminal = 'console'
    if ($env:WT_SESSION) { $terminal = 'Windows Terminal' }
    elseif ($env:TERM_PROGRAM) { $terminal = [string]$env:TERM_PROGRAM }
    $shell = [pscustomobject]@{
        Host      = $Host.Name
        Terminal  = $terminal
        PSVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition = [string]$PSVersionTable.PSEdition
        PSHome    = $PSHOME
    }

    # ── User ───────────────────────────────────────────────────
    $isAdmin = $false
    if ($IsWindows) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
                IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch { Write-Debug "admin check failed: $_" }
    }
    $user = [pscustomobject]@{
        Name    = [System.Environment]::UserName
        Machine = [System.Environment]::MachineName
        IsAdmin = $isAdmin
    }

    # ── Environment (notable variables only) ───────────────────
    $names = @('EDITOR', 'PAGER', 'DOTFILES_PWSH', 'DOTFILES_TOOLS', 'PROFILE_BENCHMARK', 'WT_SESSION', 'TERM_PROGRAM')
    $names += @(Get-ChildItem -Path Env: | Where-Object { $_.Name -like 'TOOLKIT_*' } | Select-Object -ExpandProperty Name)
    $envMap = [ordered]@{}
    foreach ($name in ($names | Select-Object -Unique)) {
        $value = [System.Environment]::GetEnvironmentVariable($name)
        if ($value) { $envMap[$name] = $value }
    }

    # ── Profiles + actual dot-sources ──────────────────────────
    $tiers = [ordered]@{
        AllUsersAllHosts       = [string]$PROFILE.AllUsersAllHosts
        AllUsersCurrentHost    = [string]$PROFILE.AllUsersCurrentHost
        CurrentUserAllHosts    = [string]$PROFILE.CurrentUserAllHosts
        CurrentUserCurrentHost = [string]$PROFILE.CurrentUserCurrentHost
    }
    $profiles = [ordered]@{}
    $dotSources = [System.Collections.Generic.List[string]]::new()
    foreach ($tier in $tiers.Keys) {
        $path = $tiers[$tier]
        $exists = Test-Path -LiteralPath $path
        $profiles[$tier] = [pscustomobject]@{ Path = $path; Exists = $exists }
        if ($exists) { $dotSources.Add($path) }
    }

    # ── PATH ───────────────────────────────────────────────────
    $entries = @($env:PATH -split [IO.Path]::PathSeparator | Where-Object { $_ })
    $duplicates = @($entries | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name)
    $missing = @($entries | Where-Object { -not (Test-Path -LiteralPath $_) })
    $pathInfo = [pscustomobject]@{
        Count      = $entries.Count
        Duplicates = $duplicates
        Missing    = $missing
        Entries    = $entries
    }

    [pscustomobject]@{
        Shell      = $shell
        User       = $user
        Env        = [pscustomobject]$envMap
        Profiles   = [pscustomobject]$profiles
        DotSources = $dotSources
        Path       = $pathInfo
    }
}
