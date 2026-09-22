<#
.SYNOPSIS
    Validates all internal links and documentation references in the repo.
.DESCRIPTION
    Scans Markdown, HTML, and PowerShell files for:
    - Broken internal links (reference non-existent files)
    - Orphaned documentation (files referenced but not found)
    - Invalid function/command names
    - Dead gist or GitHub links

    Only repo-internal `.md` links are resolved; absolute URLs (https://…),
    anchors (`#frag`) and non-`.md` targets are out of scope.
.PARAMETER RepoRoot
    Root of the repository (default: parent of this script).
.PARAMETER Fix
    Automatically remove invalid entries (experimental).
.PARAMETER Verbose
    Common parameter (from [CmdletBinding()]) — show all checked links, not just failures.
    Do not add an explicit [switch]$Verbose: the name would then be defined twice and the
    script fails to run at all with
      MetadataError: A parameter with the name 'Verbose' was defined multiple times for the command.
.EXAMPLE
    .\Validate-Links.ps1 -Verbose
    .\Validate-Links.ps1 -Fix
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'
$issues = @()
$checked = 0
$valid = 0

Write-Host "🔍 Link Validation Report" -ForegroundColor Cyan
Write-Host "$(('─' * 60))`n" -ForegroundColor DarkGray

# Vendored third-party material and VCS internals are not ours to lint.
# .github/agents/ is a 222-file third-party Copilot agent pack that AGENTS.md
# states explicitly is not maintained here.
$excluded = '\\(\.git|\.github\\agents|node_modules)\\'

$repoFiles = @(
    Get-ChildItem -Path $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $excluded }
)

# Index every function defined anywhere in the repo, via the AST — so both
# `function Foo {` and `function Foo(...) {` count. The previous regex only
# matched the parenthesised form (and re-scanned the whole tree once per
# candidate name), so most of this repo's own helpers — everything in
# profile/lib, Setup-Windows.ps1's Test-CommandExists/Set-WindowsDefaults —
# were reported as "undefined".
$defined = @{}
# Command names the author already probes for with `Get-Command <name>`. Those
# are deliberately optional (e.g. the Windows-only Get-AppxPackage, which does
# not exist in pwsh) and must not be reported as undefined.
$probed = @{}
foreach ($file in $repoFiles | Where-Object { $_.Extension -in '.ps1', '.psm1' }) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $defined[$fn.Name] = $true
    }
    foreach ($call in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        if ($call.GetCommandName() -ne 'Get-Command') { continue }
        $nameArg = $call.CommandElements |
            Select-Object -Skip 1 |
            Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
            Select-Object -First 1
        if ($nameArg) { $probed[$nameArg.Value] = $true }
    }
}

# Commands declared by the modules installed on this machine. Built lazily —
# only when the function check actually hits an unresolved name — so a clean
# run never pays the ~750ms Get-Module -ListAvailable cost.
$moduleCommands = $null

# Recursive, not just the repo root — docs/*.md link to each other and to the
# root, and the old root-only glob silently skipped every one of them.
$scanFiles = @($repoFiles | Where-Object { $_.Extension -in '.md', '.html', '.ps1' })
Write-Host "Scanning $(@($scanFiles).Count) files...`n" -ForegroundColor Gray

# Relative Markdown/HTML link to a .md file, with an optional #anchor.
$linkPattern = '\[[^\]]*\]\(([^)\s#]+?\.md)(?:#[^)]*)?\)|href="((?:docs|github)[^"]*?\.md)"'

foreach ($file in $scanFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $fileRel = $file.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
    $fileDir = Split-Path $file.FullName -Parent

    # ── Internal .md links ──────────────────────────────────────
    foreach ($match in [regex]::Matches($content, $linkPattern)) {
        # PowerShell's -or is a *boolean* operator, not a null-coalescing one:
        # `$m.Groups[1].Value -or $m.Groups[2].Value` evaluated to $true, so
        # every match was then tested as the literal string "True" and the
        # report read "❌ Broken link: True" for the entire repo.
        $link = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        if (-not $link) { continue }
        if ($link -match '^[a-z][a-z0-9+.-]*://') { continue }   # absolute URL, not repo-internal
        $checked++

        # Resolve relative to the containing file first (how Markdown links
        # actually work), then fall back to the repo root (how the portal's
        # root-relative hrefs work). The old version only ever tried the root.
        $resolved = if (Test-Path (Join-Path $fileDir $link)) { Join-Path $fileDir $link }
                    elseif (Test-Path (Join-Path $RepoRoot $link)) { Join-Path $RepoRoot $link }
                    else { $null }
        if ($resolved) {
            $valid++
            if ($VerbosePreference -ne 'SilentlyContinue') { Write-Host "  ✓ $link" -ForegroundColor Green }
        } else {
            $issues += @{
                File = $fileRel
                Issue = "❌ Broken link: $link"
                Type = 'broken-link'
                Link = $link
            }
        }
    }

    # ── Function/command names invoked from PowerShell files ────
    if ($file.Extension -eq '.ps1') {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $called = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
            ForEach-Object { $_.GetCommandName() } |
            Where-Object { $_ -match '^(Get|Invoke|Test|Show|Add|Remove|Set)-[\w-]+$' } |
            Sort-Object -Unique
        foreach ($func in $called) {
            $checked++
            $known = $defined.ContainsKey($func) -or
                     $probed.ContainsKey($func) -or
                     [bool](Get-Command -Name $func -ErrorAction SilentlyContinue)
            if (-not $known) {
                # Get-Command does NOT auto-load modules, and Windows-only
                # modules (NetTCPIP, Appx) are not even on pwsh's module path —
                # so a name that works fine for the user can look undefined
                # here. PSFzf's Set-PsFzfOption was reported this way. Fall back
                # to the commands the available modules declare.
                if ($null -eq $moduleCommands) {
                    $moduleCommands = @{}
                    foreach ($m in Get-Module -ListAvailable -ErrorAction SilentlyContinue) {
                        foreach ($coll in @($m.ExportedFunctions, $m.ExportedCmdlets, $m.ExportedAliases)) {
                            if ($coll) { foreach ($k in $coll.Keys) { $moduleCommands[$k] = $true } }
                        }
                    }
                }
                $known = $moduleCommands.ContainsKey($func)
            }
            if ($known) { $valid++ }
            else {
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
# NOT `exit if ($issues) { 1 } else { 0 }` — that parses but at runtime `exit` treats the
# `if` keyword as a command name and fails with
#   The term 'if' is not recognized as a name of a cmdlet, function, script file, ...
# so the script always died on its last line (masked until the -Verbose param collision above
# was fixed, because the script never got this far).
if ($issues) { exit 1 } else { exit 0 }
