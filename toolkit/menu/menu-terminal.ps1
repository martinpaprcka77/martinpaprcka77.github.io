<#
.SYNOPSIS
    Windows Terminal management — profiles, schemes, fonts, shell integration, backup, restore.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-terminal.ps1
#>

function Show-TerminalTroubleshootingMenu {
    $items = [ordered]@{
        '1. 🔎 Check VS Code terminal settings' = @{ Action = {
            Write-Host "`n  Review these settings in VS Code:" -ForegroundColor Cyan
            @(
                'terminal.integrated.defaultProfile.windows',
                'terminal.integrated.profiles.windows',
                'terminal.integrated.cwd',
                'terminal.integrated.env.windows',
                'terminal.integrated.inheritEnv',
                'terminal.integrated.automationProfile.windows',
                'terminal.integrated.splitCwd',
                'terminal.integrated.windowsEnableConpty'
            ) | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
            Write-Host "`n  Open Settings JSON with: Preferences: Open User Settings (JSON)" -ForegroundColor Yellow
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Review the VS Code terminal settings that affect launch' }
        '2. 🧪 Test shell outside VS Code' = @{ Action = {
            Write-Host "`n  Try launching your shell directly from an external terminal:" -ForegroundColor Cyan
            Write-Host "    - PowerShell: pwsh" -ForegroundColor White
            Write-Host "    - Windows Terminal: wt" -ForegroundColor White
            Write-Host "    - WSL: wsl -d <distro>" -ForegroundColor White
            Write-Host "`n  If it fails, the issue is likely with the shell installation rather than VS Code." -ForegroundColor Yellow
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Validate whether the shell works outside VS Code' }
        '3. 🧰 Check VS Code and shell versions' = @{ Action = {
            Write-Host "`n  Recommended checks:" -ForegroundColor Cyan
            Write-Host "    - VS Code: Help > About" -ForegroundColor White
            Write-Host "    - Shell: update PowerShell/WSL/Windows Terminal to the latest version" -ForegroundColor White
            Write-Host "    - OS: install the latest Windows updates if available" -ForegroundColor White
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Verify recent versions of VS Code, shell, and OS' }
        '4. 📝 Enable trace logging' = @{ Action = {
            Write-Host "`n  To capture terminal launch diagnostics:" -ForegroundColor Cyan
            Write-Host "    1. Enable trace logging in VS Code" -ForegroundColor White
            Write-Host "    2. Reproduce the terminal launch failure" -ForegroundColor White
            Write-Host "    3. Review the log for shell path, args, and env issues" -ForegroundColor White
            Write-Host "`n  This often reveals bad shell names, arguments, or environment variables." -ForegroundColor Yellow
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Collect trace logs for terminal launch failures' }
        '5. ↩️  Back' = @{ Action = { return }; Desc = 'Return to terminal menu' }
    }
    Show-Menu -Title 'TERMINAL TROUBLESHOOTING' -Items $items
}

function Show-TerminalMenu {
    $fragPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json"
    # scripts/Add-WTProfiles.ps1 lives inside THIS repo — $env:DOTFILES_TOOLS is only ever set by
    # the companion profile, so fall back to deriving our own root when it isn't loaded (e.g. the
    # WT "Menu" profile launches menu-main.ps1 directly, without the companion profile).
    $toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
    $items = [ordered]@{
        '1. 📊 Check Status'     = @{ Action = {
            if (Test-Path $fragPath) {
                $f = Get-Content $fragPath -Raw | ConvertFrom-Json
                Write-Host "`n  Profiles: $(@($f.profiles).Count)" -ForegroundColor White
                Write-Host "  Schemes:  $(@($f.schemes).Count)" -ForegroundColor White
                $p = $f.profiles | Where-Object { $_.name -eq 'PowerShell 7' }
                Write-Host "  Font:     $($p.font.face) $($p.font.size)pt" -ForegroundColor White
                Write-Host "  Scheme:   $($p.colorScheme)" -ForegroundColor White
                Write-Host "  Marks:    $(if($p.showMarksOnScrollbar){'ON'}else{'OFF'})" -ForegroundColor White
            } else { Write-Warn "Fragment not found. Run Generate first." }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Current fragment: profiles, schemes, font, marks status' }
        '2. 🔄 Generate/Update'  = @{ Action = {
            $s = Join-Path $toolsRoot 'scripts\Add-WTProfiles.ps1'
            if (Test-Path $s) { & $s } else { Write-Err "Not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Create/update JSON fragment with 4 profiles + 7 schemes' }
        '3. 💾 Backup Fragment'  = @{ Action = {
            if (-not (Test-Path $fragPath)) { Write-Warn "No fragment to backup."; Read-Host "`nStiskni Enter..."; return }
            $backup = "$fragPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $fragPath $backup
            Write-Success "Backup: $backup"
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Save fragment copy with timestamp' }
        '4. ♻️  Restore Fragment' = @{ Action = {
            $dir = Split-Path $fragPath -Parent
            $backups = Get-ChildItem $dir -Filter 'dotfiles.json.backup.*' -ErrorAction SilentlyContinue | Sort LastWriteTime -Desc
            if (-not $backups) { Write-Warn "No backups found."; Read-Host "`nStiskni Enter..."; return }
            Write-Host "`n  Backups:" -ForegroundColor Cyan
            for ($i=0; $i -lt $backups.Count; $i++) { Write-Host "    $($i+1). $($backups[$i].Name)" }
            $c = Read-Host "`n  Restore which?"
            if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $backups.Count) {
                Copy-Item $backups[[int]$c-1].FullName $fragPath -Force
                Write-Success "Restored. Restart WT to apply."
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Restore fragment from a backup' }
        '5. ♻️  Reset to Default' = @{ Action = {
            $c = Read-Host "Delete fragment and regenerate? (y/N)"
            if ($c -eq 'y') {
                Remove-Item $fragPath -Force -ErrorAction SilentlyContinue
                $s = Join-Path $toolsRoot 'scripts\Add-WTProfiles.ps1'
                if (Test-Path $s) { & $s }
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Delete fragment, regenerate from scratch' }
        '6. 🎨 Color Schemes'    = @{ Action = {
            if (-not (Test-Path $fragPath)) { Write-Warn "Fragment not found."; Read-Host "`nStiskni Enter..."; return }
            $f = Get-Content $fragPath -Raw | ConvertFrom-Json
            $schemes = $f.schemes | ForEach-Object { $_.name }
            for ($i=0; $i -lt $schemes.Count; $i++) { Write-Host "    $($i+1). $($schemes[$i])" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Browse 7 built-in schemes' }
        '7. 🔤 Fonts'           = @{ Action = {
            Write-Host "`n  Recommended Nerd Fonts: CascadiaCove NF, JetBrainsMono NF, FiraCode NF, Hack NF, MesloLGS NF" -ForegroundColor White
            Write-Host "  Set in WT → Profiles → PowerShell 7 → Appearance → Font face" -ForegroundColor Yellow
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Nerd Font recommendations with install sources' }
        '8. 🐧 WSL Profiles'    = @{ Action = {
            if (Get-Command wsl -ErrorAction SilentlyContinue) {
                $distros = wsl -l -q 2>&1 | Where-Object { $_ -match '\S' -and $_ -notmatch 'Windows Subsystem' }
                if ($distros) {
                    Write-Host "`n  Detected WSL distros:" -ForegroundColor Cyan
                    foreach ($d in $distros) { Write-Host "    🐧 $($d.Trim())" -ForegroundColor White }
                    Write-Host "`n  Run 'Generate/Update Profiles' to add WSL profiles to WT fragment." -ForegroundColor Yellow
                } else { Write-Host "`n  No WSL distros found." -ForegroundColor Gray }
            } else { Write-Host "`n  WSL not installed. Install: wsl --install" -ForegroundColor Yellow }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Auto-detected WSL distros for WT profiles' }
        '9. 🛠️  Troubleshooting' = @{ Action = { Show-TerminalTroubleshootingMenu }; Desc = 'VS Code terminal launch troubleshooting checklist' }
        '10. ↩️  Back'            = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'TERMINAL' -Items $items
}

# Direct launch (e.g. the Windows Terminal "Menu" profile runs this file
# directly, not via the module): the Toolkit module isn't loaded yet, so import
# it — which dot-sources this file's Show-* function — then invoke it.
if ($MyInvocation.InvocationName -ne '.') {
    Import-Module (Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1') -Force
    Show-TerminalMenu
}
