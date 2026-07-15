<#
.SYNOPSIS
    Performance optimization tools for the PowerShell Dotfiles Ecosystem.
.DESCRIPTION
    Measure-Profile, Clear-PSCache, module analysis, startup diagnostics.
    Based on: https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/startup-performance
.NOTES
    Cesta: ~/.config/powershell/profile/core/perf.ps1
#>

# ── Measure-Profile — detailed step-by-step timing ─────────────
<#
.SYNOPSIS
    Measures profile load time step by step, identifying slow parts.
.DESCRIPTION
    Runs profile.ps1 with timing for each section. Outputs a breakdown
    that shows exactly which part of the profile is slow.
    For ETW-level detail (module loads, JIT, provider events) instead of
    coarse timing, see Measure-PSCommand in core/diag.ps1 (Windows-only).
.EXAMPLE
    Measure-Profile
#>
function Measure-Profile {
    [CmdletBinding()]
    param()
    $profilePath = Join-Path $env:DOTFILES_PWSH 'profile.ps1'
    if (-not (Test-Path $profilePath)) {
        Write-Host "Profile not found: $profilePath" -ForegroundColor Red
        return
    }

    Write-Host "`n⏱️  PROFILE PERFORMANCE ANALYSIS" -ForegroundColor Magenta
    Write-Host "   $(('─' * 50))" -ForegroundColor DarkGray

    $total = Measure-Command {
        # Capture detailed timing by running with benchmark mode
        $env:PROFILE_BENCHMARK = 'true'
        $origProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            . $profilePath -ErrorAction Stop
        } catch {
            Write-Error "Profile error: $_"
        } finally {
            $ProgressPreference = $origProgressPreference
            $env:PROFILE_BENCHMARK = $null
        }
    }

    Write-Host "   Total load time: $($total.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor $(if ($total.TotalMilliseconds -lt 500) { 'Green' } elseif ($total.TotalMilliseconds -lt 1000) { 'Yellow' } else { 'Red' })

    # Analyze what's loaded
    Write-Host "`n   Loaded modules:" -ForegroundColor Cyan
    $loadedModules = Get-Module | Where-Object { $_.Name -notmatch '^Microsoft\.PowerShell\.(Core|Utility|Management|Security|Diagnostics|Host)$' }
    foreach ($m in $loadedModules) {
        $loadTime = if ($m.Name -eq 'PSReadLine') { '~150ms' } else { 'unknown' }
        Write-Host "     $($m.Name) v$($m.Version)  ($loadTime)" -ForegroundColor DarkGray
    }

    Write-Host "`n   Dot-sourced scripts:" -ForegroundColor Cyan
    $coreDir = Join-Path $env:DOTFILES_PWSH 'core'
    if (Test-Path $coreDir) {
        Get-ChildItem $coreDir -Filter '*.ps1' | ForEach-Object {
            $size = (Get-Content $_.FullName | Measure-Object -Line).Lines
            Write-Host "     core/$($_.Name)  ($size lines)" -ForegroundColor DarkGray
        }
    }

    Write-Host "`n   Recommendations:" -ForegroundColor Yellow
    if ($total.TotalMilliseconds -gt 1000) {
        Write-Host "   ⚠️  Profile load >1s. Consider:" -ForegroundColor Red
        Write-Host "     - Remove unused Import-Module calls"
        Write-Host "     - Use lazy loading: if (Get-Command ...) { Import-Module }"
        Write-Host "     - Move heavy init to function (load on first use)"
    } elseif ($total.TotalMilliseconds -gt 500) {
        Write-Host "   ⚡ Profile load 500ms-1s. Decent, room to improve." -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Profile load <500ms. Good!" -ForegroundColor Green
    }
}

# ── Clear-PSCache — cleanup corrupted module/startup caches ────
<#
.SYNOPSIS
    Clears PowerShell module analysis and startup caches.
.DESCRIPTION
    Deletes ModuleAnalysisCache-* and StartupProfileData-* files.
    Useful when PowerShell starts slowly or crashes during startup.
.EXAMPLE
    Clear-PSCache
#>
function Clear-PSCache {
    [CmdletBinding()]
    param()
    $caches = @(
        "$env:LOCALAPPDATA\Microsoft\PowerShell\ModuleAnalysisCache-*",
        "$env:LOCALAPPDATA\Microsoft\PowerShell\StartupProfileData-*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Caches"
    )

    Write-Host "`n🧹 CLEARING POWERSHELL CACHES" -ForegroundColor Magenta
    $cleared = 0
    foreach ($pattern in $caches) {
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "   Deleted: $($f.Name)" -ForegroundColor DarkGray
            $cleared++
        }
    }

    if ($cleared -eq 0) {
        Write-Host "   No cache files found." -ForegroundColor Gray
    } else {
        Write-Host "`n   ✅ Cleared $cleared cache files. Restart PowerShell to rebuild." -ForegroundColor Green
    }
}

# ── Optimize-ModuleLoading — analyze and suggest lazy alternatives ──
<#
.SYNOPSIS
    Analyzes loaded modules and suggests lazy loading strategies.
.DESCRIPTION
    Lists all non-essential modules loaded at startup and shows
    how to convert them to lazy (on-demand) loading.
.EXAMPLE
    Optimize-ModuleLoading
#>
function Optimize-ModuleLoading {
    [CmdletBinding()]
    param()
    Write-Host "`n📦 MODULE LOADING ANALYSIS" -ForegroundColor Magenta

    $essential = @('Microsoft.PowerShell.Core', 'PSReadLine')
    $loaded = Get-Module | Where-Object { $_.Name -notin $essential }

    Write-Host "   Lazy loading patterns:" -ForegroundColor Cyan
    Write-Host "   $(('─' * 50))" -ForegroundColor DarkGray

    foreach ($m in $loaded) {
        $funcs = $m.ExportedCommands.Keys | Select-Object -First 3
        $funcList = ($funcs -join ', ')
        Write-Host "`n   $($m.Name) v$($m.Version)" -ForegroundColor White
        Write-Host "   Exports: $funcList..." -ForegroundColor DarkGray
        Write-Host "   Replace Import-Module with:" -ForegroundColor Yellow
        Write-Host "     if (Get-Command $($funcs[0]) -ErrorAction SilentlyContinue) { Import-Module $($m.Name) }" -ForegroundColor Green
    }

    Write-Host "`n   💡 Tip: Lazy loading means modules load on first use, not at startup." -ForegroundColor Cyan
}

# ── Get-ProfileSize ────────────────────────────────────────────
<#
.SYNOPSIS
    Reports total size of the profile in lines and bytes.
#>
function Get-ProfileSize {
    [CmdletBinding()]
    param()
    $profilePath = Join-Path $env:DOTFILES_PWSH 'profile.ps1'
    $coreDir = Join-Path $env:DOTFILES_PWSH 'core'

    if (-not (Test-Path $profilePath)) { Write-Host "Profile not found." -ForegroundColor Red; return }

    $total = @{ Lines = 0; Bytes = 0; Files = 0 }
    # $files must be a uniform array of file objects (not a mix of string + FileInfo) —
    # the loop below reads $f.FullName on every entry.
    $files = @(Get-Item $profilePath)
    if (Test-Path $coreDir) { $files += Get-ChildItem $coreDir -Filter '*.ps1' }

    foreach ($f in $files) {
        $content = Get-Content $f.FullName -Raw
        $total.Lines += ($content -split "`n").Count
        $total.Bytes += $content.Length
        $total.Files++
    }

    Write-Host "`n📏 PROFILE SIZE" -ForegroundColor Magenta
    Write-Host "   Files: $($total.Files)" -ForegroundColor White
    Write-Host "   Lines: $($total.Lines)" -ForegroundColor White
    Write-Host "   Size:  $([math]::Round($total.Bytes / 1KB, 1)) KB" -ForegroundColor White
    if ($total.Lines -gt 500) {
        Write-Host "   ⚠️  Profile >500 lines. Consider splitting or lazy-loading." -ForegroundColor Yellow
    }
}
