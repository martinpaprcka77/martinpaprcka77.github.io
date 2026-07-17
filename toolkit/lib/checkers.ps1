<#
.SYNOPSIS
    Funkce pro systémové kontroly.
.DESCRIPTION
    Diagnostické funkce – disky, služby, síť, procesy.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/checkers.ps1
#>

<#
.SYNOPSIS
    Zobrazí stav disků (volné místo, celková kapacita).
.NOTES
    Windows-only (Win32_LogicalDisk CIM class).
#>
function Get-DiskStatus {
    Write-Info "Kontrola disků..."

    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{N='Size(GB)';E={[math]::Round($_.Size/1GB,1)}},
            @{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,1)}},
            @{N='Used%';E={[math]::Round(($_.Size - $_.FreeSpace)/$_.Size*100,1)}} |
        Format-Table -AutoSize
}

<#
.SYNOPSIS
    Zobrazí stav klíčových služeb.
.NOTES
    Windows-only (Get-Service targets the Windows Service Control Manager).
#>
function Get-ServiceStatus {
    Write-Info "Kontrola služeb..."

    $services = @('WinRM', 'W3SVC', 'Docker', 'Spooler', 'WSearch')
    Get-Service -Name $services -ErrorAction SilentlyContinue |
        Select-Object Name, Status, StartType |
        Format-Table -AutoSize
}

<#
.SYNOPSIS
    Zobrazí základní síťové informace.
.NOTES
    Windows-only (Get-NetIPAddress requires the NetTCPIP module, Windows-only).
#>
function Get-NetworkInfo {
    Write-Info "Síťové informace..."

    Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
        Select-Object InterfaceAlias, IPAddress, PrefixLength |
        Format-Table -AutoSize
}

<#
.SYNOPSIS
    Zobrazí top 10 procesů podle využití CPU.
#>
function Get-TopProcesses {
    Write-Info "Top 10 procesů (CPU)..."

    Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 |
        Select-Object Name, Id,
            @{N='CPU(s)';E={[math]::Round($_.CPU,1)}},
            @{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} |
        Format-Table -AutoSize
}

<#
.SYNOPSIS
    Spustí kompletní diagnostiku systému.
#>
function Invoke-SystemCheck {
    Write-Host "`n=== SYSTÉMOVÁ DIAGNOSTIKA ===" -ForegroundColor Magenta
    Write-Host "Čas: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

    Get-DiskStatus
    Write-Host ""
    Get-ServiceStatus
    Write-Host ""
    Get-NetworkInfo
    Write-Host ""
    Get-TopProcesses

    Write-Host "`n=== DIAGNOSTIKA DOKONČENA ===" -ForegroundColor Magenta
}
