<#
.SYNOPSIS
    One-command remote bootstrapper — safe to run via `irm <raw-url> | iex`.
.DESCRIPTION
    Clones (or updates) the dotfiles monorepo (profile + toolkit), then hands
    off to its own install.ps1, which does everything else (inject the
    native $PROFILE bootstrap at the real Known-Folder-correct Documents
    location, PATH setup). This script's own job is deliberately minimal —
    just enough to get install.ps1 onto disk and running, so there is
    exactly one implementation of the clone/bootstrap-inject/idempotency
    logic, not two.

    Cannot dot-source lib/output.ps1 or lib/paths.ps1 — this script's whole
    job is to fetch the repo they live in (chicken/egg), so it carries a
    minimal inline copy of the Write-* helpers, same as bootstrap.ps1
    already does for the same reason. Do not "simplify" this into a
    dot-source of lib/output.ps1 — it would break the one supported
    invocation this script exists for (irm | iex, no local clone yet).

    -Force/-NoUpdates/-WhatIf aren't reachable through `iex`
    (it executes script text, no CLI param binding) — use the
    $env:DOTFILES_* toggles below, or download this file first for full
    parameter parity via a normal invocation.
    SupportsShouldProcess is declared for PARAMETER BINDING ONLY (so -WhatIf is
    actually accepted instead of being silently swallowed into $args by a
    param()-only script). This script deliberately never calls
    $PSCmdlet.ShouldProcess: $PSCmdlet is $null when it runs via
    `Invoke-Expression` (the whole point of this file), where calling
    ShouldProcess throws rather than silently skipping. -WhatIf therefore aborts
    before the first state-changing step (see below) rather than gating each one.
    install.ps1 (which this hands off to) has full ShouldProcess/-WhatIf support
    for per-step dry runs.
.PARAMETER Force
    Forwarded to install.ps1 -Force.
.PARAMETER NoUpdates
    Forwarded to install.ps1 -NoUpdates.
.PARAMETER WhatIf
    Common parameter (from SupportsShouldProcess). Aborts before cloning or
    updating anything and reports what would have happened.
.EXAMPLE
    # Already in PowerShell (5.1 or 7+):
    irm https://raw.githubusercontent.com/martinpaprcka77/martinpaprcka77.github.io/main/remote-install.ps1 | iex

    # From cmd.exe, bash-on-Windows, or any shell with a PowerShell host on PATH:
    powershell -c "irm https://raw.githubusercontent.com/martinpaprcka77/martinpaprcka77.github.io/main/remote-install.ps1 | iex"

    # From a Linux/macOS shell with pwsh installed:
    pwsh -c "irm https://raw.githubusercontent.com/martinpaprcka77/martinpaprcka77.github.io/main/remote-install.ps1 | iex"

    # Passing options through iex (env-var toggles, since -Force etc. aren't reachable):
    $env:DOTFILES_FORCE=1; irm https://raw.githubusercontent.com/martinpaprcka77/martinpaprcka77.github.io/main/remote-install.ps1 | iex
.NOTES
    Cesta: ~/.config/powershell/remote-install.ps1
    No PowerShell installed at all (Linux/macOS): this cannot help you get
    started — there is no PowerShell-free path in. Install PowerShell first:
    https://aka.ms/install-powershell
#>
# Note: #Requires is silently ignored when this script runs via `irm | iex`
# (Invoke-Expression evaluates text, not a script file — verified empirically:
# no error, no enforcement, just a no-op). It DOES enforce for the documented
# alternative invocation ("download this file first for full parameter
# parity"), so it's kept here for that path — harmless either way.
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$NoUpdates
)

# Inline, minimal — see the chicken/egg note above. Kept deliberately tiny;
# this is NOT the place to add features, that's what lib/output.ps1 is for
# once install.ps1 takes over.
function Write-Step { param([string]$M) Write-Host "==> $M" -ForegroundColor Cyan }
function Write-Ok   { param([string]$M) Write-Host "  [+] $M" -ForegroundColor Green }
function Write-Skip { param([string]$M) Write-Host "  [=] $M" -ForegroundColor Gray }
function Write-Fail { param([string]$M) Write-Host "  [x] $M" -ForegroundColor Red }
function Write-Warn { param([string]$M) Write-Host "  [!] $M" -ForegroundColor Yellow }

# Env-var toggles — the only way to pass options through `irm | iex`, which
# executes script text with no CLI param binding. Real -Force/-NoUpdates
# switches above still work for direct (non-iex) invocation.
if ($env:DOTFILES_FORCE)      { $Force = $true }
if ($env:DOTFILES_NO_UPDATES) { $NoUpdates = $true }

# `exit` under `irm | iex` does not merely end this script — it tears down the
# HOST, so a failed bootstrap closed the user's console window instead of
# showing them the message (verified: `iex 'exit 7'` exits the process with code
# 7 and the statement after it never runs). A top-level `return` ends only this
# script and leaves the session alive, so `exit` is used solely when this file
# was really invoked as a file, where a non-zero exit code means something to
# the caller ($MyInvocation.MyCommand.Path is $null under `Invoke-Expression`).
$invokedAsFile = [bool]$MyInvocation.MyCommand.Path

# $IsWindows is PS6+ only; on PS5.1 it doesn't exist and $PSVersionTable has no
# .OS key. Guard on version: PS5.1 is always Windows, PS7+ uses real $IsWindows.
# (No Set-StrictMode here, so a "$PSVersionTable.OS -match 'Windows'" form would
# silently return $false on PS5.1 rather than throw — the try/catch wouldn't save it.)
$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

Write-Step "PowerShell Dotfiles Ecosystem — remote bootstrap"

$dotfilesUrl = 'https://github.com/martinpaprcka77/martinpaprcka77.github.io.git'
$homeRoot = if ($HOME) { $HOME } else { $env:USERPROFILE }
if (-not $homeRoot) {
    Write-Fail 'Could not determine the user home directory ($HOME or USERPROFILE).'
    if ($invokedAsFile) { exit 1 } else { return }
}
$dotfilesPath = Join-Path (Join-Path $homeRoot '.config') 'powershell'

# Bail out before even requiring git: -WhatIf must be a genuine no-op. Deliberately
# after $dotfilesPath exists so the message can name the target, and before the
# clone/update. (Under `irm | iex` there is no -WhatIf to bind — see .NOTES — so
# this branch is reachable only on the direct-invocation path.)
if ($WhatIfPreference) {
    Write-Warn "-WhatIf: nothing was changed. This bootstrap would have:"
    Write-Warn "  - cloned or fast-forward updated $dotfilesPath"
    Write-Warn "  - handed off to its install.ps1"
    Write-Warn "For a per-step dry run, clone it first and run 'install.ps1 -WhatIf'."
    if ($invokedAsFile) { exit 0 } else { return }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail "git is required but not found on PATH. Install it first: https://git-scm.com/downloads"
    if ($invokedAsFile) { exit 1 } else { return }
}

$isRepo = Test-Path (Join-Path $dotfilesPath '.git')
if ($isRepo) {
    try {
        Push-Location $dotfilesPath
        # A pre-merge install still has 'origin' pointing at one of the OLD
        # repos (dotfiles-powershell / dotfiles-tools) — a plain `git pull`
        # there only fast-forwards within THAT repo's own (now-frozen,
        # README-pointer-only) history, so this directory's install.ps1 silently
        # stays the stale pre-merge version forever (field-reported: kept
        # running the old two-repo installer even after this bootstrapper itself
        # was fetched fresh from the new repo). Detect ONLY that specific case by
        # matching the old repo names — NOT any origin that merely differs from
        # $dotfilesUrl, which would also catch a legitimate SSH clone
        # (git@github.com:...) or a fork of THIS repo and hard-reset it, blowing
        # away the user's remote choice and any local commits. Re-point +
        # hard-sync only the genuine pre-merge case. User customizations live in
        # untracked files (see core/extra.ps1.example) and survive a hard reset.
        $currentOrigin = (git remote get-url origin 2>$null)
        if ($currentOrigin -and $currentOrigin -match 'dotfiles-powershell|dotfiles-tools') {
            Write-Warn "Existing install points at a pre-merge repo ($currentOrigin) — migrating to $dotfilesUrl"
            git remote set-url origin $dotfilesUrl 2>&1 | Out-Null
            git fetch origin 2>&1 | Out-Null
            git reset --hard origin/main 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Migrated: $dotfilesPath -> $dotfilesUrl" }
            else { Write-Fail "Migration failed for $dotfilesPath — remove it and re-run this bootstrap." }
        } else {
            Write-Step "Updating $dotfilesPath..."
            git pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Updated: $dotfilesPath" }
            else { Write-Fail "git pull failed in $dotfilesPath — continuing with the existing local copy" }
        }
    } catch {
        Write-Fail "Update failed: $_"
    } finally {
        Pop-Location
    }
} else {
    if (Test-Path $dotfilesPath) {
        Write-Fail "Directory exists but is not a git repo: $dotfilesPath"
        Write-Fail "Move or remove it, then re-run this bootstrap."
        if ($invokedAsFile) { exit 1 } else { return }
    }
    Write-Step "Cloning $dotfilesUrl to $dotfilesPath..."
    $parent = Split-Path $dotfilesPath -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    git clone $dotfilesUrl $dotfilesPath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Clone failed for $dotfilesUrl"
        if ($invokedAsFile) { exit 1 } else { return }
    }
    Write-Ok "Cloned: $dotfilesPath"
}

if (-not $isWindowsHost) {
    Write-Skip "PS5.1-without-pwsh guidance and Windows Terminal setup don't apply off-Windows."
}

# ── Hand off — install.ps1 does everything else (native $PROFILE bootstrap
# injection at the real Known-Folder-correct location, PATH setup) exactly
# once, not duplicated here.
$installScript = Join-Path $dotfilesPath 'install.ps1'
if (-not (Test-Path $installScript)) {
    Write-Fail "install.ps1 not found at $installScript — clone may have failed."
    if ($invokedAsFile) { exit 1 } else { return }
}

Write-Step "Handing off to install.ps1..."
$forwardedArgs = @{}
if ($Force) { $forwardedArgs.Force = $true }
if ($NoUpdates) { $forwardedArgs.NoUpdates = $true }
# No -WhatIf forwarding: the script already returned above when
# $WhatIfPreference is set, so it can never reach this line with -WhatIf on.

& $installScript @forwardedArgs
