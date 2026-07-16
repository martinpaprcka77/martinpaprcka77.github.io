<#
.SYNOPSIS
    PowerShell profile and environment management.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-pwsh.ps1
#>

function Show-PwshMenu {
    $profilePath = Join-Path $HOME '.config\powershell\profile\profile.ps1'
    $items = [ordered]@{
        '1. 📊 Check Status'   = @{ Action = { Invoke-IfAvailable -Command 'Show-Status' -Action { Show-Status } }; Desc = 'Full ecosystem health dashboard'; Detector = { Get-DotfilesCompanionStatus } }
        '2. ✏️  Edit Profile'   = @{ Action = {
            $e = if ($env:EDITOR) { $env:EDITOR } elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code' } else { 'notepad' }
            & $e $profilePath
        }; Desc = 'Open profile.ps1 in editor' }
        '3. 🔄 Reload Profile' = @{ Action = {
            if (Test-Path $profilePath) { . $profilePath; Write-Success "Reloaded." } else { Write-Err "Not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Re-source profile without restart' }
        '4. 💾 Backup Profile' = @{ Action = {
            $backupDir = Join-Path $HOME '.config\powershell\backups'
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            if (Test-Path $profilePath) {
                $dest = Join-Path $backupDir "profile.ps1.$ts.bak"
                Copy-Item $profilePath $dest
                Write-Success "Backup: $dest"
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Save profile.ps1 with timestamp' }
        '5. ♻️  Restore Profile'= @{ Action = {
            $backupDir = Join-Path $HOME '.config\powershell\backups'
            $backups = Get-ChildItem $backupDir -Filter 'profile.ps1.*.bak' -ErrorAction SilentlyContinue | Sort LastWriteTime -Desc
            if (-not $backups) { Write-Warn "No profile backups found."; Read-Host "`nStiskni Enter..."; return }
            Write-Host "`n  Backups:" -ForegroundColor Cyan
            for ($i=0; $i -lt $backups.Count; $i++) { Write-Host "    $($i+1). $($backups[$i].Name)" }
            $c = Read-Host "`n  Restore which?"
            if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $backups.Count) {
                Copy-Item $backups[[int]$c-1].FullName $profilePath -Force
                Write-Success "Restored. Reload profile to apply."
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Restore profile.ps1 from backup' }
        '6. ⚡ Performance'     = @{ Action = {
            $sub = [ordered]@{
                '1. Run Benchmark'   = @{ Action = { Invoke-IfAvailable -Command 'Measure-Profile' -Action { Measure-Profile } }; Desc = 'Detailed step-by-step timing' }
                '2. Module Analysis' = @{ Action = { Invoke-IfAvailable -Command 'Optimize-ModuleLoading' -Action { Optimize-ModuleLoading } }; Desc = 'Lazy loading suggestions' }
                '3. Profile Size'    = @{ Action = { Invoke-IfAvailable -Command 'Get-ProfileSize' -Action { Get-ProfileSize } }; Desc = 'Lines, bytes, file count' }
                '4. Clear Cache'     = @{ Action = { Invoke-IfAvailable -Command 'Clear-PSCache' -Action { Clear-PSCache } }; Desc = 'Clean corrupted module caches' }
                '5. ETW Profiling'   = @{ Action = { Invoke-IfAvailable -Command 'Start-PSProfiling' -Action { Write-Info "Starting ETW trace... run commands, then Stop-PSProfiling"; Start-PSProfiling } }; Desc = 'Start ETW trace for deep diagnostics' }
                '6. Event Logs'      = @{ Action = { Invoke-IfAvailable -Command 'Get-PSEventLog' -Action { Get-PSEventLog } }; Desc = 'PowerShell event log sizes and properties' }
                '7. ↩️  Back'         = @{ Action = { return } }
            }
            Show-Menu -Title 'PERFORMANCE' -Items $sub
        }; Desc = 'Benchmark, analyze, optimize, clear caches'; Detector = { Get-DotfilesCompanionStatus } }
        '7. 📦 Modules'        = @{ Action = {
            Write-Host "`n  Loaded:" -ForegroundColor Cyan
            Get-Module | Where-Object { $_.Name -notmatch '^Microsoft\.|^Cim|^PSReadLine$' } | Select Name, Version | Sort Name | ForEach-Object { Write-Host "    $($_.Name) v$($_.Version)" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'All loaded PowerShell modules'; Detector = { Get-ModuleStackStatus } }
        '8. 📂 ModulePath'      = @{ Action = {
            $sub = [ordered]@{
                '1. List Paths'       = @{ Action = { Get-PSModulePath | Out-Null }; Desc = 'Show all entries with validation' }
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
        '9. ↩️  Back'           = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'POWERSHELL' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Show-PwshMenu' }
