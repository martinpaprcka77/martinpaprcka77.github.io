<#
.SYNOPSIS
    VS Code management menu.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-vscode.ps1
#>

function Show-VSCodeMenu {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Err "VS Code (code) is not in PATH."
        return
    }
    # .vscode/ lives inside THIS repo — $env:DOTFILES_TOOLS is only ever set by the companion
    # profile, so fall back to deriving our own root when it isn't loaded (e.g. the WT "Menu"
    # profile launches menu-main.ps1 directly, without the companion profile).
    $toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }
    $vsc = Join-Path $toolsRoot '.vscode'
    $items = [ordered]@{
        '1.  Check Status' = @{ Action = {
            Write-Host "`n  Committed configs:" -ForegroundColor Cyan
            @('settings.json', 'tasks.json', 'agent-instructions.md', 'extensions.json') | ForEach-Object {
                $p = Join-Path $vsc $_
                if (Test-Path $p) { Write-Host "    [OK] $_ ($((Get-Item $p).Length) bytes)" -ForegroundColor Green }
                else { Write-Host "    [X] $_" -ForegroundColor Red }
            }
            Write-Host "`n  Extensions:" -ForegroundColor Cyan
            code --list-extensions 2>&1 | Select-String 'powershell|terminal|copilot' | ForEach-Object { Write-Host "    $_" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Committed files + PowerShell extensions' }
        '2.  Settings' = @{ Action = {
            $p = Join-Path $vsc 'settings.json'
            if (Test-Path $p) { code $p } else { Write-Err "Not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Open committed settings.json' }
        '3.  Tasks' = @{ Action = {
            $p = Join-Path $vsc 'tasks.json'
            if (Test-Path $p) { code $p } else { Write-Err "Not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = '5 tasks: Pester, install, update, WT, deps' }
        '4.  Agent' = @{ Action = {
            $p = Join-Path $vsc 'agent-instructions.md'
            if (Test-Path $p) { code $p } else { Write-Err "Not found" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Copilot agent context file' }
        '5.  Extensions' = @{ Action = {
            $p = Join-Path $vsc 'extensions.json'
            if (Test-Path $p) { code $p } else { Write-Err "Not found — run install.ps1 first" }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Open recommended extensions.json' }
        '6.  Install Rec.' = @{ Action = {
            $extFile = Join-Path $vsc 'extensions.json'
            if (-not (Test-Path $extFile)) { Write-Warn "extensions.json not found."; Read-Host "`nStiskni Enter..."; return }
            $recs = (Get-Content $extFile -Raw | ConvertFrom-Json).recommendations
            $installed = code --list-extensions 2>&1
            $missing = $recs | Where-Object { $_ -notin $installed }
            if (-not $missing) { Write-Success "All recommended extensions are installed."; Read-Host "`nStiskni Enter..."; return }
            Write-Host "`n  Installing $($missing.Count) missing extensions..." -ForegroundColor Yellow
            $missing | ForEach-Object { Write-Host "    Installing: $_" ; code --install-extension $_ 2>&1 | Out-Null }
            Write-Success "Done. Restart VS Code to activate."
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Install all recommended from extensions.json' }
        '7.  Backup Configs' = @{ Action = {
            $backupDir = Join-Path $toolsRoot '.vscode\backups'
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            @('settings.json', 'tasks.json', 'agent-instructions.md', 'extensions.json') | ForEach-Object {
                $p = Join-Path $vsc $_
                if (Test-Path $p) { Copy-Item $p (Join-Path $backupDir "$_.$ts.bak") }
            }
            Write-Success "Backed up to: $backupDir"
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Save all configs with timestamp' }
        '8.   Restore Configs' = @{ Action = {
            $backupDir = Join-Path $toolsRoot '.vscode\backups'
            $backups = Get-ChildItem $backupDir -Filter '*.bak' -ErrorAction SilentlyContinue | Sort LastWriteTime -Desc
            if (-not $backups) { Write-Warn "No backups."; Read-Host "`nStiskni Enter..."; return }
            Write-Host "`n  Backups:" -ForegroundColor Cyan
            for ($i=0; $i -lt $backups.Count; $i++) { Write-Host "    $($i+1). $($backups[$i].Name)" }
            $c = Read-Host "`n  Restore which?"
            if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $backups.Count) {
                $origName = $backups[[int]$c-1].Name -replace '\.\d{8}-\d{6}\.bak$', ''
                Copy-Item $backups[[int]$c-1].FullName (Join-Path $vsc $origName) -Force
                Write-Success "Restored: $origName"
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Restore from timestamped backup' }
        '9.  Extensions' = @{ Action = {
            code --list-extensions 2>&1 | Select-String 'powershell|terminal|copilot' | ForEach-Object { Write-Host "    $_" }
            Write-Host "`n  Recommended: see .vscode\\extensions.json" -ForegroundColor Yellow
            Read-Host "`nStiskni Enter..."
        }; Desc = 'List installed + recommended extensions' }
        '10.   Open Folder' = @{ Action = { code $toolsRoot }; Desc = 'Open toolkit/ in VS Code' }
        '11.   Back' = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'VS CODE' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Show-VSCodeMenu' }
