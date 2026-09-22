<#
.SYNOPSIS
    Verifies that the canonical Gists and configured repositories are in sync.
.DESCRIPTION
    Read-only check. For each canonical Gist (Install, Cheatsheet,
    MasterPrompt, ModularProfile) it compares the remote description and the
    exact remote file set against the canonical local sources. For the
    repository itself and every -RepoPath it fetches the upstream default
    remote and reports whether HEAD matches the upstream branch and the
    working tree is clean. Never modifies anything; exits 0 when all checks
    pass, 1 when any check fails.
.PARAMETER RepoPath
    Additional local repository paths to check, besides this repository.
.EXAMPLE
    .\tools\Verify-Sync.ps1
    .\tools\Verify-Sync.ps1 -RepoPath D:\aios,C:\Users\x\GitHub\PaprckoviSvatba2026
#>
[CmdletBinding()]
param(
    [string[]]$RepoPath = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'gist-sources.ps1')

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required and must be available on PATH.'
}
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI authentication is required. Run: gh auth login'
}

$failed = $false

# --- Gist checks ----------------------------------------------------------

foreach ($item in Get-CanonicalGists) {
    $response = gh api "gists/$($item.Id)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[DIFF] $($item.Name) — unable to query gist: $($response -join ' ')" -ForegroundColor Yellow
        $failed = $true
        continue
    }
    $remote = $response | ConvertFrom-Json

    $issues = New-Object System.Collections.Generic.List[string]

    if ($remote.description -cne $item.Description) {
        $issues.Add('description differs')
    }

    $remoteFiles = $remote.files
    foreach ($name in @($item.Files.Keys)) {
        $remoteProp = $remoteFiles.PSObject.Properties[$name]
        if ($null -eq $remoteProp) {
            $issues.Add("missing remote file '$name'")
        }
        elseif ($remoteProp.Value.content -cne $item.Files[$name]) {
            $issues.Add("content differs in '$name'")
        }
    }

    foreach ($remoteProp in $remoteFiles.PSObject.Properties) {
        if ($remoteProp.Name -notin @($item.Files.Keys)) {
            $issues.Add("unexpected remote file '$($remoteProp.Name)'")
        }
    }

    if ($issues.Count -gt 0) {
        Write-Host "[DIFF] $($item.Name) — $($issues -join '; ')" -ForegroundColor Yellow
        $failed = $true
    }
    else {
        Write-Host "[OK] $($item.Name) — $($item.Files.Keys.Count) file(s), description matches" -ForegroundColor Green
    }
}

# --- Repository checks ----------------------------------------------------

$extra = @()
foreach ($arg in @($RepoPath)) {
    $extra += @($arg -split ',')
}
$paths = New-Object System.Collections.Generic.List[string]
foreach ($candidate in @($repoRoot) + $extra) {
    $full = [IO.Path]::GetFullPath($candidate)
    if (-not $paths.Contains($full)) {
        $paths.Add($full)
    }
}

foreach ($repoPath in $paths) {
    if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
        Write-Host "[DIFF] $repoPath — path does not exist" -ForegroundColor Yellow
        $failed = $true
        continue
    }

    $fetchErr = git -C $repoPath fetch --quiet origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[DIFF] $repoPath — git fetch origin failed: $($fetchErr -join ' ')" -ForegroundColor Yellow
        $failed = $true
        continue
    }

    $branch = (git -C $repoPath rev-parse --abbrev-ref HEAD) 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[DIFF] $repoPath — not a git repository" -ForegroundColor Yellow
        $failed = $true
        continue
    }
    if ($branch -eq 'HEAD') {
        Write-Host "[DIFF] $repoPath — detached HEAD" -ForegroundColor Yellow
        $failed = $true
        continue
    }

    $local = (git -C $repoPath rev-parse HEAD) 2>$null
    $upstream = (git -C $repoPath rev-parse '@{u}') 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[DIFF] $repoPath — branch '$branch' has no upstream" -ForegroundColor Yellow
        $failed = $true
        continue
    }

    $porcelain = @(git -C $repoPath status --porcelain 2>$null)
    $dirty = $porcelain.Count
    $aheadRaw = (git -C $repoPath rev-list --count "@{u}..HEAD") 2>$null
    $behindRaw = (git -C $repoPath rev-list --count "HEAD..@{u}") 2>$null
    $ahead = if ($aheadRaw) { [int]$aheadRaw } else { 0 }
    $behind = if ($behindRaw) { [int]$behindRaw } else { 0 }

    $details = New-Object System.Collections.Generic.List[string]
    if ($dirty -gt 0) { $details.Add("$dirty uncommitted change(s)") }
    if ($ahead -gt 0) { $details.Add("ahead by $ahead") }
    if ($behind -gt 0) { $details.Add("behind by $behind") }

    if ($details.Count -gt 0) {
        Write-Host "[DIFF] $repoPath — ${branch}: $($details -join '; ')" -ForegroundColor Yellow
        $failed = $true
    }
    else {
        Write-Host "[OK] $repoPath — $branch, clean, in sync" -ForegroundColor Green
    }
}

# --- Summary ---------------------------------------------------------------

if ($failed) {
    Write-Host ''
    Write-Host 'Verify-Sync: FAILED — differences found.' -ForegroundColor Red
    exit 1
}
Write-Host ''
Write-Host 'Verify-Sync: OK — everything in sync.' -ForegroundColor Green
exit 0
