<#
.SYNOPSIS
    Toolkit – osobní PowerShell toolbox modul.
.DESCRIPTION
    Loads the source functions and exposes them. The public surface is declared
    exactly once, in Toolkit.psd1's FunctionsToExport — this file deliberately has
    no Export-ModuleMember list, because keeping two export lists in sync was the
    main drift risk. Run build/Build.ps1 to verify the manifest matches the code.
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Toolkit.psm1
#>

# Private helpers first, then the public sources, then the menus (app layer).
$loadDirs = @(
    (Join-Path $PSScriptRoot 'Private')
    (Join-Path $PSScriptRoot 'Public')
)
foreach ($dir in $loadDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Filter *.ps1 -Recurse |
        Sort-Object FullName |
        ForEach-Object { . $_.FullName }
}
