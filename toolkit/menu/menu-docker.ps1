<#
.SYNOPSIS
    Docker management menu.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-docker.ps1
#>

function Show-DockerMenu {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Err "Docker is not installed or not in PATH."
        return
    }
    $items = [ordered]@{
        '1.  Check Status' = @{ Action = { docker info --format '{{.Containers}} containers, {{.Images}} images, {{.ServerVersion}}' 2>&1; Read-Host "`nStiskni Enter..." }; Desc = 'Quick Docker daemon status' }
        '2.  Containers' = @{ Action = { docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; Read-Host "`nStiskni Enter..." }; Desc = 'All containers with status and ports' }
        '3.   Images' = @{ Action = { docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'; Read-Host "`nStiskni Enter..." }; Desc = 'All images with size' }
        '4.  Stats' = @{ Action = { docker stats --no-stream; Read-Host "`nStiskni Enter..." }; Desc = 'Live CPU/memory per container' }
        '5.  Disk' = @{ Action = { docker system df; Read-Host "`nStiskni Enter..." }; Desc = 'Docker disk usage summary' }
        '6.  Logs' = @{ Action = { $n = Read-Host 'Container name'; docker logs --tail 50 $n 2>&1; Read-Host "`nStiskni Enter..." }; Desc = 'Last 50 log lines from a container' }
        '7.  Compose Up' = @{ Action = {
            $p = Read-Host 'Compose file path (Enter for ./docker-compose.yml)'
            if ([string]::IsNullOrEmpty($p)) { $p = 'docker-compose.yml' }
            docker compose -f $p up -d 2>&1; Write-Success "Compose started."
            Read-Host "`nStiskni Enter..."
        }; Desc = 'docker compose up -d' }
        '8.  Compose Down' = @{ Action = {
            $p = Read-Host 'Compose file path (Enter for ./docker-compose.yml)'
            if ([string]::IsNullOrEmpty($p)) { $p = 'docker-compose.yml' }
            docker compose -f $p down 2>&1; Write-Success "Compose stopped."
            Read-Host "`nStiskni Enter..."
        }; Desc = 'docker compose down' }
        '9.  Networks' = @{ Action = { docker network ls; Read-Host "`nStiskni Enter..." }; Desc = 'List all Docker networks' }
        '10.  Prune' = @{ Action = {
            Write-Warn "This will remove all stopped containers, unused networks, dangling images, and build cache."
            $c = Read-Host "Continue? (y/N)"
            if ($c -eq 'y') { docker system prune -af --volumes 2>&1; Write-Success "Pruned." }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Docker system prune -af ([!]️ destructive!)' }
        '11.   Back' = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'DOCKER' -Items $items
}

# Direct launch (e.g. the Windows Terminal "Menu" profile runs this file
# directly, not via the module): the Toolkit module isn't loaded yet, so import
# it — which dot-sources this file's Show-* function — then invoke it.
if ($MyInvocation.InvocationName -ne '.') {
    Import-Module (Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1') -Force
    Show-DockerMenu
}
