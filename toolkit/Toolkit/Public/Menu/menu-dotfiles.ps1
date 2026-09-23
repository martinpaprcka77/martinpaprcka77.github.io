<#
.SYNOPSIS
    Dotfiles ecosystem management — install, update, backup, restore, clean.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-dotfiles.ps1
#>

function Show-DotfilesMenu {
    # ops/configure.ps1, deps.ps1, modernize.ps1, windows.ps1 live inside THIS repo —
    # $env:DOTFILES_TOOLS is only ever set by the companion profile, so fall back to deriving
    # our own root when it isn't loaded (e.g. the WT "Menu" profile launches menu-main.ps1
    # directly, without dotfiles-powershell's profile).
    $toolsRoot = Get-ToolkitRoot
    $items = [ordered]@{
        '1. 💾 Backup Profiles'  = @{ Action = {
            $backupDir = Join-Path $HOME 'Documents\PowerShell\backups'
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            # Known-Folder-correct when available (Get-NativeProfilePaths lives in
            # the companion dotfiles-powershell repo's lib/paths.ps1, loaded if its
            # profile is active this session) — falls back to the naive $HOME guess
            # otherwise, same as it always did.
            $profiles = if (Get-Command Get-NativeProfilePaths -ErrorAction SilentlyContinue) {
                @(Get-NativeProfilePaths) + (Join-Path $HOME '.config\powershell\profile.ps1')
            } else {
                @(
                    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
                    "$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1",
                    (Join-Path $HOME '.config\powershell\profile.ps1')
                )
            }
            $saved = 0
            foreach ($p in $profiles) {
                if (Test-Path $p) {
                    $dest = Join-Path $backupDir "$(Split-Path $p -Leaf).$ts.bak"
                    Copy-Item $p $dest
                    Write-Host "   💾 $p → $dest" -ForegroundColor DarkGray
                    $saved++
                }
            }
            Write-Success "Backed up $saved profiles to: $backupDir"
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Save all profile files to backups/ with timestamp' }
        '2. ♻️  Restore Profiles' = @{ Action = {
            $backupDir = Join-Path $HOME 'Documents\PowerShell\backups'
            if (-not (Test-Path $backupDir)) { Write-Warn "No backups found at: $backupDir"; Read-Host "`nStiskni Enter..."; return }
            $backups = Get-ChildItem $backupDir -Filter '*.bak' | Sort-Object LastWriteTime -Descending
            Write-Host "`n  Available backups:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $backups.Count; $i++) { Write-Host "    $($i+1). $($backups[$i].Name)" }
            $c = Read-Host "`n  Restore which? (1-$($backups.Count), Enter=cancel)"
            if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $backups.Count) {
                $src = $backups[[int]$c-1]
                $origName = $src.Name -replace '\.\d{8}-\d{6}\.bak$', ''
                $docsBase = if (Get-Command Resolve-DocumentsPath -ErrorAction SilentlyContinue) { Resolve-DocumentsPath } else { "$HOME\Documents" }
                $dest = Join-Path $docsBase "PowerShell\$origName"
                Copy-Item $src.FullName $dest -Force
                Write-Success "Restored: $dest"
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Restore profile from a timestamped backup' }
        '3. 🧹 Clean Backups'    = @{ Action = {
            $backupDir = Join-Path $HOME 'Documents\PowerShell\backups'
            if (-not (Test-Path $backupDir)) { Write-Warn "No backups found."; Read-Host "`nStiskni Enter..."; return }
            $count = @(Get-ChildItem $backupDir -Filter '*.bak').Count
            $c = Read-Host "Delete $count backup files? (y/N)"
            if ($c -eq 'y') { Remove-Item "$backupDir\*.bak" -Force; Write-Success "Cleaned $count backups." }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Delete old timestamped backups' }
        '4. ⚙️  Configure Wizard' = @{ Action = {
            $s = Join-Path $toolsRoot 'ops\configure.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "configure.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Interactive 5-step setup wizard' }
        '5. 📦 Dependencies'     = @{ Action = {
            $s = Join-Path $toolsRoot 'ops\deps.ps1'
            if (Test-Path $s) { Write-Info "Running deps.ps1..."; & $s } else { Write-Err "deps.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Winget auto-installer: Git, PS7, WT, VS Code, Starship, zoxide' }
        '6. 🧹 Modernize PS'     = @{ Action = {
            $s = Join-Path $toolsRoot 'ops\modernize.ps1'
            if (Test-Path $s) { Write-Info "Running modernize.ps1..."; & $s } else { Write-Err "modernize.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'PSResourceGet, cleanup legacy, security baseline, PS 7.6+ ready'; Detector = { Get-ModuleStackStatus } }
        '7. 🪟 Windows Defaults' = @{ Action = {
            $s = Join-Path $toolsRoot 'ops\windows.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "windows.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Explorer, taskbar, privacy, bloatware removal' }
        '↩️  Back'                = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'DOTFILES' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    Show-DotfilesMenu
}
