<#
.SYNOPSIS
    PowerShell profile and environment management.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-pwsh.ps1
#>

function Show-PwshMenu {
    $items = [ordered]@{
        '1. 📦 Modules'        = @{ Action = {
            Write-Host "`n  Loaded:" -ForegroundColor Cyan
            Get-Module | Where-Object { $_.Name -notmatch '^Microsoft\.|^Cim|^PSReadLine$' } | Select-Object Name, Version | Sort-Object Name | ForEach-Object { Write-Host "    $($_.Name) v$($_.Version)" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'All loaded PowerShell modules'; Detector = { Get-ModuleStackStatus } }
        '2. 📂 ModulePath'      = @{ Action = {
            $sub = [ordered]@{
                '1. List Paths'       = @{ Action = { Get-PSModulePath }; Desc = 'Show all entries with validation' }
                '2. Validate'         = @{ Action = { Test-PSModulePath }; Desc = 'Check duplicates, OneDrive, priority' }
                '3. Reset Baseline'   = @{ Action = { Reset-PSModulePath }; Desc = 'Modern: PS7 first, no OneDrive' }
                '4. Add Path'         = @{ Action = { $p = Read-Host 'Path'; Add-PSModulePath -Path $p }; Desc = 'Add a directory (no duplicates)' }
                '5. Remove Path'      = @{ Action = { Get-PSModulePath | Out-Null; $i = Read-Host 'Index to remove'; if ($i -match '^\d+$') { Remove-PSModulePath -Index ([int]$i) } }; Desc = 'Remove by index number' }
                '6. Export Config'    = @{ Action = { Export-PSModulePath }; Desc = 'Save to psmodulepath.json' }
                '7. Import Config'    = @{ Action = { Import-PSModulePath }; Desc = 'Restore from psmodulepath.json' }
                '8. ↩️  Back'          = @{ Action = { return } }
            }
            Show-Menu -Title 'MODULE PATH' -Items $sub
        }; Desc = 'List, add, remove, reset, export/import PSModulePath'; Detector = { Get-ModulePathStatus } }
        '3. ↩️  Back'           = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'POWERSHELL' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    Show-PwshMenu
}
