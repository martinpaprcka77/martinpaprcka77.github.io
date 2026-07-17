<#
.SYNOPSIS
    Hlavní interaktivní menu  -  kořen celého systému.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-main.ps1
#>

function Start-MainMenu {
    $items = [ordered]@{
      '1.  Status'    = @{ Action = {
            if (Get-Command Show-Status -ErrorAction SilentlyContinue) {
                Show-Status
            } else {
                # Auto-attempt: load profile from expected location
                $profileFile = Join-Path $HOME '.config\powershell\profile\profile.ps1'
                if (Test-Path $profileFile) { . $profileFile }
                if (Get-Command Show-Status -ErrorAction SilentlyContinue) {
                    Write-Host "`n  [OK] Profile auto-loaded from $profileFile" -ForegroundColor Green
                    Show-Status; return
                }
                Write-Host "`n   STANDALONE STATUS (profile not found)" -ForegroundColor Cyan
                Write-Host "  $(('-' * 55))" -ForegroundColor DarkGray
                Write-Host "  PS $($PSVersionTable.PSVersion) | $($Host.Name)" -ForegroundColor White
                $pCount = ($env:PSModulePath -split [IO.Path]::PathSeparator).Count
                Write-Host "  PSModulePath: $pCount entries" -ForegroundColor White
                $bin = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin'
                $inPath = $bin -in ($env:PATH -split [IO.Path]::PathSeparator)
                Write-Host "  toolkit/bin in PATH: $(if ($inPath) { '[OK]' } else { '[X]' })" -ForegroundColor $(if ($inPath) { 'Green' } else { 'Red' })
                if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "  git: [OK] $((git --version 2>$null))" -ForegroundColor Green }
                if (Get-Command docker -ErrorAction SilentlyContinue) { Write-Host "  docker: [OK] $((docker --version 2>$null))" -ForegroundColor Green }
                if (Get-Command starship -ErrorAction SilentlyContinue) { Write-Host "  starship: [OK]" -ForegroundColor Green }
                if (Get-Command code -ErrorAction SilentlyContinue) { Write-Host "  code: [OK] $(code --version 2>&1 | Select-Object -First 1)" -ForegroundColor Green }
                if ($env:WT_SESSION) { Write-Host "  WT session: [OK]" -ForegroundColor Green }
                Write-Host "`n   Run 'install.ps1' or 'update' to load the full profile." -ForegroundColor Yellow
                Read-Host "`nPress Enter..."
            }
        }; Desc = 'Global dashboard or standalone status'; Detector = { Get-DotfilesCompanionStatus } }
      '2.  Dotfiles'  = @{ Action = { Show-DotfilesMenu };     Desc = 'Install, update, configure, precheck, backup, restore, clean' }
      '3.  Systém'    = @{ Action = { Invoke-SystemCheck };    Desc = 'Disk, services, network, top processes' }
      '4.  Docker'    = @{ Action = { Show-DockerMenu };       Desc = 'Containers, images, stats, logs, prune' }
      '5.  Git'       = @{ Action = { Show-GitMenu };          Desc = 'Status, log, branches, remotes, stash, commit, clean' }
      '6.   Terminal'  = @{ Action = { Show-TerminalMenu };     Desc = 'Profiles, schemes, fonts, shell integration, backup, restore' }
      '7.  PowerShell' = @{ Action = { Show-PwshMenu };         Desc = 'Edit, reload, benchmark, backup, restore, clean cache' }
      '8.  VS Code'   = @{ Action = { Show-VSCodeMenu };       Desc = 'Settings, tasks, agent, extensions, backup' }
      '9.  Exit'      = @{ Action = { return };                Desc = 'Close the menu' }
    }

    Show-Menu -Title 'HLAVNÍ MENU' -Items $items -Inline
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Start-MainMenu' }