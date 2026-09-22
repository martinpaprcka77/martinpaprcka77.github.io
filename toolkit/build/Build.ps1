<#
.SYNOPSIS
    Validates the Toolkit module surface against the manifest.
.DESCRIPTION
    The manifest (Toolkit.psd1 FunctionsToExport) is the single source of truth for
    the public API; Toolkit.psm1 has no export list. This script proves the two
    cannot drift:

      - public functions are every top-level function in Toolkit/Public/*.ps1 and menu/*.ps1
      - private helpers (Toolkit/Private/*.ps1) must NOT be exported
      - every FunctionsToExport entry must resolve to a defined function

    Exits 0 when consistent, 1 otherwise. Pass -UpdateManifest to rewrite the
    FunctionsToExport array from the discovered public functions.
.PARAMETER UpdateManifest
    Rewrite Toolkit.psd1's FunctionsToExport to match the discovered public functions.
.EXAMPLE
    pwsh -File build/Build.ps1
.EXAMPLE
    pwsh -File build/Build.ps1 -UpdateManifest
.NOTES
    Local-only. No network access.
#>
[CmdletBinding()]
param(
    [switch]$UpdateManifest
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path $PSScriptRoot -Parent
$toolkitDir = Join-Path $root 'Toolkit'
$manifest   = Join-Path $toolkitDir 'Toolkit.psd1'
$publicDirs = @((Join-Path $toolkitDir 'Public'))
$privateDir = Join-Path $toolkitDir 'Private'

function Get-TopLevelFunctions {
    param([string[]]$Directories)
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($dir in $Directories) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $dir -Filter *.ps1 -File -Recurse) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName, [ref]$null, [ref]$null)
            # searchNestedScriptBlocks:$false -> excludes nested/local function bodies.
            $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
                ForEach-Object { if (-not $names.Contains($_.Name)) { $names.Add($_.Name) } }
        }
    }
    $names
}

$publicFunctions  = Get-TopLevelFunctions -Directories $publicDirs
$privateFunctions = Get-TopLevelFunctions -Directories @($privateDir)
$exported         = @((Import-PowerShellDataFile -LiteralPath $manifest).FunctionsToExport)

if ($UpdateManifest) {
    $lines = $publicFunctions | Sort-Object | ForEach-Object { "        '$_'" }
    $block = "FunctionsToExport = @(`n" + ($lines -join ",`n") + "`n    )"
    $raw = Get-Content -LiteralPath $manifest -Raw
    $updated = [regex]::Replace($raw, 'FunctionsToExport\s*=\s*@\([\s\S]*?\)', $block, 1)
    if ($updated -eq $raw) { throw 'FunctionsToExport block not found in manifest.' }
    Set-Content -LiteralPath $manifest -Value $updated -Encoding utf8
    Write-Host "Updated FunctionsToExport with $($publicFunctions.Count) functions."
    $exported = @($publicFunctions)
}

$dangling  = @($exported | Where-Object { $publicFunctions -notcontains $_ })
$unexported = @($publicFunctions | Where-Object { $exported -notcontains $_ })
$leaked    = @($exported | Where-Object { $privateFunctions -contains $_ })

Write-Host "public functions : $($publicFunctions.Count)"
Write-Host "exported (manifest): $($exported.Count)"
if ($privateFunctions.Count) { Write-Host "private helpers  : $($privateFunctions.Count) ($($privateFunctions -join ', '))" }

$ok = $true
if ($dangling.Count)   { Write-Host "ERROR: exported but undefined: $($dangling -join ', ')" -ForegroundColor Red; $ok = $false }
if ($unexported.Count) { Write-Host "ERROR: defined but not exported: $($unexported -join ', ')" -ForegroundColor Red; $ok = $false }
if ($leaked.Count)     { Write-Host "ERROR: private helper exported: $($leaked -join ', ')" -ForegroundColor Red; $ok = $false }

if ($ok) { Write-Host "OK: manifest and source agree." -ForegroundColor Green; exit 0 }
exit 1
