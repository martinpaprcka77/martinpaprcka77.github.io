<#
.SYNOPSIS
    PowerShell diagnostic tracing tools — ETW, event logs, profiling.
.DESCRIPTION
    Wraps PSDiagnostics module cmdlets for easy one-command profiling.
    Used for debugging slow profiles, module loads, and script execution.
    Windows-only (PSDiagnostics requires ETW).
.NOTES
    Cesta: ~/.config/powershell/profile/core/diag.ps1
    Requires: PSDiagnostics module (built into PowerShell 7 on Windows)
#>

# PSDiagnostics is Windows-only.
# on PS5.1 the guard short-circuits before evaluating them. {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [string]$SessionName = 'PSCommandTrace'
    )
    if (-not (Get-Module PSDiagnostics -ListAvailable)) {
        Write-Warning "PSDiagnostics not available — falling back to Measure-Command"
        return Measure-Command $ScriptBlock
    }
    Start-PSProfiling -SessionName $SessionName
    try {
        $result = Measure-Command $ScriptBlock
        Write-Host "Command completed in $($result.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Green
    } finally {
        Stop-PSProfiling -SessionName $SessionName
    }
}

# ── Get-PSEventLog — quick event log inspection ────────────────
<#
.SYNOPSIS
    Shows PowerShell-related Windows event log properties.
#>
function Get-PSEventLog {
    [CmdletBinding()]
    param()
    $logs = @('PowerShellCore/Operational', 'Windows PowerShell', 'Microsoft-Windows-PowerShell/Operational')
    if (-not (Get-Module PSDiagnostics -ListAvailable)) {
        Write-Warning "PSDiagnostics not available (Windows only)"
        return
    }
    Import-Module PSDiagnostics -ErrorAction Stop
    Write-Host "`n📋 PowerShell Event Logs" -ForegroundColor Cyan
    foreach ($log in $logs) {
        try {
            $logInfo = Get-WinEvent -ListLog $log -ErrorAction Stop
            $size = if ($logInfo.FileSize) { "$([math]::Round($logInfo.FileSize/1MB, 1)) MB" } else { 'N/A' }
            Write-Host "  $log" -ForegroundColor White
            Write-Host "    Size: $size  |  Max: $($logInfo.MaximumSizeInBytes/1MB) MB  |  Retention: $($logInfo.LogMode)" -ForegroundColor DarkGray
        } catch {
            Write-Host "  $log — not available" -ForegroundColor DarkGray
        }
    }
}
