<#
.SYNOPSIS
    Single source of truth for console/logging formatting.
.DESCRIPTION
    Every module function and every ops script emits through Write-TkMessage, so
    each level's prefix and colour are defined exactly once. It is part of the
    public API so standalone ops scripts can import the module and use it.

    - The public wrappers (Write-Info/Success/Warn/Err in Toolkit/Public/Console.ps1) delegate here.
    - The ops scripts' Write-Step/Ok/Skip/Fail helpers delegate here (they keep their
      own counters, but not their own formatting).
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Public/Output.ps1
#>
function Write-TkMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Message,
        [ValidateSet('Info', 'Step', 'Ok', 'Skip', 'Warn', 'Fail')][string]$Level = 'Info'
    )
    switch ($Level) {
        'Step'  { Write-Host "==> $Message"   -ForegroundColor Cyan }
        'Ok'    { Write-Host "  [+] $Message" -ForegroundColor Green }
        'Skip'  { Write-Host "  [=] $Message" -ForegroundColor Gray }
        'Warn'  { Write-Host "  [!] $Message" -ForegroundColor Yellow }
        'Fail'  { Write-Host "  [x] $Message" -ForegroundColor Red }
        default { Write-Host "[*] $Message"   -ForegroundColor Cyan }
    }
}
