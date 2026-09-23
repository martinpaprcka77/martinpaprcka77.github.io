<#
.SYNOPSIS
    Startup menu — the PowerShell bootstrap lifecycle, stage by stage.
.DESCRIPTION
    A process-oriented submenu: instead of grouping by tool, its entries map to the
    stages in docs/00-bootstrap.md (Configuration, Modules, Profiles, Discovery) so a
    failure can be traced to the subsystem that introduced it. Integrates the new
    startup tooling (ops/Get-PowerShellStartupHealth.ps1, Get-ModuleStackStatus,
    Get-ModulePathStatus, Test-PSModulePath) and the interactive map.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-startup.ps1
#>

function Show-StartupMenu {
    $toolsRoot = Get-ToolkitRoot
    $items = [ordered]@{
        '1. 🩺 Health report (stages 1–7)' = @{ Action = {
            $collector = Join-Path $toolsRoot 'ops\Get-PowerShellStartupHealth.ps1'
            if (-not (Test-Path $collector)) { Write-Err "Collector not found: $collector"; Read-Host "`nStiskni Enter..."; return }
            try { $report = & $collector | ConvertFrom-Json }
            catch { Write-Err "Collector failed: $($_.Exception.Message)"; Read-Host "`nStiskni Enter..."; return }
            Write-Host "`n  Startup health: $($report.healthScore)%" -ForegroundColor Cyan
            Write-Host ("  {0,-10} {1,-10} {2}" -f 'STAGE', 'STATUS', 'VALUE') -ForegroundColor DarkGray
            foreach ($name in @('launcher', 'loader', 'engine', 'modules', 'profiles', 'shell')) {
                $p = $report.$name
                if (-not $p) { continue }
                $color = if ($p.status -eq 'healthy') { 'Green' } elseif ($p.status -eq 'warning') { 'Yellow' } else { 'Red' }
                Write-Host ("  {0,-10} {1,-10} {2}" -f $name, $p.status, $p.value) -ForegroundColor $color
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Local-only phase status + score from the startup collector' }

        '2. 📦 Module stack (stage 4/6)' = @{ Action = {
            $status = Get-ModuleStackStatus
            Write-Host "`n  $($status.Icon) $($status.Text)" -ForegroundColor White
            if (Confirm-Action "Run modernize.ps1 to migrate to PSResourceGet?") {
                $s = Join-Path $toolsRoot 'ops\modernize.ps1'
                if (Test-Path $s) { & $s }
            }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Legacy PowerShellGet vs PSResourceGet'; Detector = { Get-ModuleStackStatus } }

        '3. 📂 PSModulePath (stage 4)' = @{ Action = {
            Test-PSModulePath
            if (Confirm-Action "Reset PSModulePath to the PowerShell 7 baseline?") { Reset-PSModulePath }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Validate / reset module search paths'; Detector = { Get-ModulePathStatus } }

        '4. 👤 Profile & policy (stage 5)' = @{ Action = {
            Write-Host "`n  PROFILE       : $PROFILE" -ForegroundColor White
            Write-Host "  exists        : $(Test-Path $PROFILE)" -ForegroundColor White
            Write-Host "  language mode : $($ExecutionContext.SessionState.LanguageMode)" -ForegroundColor White
            Write-Host "  profiles      : $($PROFILE.CurrentUserAllHosts)" -ForegroundColor DarkGray
            Write-Host "  execution     :" -ForegroundColor White
            Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-String | Write-Host
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Resolve $PROFILE tiers, execution policy and language mode' }

        '5. 🔎 Discovery (stage 7)' = @{ Action = {
            Write-Host "`n  modules available : $(@(Get-Module -ListAvailable).Count)" -ForegroundColor White
            Write-Host "  modules loaded    : $(@(Get-Module).Count)" -ForegroundColor White
            Write-Host "  aliases           : $(@(Get-Alias).Count)" -ForegroundColor White
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Module discovery, loaded modules and aliases' }

        '6. 🖥️  Shell info (env, PATH, profiles)' = @{ Action = {
            $i = Get-ShellInfo
            Write-Host "`n  shell   : $($i.Shell.Host) / $($i.Shell.Terminal) / PS $($i.Shell.PSVersion) ($($i.Shell.PSEdition))" -ForegroundColor White
            Write-Host "  user    : $($i.User.Name)@$($i.User.Machine)  admin: $($i.User.IsAdmin)" -ForegroundColor White
            Write-Host "  env     : $(@($i.Env.PSObject.Properties).Count) notable variable(s)" -ForegroundColor White
            foreach ($p in $i.Env.PSObject.Properties) { Write-Host "      $($p.Name) = $($p.Value)" -ForegroundColor DarkGray }
            Write-Host "  PATH    : $($i.Path.Count) entries, $($i.Path.Duplicates.Count) duplicate(s), $($i.Path.Missing.Count) missing" -ForegroundColor White
            Write-Host "  profiles:" -ForegroundColor White
            foreach ($p in $i.Profiles.PSObject.Properties) { Write-Host "      $($p.Name): exists=$($p.Value.Exists)" -ForegroundColor DarkGray }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Host/user/env/PATH/$PROFILE snapshot (local-only)' }

        '7. 🗺️  Open startup map' = @{ Action = {
            $map = Join-Path $toolsRoot 'PowerShell-Startup-Map.html'
            if (Test-Path $map) { Start-Process $map } else { Write-Err "Not found: $map" }
        }; Desc = 'Open the interactive green/yellow/red startup health map' }

        '8. ↩️  Back' = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'STARTUP (bootstrap process)' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') {
    $modulePath = Join-Path $PSScriptRoot '..\..\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    Show-StartupMenu
}
