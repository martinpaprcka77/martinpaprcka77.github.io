#Requires -Version 7

<#
.SYNOPSIS
  Portable, location-independent launcher menu for pi, pwsh, wt, and cmd.
.DESCRIPTION
  Prints a dashboard of launch targets and starts the selected one in a new
  window. Targets can be extended or overridden with JSON fragments in
  <script root>/devmenu.d/*.json. Everything is resolved relative to the script,
  so devmenu works regardless of where it is installed or invoked from.
  Press d in the menu (or pass -Diagnose) for an environment and configuration
  report.
.PARAMETER Dir
  Working directory for launched processes. Defaults to the current directory.
.PARAMETER FragmentDir
  Directory of *.json fragments. Defaults to <script root>/devmenu.d.
.PARAMETER Diagnose
  Print the environment, PowerShell, Windows Terminal, config, and location
  report, then exit.
.PARAMETER SelfTest
  Runs the built-in assertions and exits 0 (pass) or 1 (fail).
.EXAMPLE
  pwsh -File ./devmenu.ps1
.EXAMPLE
  pwsh -File ./devmenu.ps1 -Dir C:\src
.EXAMPLE
  pwsh -File ./devmenu.ps1 -Diagnose
.EXAMPLE
  pwsh -File ./devmenu.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string]$Dir,
    [string]$FragmentDir,
    [switch]$Diagnose,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultTargets {
    @(
        [pscustomobject]@{ Name = 'pi';   Arguments = @() }
        [pscustomobject]@{ Name = 'pwsh'; Arguments = @('-NoLogo') }
        [pscustomobject]@{ Name = 'wt';   Arguments = @() }
        [pscustomobject]@{ Name = 'cmd';  Arguments = @() }
    )
}

function Get-Prop {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-ScriptRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($PSCommandPath) { return (Split-Path -Parent $PSCommandPath) }
    return (Get-Location).Path
}

function Resolve-ProductName {
    param([string]$Product, [int]$Build)
    if ($Build -ge 22000 -and $Product -match '^Windows 10') {
        return ($Product -replace '^Windows 10', 'Windows 11')
    }
    return $Product
}

function Get-OsInfo {
    $version = [System.Environment]::OSVersion.Version
    $product = ''
    $display = ''
    try {
        $current = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $product = [string]$current.ProductName
        $display = [string]$current.DisplayVersion
    }
    catch { }
    $terminal = 'console'
    if ($env:WT_SESSION) { $terminal = 'Windows Terminal' }
    elseif ($env:TERM_PROGRAM) { $terminal = [string]$env:TERM_PROGRAM }
    [pscustomobject]@{
        Product      = Resolve-ProductName -Product $product -Build $version.Build
        Display      = $display
        Version      = $version.ToString()
        Build        = $version.Build
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        User         = [System.Environment]::UserName
        Machine      = [System.Environment]::MachineName
        Cwd          = (Get-Location).Path
        Terminal     = $terminal
    }
}

function Get-PowerShellInfo {
    $installs = [System.Collections.Generic.List[object]]::new()
    foreach ($name in @('pwsh', 'pwsh-preview', 'powershell')) {
        foreach ($command in @(Get-Command -Name $name -All -ErrorAction SilentlyContinue)) {
            if (-not $command.Source) { continue }
            $version = if ($command.Version) { $command.Version.ToString() } else { '' }
            if ($version -eq '0.0.0.0') { $version = '(alias)' }
            $installs.Add([pscustomobject]@{ Name = $name; Path = [string]$command.Source; Version = $version })
        }
    }
    $currentPath = ''
    try { $currentPath = (Get-Process -Id $PID).Path } catch { }
    [pscustomobject]@{
        CurrentVersion = $PSVersionTable.PSVersion.ToString()
        CurrentEdition = [string]$PSVersionTable.PSEdition
        CurrentPath    = $currentPath
        Installs       = $installs.ToArray()
    }
}

function Get-TerminalAppInfo {
    $path = ''
    $resolved = Get-Command -Name 'wt' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolved -and $resolved.Source) { $path = [string]$resolved.Source }
    $stable = ''
    $canary = ''
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        'Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages')
    if ($key) {
        try {
            foreach ($name in $key.GetSubKeyNames()) {
                if ($name -match '^Microsoft\.WindowsTerminal_([0-9][^_]*)_') { $stable = $Matches[1] }
                elseif ($name -match '^Microsoft\.WindowsTerminal(?:Preview|Canary)_([0-9][^_]*)_') { $canary = $Matches[1] }
            }
        }
        finally { $key.Dispose() }
    }
    [pscustomobject]@{
        Available     = [bool]$path
        Path          = $path
        StableVersion = $stable
        CanaryVersion = $canary
    }
}

function Get-ConfigState {
    param([object[]]$Defaults, [string[]]$FragmentPaths)
    $fragments = @(Read-TargetFragments -Paths $FragmentPaths)
    $merged = @(Merge-Targets -Defaults $Defaults -Fragments $fragments)
    $builtin = @($Defaults | ForEach-Object { ([string]$_.Name).ToLowerInvariant() })
    $kept = @($merged | ForEach-Object { ([string]$_.Name).ToLowerInvariant() })
    $added = @()
    $overridden = @()
    foreach ($target in $merged) {
        if ([string]$target.Source -eq 'builtin') { continue }
        if ($builtin -contains ([string]$target.Name).ToLowerInvariant()) { $overridden += [string]$target.Name }
        else { $added += [string]$target.Name }
    }
    $removed = @($builtin | Where-Object { $kept -notcontains $_ })
    $isDefault = ($added.Count -eq 0 -and $overridden.Count -eq 0 -and $removed.Count -eq 0)
    [pscustomobject]@{
        IsDefault     = $isDefault
        FragmentCount = $fragments.Count
        FragmentFiles = @($FragmentPaths | ForEach-Object { [System.IO.Path]::GetFileName($_) })
        Added         = $added
        Overridden    = $overridden
        Removed       = $removed
    }
}

function Get-Locations {
    param([string]$Root, [string]$FragmentDir, [string[]]$FragmentPaths)
    $samples = @()
    if ($FragmentDir -and (Test-Path -LiteralPath $FragmentDir)) {
        $samples = @(Get-ChildItem -LiteralPath $FragmentDir -Filter '*.example' -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName)
    }
    [pscustomobject]@{
        ScriptPath   = $PSCommandPath
        ScriptRoot   = $Root
        Shim         = (Join-Path $Root 'devmenu.cmd')
        Readme       = (Join-Path $Root 'README.md')
        Architecture = (Join-Path (Join-Path $Root 'docs') 'ARCHITECTURE.md')
        FragmentDir  = $FragmentDir
        Fragments    = @($FragmentPaths)
        Samples      = $samples
        PiSettings   = [System.IO.Path]::Combine($HOME, '.pi', 'agent', 'settings.json')
    }
}

function Read-TargetFragments {
    param([string[]]$Paths)
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($path in @($Paths)) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }
        try {
            $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "ignoring fragment '$path': $($_.Exception.Message)"
            continue
        }
        $entries = if ($null -ne $data -and $null -ne $data.PSObject.Properties['targets']) { @($data.targets) } else { @($data) }
        foreach ($entry in $entries) {
            $name = Get-Prop -Object $entry -Name 'name'
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $arguments = Get-Prop -Object $entry -Name 'arguments'
            $enabled = Get-Prop -Object $entry -Name 'enabled'
            $result.Add([pscustomobject]@{
                Name      = [string]$name
                Arguments = if ($null -ne $arguments) { @($arguments) } else { @() }
                Enabled   = if ($null -ne $enabled) { [bool]$enabled } else { $true }
                Source    = [System.IO.Path]::GetFileName($path)
            })
        }
    }
    return $result.ToArray()
}

function Merge-Targets {
    param([object[]]$Defaults, [object[]]$Fragments)
    $order = [System.Collections.Generic.List[string]]::new()
    $map = [ordered]@{}
    foreach ($default in @($Defaults)) {
        $key = ([string]$default.Name).ToLowerInvariant()
        $map[$key] = [pscustomobject]@{
            Name      = [string]$default.Name
            Arguments = @($default.Arguments)
            Enabled   = $true
            Source    = 'builtin'
        }
        $order.Add($key)
    }
    foreach ($fragment in @($Fragments)) {
        $key = ([string]$fragment.Name).ToLowerInvariant()
        if (-not $map.Contains($key)) { $order.Add($key) }
        $map[$key] = [pscustomobject]@{
            Name      = [string]$fragment.Name
            Arguments = @($fragment.Arguments)
            Enabled   = [bool]$fragment.Enabled
            Source    = [string]$fragment.Source
        }
    }
    $out = foreach ($key in $order) { if ($map[$key].Enabled) { $map[$key] } }
    return $out
}

function Resolve-Targets {
    param([object[]]$Targets, [scriptblock]$Lookup, [hashtable]$Cache)
    $out = foreach ($target in @($Targets)) {
        $name = [string](Get-Prop -Object $target -Name 'Name' -Default '')
        if ($Cache -and $Cache.ContainsKey($name)) {
            $path = [string]$Cache[$name]
        }
        else {
            $path = ''
            try {
                $resolved = & $Lookup $name
                if ($resolved) { $path = [string]$resolved }
            }
            catch { $path = '' }
            if ($Cache) { $Cache[$name] = $path }
        }
        [pscustomobject]@{
            Name      = $name
            Arguments = @(Get-Prop -Object $target -Name 'Arguments' -Default @())
            Available = [bool]$path
            Path      = $path
            Source    = [string](Get-Prop -Object $target -Name 'Source' -Default 'builtin')
        }
    }
    return $out
}

function New-LaunchSpec {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Arguments = @(),
        [string]$Dir
    )
    $spec = @{ FilePath = $Name }
    if ($Arguments.Count -gt 0) { $spec.ArgumentList = $Arguments }
    if ($Dir) { $spec.WorkingDirectory = $Dir }
    return $spec
}

function Start-Target {
    param([Parameter(Mandatory)][hashtable]$Spec)
    Start-Process @Spec
}

function Show-Dashboard {
    param([object[]]$Targets, [string]$Dir, [string]$Root, [object]$ConfigState, [switch]$ShowDetail)
    Write-Host ''
    Write-Host '  devmenu' -ForegroundColor Cyan
    Write-Host ("  script : {0}" -f $Root) -ForegroundColor DarkGray
    Write-Host ("  workdir: {0}" -f $Dir) -ForegroundColor DarkGray
    $config = 'default'
    if ($ConfigState) {
        if (-not $ConfigState.IsDefault) {
            $config = "changed ({0} fragment file(s))" -f $ConfigState.FragmentCount
        }
        else { $config = 'default' }
    }
    Write-Host ("  config : {0}" -f $config) -ForegroundColor DarkGray
    Write-Host ''
    for ($i = 0; $i -lt @($Targets).Count; $i++) {
        $target = $Targets[$i]
        $mark = if ($target.Available) { '[x]' } else { '[ ]' }
        $detail = if ($target.Available) { $target.Path } else { 'not found on PATH' }
        Write-Host ("  {0}) {1} {2,-6} {3}" -f ($i + 1), $mark, $target.Name, $detail)
        if ($ShowDetail) {
            $args = if ($target.Arguments.Count -gt 0) { $target.Arguments -join ' ' } else { '(none)' }
            Write-Host ("       args: {0}  source: {1}" -f $args, $target.Source) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    Write-Host '  number=launch  r=refresh  l=detail  d=diagnostics  q=quit' -ForegroundColor DarkGray
}

function Show-Diagnostics {
    param([object[]]$Defaults, [string]$Root, [string]$FragmentDir, [string[]]$FragmentPaths)
    $os = Get-OsInfo
    $ps = Get-PowerShellInfo
    $term = Get-TerminalAppInfo
    $config = Get-ConfigState -Defaults $Defaults -FragmentPaths $FragmentPaths
    $loc = Get-Locations -Root $Root -FragmentDir $FragmentDir -FragmentPaths $FragmentPaths

    Write-Host ''
    Write-Host '  === environment ===' -ForegroundColor Cyan
    Write-Host ("  OS        : {0} {1} (build {2}, {3})" -f $os.Product, $os.Display, $os.Build, $os.Architecture)
    Write-Host ("  user/host : {0} @ {1}" -f $os.User, $os.Machine)
    Write-Host ("  cwd       : {0}" -f $os.Cwd)
    Write-Host ("  terminal  : {0}" -f $os.Terminal)

    Write-Host ''
    Write-Host '  === powershell ===' -ForegroundColor Cyan
    Write-Host ("  current   : {0} ({1}) {2}" -f $ps.CurrentVersion, $ps.CurrentEdition, $ps.CurrentPath)
    foreach ($install in $ps.Installs) {
        Write-Host ("  install   : {0,-16} {1,-11} {2}" -f $install.Name, $install.Version, $install.Path)
    }

    Write-Host ''
    Write-Host '  === windows terminal ===' -ForegroundColor Cyan
    Write-Host ("  found     : {0}" -f $term.Available)
    Write-Host ("  path      : {0}" -f $term.Path)
    if ($term.StableVersion) { Write-Host ("  stable    : {0}" -f $term.StableVersion) }
    if ($term.CanaryVersion) { Write-Host ("  canary    : {0}" -f $term.CanaryVersion) }

    Write-Host ''
    Write-Host '  === config ===' -ForegroundColor Cyan
    Write-Host ("  state     : {0}" -f $(if ($config.IsDefault) { 'default' } else { 'changed' }))
    Write-Host ("  fragments : {0} file(s) in {1}" -f $config.FragmentCount, $loc.FragmentDir)
    foreach ($file in $config.FragmentFiles) { Write-Host ("              - {0}" -f $file) }
    if ($config.Added.Count)      { Write-Host ("  added     : {0}" -f ($config.Added -join ', ')) }
    if ($config.Overridden.Count) { Write-Host ("  overridden: {0}" -f ($config.Overridden -join ', ')) }
    if ($config.Removed.Count)    { Write-Host ("  removed   : {0}" -f ($config.Removed -join ', ')) }

    Write-Host ''
    Write-Host '  === locations ===' -ForegroundColor Cyan
    Write-Host ("  script    : {0}" -f $loc.ScriptPath)
    Write-Host ("  root      : {0}" -f $loc.ScriptRoot)
    Write-Host ("  shim      : {0}" -f $loc.Shim)
    Write-Host ("  readme    : {0}" -f $loc.Readme)
    Write-Host ("  arch doc  : {0}" -f $loc.Architecture)
    Write-Host ("  fragments : {0}" -f $loc.FragmentDir)
    foreach ($sample in $loc.Samples) { Write-Host ("  sample    : {0}" -f $sample) }
    Write-Host ("  pi config : {0}" -f $loc.PiSettings)
    Write-Host ''
}

function Invoke-Menu {
    param(
        [string]$Dir,
        [string]$Root,
        [string]$FragmentDir,
        [scriptblock]$Lookup,
        [object[]]$Defaults,
        [string[]]$FragmentPaths
    )
    $specs = @(Merge-Targets -Defaults $Defaults -Fragments @(Read-TargetFragments -Paths $FragmentPaths))
    $configState = Get-ConfigState -Defaults $Defaults -FragmentPaths $FragmentPaths
    $showDetail = $false
    $resolveCache = @{}
    while ($true) {
        $targets = @(Resolve-Targets -Targets $specs -Lookup $Lookup -Cache $resolveCache)
        Show-Dashboard -Targets $targets -Dir $Dir -Root $Root -ConfigState $configState -ShowDetail:$showDetail
        try { $choice = (Read-Host '>').Trim() }
        catch { Write-Host ''; return }

        if ($choice -in @('q', 'quit')) { return }
        if ($choice -in @('r', 'refresh')) { $resolveCache.Clear(); continue }
        if ($choice -in @('l', 'list')) { $showDetail = -not $showDetail; continue }
        if ($choice -in @('d', 'diagnostics')) {
            Show-Diagnostics -Defaults $Defaults -Root $Root -FragmentDir $FragmentDir -FragmentPaths $FragmentPaths
            continue
        }
        if ($choice -match '^\d+$') {
            $index = [int]$choice
            if ($index -ge 1 -and $index -le $targets.Count) {
                $target = $targets[$index - 1]
                if (-not $target.Available) {
                    Write-Host "  $($target.Name) not found on PATH" -ForegroundColor Yellow
                    continue
                }
                try {
                    Start-Target -Spec (New-LaunchSpec -Name $target.Name -Arguments $target.Arguments -Dir $Dir)
                    Write-Host "  launched $($target.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Host "  failed to launch $($target.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
                continue
            }
        }
        Write-Host '  invalid selection' -ForegroundColor Yellow
    }
}

function Invoke-SelfTest {
    $script:failures = 0
    function Assert-True {
        param([string]$Name, [bool]$Condition)
        if ($Condition) { Write-Host "ok   $Name" }
        else { Write-Host "FAIL $Name"; $script:failures++ }
    }

    $defaults = Get-DefaultTargets
    $merged = @(Merge-Targets -Defaults $defaults -Fragments @())
    Assert-True 'four default targets' ($merged.Count -eq 4)
    Assert-True 'default order' (($merged.Name -join ',') -eq 'pi,pwsh,wt,cmd')

    $fragments = @(
        [pscustomobject]@{ Name = 'pwsh'; Arguments = @('-NoLogo', '-NoProfile'); Enabled = $true;  Source = 'test.json' }
        [pscustomobject]@{ Name = 'cmd';  Arguments = @();                          Enabled = $false; Source = 'test.json' }
        [pscustomobject]@{ Name = 'bash'; Arguments = @('-l');                      Enabled = $true;  Source = 'test.json' }
    )
    $merged2 = @(Merge-Targets -Defaults $defaults -Fragments $fragments)
    Assert-True 'fragment disables default' (($merged2.Name) -notcontains 'cmd')
    Assert-True 'fragment adds target' ($merged2.Name -contains 'bash')
    Assert-True 'fragment overrides args' (((($merged2 | Where-Object Name -eq 'pwsh').Arguments) -join ',') -eq '-NoLogo,-NoProfile')
    Assert-True 'fragment records source' ((($merged2 | Where-Object Name -eq 'pwsh').Source) -eq 'test.json')

    $tempPath = Join-Path $env:TEMP ("devmenu-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    '{ "targets": [ { "name": "nvim", "arguments": ["--clean"] }, { "name": "cmd", "enabled": false } ] }' |
        Set-Content -LiteralPath $tempPath -Encoding utf8
    $read = @(Read-TargetFragments -Paths @($tempPath))
    Assert-True 'fragment file parsed' ($read.Count -eq 2)
    $merged3 = @(Merge-Targets -Defaults $defaults -Fragments $read)
    Assert-True 'fragment file adds' ($merged3.Name -contains 'nvim')
    Assert-True 'fragment file disables' (($merged3.Name) -notcontains 'cmd')

    $configChanged = Get-ConfigState -Defaults $defaults -FragmentPaths @($tempPath)
    Assert-True 'config changed with fragment' (-not $configChanged.IsDefault)
    Assert-True 'config lists added target' ($configChanged.Added -contains 'nvim')
    Assert-True 'config lists removed target' ($configChanged.Removed -contains 'cmd')
    Assert-True 'config default without fragments' ((Get-ConfigState -Defaults $defaults -FragmentPaths @()).IsDefault)
    Remove-Item -LiteralPath $tempPath -Force

    $lookup = { param($name) if ($name -eq 'cmd') { 'C:\Windows\System32\cmd.exe' } else { $null } }
    $resolved = @(Resolve-Targets -Targets $defaults -Lookup $lookup)
    Assert-True 'resolves available target' ([bool]($resolved | Where-Object Name -eq 'cmd').Available)
    Assert-True 'marks missing target' (-not [bool]($resolved | Where-Object Name -eq 'pi').Available)
    Assert-True 'captures resolved path' ((($resolved | Where-Object Name -eq 'cmd').Path) -eq 'C:\Windows\System32\cmd.exe')

    $spec = New-LaunchSpec -Name 'pwsh' -Arguments @('-NoLogo') -Dir 'C:\work'
    Assert-True 'spec file path' ($spec.FilePath -eq 'pwsh')
    Assert-True 'spec arguments' (($spec.ArgumentList -join ',') -eq '-NoLogo')
    Assert-True 'spec working dir' ($spec.WorkingDirectory -eq 'C:\work')

    $bare = New-LaunchSpec -Name 'cmd'
    Assert-True 'bare spec has no arguments' (-not $bare.ContainsKey('ArgumentList'))
    Assert-True 'bare spec has no working dir' (-not $bare.ContainsKey('WorkingDirectory'))

    Assert-True 'script root is location independent' ([bool](Get-ScriptRoot))
    $loc = Get-Locations -Root (Get-ScriptRoot) -FragmentDir 'C:\devmenu-nonexistent' -FragmentPaths @()
    Assert-True 'locations expose script root' ($loc.ScriptRoot -eq (Get-ScriptRoot))
    Assert-True 'locations expose shim path' ($loc.Shim -like '*devmenu.cmd')

    $os = Get-OsInfo
    Assert-True 'detects os info' ([bool]$os.Version)
    Assert-True 'relabels windows 11 by build' ((Resolve-ProductName -Product 'Windows 10 Pro' -Build 26100) -eq 'Windows 11 Pro')
    Assert-True 'keeps windows 10 below threshold' ((Resolve-ProductName -Product 'Windows 10 Pro' -Build 19045) -eq 'Windows 10 Pro')
    Assert-True 'leaves windows 11 unchanged' ((Resolve-ProductName -Product 'Windows 11 Pro' -Build 22631) -eq 'Windows 11 Pro')
    $psInfo = Get-PowerShellInfo
    Assert-True 'detects current powershell' ([bool]$psInfo.CurrentVersion)
    Assert-True 'detects powershell installs' (@($psInfo.Installs).Count -ge 1)
    $term = Get-TerminalAppInfo
    Assert-True 'detects windows terminal entry' ($null -ne $term.PSObject.Properties['StableVersion'])

    Write-Host ''
    if ($script:failures -gt 0) {
        Write-Host "$($script:failures) check(s) failed"
        return $script:failures
    }
    Write-Host 'all checks passed'
    return 0
}

$root = Get-ScriptRoot
if (-not $FragmentDir) { $FragmentDir = Join-Path $root 'devmenu.d' }
$fragmentPaths = @(
    Get-ChildItem -LiteralPath $FragmentDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -ExpandProperty FullName
)

if ($SelfTest) {
    $failed = Invoke-SelfTest
    exit $(if ($failed -gt 0) { 1 } else { 0 })
}

if ($Diagnose) {
    Show-Diagnostics -Defaults (Get-DefaultTargets) -Root $root -FragmentDir $FragmentDir -FragmentPaths $fragmentPaths
    exit 0
}

$workDir = if ($Dir) { $Dir } else { (Get-Location).Path }
$lookup = {
    param($name)
    $command = Get-Command -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.PSObject.Properties['Source']) { $command.Source }
}

Invoke-Menu -Dir $workDir -Root $root -FragmentDir $FragmentDir -Lookup $lookup -Defaults (Get-DefaultTargets) -FragmentPaths $fragmentPaths
