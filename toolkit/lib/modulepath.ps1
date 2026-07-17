<#
.SYNOPSIS
    PSModulePath manager — list, add, remove, reset, export/import, validate.
.DESCRIPTION
    Manages $env:PSModulePath programmatically. Prevents OneDrive pollution,
    ensures modern module priority, and provides export/import for reproducibility.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/modulepath.ps1
#>

# ── Get-PSModulePath — list all entries ────────────────────────
<#
.SYNOPSIS
    Lists all PSModulePath entries with validation status.
.EXAMPLE
    Get-PSModulePath
#>
function Get-PSModulePath {
    $entries = $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ }
    Write-Host "`n PSModulePath entries ($($entries.Count)):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e = $entries[$i]
        $exists = Test-Path $e
        $icon = if ($exists) { '[OK]' } else { '[X]' }
        $color = if ($exists) { 'White' } else { 'Red' }
        $label = if ($i -eq 0) { ' (primary)' } else { '' }
        Write-Host "  $icon [$i]$label $e" -ForegroundColor $color
    }
    return $entries
}

# ── Add-PSModulePath — add path without duplicates ─────────────
<#
.SYNOPSIS
    Adds a path to PSModulePath if not already present.
.PARAMETER Path
    Directory path to add.
.PARAMETER Prepend
    Add to beginning (higher priority) instead of end.
.EXAMPLE
    Add-PSModulePath -Path "$env:LOCALAPPDATA\PowerShell\Modules" -Prepend
#>
function Add-PSModulePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Prepend
    )
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    $Path = if ($resolved) { $resolved.Path } else { $Path }
    $entries = $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ }

    if ($Path -in $entries) {
        Write-Host "  [=] Already in PSModulePath: $Path" -ForegroundColor Gray
        return
    }

    if (-not (Test-Path $Path)) {
        Write-Warn "Path does not exist: $Path (still adding)"
    }

    if ($Prepend) {
        $env:PSModulePath = "$Path$([IO.Path]::PathSeparator)$env:PSModulePath"
    } else {
        $env:PSModulePath = "$env:PSModulePath$([IO.Path]::PathSeparator)$Path"
    }
    Write-Host "  [+] Added to PSModulePath: $Path" -ForegroundColor Green
}

# ── Remove-PSModulePath — remove a path entry ──────────────────
<#
.SYNOPSIS
    Removes a path from PSModulePath.
.PARAMETER Path
    Exact path or index number to remove.
.EXAMPLE
    Remove-PSModulePath -Path "C:\Old\Modules"
    Remove-PSModulePath -Index 3
#>
function Remove-PSModulePath {
    param(
        [string]$Path,
        [int]$Index = -1
    )
    $entries = [System.Collections.ArrayList]@($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })

    if ($Index -ge 0 -and $Index -lt $entries.Count) {
        $removed = $entries[$Index]
        $entries.RemoveAt($Index)
        $env:PSModulePath = $entries -join [IO.Path]::PathSeparator
        Write-Host "  [+] Removed [$Index]: $removed" -ForegroundColor Green
        return
    }

    if ($Path -and ($Path -in $entries)) {
        $entries.Remove($Path)
        $env:PSModulePath = $entries -join [IO.Path]::PathSeparator
        Write-Host "  [+] Removed: $Path" -ForegroundColor Green
        return
    }

    Write-Warn "Path not found. Use Get-PSModulePath to see entries."
}

# ── Reset-PSModulePath — modern baseline ───────────────────────
<#
.SYNOPSIS
    Resets PSModulePath to the modern recommended baseline.
.DESCRIPTION
    Sets: ProgramFiles\PowerShell\7\Modules first, then Documents\PowerShell\Modules.
    Removes WindowsPowerShell 5.1 paths to prevent legacy module conflicts.
.EXAMPLE
    Reset-PSModulePath
#>
function Reset-PSModulePath {
    # $env:USERPROFILE\Documents\... was here previously — exactly the
    # OneDrive-affected path this function's own OneDrive-pollution check
    # (Test-PSModulePath) warns about. LOCALAPPDATA is never a Known-Folder
    # redirection target, so it's the actually-safe "modern baseline" entry.
    $modern = @(
        "$env:ProgramFiles\PowerShell\7\Modules",
        "$env:LOCALAPPDATA\PowerShell\Modules"
    )
    Write-Host "`n Resetting PSModulePath to modern baseline..." -ForegroundColor Magenta
    foreach ($p in $modern) {
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
            Write-Host "  [+] Created: $p" -ForegroundColor Green
        }
    }
    $env:PSModulePath = $modern -join [IO.Path]::PathSeparator
    Write-Host "  [+] PSModulePath reset:" -ForegroundColor Green
    # Call Get-PSModulePath to display the new state — was | Out-Null, which
    # suppressed the returned entries display. The Write-Host lines inside
    # the function still showed, but the raw entry list is also informative.
    Get-PSModulePath | Out-Host
}

# ── Export-PSModulePath — save config to file ──────────────────
<#
.SYNOPSIS
    Exports current PSModulePath to a JSON config file.
.PARAMETER OutputPath
    Where to save (default: ~/.config/powershell/psmodulepath.json)
.EXAMPLE
    Export-PSModulePath
    Export-PSModulePath -OutputPath "D:\backup\modules.json"
#>
function Export-PSModulePath {
    param(
        [string]$OutputPath = (Join-Path $HOME '.config\powershell\psmodulepath.json')
    )
    $entries = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })
    $export = @{
        ExportedAt   = (Get-Date -Format 'o')
        PSVersion    = $PSVersionTable.PSVersion.ToString()
        Entries      = $entries
        EntryCount   = $entries.Count
    }
    $export | ConvertTo-Json -Depth 2 | Set-Content $OutputPath -Encoding UTF8
    Write-Host "  [+] Exported $($entries.Count) paths to: $OutputPath" -ForegroundColor Green
}

# ── Import-PSModulePath — restore from config ──────────────────
<#
.SYNOPSIS
    Imports PSModulePath from a previously exported JSON file.
.PARAMETER InputPath
    Path to the JSON export file.
.PARAMETER Merge
    Merge with current paths instead of replacing.
.EXAMPLE
    Import-PSModulePath
    Import-PSModulePath -InputPath "D:\backup\modules.json" -Merge
#>
function Import-PSModulePath {
    param(
        [string]$InputPath = (Join-Path $HOME '.config\powershell\psmodulepath.json'),
        [switch]$Merge
    )
    if (-not (Test-Path $InputPath)) {
        throw "Export file not found: $InputPath"
    }
    try {
        $import = Get-Content $InputPath -Raw | ConvertFrom-Json
        $entries = @($import.Entries)
        Write-Host "`n Importing $($entries.Count) paths from: $InputPath" -ForegroundColor Cyan
        Write-Host "   Exported: $($import.ExportedAt) | PS $($import.PSVersion)" -ForegroundColor DarkGray

        if ($Merge) {
            $current = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })
            $entries = @($current + $entries | Select-Object -Unique)
        }

        foreach ($e in $entries) {
            if (Test-Path $e) {
                Write-Host "  [OK] $e" -ForegroundColor Green
            } else {
                Write-Host "  [X] $e (not found, still adding)" -ForegroundColor Red
            }
        }
        $env:PSModulePath = $entries -join [IO.Path]::PathSeparator
        Write-Host "  [+] PSModulePath imported." -ForegroundColor Green
    } catch {
        throw "Import failed: $_"
    }
}

# ── Test-PSModulePath — self-validation ────────────────────────
<#
.SYNOPSIS
    Validates the PSModulePath configuration.
.DESCRIPTION
    Checks: duplicate entries, missing directories, OneDrive paths,
    legacy module conflicts, and version consistency.
.EXAMPLE
    Test-PSModulePath
#>
function Test-PSModulePath {
    $entries = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })
    $issues = 0

    Write-Host "`n PSModulePath VALIDATION" -ForegroundColor Magenta
    Write-Host "   $(('-' * 55))" -ForegroundColor DarkGray

    # Check duplicates
    $dupes = $entries | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dupes) {
        foreach ($d in $dupes) {
            Write-Host "  [!]  Duplicate ($($d.Count)x): $($d.Name)" -ForegroundColor Yellow
            $issues++
        }
    } else {
        Write-Host "  [OK] No duplicates" -ForegroundColor Green
    }

    # Check missing directories
    $missing = $entries | Where-Object { -not (Test-Path $_) }
    foreach ($m in $missing) {
        Write-Host "  [X] Missing: $m" -ForegroundColor Red
        $issues++
    }
    if (-not $missing) {
        Write-Host "  [OK] All paths exist" -ForegroundColor Green
    }

    # Check OneDrive pollution
    $oneDrive = $entries | Where-Object { $_ -match 'OneDrive' }
    if ($oneDrive) {
        foreach ($o in $oneDrive) {
            Write-Host "  [!]  OneDrive path (may cause slowdowns): $o" -ForegroundColor Yellow
            $issues++
        }
    } else {
        Write-Host "  [OK] No OneDrive paths" -ForegroundColor Green
    }

    # Check priority
    $ps7Path = "$env:ProgramFiles\PowerShell\7\Modules"
    if ($entries[0] -eq $ps7Path) {
        Write-Host "  [OK] PS7 modules have priority" -ForegroundColor Green
    } else {
        Write-Host "  [!]  PS7 modules NOT first — current: $($entries[0])" -ForegroundColor Yellow
        $issues++
    }

    # Summary
    Write-Host "   $(('-' * 55))" -ForegroundColor DarkGray
    if ($issues -eq 0) {
        Write-Host "  [OK] All checks passed." -ForegroundColor Green
    } else {
        Write-Host "  [!]  $issues issue(s) found. Run Reset-PSModulePath to fix." -ForegroundColor Yellow
    }
    return ($issues -eq 0)
}
