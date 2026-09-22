$repoRoot = Split-Path $PSScriptRoot -Parent

function Get-CanonicalGists {
    $promptPath = Join-Path (Join-Path $repoRoot 'docs') 'PROMPT.md'
    $prompt = Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8
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
                'bootstrap.ps1' = Get-Content -LiteralPath $remoteInstallPath -Raw -Encoding UTF8
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
                '00-Core.ps1' = Get-Content -LiteralPath $aliasesPath -Raw -Encoding UTF8
                '10-Modules.ps1' = Get-Content -LiteralPath $envPath -Raw -Encoding UTF8
                'ProfileLoader.ps1' = Get-Content -LiteralPath $profileLoaderPath -Raw -Encoding UTF8
            }
        }
    )
}
