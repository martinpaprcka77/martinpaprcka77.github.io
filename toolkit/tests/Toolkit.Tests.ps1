<#
.SYNOPSIS
    Pester testy pro Toolkit modul — rozšířené pokrytí.
.DESCRIPTION
    Testuje existenci, chování a chybové stavy všech exportovaných funkcí.
    Připraveno pro CI (GitHub Actions).
.NOTES
    Cesta: ~/Projects/tools/tests/Toolkit.Tests.ps1
    Spuštění: Invoke-Pester ~/Projects/tools/tests/Toolkit.Tests.ps1

    Host output: every call under test that writes through Write-Host is redirected with
    `6>$null` (the information stream). Write-Host ignores $InformationPreference — it is
    hardwired to InformationAction Continue — so the preference cannot quiet these tests,
    while 6>$null can. Without it a green run is buried under the module's own diagnostics
    dump, which is exactly when a real failure gets missed. Do not "fix" this by mocking
    Write-Host: that would also mask a regression in the logging path itself.
#>

Describe 'Toolkit Module' {

    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1'
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
        }
    }

    # ── Module structure ──────────────────────────────────────
    Context 'Module structure' {
        It 'Toolkit.psd1 exists' {
            Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1' | Should -Exist
        }

        It 'Toolkit.psm1 exists' {
            Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psm1' | Should -Exist
        }

        It 'module sources exist' {
            $public = @('Console.ps1', 'Configuration.ps1', 'Detectors.ps1', 'Diagnostics.ps1', 'ModulePath.ps1', 'Output.ps1', 'Show-Menu.ps1')
            foreach ($f in $public) {
                Join-Path $PSScriptRoot "..\Toolkit\Public\$f" | Should -Exist
            }
            Join-Path $PSScriptRoot '..\Toolkit\Private\Get-ToolkitRoot.ps1' | Should -Exist
        }
    }

    # ── Exported functions ────────────────────────────────────
    Context 'Public functions' {
        $expectedFunctions = @(
            'Write-Info', 'Write-Success', 'Write-Warn', 'Write-Err', 'Confirm-Action',
            'Show-Menu', 'Start-MainMenu', 'Show-GitMenu',
            'Show-TerminalMenu', 'Show-DotfilesMenu', 'Show-PwshMenu', 'Show-VSCodeMenu', 'Show-StartupMenu',
            'Get-DiskStatus', 'Get-ServiceStatus', 'Get-NetworkInfo', 'Get-TopProcesses',
            'Invoke-SystemCheck',
            'Get-ToolkitConfig', 'Save-ToolkitConfig', 'Merge-Hashtable',
            'Get-PSModulePath', 'Add-PSModulePath', 'Remove-PSModulePath',
            'Reset-PSModulePath', 'Export-PSModulePath', 'Import-PSModulePath',
            'Test-PSModulePath',
            'Test-LegacyPowerShellGetPresent', 'Test-PSResourceGetReady', 'Get-ModuleStackStatus',
            'Get-ModulePathStatus', 'Write-TkMessage', 'Test-NetworkEndpoint', 'Get-SystemSummary', 'Get-ShellInfo'
        )

        It "Function '<_>' is exported" -ForEach $expectedFunctions {
            Get-Command -Name $_ -Module Toolkit -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    # ── Utility functions ────────────────────────────────────
    Context 'Utility functions' {
        It 'Write-Info does not throw' {
            { Write-Info 'test message' 6>$null } | Should -Not -Throw
        }

        It 'Write-Success does not throw' {
            { Write-Success 'test message' 6>$null } | Should -Not -Throw
        }

        It 'Write-Warn does not throw' {
            { Write-Warn 'test message' 6>$null } | Should -Not -Throw
        }

        It 'Write-Err does not throw' {
            { Write-Err 'test message' 6>$null } | Should -Not -Throw
        }

        It 'Confirm-Action returns false for default (no input)' {
            Mock Read-Host { return '' } -ModuleName Toolkit
            $result = Confirm-Action -Prompt 'Test?'
            $result | Should -Be $false
        }

        It 'Confirm-Action returns true for "y"' {
            Mock Read-Host { return 'y' } -ModuleName Toolkit
            $result = Confirm-Action -Prompt 'Test?'
            $result | Should -Be $true
        }
    }

    # ── Config functions ──────────────────────────────────────
    Context 'Configuration' {
        It 'Get-ToolkitConfig returns defaults' {
            # Force reload by clearing script cache
            InModuleScope Toolkit {
                $script:Config = $null
            }
            $cfg = Get-ToolkitConfig
            $cfg.menu.theme | Should -Be 'default'
            $cfg.system.checkDisks | Should -Be $true
        }

        It 'Get-ToolkitConfig respects TOOLKIT_* env vars' {
            $env:TOOLKIT_MENU_THEME = 'test-theme'
            InModuleScope Toolkit { $script:Config = $null }
            $cfg = Get-ToolkitConfig
            $cfg.menu.theme | Should -Be 'test-theme'
            Remove-Item Env:TOOLKIT_MENU_THEME -ErrorAction SilentlyContinue
            InModuleScope Toolkit { $script:Config = $null }
        }

        It 'Merge-Hashtable overrides base with override' {
            $b = @{ a = 1; b = 2; nested = @{ x = 1 } }
            $o = @{ b = 42; nested = @{ x = 99; y = 100 } }
            $r = Merge-Hashtable -Base $b -Override $o
            $r.a | Should -Be 1
            $r.b | Should -Be 42
            $r.nested.x | Should -Be 99
            $r.nested.y | Should -Be 100
        }
    }

    # ── Menu system ───────────────────────────────────────────
    Context 'Menu functions' {
        It 'Show-Menu parameter validation — Title is mandatory' {
            { Show-Menu -Items @{ '1' = { } } } | Should -Throw
        }

        It 'Show-Menu parameter validation — Items is mandatory' {
            { Show-Menu -Title 'Test' } | Should -Throw
        }

        It 'Start-MainMenu is callable without errors (mocked menu)' {
            Mock Show-Menu { } -ModuleName Toolkit
            { Start-MainMenu } | Should -Not -Throw
        }

        It 'Show-GitMenu handles missing Git gracefully' {
            Mock Get-Command { return $null } -ModuleName Toolkit -ParameterFilter { $Name -eq 'git' }
            Mock Write-Err { } -ModuleName Toolkit
            Mock Read-Host { '' } -ModuleName Toolkit
            { Show-GitMenu } | Should -Not -Throw
        }
    }

    # ── Checkers ──────────────────────────────────────────────
    Context 'System check functions' {
        It 'Invoke-SystemCheck runs without errors' {
            Mock Get-DiskStatus { 'mock-disks' } -ModuleName Toolkit
            Mock Get-ServiceStatus { 'mock-services' } -ModuleName Toolkit
            Mock Get-NetworkInfo { 'mock-network' } -ModuleName Toolkit
            Mock Get-TopProcesses { 'mock-processes' } -ModuleName Toolkit
            { Invoke-SystemCheck 6>$null } | Should -Not -Throw
        }

        It 'Get-DiskStatus does not throw' {
            { Get-DiskStatus -ErrorAction SilentlyContinue 6>$null } | Should -Not -Throw
        }

        It 'Get-ServiceStatus does not throw' {
            { Get-ServiceStatus -ErrorAction SilentlyContinue 6>$null } | Should -Not -Throw
        }

        It 'Get-TopProcesses does not throw' {
            { Get-TopProcesses -ErrorAction SilentlyContinue 6>$null } | Should -Not -Throw
        }

        It 'Get-SystemSummary returns a snapshot' {
            $s = Get-SystemSummary 6>$null
            $s.ComputerName | Should -Not -BeNullOrEmpty
            $s.PSVersion | Should -Not -BeNullOrEmpty
        }
    }

    # ── Shell info ────────────────────────────────────────────
    Context 'Shell info' {
        It 'Get-ShellInfo exposes shell, user, env, profiles, path' {
            $i = Get-ShellInfo 6>$null
            $i.Shell.Host | Should -Not -BeNullOrEmpty
            $i.User.Name | Should -Not -BeNullOrEmpty
            $i.Profiles.CurrentUserCurrentHost.Path | Should -Be $PROFILE.CurrentUserCurrentHost
            $i.Path.Count | Should -BeGreaterThan 0
            $i.DotSources.Count | Should -BeGreaterOrEqual 0
        }
    }

    # ── Connectivity ──────────────────────────────────────────
    Context 'Connectivity' {
        It 'Test-NetworkEndpoint reports unreachable hosts without throwing' {
            $r = Test-NetworkEndpoint -Target 'invalid.invalid' -TimeoutMs 200 6>$null
            $r.Target | Should -Be 'invalid.invalid'
            $r.Reachable | Should -BeFalse
        }
    }

    # ── PSModulePath functions ────────────────────────────────
    Context 'PSModulePath functions' {
        BeforeEach {
            $script:origPSModulePath = $env:PSModulePath
        }

        AfterEach {
            $env:PSModulePath = $script:origPSModulePath
        }

        It 'Get-PSModulePath returns the split entries' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            $result = Get-PSModulePath 6>$null
            $result | Should -Be @('C:\Mods\A', 'C:\Mods\B')
        }

        It 'Add-PSModulePath adds a new path' {
            $env:PSModulePath = 'C:\Mods\A'
            Add-PSModulePath -Path 'C:\Mods\New' 6>$null
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Contain 'C:\Mods\New'
        }

        It 'Add-PSModulePath is a no-op when the path already exists' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            Add-PSModulePath -Path 'C:\Mods\A' 6>$null
            ($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ -eq 'C:\Mods\A' }).Count | Should -Be 1
        }

        It 'Remove-PSModulePath removes by index' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            Remove-PSModulePath -Index 0 6>$null
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @('C:\Mods\B')
        }

        It 'Remove-PSModulePath removes by path' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            Remove-PSModulePath -Path 'C:\Mods\A' 6>$null
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @('C:\Mods\B')
        }

        It 'Reset-PSModulePath sets the modern baseline entries in order' {
            Mock Test-Path { $true } -ModuleName Toolkit
            Mock New-Item { } -ModuleName Toolkit
            Reset-PSModulePath 6>$null
            $entries = $env:PSModulePath -split [IO.Path]::PathSeparator
            $entries[0] | Should -Be (Join-Path $PSHOME 'Modules')
            # LOCALAPPDATA, never Documents — Documents can be OneDrive-redirected
            $entries[1] | Should -Be "$env:LOCALAPPDATA\PowerShell\Modules"
        }

        It 'Export-PSModulePath writes JSON with the correct entry count' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            $outPath = Join-Path $TestDrive 'psmodulepath.json'
            Export-PSModulePath -OutputPath $outPath 6>$null
            $exported = Get-Content $outPath -Raw | ConvertFrom-Json
            $exported.EntryCount | Should -Be 2
            $exported.Entries | Should -Be @('C:\Mods\A', 'C:\Mods\B')
        }

        It 'Import-PSModulePath restores entries from an exported file' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            $outPath = Join-Path $TestDrive 'psmodulepath-import.json'
            Export-PSModulePath -OutputPath $outPath 6>$null
            $env:PSModulePath = 'C:\Mods\Other'
            Import-PSModulePath -InputPath $outPath 6>$null
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @('C:\Mods\A', 'C:\Mods\B')
        }

        It 'Import-PSModulePath errors cleanly when the file is missing' {
            Mock Write-Err { } -ModuleName Toolkit
            { Import-PSModulePath -InputPath (Join-Path $TestDrive 'does-not-exist.json') } | Should -Not -Throw
            Should -Invoke Write-Err -ModuleName Toolkit -Times 1
        }

        It 'Test-PSModulePath runs without throwing' {
            $env:PSModulePath = @('C:\Mods\A', 'C:\Mods\B') -join [IO.Path]::PathSeparator
            { Test-PSModulePath 6>$null } | Should -Not -Throw
        }
    }

    # ── Profile integration (the one intentionally profile-coupled test) ──
    Context 'Live dashboard (profile integration)' {
        BeforeAll {
            # Watch-SystemMetrics lives in the profile, not the Toolkit module, so
            # dot-source it (as install/update do) to assert the contract the menu
            # relies on. Guarded so the suite still runs where the profile is absent.
            $statusScript = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'profile\core\status.ps1'
            if (Test-Path -LiteralPath $statusScript) { . $statusScript }
        }
        It 'Watch-SystemMetrics accepts interval and sample parameters' {
            $cmd = Get-Command -Name Watch-SystemMetrics -ErrorAction SilentlyContinue
            if ($cmd) {
                $cmd.Parameters.Keys | Should -Contain 'IntervalMs'
                $cmd.Parameters.Keys | Should -Contain 'SampleCount'
            }
            else {
                Set-ItResult -Skipped -Because 'profile/core/status.ps1 not present'
            }
        }
    }

    # ── Repository invariants ─────────────────────────────────
    # Whole-repo static checks. They live in the Pester suite rather than build/ so the CI
    # "Pester Tests" step (the gate that actually blocks a push) covers them.
    Context 'Repository invariants' {
        BeforeAll {
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
            $repoScripts = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Extension -in '.ps1', '.psm1', '.psd1' -and
                    $_.FullName -notmatch '\\\.github\\agents\\'
                })
        }

        It 'no 3-argument Join-Path (PS 6/7-only -AdditionalChildPath) exists in the repo' {
            # Join-Path only takes a third positional path on PowerShell 6+. On Windows
            # PowerShell 5.1 the 3-arg form binds as an extra positional argument and dies:
            #   A positional parameter cannot be found that accepts argument 'Toolkit.psd1'
            # That really broke build/Build.ps1 and Setup-Windows.ps1 (both reachable from a
            # 5.1 session) until they were rewritten to the nested 2-arg form used elsewhere.
            $offenders = @(
                foreach ($file in $repoScripts) {
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                    $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
                        Where-Object { $_.GetCommandName() -eq 'Join-Path' } |
                        Where-Object {
                            $positional = @($_.CommandElements |
                                Select-Object -Skip 1 |
                                Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
                            $positional.Count -ge 3
                        } |
                        ForEach-Object {
                            '{0}:{1}' -f $file.FullName.Substring($repoRoot.Length).TrimStart('\'), $_.Extent.StartLineNumber
                        }
                }
            )
            $offenders | Should -BeNullOrEmpty -Because ('these use the PS 7-only 3-arg Join-Path and break on Windows PowerShell 5.1: ' + ($offenders -join ', '))
        }

        It 'profile and toolkit logging style tables do not drift' {
            # See profile/lib/output.ps1 and toolkit/Toolkit/Public/Output.ps1: the two writers
            # cannot share a file by design (install.ps1/update.ps1 run before any profile or
            # module exists; the toolkit must stay usable standalone), so the prefix/colour
            # table is duplicated on purpose. This assertion is what stops the copy drifting —
            # it was the only thing keeping the pair honest, and it had already drifted
            # (toolkit Write-Info was "[*] "/Cyan vs the profile's "  [*] "/DarkGray).
            $profileText = Get-Content -LiteralPath (Join-Path $repoRoot 'profile\lib\output.ps1') -Raw
            $toolkitText = Get-Content -LiteralPath (Join-Path $repoRoot 'toolkit\Toolkit\Public\Output.ps1') -Raw

            $levelOf = @{
                'Write-Step' = 'Step'; 'Write-Ok' = 'Ok'; 'Write-Skip' = 'Skip'
                'Write-Fail' = 'Fail'; 'Write-Warn' = 'Warn'; 'Write-Info' = 'Info'
            }

            # Match the literal string only, then strip the trailing variable reference. Doing it
            # this way keeps `$` out of the patterns entirely: a `\$M` inside a double-quoted
            # pattern backtick-escapes the backslash and then interpolates $M (empty), so the
            # pattern silently matches the wrong span instead of failing loudly.
            $profileMap = @{}
            foreach ($m in [regex]::Matches($profileText, "function\s+(Write-\w+)\s*\{[^}]*?Write-Host\s+`"([^`"]+)`"\s*-ForegroundColor\s+(\w+)")) {
                if ($levelOf.ContainsKey($m.Groups[1].Value)) {
                    $prefix = $m.Groups[2].Value -replace '\$[A-Za-z]+$', ''
                    $profileMap[$levelOf[$m.Groups[1].Value]] = '{0}|{1}' -f $prefix, $m.Groups[3].Value
                }
            }

            $toolkitMap = @{}
            foreach ($m in [regex]::Matches($toolkitText, "'(Step|Ok|Skip|Warn|Fail)'\s*\{\s*Write-Host\s+`"([^`"]+)`"\s*-ForegroundColor\s+(\w+)")) {
                $prefix = $m.Groups[2].Value -replace '\$[A-Za-z]+$', ''
                $toolkitMap[$m.Groups[1].Value] = '{0}|{1}' -f $prefix, $m.Groups[3].Value
            }
            $defaultBranch = [regex]::Match($toolkitText, "default\s*\{\s*Write-Host\s+`"([^`"]+)`"\s*-ForegroundColor\s+(\w+)")
            if ($defaultBranch.Success) {
                $prefix = $defaultBranch.Groups[1].Value -replace '\$[A-Za-z]+$', ''
                $toolkitMap['Info'] = '{0}|{1}' -f $prefix, $defaultBranch.Groups[2].Value
            }

            # Guard the guards: if either regex silently stops matching, the loop below would
            # compare nothing and quietly pass.
            $profileMap.Keys.Count | Should -Be 6 -Because 'profile/lib/output.ps1 writer table must parse'
            $toolkitMap.Keys.Count | Should -Be 6 -Because 'toolkit Write-TkMessage table must parse'

            foreach ($level in @('Step', 'Ok', 'Skip', 'Warn', 'Fail', 'Info')) {
                "{0} {1}" -f $level, $toolkitMap[$level] | Should -Be ("{0} {1}" -f $level, $profileMap[$level]) -Because "level $level must render identically in profile/lib/output.ps1 and toolkit/Toolkit/Public/Output.ps1"
            }
        }

        It 'toolkit config/settings.json is local-only and ships an example instead' {
            # Save-ToolkitConfig writes config/settings.json (ops/configure.ps1 calls it), so if
            # that path is tracked, running the wizard dirties the tree and the next update.ps1
            # (`git pull --ff-only`) fails — or remote-install.ps1 (`git reset --hard`) discards
            # the user's settings. Docs claimed this was fixed long before the fix existed; this
            # test is what makes the claim true and keeps it true.
            $example = Join-Path $repoRoot 'toolkit\config\settings.example.json'
            $example | Should -Exist -Because 'the committed template must exist for users to copy'

            $ignoreText = Get-Content -LiteralPath (Join-Path $repoRoot 'toolkit\.gitignore') -Raw
            $ignoreText | Should -Match '(?m)^config/settings\.json\s*$' -Because 'the local config must be ignored'

            $git = Get-Command git -ErrorAction SilentlyContinue
            if ($git) {
                $null = & git -C $repoRoot ls-files --error-unmatch toolkit/config/settings.json 2>$null
                $LASTEXITCODE | Should -Not -Be 0 -Because 'toolkit/config/settings.json must not be tracked by git'
            }
        }

        It 'no source file hardcodes the machine PS7 module dir' {
            # A PowerShell 7 installed from the Microsoft Store (MSIX) keeps its
            # own modules under $PSHOME\Modules; the literal path used to be
            # assumed instead and does not exist at all on that install flavour,
            # which silently disabled legacy-module detection (Detectors.ps1),
            # its cleanup (ops/modernize.ps1) and the PSModulePath baseline
            # (ModulePath.ps1) — all three reported "modern/clean" no matter what
            # was installed. Comments are exempt: they name the wrong path on
            # purpose, to explain why it is wrong.
            $offenders = @(
                foreach ($file in $repoScripts) {
                    $lineNo = 0
                    foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
                        $lineNo++
                        if ($line -notmatch '^\s*#' -and $line -match 'ProgramFiles\\PowerShell\\7') {
                            '{0}:{1}' -f $file.FullName.Substring($repoRoot.Length).TrimStart('\'), $lineNo
                        }
                    }
                }
            )
            $offenders | Should -BeNullOrEmpty -Because ('resolve it from $PSHOME instead (Join-Path $PSHOME ''Modules''): ' + ($offenders -join ', '))
        }

        It 'the duplicated legacy-module list agrees between Detectors.ps1 and modernize.ps1' {
            # ops/modernize.ps1 needs the same list+path as the module's
            # Test-LegacyPowerShellGetPresent so the menu's live status icon and
            # the script can never disagree about whether legacy modules are
            # present. The pair is duplicated by design — this is what stops the
            # copy drifting, same idea as the logging-style-table test above.
            $pattern = "'((?:PowerShellGet|PackageManagement)\\[\d.]+)'"
            $detectors = [regex]::Matches(
                (Get-Content -LiteralPath (Join-Path $repoRoot 'toolkit\Toolkit\Public\Detectors.ps1') -Raw), $pattern) |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            $modernize = [regex]::Matches(
                (Get-Content -LiteralPath (Join-Path $repoRoot 'toolkit\ops\modernize.ps1') -Raw), $pattern) |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

            # Guard the guard: if the pattern stops matching, both lists are
            # empty and the comparison below would pass vacuously.
            $detectors.Count | Should -BeGreaterThan 0 -Because 'the legacy-module list must parse out of Detectors.ps1'
            $modernize.Count | Should -BeGreaterThan 0 -Because 'the legacy-module list must parse out of modernize.ps1'

            ($modernize -join ',') | Should -Be ($detectors -join ',') -Because 'the two copies of the legacy-module list must stay identical'
        }

        It 'Show-Menu detectors stay cheap (no Get-Module -ListAvailable per redraw)' {
            # Detectors.ps1's own header promises "Get-Command/Test-Path/cached
            # config reads only", because Show-Menu re-evaluates each item's
            # Detector on every redraw (every keypress) with only a per-redraw
            # cache. Get-Module -ListAvailable rescans PSModulePath rather than
            # asking the engine: measured ~86 ms per call here (4.5 s for the
            # unfiltered form), i.e. ~87 ms of input lag per keystroke through
            # Get-ModuleStackStatus. This test is what keeps that regression from
            # coming back.
            $detectors = Get-Content -LiteralPath (Join-Path $repoRoot 'toolkit\Toolkit\Public\Detectors.ps1') -Raw
            $code = ($detectors -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
            $code | Should -Not -Match 'Get-Module\s+\S*\s*-ListAvailable' -Because 'Get-Command resolves a module cmdlet in ~2 ms without rescanning; Test-Path on the module dirs is also fine'
        }
    }

    # ── Cleanup ───────────────────────────────────────────────
    AfterAll {
        Remove-Module Toolkit -ErrorAction SilentlyContinue
    }
}
