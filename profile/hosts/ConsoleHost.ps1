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
$maxLen = [Math]::Max([Math]::Max($psVer.Length, $userHost.Length), 20)

Write-Host "╔$('═' * ($maxLen + 4))╗" -ForegroundColor Cyan
Write-Host ("║  PowerShell {0}  ║" -f $psVer.PadRight($maxLen)) -ForegroundColor Cyan
Write-Host ("║  {0}  ║" -f $userHost.PadRight($maxLen)) -ForegroundColor Cyan
Write-Host ("║  Uptime: {0}  ║" -f (& $uptimeBlock).PadRight($maxLen)) -ForegroundColor Cyan
Write-Host "╚$('═' * ($maxLen + 4))╝" -ForegroundColor Cyan

# Windows Terminal enhanced profile (zoxide, CTT utils, PSReadLine colors, Show-Help)
# Guarded internally by $env:WT_SESSION
$wtProfile = Join-Path $env:DOTFILES_PWSH 'hosts\wtprofile.ps1'
if (Test-Path $wtProfile) { . $wtProfile }
