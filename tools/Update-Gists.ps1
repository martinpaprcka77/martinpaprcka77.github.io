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

function Get-CanonicalGists {
    $promptPath = Join-Path (Join-Path $repoRoot 'docs') 'PROMPT.md'
    $prompt = Get-Content -LiteralPath $promptPath -Raw
    $currentPrompt = [regex]::Match(
        $prompt,
        '(?s)## Aktuální prompt — jeden repozitář\s*(?<content>.*?)(?=\r?\n## Historický původní prompt)'
    )
    if (-not $currentPrompt.Success) {
        throw "Could not extract the current prompt from $promptPath."
    }

    $remoteInstallPath = Join-Path $repoRoot 'remote-install.ps1'
    $profileRoot = Join-Path $repoRoot 'profile'
    $aliasesPath = Join-Path (Join-Path $profileRoot 'core') 'aliases.ps1'
    $envPath = Join-Path (Join-Path $profileRoot 'core') 'env.ps1'
    $profileLoaderPath = Join-Path $profileRoot 'profile.ps1'
    $cheatsheet = @'
# PowerShell Dotfiles — Cheat Sheet

## Quick Commands
| Command | Action |
|---------|--------|
| `menu` | Interactive main menu |
| `check` | Full system diagnostics |
| `status` | Global health dashboard |
| `precheck` | Pre-install inventory |
| `update` | Git pull latest + self-heal profile |
| `configure` | Interactive setup wizard |
| `modernize` | PSResourceGet migration |

## Profile
| Command | Action |
|---------|--------|
| `ep` | Edit profile |
| `rp` | Reload profile |
| `Show-Status` | Global health dashboard |
| `Measure-Profile` | Profile timing |
| `Test-PathHealth` | Validate configured paths |

## Git and Docker aliases
`g` `gst` `gco` `gbr` `gcm` `gpl` `gps` `gdf` `glo`

`dps` `dpsa` `dcu` `dcd`

## Repositories
- https://github.com/martinpaprcka77/martinpaprcka77.github.io
- https://martinpaprcka77.github.io
- https://martinpaprcka77.github.io/prompts.html
'@

    @(
        [ordered]@{
            Name = 'Install'
            Id = 'bafc2457fd9d93daf1b1b69c348e0cfd'
            Description = 'PowerShell Dotfiles Ecosystem — one-liner bootstrap install'
            Files = [ordered]@{
                'bootstrap.ps1' = Get-Content -LiteralPath $remoteInstallPath -Raw
            }
        }
        [ordered]@{
            Name = 'Cheatsheet'
            Id = 'b30ae161dfb693431a438e309f236467'
            Description = 'PowerShell Dotfiles — Command Cheat Sheet'
            Files = [ordered]@{
                'cheat-sheet.md' = $cheatsheet
            }
        }
        [ordered]@{
            Name = 'MasterPrompt'
            Id = '1c74223f4e57b46977abd6df06d4e8fd'
            Description = 'Master Prompt — Regenerate PowerShell Dotfiles Ecosystem'
            Files = [ordered]@{
                'master-prompt.md' = $currentPrompt.Groups['content'].Value.Trim() + "`n"
            }
        }
        [ordered]@{
            Name = 'ModularProfile'
            Id = '49b12adb210724e2378c8a4f5249cebd'
            Description = 'Modular PowerShell Profile — current dotfiles loader'
            Files = [ordered]@{
                '00-Core.ps1' = Get-Content -LiteralPath $aliasesPath -Raw
                '10-Modules.ps1' = Get-Content -LiteralPath $envPath -Raw
                'ProfileLoader.ps1' = Get-Content -LiteralPath $profileLoaderPath -Raw
            }
        }
    )
}

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
    $json | gh api --method PATCH "gists/$($item.Id)" --input -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update $($item.Name) ($($item.Id))."
    }
    Write-Host "[+] $($item.Name): updated" -ForegroundColor Green
}
