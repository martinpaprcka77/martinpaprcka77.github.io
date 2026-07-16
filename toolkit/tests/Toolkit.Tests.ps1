<#
.SYNOPSIS
    Pester testy pro Toolkit modul — rozšířené pokrytí.
.DESCRIPTION
    Testuje existenci, chování a chybové stavy všech exportovaných funkcí.
    Připraveno pro CI (GitHub Actions).
.NOTES
    Cesta: ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1
    Spuštění: Invoke-Pester ~/Projects/tools/tests/Toolkit.Tests.ps1
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

        It 'all lib/*.ps1 exist' {
            $libFiles = @('common.ps1', 'menu.ps1', 'checkers.ps1', 'config.ps1')
            foreach ($f in $libFiles) {
                Join-Path $PSScriptRoot "..\lib\$f" | Should -Exist
            }
        }
    }

    # ── All 30 exported functions ─────────────────────────────
    Context 'Public functions' {
        $expectedFunctions = @(
            'Test-Admin', 'Get-ScriptDirectory',
            'Write-Info', 'Write-Success', 'Write-Warn', 'Write-Err', 'Confirm-Action',
            'Show-Menu', 'Start-MainMenu', 'Show-DockerMenu', 'Show-GitMenu',
            'Show-TerminalMenu', 'Show-DotfilesMenu', 'Show-PwshMenu', 'Show-VSCodeMenu',
            'Get-DiskStatus', 'Get-ServiceStatus', 'Get-NetworkInfo', 'Get-TopProcesses',
            'Invoke-SystemCheck',
            'Get-ToolkitConfig', 'Save-ToolkitConfig', 'Merge-Hashtable',
            'Get-PSModulePath', 'Add-PSModulePath', 'Remove-PSModulePath',
            'Reset-PSModulePath', 'Export-PSModulePath', 'Import-PSModulePath',
            'Test-PSModulePath'
        )

        It "Function '<_>' is exported" -ForEach $expectedFunctions {
            Get-Command -Name $_ -Module Toolkit -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    # ── Utility functions ────────────────────────────────────
    Context 'Utility functions' {
        It 'Test-Admin returns a boolean' {
            $result = Test-Admin
            $result | Should -BeOfType ([bool])
        }

        It 'Get-ScriptDirectory returns a valid path' {
            $result = Get-ScriptDirectory
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Write-Info does not throw' {
            { Write-Info 'test message' } | Should -Not -Throw
        }

        It 'Write-Success does not throw' {
            { Write-Success 'test message' } | Should -Not -Throw
        }

        It 'Write-Warn does not throw' {
            { Write-Warn 'test message' } | Should -Not -Throw
        }

        It 'Write-Err does not throw' {
            { Write-Err 'test message' } | Should -Not -Throw
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

        It 'Show-DockerMenu handles missing Docker gracefully' {
            # If Docker not installed, should just warn and return
            Mock Get-Command { return $null } -ModuleName Toolkit -ParameterFilter { $Name -eq 'docker' }
            Mock Write-Err { } -ModuleName Toolkit
            { Show-DockerMenu } | Should -Not -Throw
        }

        It 'Show-GitMenu handles missing Git gracefully' {
            Mock Get-Command { return $null } -ModuleName Toolkit -ParameterFilter { $Name -eq 'git' }
            Mock Write-Err { } -ModuleName Toolkit
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
            { Invoke-SystemCheck } | Should -Not -Throw
        }

        It 'Get-DiskStatus does not throw' {
            { Get-DiskStatus -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Get-ServiceStatus does not throw' {
            { Get-ServiceStatus -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Get-TopProcesses does not throw' {
            { Get-TopProcesses -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    # ── PSModulePath functions ────────────────────────────────
    Context 'PSModulePath functions' {
        BeforeAll {
            # Fixture paths must never contain [IO.Path]::PathSeparator itself —
            # on Windows that's ';' so 'C:\Mods\A' splits fine, but on Linux/macOS
            # it's ':', which collides with the drive-letter colon and silently
            # shreds 'C:\Mods\A' into 'C' + '\Mods\A' (field-reported as 7
            # cross-platform Pester failures). Use a real Windows path on
            # Windows, a colon-free POSIX-style path everywhere else — the
            # functions under test only care about the separator, not the
            # path format, so this doesn't weaken what's being verified.
            $script:isWindowsHost = $IsWindows
            $script:modA     = if ($script:isWindowsHost) { 'C:\Mods\A' }     else { '/Mods/A' }
            $script:modB     = if ($script:isWindowsHost) { 'C:\Mods\B' }     else { '/Mods/B' }
            $script:modNew   = if ($script:isWindowsHost) { 'C:\Mods\New' }   else { '/Mods/New' }
            $script:modOther = if ($script:isWindowsHost) { 'C:\Mods\Other' } else { '/Mods/Other' }
        }

        BeforeEach {
            $script:origPSModulePath = $env:PSModulePath
        }

        AfterEach {
            $env:PSModulePath = $script:origPSModulePath
        }

        It 'Get-PSModulePath returns the split entries' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            $result = Get-PSModulePath
            $result | Should -Be @($script:modA, $script:modB)
        }

        It 'Add-PSModulePath adds a new path' {
            $env:PSModulePath = $script:modA
            Add-PSModulePath -Path $script:modNew
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Contain $script:modNew
        }

        It 'Add-PSModulePath is a no-op when the path already exists' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            Add-PSModulePath -Path $script:modA
            ($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ -eq $script:modA }).Count | Should -Be 1
        }

        It 'Remove-PSModulePath removes by index' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            Remove-PSModulePath -Index 0
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @($script:modB)
        }

        It 'Remove-PSModulePath removes by path' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            Remove-PSModulePath -Path $script:modA
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @($script:modB)
        }

        It 'Reset-PSModulePath sets the modern baseline entries in order' {
            Mock Test-Path { $true } -ModuleName Toolkit
            Mock New-Item { } -ModuleName Toolkit
            Reset-PSModulePath
            $entries = $env:PSModulePath -split [IO.Path]::PathSeparator
            $entries[0] | Should -Be "$env:ProgramFiles\PowerShell\7\Modules"
            # LOCALAPPDATA, never Documents — Documents can be OneDrive-redirected
            $entries[1] | Should -Be "$env:LOCALAPPDATA\PowerShell\Modules"
        }

        It 'Export-PSModulePath writes JSON with the correct entry count' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            $outPath = Join-Path $TestDrive 'psmodulepath.json'
            Export-PSModulePath -OutputPath $outPath
            $exported = Get-Content $outPath -Raw | ConvertFrom-Json
            $exported.EntryCount | Should -Be 2
            $exported.Entries | Should -Be @($script:modA, $script:modB)
        }

        It 'Import-PSModulePath restores entries from an exported file' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            $outPath = Join-Path $TestDrive 'psmodulepath-import.json'
            Export-PSModulePath -OutputPath $outPath
            $env:PSModulePath = $script:modOther
            Import-PSModulePath -InputPath $outPath
            ($env:PSModulePath -split [IO.Path]::PathSeparator) | Should -Be @($script:modA, $script:modB)
        }

        It 'Import-PSModulePath errors cleanly when the file is missing' {
            Mock Write-Err { } -ModuleName Toolkit
            { Import-PSModulePath -InputPath (Join-Path $TestDrive 'does-not-exist.json') } | Should -Not -Throw
            Should -Invoke Write-Err -ModuleName Toolkit -Times 1
        }

        It 'Test-PSModulePath runs without throwing' {
            $env:PSModulePath = @($script:modA, $script:modB) -join [IO.Path]::PathSeparator
            { Test-PSModulePath } | Should -Not -Throw
        }
    }

    # ── Cleanup ───────────────────────────────────────────────
    AfterAll {
        Remove-Module Toolkit -ErrorAction SilentlyContinue
    }
}
