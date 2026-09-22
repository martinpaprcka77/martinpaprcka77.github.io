<#
.SYNOPSIS
    Nastavení pro klasickou konzoli (ConsoleHost).
.DESCRIPTION
    Titulek okna, uvítací zpráva, vlastní prompt prefix.
.NOTES
    Cesta: ~/.config/powershell/profile/hosts/ConsoleHost.ps1
#>

# Window title
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)"

# Welcome message
# Get-CimInstance is Windows-only; a missing cmdlet is "command not found",
# which -ErrorAction does not suppress — guard with Get-Command first.
# Lazy: wrap in a scriptblock so the CIM query only runs when the banner
# renders, not at parse/dot-source time. Reuses a cached result if available.
$script:uptimeStr = $null
$uptimeBlock = {
    if (-not $script:uptimeStr -and (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $uptime = (Get-Date) - $os.LastBootUpTime
            $script:uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        } else {
            $script:uptimeStr = "unknown"
        }
    }
    $script:uptimeStr
}

$psVer = $PSVersionTable.PSVersion.ToString()
$userHost = "$($env:USERNAME)@$($env:COMPUTERNAME)"

# Build the three cell strings first, then size the box from the longest one.
# The previous version padded each row to $maxLen and *then* prepended the
# "PowerShell "/"Uptime: " labels, so the rows came out 37/26/34 characters
# wide against a 26-character border — the right edge was ragged, and only the
# user row lined up (it is the one row with no label prefix).
$cells = @(
    "PowerShell $psVer"
    $userHost
    "Uptime: $(& $uptimeBlock)"
)
$maxLen = ($cells | Measure-Object -Property Length -Maximum).Maximum
if ($maxLen -lt 20) { $maxLen = 20 }

Write-Host "╔$('═' * ($maxLen + 4))╗" -ForegroundColor Cyan
Write-Host ("║  {0}  ║" -f $cells[0].PadRight($maxLen)) -ForegroundColor Cyan
Write-Host ("║  {0}  ║" -f $cells[1].PadRight($maxLen)) -ForegroundColor Cyan
Write-Host ("║  {0}  ║" -f $cells[2].PadRight($maxLen)) -ForegroundColor Cyan
Write-Host "╚$('═' * ($maxLen + 4))╝" -ForegroundColor Cyan

# Windows Terminal enhanced profile (zoxide, CTT utils, PSReadLine colors, Show-Help)
# Guarded internally by $env:WT_SESSION
$wtProfile = Join-Path $env:DOTFILES_PWSH 'hosts\wtprofile.ps1'
if (Test-Path $wtProfile) { . $wtProfile }
