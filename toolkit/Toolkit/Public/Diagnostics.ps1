<#
.SYNOPSIS
    Funkce pro systémové kontroly.
.DESCRIPTION
    Diagnostické funkce – disky, služby, síť, procesy.
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Public/Diagnostics.ps1
#>

<#
.SYNOPSIS
    Zobrazí stav disků (volné místo, celková kapacita).
.NOTES
    Windows-only (Win32_LogicalDisk CIM class).
#>
function Get-DiskStatus {
    if (-not $IsWindows) {
        Write-Warning "Get-DiskStatus is Windows-only (CIM/WMI)."
        return
    }
    Write-Info "Kontrola disků..."

    try {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,
                @{N='Size(GB)';E={[math]::Round($_.Size/1GB,1)}},
                @{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,1)}},
                @{N='Used%';E={[math]::Round(($_.Size - $_.FreeSpace)/$_.Size*100,1)}} |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning "Disk status unavailable (CIM/WMI): $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Zobrazí stav klíčových služeb.
.NOTES
    Windows-only (Get-Service targets the Windows Service Control Manager).
#>
function Get-ServiceStatus {
    if (-not $IsWindows) {
        Write-Warning "Get-ServiceStatus is Windows-only."
        return
    }
    Write-Info "Kontrola služeb..."

    $services = @('WinRM', 'W3SVC', 'Spooler', 'WSearch')
    try {
        Get-Service -Name $services -ErrorAction SilentlyContinue |
            Select-Object Name, Status, StartType |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning "Service status unavailable: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Zobrazí základní síťové informace.
.NOTES
    Windows-only (Get-NetIPAddress requires the NetTCPIP module, Windows-only).
#>
function Get-NetworkInfo {
    if (-not $IsWindows) {
        Write-Warning "Get-NetworkInfo is Windows-only."
        return
    }
    # NetTCPIP is a Windows PowerShell-only module: it lives under
    # %SystemRoot%\System32\WindowsPowerShell\v1.0\Modules, which is not on
    # PowerShell 7's $env:PSModulePath, so Get-NetIPAddress does not resolve in
    # pwsh even on Windows and the call below only ever hit its catch block.
    # Probe first and say why instead.
    if (-not (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue)) {
        Write-Warning "Get-NetworkInfo needs the NetTCPIP module (Windows PowerShell only)."
        return
    }
    Write-Info "Síťové informace..."

    try {
        Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
            Select-Object InterfaceAlias, IPAddress, PrefixLength |
            Format-Table -AutoSize
    }
    catch {
        Write-Warning "Network info unavailable (NetTCPIP): $($_.Exception.Message)"
    }
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
    Jednorázový přehled systému (OS, CPU, paměť, uptime).
.DESCRIPTION
    Lehká alternativa k "live dashboardu" — jeden snapshot místo průběžného
    sledování. Local-only (CIM je volitelné; bez něj vrátí aspoň OS/CPU/PS verzi).
.NOTES
    Windows-only.
#>
function Get-SystemSummary {
    if (-not $IsWindows) {
        Write-Warning "Get-SystemSummary is Windows-only."
        return
    }
    Write-Info "Přehled systému..."

    $os = $null
    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch { Write-Debug "CIM OS info unavailable: $_" }

    $uptime = $null
    if ($os -and $os.LastBootUpTime) { $uptime = (Get-Date) - $os.LastBootUpTime }

    [pscustomobject]@{
        ComputerName  = $env:COMPUTERNAME
        OS            = if ($os) { ([string]$os.Caption).Trim() } else { [Environment]::OSVersion.VersionString }
        PSVersion     = $PSVersionTable.PSVersion.ToString()
        CPUs          = [Environment]::ProcessorCount
        TotalMemoryGB = if ($os) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 1) } else { $null }
        FreeMemoryGB  = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 1) } else { $null }
        Uptime        = if ($uptime) { '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes } else { 'unknown' }
    }
}

<#
.SYNOPSIS
    Spustí kompletní diagnostiku systému.
#>
function Invoke-SystemCheck {
    Write-Host "`n=== SYSTÉMOVÁ DIAGNOSTIKA ===" -ForegroundColor Magenta
    Write-Host "Čas: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

    Get-SystemSummary
    Write-Host ""
    Get-DiskStatus
    Write-Host ""
    Get-ServiceStatus
    Write-Host ""
    Get-NetworkInfo
    Write-Host ""
    Get-TopProcesses

    Write-Host "`n=== DIAGNOSTIKA DOKONČENA ===" -ForegroundColor Magenta
}
