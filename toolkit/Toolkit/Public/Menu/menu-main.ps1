<#
.SYNOPSIS
    Hlavní interaktivní menu — kořen celého systému.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-main.ps1
#>

function Start-MainMenu {
    $items = [ordered]@{
        '1. 🚀 Startup'    = @{ Action = { Show-StartupMenu };      Desc = 'Bootstrap lifecycle: health report, modules, profiles, policy' }
        '2. ⚡ Dotfiles'   = @{ Action = { Show-DotfilesMenu };     Desc = 'Backup, restore, clean, configure, deps, modernize, windows' }
        '3. 🔍 Systém'     = @{ Action = { Invoke-SystemCheck };    Desc = 'Disk, services, network, top processes' }
        '4. 📋 Git'        = @{ Action = { Show-GitMenu };          Desc = 'Status, log, branches, remotes, stash, commit, clean' }
        '5. 🖥️  Terminal'   = @{ Action = { Show-TerminalMenu };     Desc = 'Profiles, schemes, fonts, shell integration, backup, restore' }
        '6. 💻 PowerShell' = @{ Action = { Show-PwshMenu };         Desc = 'Modules, ModulePath' }
        '7. 📝 VS Code'    = @{ Action = { Show-VSCodeMenu };       Desc = 'Settings, tasks, agent, extensions, backup' }
        '8. 🚪 Exit'       = @{ Action = {}; Exit = $true;        Desc = 'Close the menu' }
    }

    Show-Menu -Title 'HLAVNÍ MENU' -Items $items -Inline
}

if ($MyInvocation.InvocationName -ne '.') {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    Start-MainMenu
}
