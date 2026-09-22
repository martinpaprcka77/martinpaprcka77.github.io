<#
.SYNOPSIS
    Connectivity checks — the toolkit's one network-touching function.
.DESCRIPTION
    Roadmap item: "Síťová diagnostika — Test-NetConnection na klíčové endpointy".
    Tests a TCP connection to each target and reports reachability + latency.

    This is deliberately SEPARATE from the Diagnostics group, which is local-only.
    Only Test-NetworkEndpoint performs network I/O; it is never called implicitly
    by the local diagnostics.
.EXAMPLE
    Test-NetworkEndpoint
.EXAMPLE
    Test-NetworkEndpoint -Target 'github.com' -Port 443 -TimeoutMs 1500
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Public/Connectivity.ps1
#>
function Test-NetworkEndpoint {
    [CmdletBinding()]
    param(
        [string[]]$Target = @('github.com', 'www.powershellgallery.com'),
        [int]$Port = 443,
        [int]$TimeoutMs = 3000
    )

    Write-Info "Kontrola připojení..."
    foreach ($host_ in @($Target)) {
        $reachable = $false
        $latency = $null
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $client = $null
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $connect = $client.ConnectAsync($host_, $Port)
            if ($connect.Wait($TimeoutMs) -and $client.Connected) {
                $reachable = $true
                $latency = [int]$watch.ElapsedMilliseconds
            }
        }
        catch {
            $reachable = $false
        }
        finally {
            if ($client) { $client.Dispose() }
        }
        [pscustomobject]@{
            Target    = $host_
            Port      = $Port
            Reachable = $reachable
            LatencyMs = $latency
        }
    }
}
