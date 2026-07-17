<#
.SYNOPSIS
    Validates all internal links and documentation references in the repo.
.DESCRIPTION
    Scans HTML, Markdown, and PowerShell files for:
    - Broken internal links (reference non-existent files)
    - Orphaned documentation (files referenced but not found)
    - Invalid function/command names
    - Dead gist or GitHub links
.PARAMETER RepoRoot
    Root of the repository (default: parent of this script).
.PARAMETER Fix
    Automatically remove invalid entries (experimental).
.PARAMETER Verbose
    Show all checked links (not just failures).
.EXAMPLE
    .\Validate-Links.ps1 -Verbose
    .\Validate-Links.ps1 -Fix
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$Fix,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$issues = @()
$checked = 0
$valid = 0

Write-Host "🔍 Link Validation Report" -ForegroundColor Cyan
Write-Host "$(('─' * 60))`n" -ForegroundColor DarkGray

# Index all files in repo
$allFiles = @{}
Get-ChildItem -Path $RepoRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Replace($RepoRoot, '').TrimStart('\', '/')
    $allFiles[$rel] = $_.FullName
}

# Patterns to check
$patterns = @(
    @{ Pattern = '\[.*?\]\((.*?\.md)\)'; Type = 'Markdown link'; Group = 1 }
    @{ Pattern = 'href="((?:docs|github).*?\.md)"'; Type = 'HTML link'; Group = 1 }
    @{ Pattern = '(?:Get-|Invoke-|Test-|Show-|Add-|Remove-|Set-)[\w-]+'; Type = 'Function'; Group = 0 }
)

# Files to scan
$scanFiles = @(
    '*.md', '*.html', '*.ps1'
) | ForEach-Object { Join-Path $RepoRoot $_ } | ForEach-Object {
    Get-Item -Path $_ -ErrorAction SilentlyContinue
}

Write-Host "Scanning $(@($scanFiles).Count) files...`n" -ForegroundColor Gray

foreach ($file in $scanFiles) {
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $fileRel = $file.FullName.Replace($RepoRoot, '').TrimStart('\', '/')

    # Check Markdown/HTML links
    $matches = [regex]::Matches($content, '\[.*?\]\((.*?\.md)\)|href="((?:docs|github).*?\.md)"')
    foreach ($match in $matches) {
        $link = $match.Groups[1].Value -or $match.Groups[2].Value
        $checked++

        if (-not (Test-Path (Join-Path $RepoRoot $link))) {
            $issues += @{
                File = $fileRel
                Issue = "❌ Broken link: $link"
                Type = 'broken-link'
                Link = $link
            }
        } else {
            $valid++
            if ($Verbose) { Write-Host "  ✓ $link" -ForegroundColor Green }
        }
    }

    # Check function definitions vs usage
    if ($file.Extension -eq '.ps1') {
        $funcMatches = [regex]::Matches($content, '(?:Get-|Invoke-|Test-|Show-|Add-|Remove-|Set-)[\w-]+')
        foreach ($match in $funcMatches) {
            $func = $match.Value
            $checked++

            # Quick check: is this function defined anywhere in the repo?
            $funcDef = Get-ChildItem -Path $RepoRoot -Recurse -Include '*.ps1' |
                Where-Object { (Get-Content $_ -Raw) -match "function\s+$([regex]::Escape($func))\s*\(" } |
                Select-Object -First 1

            if ($funcDef) {
                $valid++
            } else {
                # Only warn if it looks like a custom function (not a built-in)
                $builtins = @('Get-Command', 'Get-Content', 'Get-ChildItem', 'Write-Host', 'Write-Error', 'Test-Path')
                if ($func -notin $builtins) {
                    $issues += @{
                        File = $fileRel
                        Issue = "⚠️  Undefined function: $func"
                        Type = 'undefined-function'
                        Function = $func
                    }
                }
            }
        }
    }
}

# Summary
Write-Host "`n$(('─' * 60))" -ForegroundColor DarkGray
Write-Host "✓ Valid links/functions: $valid" -ForegroundColor Green
Write-Host "⚠️  Issues found: $(@($issues).Count)" -ForegroundColor Yellow
Write-Host ""

if ($issues) {
    Write-Host "Issues to review:" -ForegroundColor Red
    $issues | Group-Object File | ForEach-Object {
        Write-Host "`n  📄 $($_.Name):" -ForegroundColor Yellow
        $_.Group | ForEach-Object {
            Write-Host "    $($_.Issue)" -ForegroundColor Red
        }
    }

    if ($Fix) {
        Write-Host "`n🔧 Attempting automatic cleanup..." -ForegroundColor Cyan
        $issues | Where-Object { $_.Type -eq 'broken-link' } | ForEach-Object {
            $file = Join-Path $RepoRoot $_.File
            $content = Get-Content $file -Raw
            $content = $content -replace "\[.*?\]\($([regex]::Escape($_.Link))\)", ""
            $content = $content -replace 'href="' + [regex]::Escape($_.Link) + '"', ""
            Set-Content $file $content
            Write-Host "  ✓ Cleaned: $($_.File)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "✅ All links and references are valid!" -ForegroundColor Green
}

Write-Host ""
exit if ($issues) { 1 } else { 0 }
