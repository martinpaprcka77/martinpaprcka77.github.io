<#
.SYNOPSIS
    Dotfiles ecosystem management — install, update, backup, restore, clean.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-dotfiles.ps1
#>

function Show-DotfilesMenu {
    # scripts/configure.ps1, deps.ps1, modernize.ps1, windows.ps1 live inside THIS repo —
    # $env:DOTFILES_TOOLS is only ever set by the companion profile, so fall back to deriving
    # our own root when it isn't loaded (e.g. the WT "Menu" profile launches menu-main.ps1
    # directly, without the companion profile).
    $toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
    $items = [ordered]@{
        '1. 📊 Check Status'     = @{ Action = { Invoke-IfAvailable -Command 'Show-Status' -Action { Show-Status } }; Desc = 'Full ecosystem health dashboard'; Detector = { Get-DotfilesCompanionStatus } }
        '2. 📥 Install/Reinstall'= @{ Action = {
            $s = Join-Path $HOME '.config\powershell\install.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "install.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Run install.ps1 — idempotent, safe to re-run' }
        '3. 🔄 Update (git pull)' = @{ Action = {
            $s = Join-Path $HOME '.config\powershell\update.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "update.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Git pull latest + reload profile' }
        '4. 💾 Backup Profiles'  = @{ Action = {
            $backupDir = Join-Path $HOME '.config\powershell\backups'
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            # Known-Folder-correct when available (Get-NativeProfilePaths lives in
            # The companion profile's lib/paths.ps1, loaded if its
            # profile is active this session) — falls back to the naive $HOME guess
            # otherwise, same as it always did.
            $profiles = if (Get-Command Get-NativeProfilePaths -ErrorAction SilentlyContinue) {
                @(Get-NativeProfilePaths) + (Join-Path $HOME '.config\powershell\profile\profile.ps1')
            } else {
                @(
                    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
                    "$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1",
                    "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
                    "$HOME\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1",
                    (Join-Path $HOME '.config\powershell\profile\profile.ps1')
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
        '5. ♻️  Restore Profiles' = @{ Action = {
            $backupDir = Join-Path $HOME '.config\powershell\backups'
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
        '6. 🧹 Clean Backups'    = @{ Action = {
            $backupDir = Join-Path $HOME '.config\powershell\backups'
            if (-not (Test-Path $backupDir)) { Write-Warn "No backups found."; Read-Host "`nStiskni Enter..."; return }
            $count = @(Get-ChildItem $backupDir -Filter '*.bak').Count
            $c = Read-Host "Delete $count backup files? (y/N)"
            if ($c -eq 'y') { Remove-Item "$backupDir\*.bak" -Force; Write-Success "Cleaned $count backups." }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Delete old timestamped backups' }
        '7. ⚙️  Configure Wizard' = @{ Action = {
            $s = Join-Path $toolsRoot 'scripts\configure.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "configure.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Interactive 5-step setup wizard' }
        '8. 📦 Dependencies'     = @{ Action = {
            $s = Join-Path $toolsRoot 'scripts\deps.ps1'
            if (Test-Path $s) { Write-Info "Running deps.ps1..."; & $s } else { Write-Err "deps.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Winget auto-installer: Git, PS7, WT, VS Code, Starship, zoxide' }
        '9. 🧹 Modernize PS'     = @{ Action = {
            $s = Join-Path $toolsRoot 'scripts\modernize.ps1'
            if (Test-Path $s) { Write-Info "Running modernize.ps1..."; & $s } else { Write-Err "modernize.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'PSResourceGet, cleanup legacy, security baseline, PS 7.6+ ready'; Detector = { Get-ModuleStackStatus } }
        '10. 🪟 Windows Defaults' = @{ Action = {
            $s = Join-Path $toolsRoot 'scripts\windows.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "windows.ps1 not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Explorer, taskbar, privacy, bloatware removal' }
        '↩️  Back'                = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'DOTFILES' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Show-DotfilesMenu' }
