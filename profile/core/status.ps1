<#
.SYNOPSIS
    Global health dashboard for the entire dotfiles ecosystem.
.DESCRIPTION
    Shows status of: Dotfiles profiles, WT fragment, VS Code configs,
    PowerShell modules, environment variables, PATH, Git repos.
.NOTES
    Cesta: ~/.config/powershell/profile/core/status.ps1
#>

<#
.SYNOPSIS
    Reports duplicate PATH entries, and (Windows only) overlap between the
    User- and Machine-scope PATH that Windows concatenates into the process
    PATH — a common source of "why is this here twice" confusion.
.DESCRIPTION
    Read-only — never modifies PATH. For PSModulePath specifically (a
    related but separate concern, including OneDrive-pollution detection),
    see Test-PSModulePath / Reset-PSModulePath in the toolkit module.
#>
function Test-PathHealth {
    [CmdletBinding()]
    param()
    $entries = $env:PATH -split [IO.Path]::PathSeparator | Where-Object { $_ }
    $normalized = $entries | ForEach-Object { $_.TrimEnd('\', '/').ToLowerInvariant() }
    $duplicates = $normalized | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }

    $result = @{ Duplicates = @($duplicates); MachineUserOverlap = $null }

    # Local guard: $isWindowsHost is set by profile.ps1 before dot-sourcing core/*,
    # but Show-Status/Test-PathHealth could be called standalone (e.g. from a module
    # import session). Defensive fallback so the User/Machine PATH overlap check
    # doesn't silently skip on an undefined variable.
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User') -split [IO.Path]::PathSeparator | Where-Object { $_ }
        $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine') -split [IO.Path]::PathSeparator | Where-Object { $_ }
        $userNorm = $userPath | ForEach-Object { $_.TrimEnd('\', '/').ToLowerInvariant() }
        $machineNorm = $machinePath | ForEach-Object { $_.TrimEnd('\', '/').ToLowerInvariant() }
        $result.MachineUserOverlap = @($userNorm | Where-Object { $_ -in $machineNorm })
    }

    return $result
}

function Show-Status {
    [CmdletBinding()]
    param()
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Host "   $(('─' * 55))" -ForegroundColor DarkGray

    # Dot() is nested inside Show-Status and increments via $script:, so these
    # counters must be declared at $script: scope too, or the final tally always
    # reads 0/0/0 — Dot's $script:ok++ and this function's own bare $ok are two
    # different variables otherwise. Show-Status resets them on every call, so
    # this doesn't leak state between invocations.
    $script:ok = 0; $script:warn = 0; $script:fail = 0

    function Dot { param([string]$L, [string]$S, [string]$Extra)
        $c = if ($S -eq '✅') { $script:ok++; 'Green' } elseif ($S -eq '⚠️') { $script:warn++; 'Yellow' } else { $script:fail++; 'Red' }
        $line = "   $S $L"
        if ($Extra) { $line += "  $Extra" }
        Write-Host $line -ForegroundColor $c
    }

    # ── Environment ────────────────────────────────────────────
    # Username/hostname/host-type/WT-session — each already computed
    # somewhere in this ecosystem (welcome banner, profile.ps1 host
    # detection, WT guards) but never all shown together in one place.
    Write-Host "`n   ENVIRONMENT" -ForegroundColor Cyan
    Dot 'User@Host'           '✅' "$env:USERNAME@$env:COMPUTERNAME"
    Dot 'PowerShell host'     '✅' "$($Host.Name) ($($PSVersionTable.PSEdition), v$($PSVersionTable.PSVersion))"
    Dot 'Windows Terminal'    $(if ($env:WT_SESSION) { '✅' } else { '⚠️' }) $(if ($env:WT_SESSION) { 'active session' } else { 'not detected' })
    Dot 'Working directory'   '✅' (Get-Location).Path

    # ── Dotfiles ───────────────────────────────────────────────
    Write-Host "`n   DOTFILES" -ForegroundColor Cyan
    $nativeProfiles = Get-NativeProfilePaths
    # Monorepo root — profile/ and toolkit/ are subfolders of one clone, not
    # two independent repos, so only the root has its own .git.
    $dotfilesRoot = if ($env:DOTFILES_PWSH) { Split-Path $env:DOTFILES_PWSH -Parent } else { $null }
    Dot 'Main profile'        $(if (Test-Path (Join-Path $env:DOTFILES_PWSH 'profile.ps1')) { '✅' } else { '❌' })
    Dot 'Bootstrap (PS7)'     $(if ((Test-Path $nativeProfiles[0]) -and (Get-Content $nativeProfiles[0] -Raw -ErrorAction SilentlyContinue) -match 'Bootstrap') { '✅' } else { '⚠️' })
    Dot 'Bootstrap (PS5)'     $(if ((Test-Path $nativeProfiles[2]) -and (Get-Content $nativeProfiles[2] -Raw -ErrorAction SilentlyContinue) -match 'Bootstrap') { '✅' } else { '⚠️' })
    Dot 'tools/bin in PATH'   $(if ((Join-Path $env:DOTFILES_TOOLS 'bin') -in ($env:PATH -split [IO.Path]::PathSeparator)) { '✅' } else { '⚠️' })
    Dot '$env:DOTFILES_PWSH'  $(if ($env:DOTFILES_PWSH) { '✅' } else { '⚠️' })
    Dot '$env:DOTFILES_TOOLS' $(if ($env:DOTFILES_TOOLS) { '✅' } else { '⚠️' })

    # ── Terminal ───────────────────────────────────────────────
    Write-Host "`n   TERMINAL" -ForegroundColor Cyan
    $frag = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json"
    Dot 'WT fragment'         $(if (Test-Path $frag) { '✅' } else { '⚠️' })
    if (Test-Path $frag) {
        try { $fj = Get-Content $frag -Raw | ConvertFrom-Json; $sc = @($fj.schemes).Count; $pc = @($fj.profiles).Count
            Dot "  $pc profiles, $sc schemes" '✅'
        } catch { Dot '  Fragment parse error' '❌' }
    }
    Dot 'Shell integration'   $(if ($env:WT_SESSION) { '✅' } else { '⚠️' })

    # ── PowerShell ─────────────────────────────────────────────
    Write-Host "`n   POWERSHELL" -ForegroundColor Cyan
    Dot "Version"             $(if ($PSVersionTable.PSVersion.Major -ge 7) { '✅' } else { '⚠️' }) "v$($PSVersionTable.PSVersion)"
    Dot 'PSReadLine'          $(if (Get-Module PSReadLine) { '✅' } else { '⚠️' })
    Dot 'Toolkit module'      $(if (Get-Module Toolkit) { '✅' } else { '⚠️' })
    Dot 'Starship prompt'     $(if (Get-Command starship -ErrorAction SilentlyContinue) { '✅' } else { '⚠️' })
    $modCount = @(Get-Module | Where-Object { $_.Name -notmatch '^Microsoft\.' }).Count
    Dot "Extra modules"       $(if ($modCount -le 5) { '✅' } else { '⚠️' }) "$modCount loaded"

    # ── VS Code ────────────────────────────────────────────────
    Write-Host "`n   VS CODE" -ForegroundColor Cyan
    Dot 'code in PATH'        $(if (Get-Command code -ErrorAction SilentlyContinue) { '✅' } else { '⚠️' })
    Dot 'Committed settings'  $(if ($dotfilesRoot -and (Test-Path (Join-Path $dotfilesRoot '.vscode\settings.json'))) { '✅' } else { '⚠️' })
    Dot 'Committed tasks'     $(if ($dotfilesRoot -and (Test-Path (Join-Path $dotfilesRoot '.vscode\tasks.json'))) { '✅' } else { '⚠️' })

    # ── Git ────────────────────────────────────────────────────
    Write-Host "`n   GIT" -ForegroundColor Cyan
    Dot 'Git installed'       $(if (Get-Command git -ErrorAction SilentlyContinue) { '✅' } else { '❌' })
    Dot 'dotfiles repo'       $(if ($dotfilesRoot -and (Test-Path (Join-Path $dotfilesRoot '.git'))) { '✅' } else { '⚠️' })

    # ── Docker ─────────────────────────────────────────────────
    Write-Host "`n   DOCKER" -ForegroundColor Cyan
    Dot 'Docker installed'    $(if (Get-Command docker -ErrorAction SilentlyContinue) { '✅' } else { '⚠️' })
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $running = (docker ps -q 2>$null | Measure-Object).Count
        Dot "  Running containers" '✅' "$running"
    }

    # ── PATH health ──────────────────────────────────────────────
    Write-Host "`n   PATH" -ForegroundColor Cyan
    $pathReport = Test-PathHealth
    Dot 'Duplicate PATH entries' $(if ($pathReport.Duplicates.Count -eq 0) { '✅' } else { '⚠️' }) "$($pathReport.Duplicates.Count) found"
    if ($pathReport.MachineUserOverlap) {
        Dot 'User/Machine PATH overlap' $(if ($pathReport.MachineUserOverlap.Count -eq 0) { '✅' } else { '⚠️' }) "$($pathReport.MachineUserOverlap.Count) found"
    }

    # ── Summary ────────────────────────────────────────────────
    Write-Host "`n   $(('─' * 55))" -ForegroundColor DarkGray
    Write-Host "   ✅ $ok  ⚠️ $warn  ❌ $fail" -ForegroundColor White
    if ($fail -gt 0) { Write-Host "   Run install.ps1 to fix issues." -ForegroundColor Red }
    elseif ($warn -gt 0) { Write-Host "   Run precheck.ps1 for detailed diagnostics." -ForegroundColor Yellow }
    else { Write-Host "   All systems nominal." -ForegroundColor Green }
}
