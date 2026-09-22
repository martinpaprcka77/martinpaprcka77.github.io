<#
.SYNOPSIS
    Synchronizes the repository's public Gists from canonical local sources.
.DESCRIPTION
    Updates the existing Gist IDs in place through the authenticated GitHub CLI.
    The command is idempotent, supports -WhatIf, and never removes remote files
    unless -Prune is explicitly requested.
.PARAMETER WhatIf
    Shows planned changes without updating GitHub.
.PARAMETER Prune
    Removes remote Gist files not present in the canonical source mapping.
.PARAMETER Gist
    Limits synchronization to one or more configured Gist names.
.EXAMPLE
    .\tools\Update-Gists.ps1 -WhatIf
    .\tools\Update-Gists.ps1
    .\tools\Update-Gists.ps1 -Gist MasterPrompt
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Prune,
    [ValidateSet('Install', 'Cheatsheet', 'MasterPrompt', 'ModularProfile')]
    [string[]]$Gist
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

$configured = Get-CanonicalGists
$selected = if ($Gist) {
    @($configured | Where-Object { $_.Name -in $Gist })
} else {
    @($configured)
}

foreach ($item in $selected) {
    $remote = gh api "gists/$($item.Id)" | ConvertFrom-Json
    $changes = [ordered]@{}

    foreach ($file in $item.Files.Keys) {
        $localContent = [string]$item.Files[$file]
        $remoteFile = $remote.files.$file
        if ($null -eq $remoteFile -or $remoteFile.content -cne $localContent) {
            $changes[$file] = $localContent
        }
    }

    if ($Prune) {
        foreach ($remoteName in @($remote.files.PSObject.Properties.Name)) {
            if ($remoteName -notin $item.Files.Keys) {
                $changes[$remoteName] = $null
            }
        }
    }

    $descriptionChanged = $remote.description -cne $item.Description
    if ($changes.Count -eq 0 -and -not $descriptionChanged) {
        Write-Host "[=] $($item.Name): already current" -ForegroundColor DarkGray
        continue
    }

    Write-Host "[*] $($item.Name): $($changes.Keys -join ', ')" -ForegroundColor Cyan
    if (-not $PSCmdlet.ShouldProcess($item.Id, "Update Gist $($item.Name)")) {
        continue
    }

    $payload = [ordered]@{ description = $item.Description; files = [ordered]@{} }
    foreach ($file in $changes.Keys) {
        $payload.files[$file] = if ($null -eq $changes[$file]) { $null } else { [ordered]@{ content = $changes[$file] } }
    }
    $json = $payload | ConvertTo-Json -Depth 5 -Compress
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("gist-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
        $null = gh api --method PATCH "gists/$($item.Id)" --input $tmp
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update $($item.Name) ($($item.Id))."
        }
        Write-Host "[+] $($item.Name): updated" -ForegroundColor Green
    }
    finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}
