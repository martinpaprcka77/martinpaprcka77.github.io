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

# PSDiagnostics is Windows-only. $IsLinux/$IsMacOS are PS6+ automatic variables;
# on PS5.1 the guard short-circuits before evaluating them.
if ($PSVersionTable.PSVersion.Major -ge 6 -and ($IsLinux -or $IsMacOS)) { return }

# ── Start-PSProfiling — one-command profile trace ──────────────
<#
.SYNOPSIS
    Starts an ETW trace session for PowerShell diagnostics.
.DESCRIPTION
    Enables PowerShellCore event provider and starts a trace.
    Use Stop-PSProfiling to stop and collect the trace.
.EXAMPLE
    Start-PSProfiling
    . $PROFILE
    Stop-PSProfiling
#>
function Start-PSProfiling {
    [CmdletBinding()]
    param([string]$SessionName = 'PSProfileTrace')
    if (-not (Get-Module PSDiagnostics -ListAvailable)) {
        Write-Warning "PSDiagnostics module not available (Windows only)"
        return
    }
    Import-Module PSDiagnostics -ErrorAction Stop
    Write-Host "Starting ETW trace session: $SessionName" -ForegroundColor Cyan
    Enable-PSTrace -Force -ErrorAction SilentlyContinue
    Start-PSTrace -SessionName $SessionName -ErrorAction Stop
    Write-Host "Trace started. Run your commands, then: Stop-PSProfiling" -ForegroundColor Green
}

<#
.SYNOPSIS
    Stops the ETW trace session and reports the trace file location.
#>
function Stop-PSProfiling {
    [CmdletBinding()]
    param([string]$SessionName = 'PSProfileTrace')
    if (-not (Get-Module PSDiagnostics)) { Write-Warning "No trace running."; return }
    Write-Host "Stopping trace session: $SessionName" -ForegroundColor Cyan
    Stop-PSTrace -SessionName $SessionName -ErrorAction SilentlyContinue
    Disable-PSTrace -ErrorAction SilentlyContinue
    $traceFile = "$env:TEMP\$SessionName.etl"
    if (Test-Path $traceFile) {
        Write-Host "Trace saved: $traceFile" -ForegroundColor Green
        Write-Host "  Open in Windows Performance Analyzer or PerfView" -ForegroundColor DarkGray
    } else {
        Write-Warning "Trace file not found. Trace may not have captured data."
    }
}

# ── Measure-PSCommand — detailed command timing via ETW ─────────
<#
.SYNOPSIS
    Measures a scriptblock with ETW-level detail (module loads, JIT, provider events).
.DESCRIPTION
    Runs Start-PSProfiling, executes the scriptblock, then stops and reports.
    More detailed than Measure-Command — captures ETW events.
    For a simpler, cross-platform total-time breakdown of profile.ps1 itself,
    see Measure-Profile in core/perf.ps1.
.EXAMPLE
    Measure-PSCommand { . $PROFILE }
#>
function Measure-PSCommand {
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
