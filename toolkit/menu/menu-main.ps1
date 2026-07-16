<#
.SYNOPSIS
    Hlavní interaktivní menu — kořen celého systému.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-main.ps1
#>

function Start-MainMenu {
    $items = [ordered]@{
        '1. 📊 Status'     = @{ Action = { Invoke-IfAvailable -Command 'Show-Status' -Action { Show-Status } }; Desc = 'Global dashboard: Dotfiles, Terminal, PS, VS Code, Git, Docker'; Detector = { Get-DotfilesCompanionStatus } }
        '2. ⚡ Dotfiles'   = @{ Action = { Show-DotfilesMenu };     Desc = 'Install, update, configure, precheck, backup, restore, clean' }
        '3. 🔍 Systém'     = @{ Action = { Invoke-SystemCheck };    Desc = 'Disk, services, network, top processes' }
        '4. 🐳 Docker'     = @{ Action = { Show-DockerMenu };       Desc = 'Containers, images, stats, logs, prune' }
        '5. 📋 Git'        = @{ Action = { Show-GitMenu };          Desc = 'Status, log, branches, remotes, stash, commit, clean' }
        '6. 🖥️  Terminal'   = @{ Action = { Show-TerminalMenu };     Desc = 'Profiles, schemes, fonts, shell integration, backup, restore' }
        '7. 💻 PowerShell' = @{ Action = { Show-PwshMenu };         Desc = 'Edit, reload, benchmark, backup, restore, clean cache' }
        '8. 📝 VS Code'    = @{ Action = { Show-VSCodeMenu };       Desc = 'Settings, tasks, agent, extensions, backup' }
        '9. 🚪 Exit'       = @{ Action = { return };                Desc = 'Close the menu' }
    }

    Show-Menu -Title 'HLAVNÍ MENU' -Items $items -Inline
}

if ($MyInvocation.InvocationName -ne '.') {
    $modulePath = Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    Start-MainMenu
}
