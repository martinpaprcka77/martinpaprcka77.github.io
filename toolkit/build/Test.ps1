<#
.SYNOPSIS
    Runs the full verification gate: manifest parity, Pester, PSScriptAnalyzer.
.DESCRIPTION
    One command that a contributor or CI runs before committing:

      1. build/Build.ps1        - manifest <-> source parity
      2. Invoke-Pester          - tests/Toolkit.Tests.ps1
      3. Invoke-ScriptAnalyzer  - errors only, if installed

    Exits non-zero if any stage fails. Local-only.
.EXAMPLE
    pwsh -File build/Test.ps1
.NOTES
    PSScriptAnalyzer is optional; the step is skipped when the module is absent.
#>
[CmdletBinding()]
param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$failed = $false

Write-Host "== 1/3 manifest parity ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'Build.ps1')
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host "`n== 2/3 Pester ==" -ForegroundColor Cyan
$pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($pester) {
    $output = if ($Detailed) { 'Detailed' } else { 'None' }
    $result = Invoke-Pester -Path (Join-Path $root 'tests' 'Toolkit.Tests.ps1') -Output $output -PassThru
    Write-Host ("Passed {0} / Failed {1} / Total {2}" -f $result.PassedCount, $result.FailedCount, $result.TotalCount)
    if ($result.FailedCount -gt 0) { $failed = $true }
} else {
    Write-Host "Pester not installed - skipping." -ForegroundColor Yellow
}

Write-Host "`n== 3/3 PSScriptAnalyzer (errors) ==" -ForegroundColor Cyan
if (Get-Module -ListAvailable PSScriptAnalyzer) {
    $paths = @('Toolkit', 'ops', 'build') | ForEach-Object { Join-Path $root $_ }
    $errors = foreach ($p in $paths) { Invoke-ScriptAnalyzer -Path $p -Recurse -Severity Error }
    $errors = @($errors)
    if ($errors.Count) {
        $errors | Format-Table RuleName, ScriptName, Line, Message -AutoSize | Out-String | Write-Host
        $failed = $true
    } else {
        Write-Host "No analyzer errors." -ForegroundColor Green
    }
} else {
    Write-Host "PSScriptAnalyzer not installed - skipping." -ForegroundColor Yellow
}

Write-Host ''
if ($failed) { Write-Host "VERIFICATION FAILED" -ForegroundColor Red; exit 1 }
Write-Host "VERIFICATION PASSED" -ForegroundColor Green
exit 0
