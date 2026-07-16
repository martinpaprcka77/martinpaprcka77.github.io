<#
.SYNOPSIS
    Aktualizuje dotfiles ekosystém na nejnovější verzi.
.DESCRIPTION
    Provede git pull, opraví bootstrap (self-heal — viz Invoke-BootstrapInjection)
    a nabídne restart PowerShell session. Bezpečné pro opakované spuštění.
.PARAMETER WhatIf
    Pouze zobrazí, co by se provedlo.
.EXAMPLE
    .\update.ps1
    .\update.ps1 -WhatIf
.NOTES
    Cesta: ~/.config/powershell/update.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$dotfilesPath = $PSScriptRoot
$updateNeeded = $false
$restartNeeded = $false

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'profile\lib\output.ps1')
. (Join-Path $PSScriptRoot 'profile\lib\paths.ps1')
. (Join-Path $PSScriptRoot 'profile\lib\bootstrap.ps1')

if (-not (Test-Path (Join-Path $dotfilesPath '.git'))) {
    Write-Fail "Not a git repo at $dotfilesPath. Run install.ps1 first."
    exit 1
}

Write-Step "Checking for updates..."

if ($PSCmdlet.ShouldProcess($dotfilesPath, 'git fetch && git status')) {
    try {
        Push-Location $dotfilesPath

        git fetch origin 2>&1 | Out-Null

        $defaultBranch = (git symbolic-ref refs/remotes/origin/HEAD 2>$null) -replace '^refs/remotes/origin/', ''
        if (-not $defaultBranch) {
            $defaultBranch = 'main'
            Write-Warn "Could not resolve default branch; assuming 'main'."
        }

        $behind = git rev-list "HEAD..origin/$defaultBranch" --count 2>&1
        if ($LASTEXITCODE -eq 0 -and [int]$behind -gt 0) {
            Write-Step "Pulling $([int]$behind) new commits..."
            git pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Updated: $([int]$behind) commits"
                $updateNeeded = $true
            } else {
                Write-Fail "Pull failed — try manual: cd $dotfilesPath; git pull"
            }
        }
        else {
            Write-Skip "Already up-to-date."
        }
    }
    catch {
        Write-Fail "Update failed: $_"
    }
    finally {
        Pop-Location
    }
}

# ── Self-heal bootstrap ────────────────────────────────────────
# Runs every time, not just when $updateNeeded — repairs a stale bootstrap
# snippet (e.g. still pointing at a pre-restructure path) even if this repo
# was already at the latest commit, so update.ps1 alone is enough to recover
# without needing to know to re-run install.ps1.
Write-Step "Checking bootstrap..."
if ($PSCmdlet.ShouldProcess('$PROFILE targets', 'Repair bootstrap if stale')) {
    $restartNeeded = (Invoke-BootstrapInjection) -or $restartNeeded
}

# ── If anything updated, rebootstrap ──────────────────────────
if ($updateNeeded) {
    Write-Step "Changes pulled — reloading profile..."

    $mainProfile = Join-Path $dotfilesPath 'profile\profile.ps1'
    if (Test-Path $mainProfile) {
        if ($PSCmdlet.ShouldProcess($mainProfile, 'Reload profile')) {
            try {
                . $mainProfile
                Write-Ok "Profile reloaded."
            } catch {
                Write-Fail "Profile reload failed: $_"
                Write-Host "  Tip: restart your PowerShell session to apply changes." -ForegroundColor Yellow
            }
        }
    }
}

if ($updateNeeded -or $restartNeeded) {
    Write-Host "`nUpdate complete!" -ForegroundColor Green
    Write-Host "  Dotfiles: $dotfilesPath" -ForegroundColor Gray
    if ($restartNeeded) {
        Write-Host "`nRestart your PowerShell session to apply changes." -ForegroundColor Yellow
    }
}
else {
    Write-Host "`nEverything is up-to-date." -ForegroundColor Green
}
