<#
.SYNOPSIS
    Single source of truth for console/logging formatting.
.DESCRIPTION
    Every level's prefix and colour are defined here exactly once, and this file is the
    canonical half of the profile/toolkit duplex:

    - The public wrappers (Write-Info/Success/Warn/Err in Toolkit/Public/Console.ps1) delegate here.
    - The four ops scripts that were migrated to the module (Add-WTProfiles, deps, modernize,
      windows) define Write-Step/Ok/Skip/Fail as thin wrappers over Write-TkMessage, so they
      keep their own counters but not their own formatting.

    Two honest caveats, so nobody "fixes" a non-bug or trusts more than there is:
    - `profile/lib/output.ps1` repeats this table on purpose. It cannot share this file:
      install.ps1/update.ps1 run before any profile or module exists, and the toolkit must
      stay usable with the profile absent. toolkit/tests/Toolkit.Tests.ps1 asserts the two
      tables are identical, so the copy cannot drift silently.
    - Not every call site routes through here yet. precheck.ps1, configure.ps1,
      Generate-Icons.ps1 and build/*.ps1 still call Write-Host directly, and the Menu/
      ModulePath/Show-Menu/Diagnostics module files do too. Those are formatting
      inconsistencies, not covered by this file's guarantee.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Public/Output.ps1
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
        # 'Info' (and the default) — must match Write-Info in profile/lib/output.ps1 exactly:
        # 2-space indent like every other level, and DarkGray rather than Cyan. It used to be
        # "[*] " / Cyan here, which both broke the shared table and made Info look like Step
        # (same colour, different indent). The profile/toolkit parity test in
        # toolkit/tests/Toolkit.Tests.ps1 ('logging style tables do not drift') now enforces
        # this, so changing one side without the other fails CI.
        default { Write-Host "  [*] $Message" -ForegroundColor DarkGray }
    }
}
