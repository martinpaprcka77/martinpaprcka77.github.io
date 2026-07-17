# AGENTS.md — PowerShell Dotfiles Ecosystem

> **For AI agents (Claude, DeepSeek, GPT-4, Reasonix, Copilot):**
> This file tells you everything you need to know to work with this repo.

---

## What this repo is

**PowerShell Dotfiles Ecosystem** — a modular, version-controlled PowerShell profile plus an
interactive toolbox, in one repo, plus the GitHub Pages portal at the repo root.

| Attribute | Value |
|-----------|-------|
| **Location on disk** | `~/.config/powershell/` |
| **Portal** | [martinpaprcka77.github.io](https://martinpaprcka77.github.io) (this repo's Pages, root URL) |
| **Language** | PowerShell 5.1 / 7+ |
| **Module** | `toolkit/Toolkit` — 37 exported functions, v1.1.0 |
| **Tests** | 91 Pester cases in `toolkit/tests/Toolkit.Tests.ps1` |
| **Dependencies** | Git, PowerShell 5.1+; Docker (optional, for `toolkit`'s Docker menu) |
| **Lint** | `PSScriptAnalyzerSettings.psd1` at repo root; CI fails only on Error severity |

Previously split across two repos (`dotfiles-powershell`, `dotfiles-tools`) — merged here to
eliminate cross-repo coupling (menu items calling functions that only existed in the other repo)
and the two-sources-of-truth drift between `$env:DOTFILES_PWSH`/`$env:DOTFILES_TOOLS`. See
`docs/ROADMAP.md` Fáze 5 for the full rationale.

---

## Directory map (what each file does)

```
~/.config/powershell/
├── install.ps1              ← idempotent installer (git pull self, inject bootstrap, PATH setup)
├── remote-install.ps1       ← one-command bootstrapper, safe via `irm <url> | iex`
├── update.ps1               ← git pull + bootstrap self-heal + reload profile
├── bootstrap.ps1            ← minimal reference snippet injected into $PROFILE (never itself
│                                run as a script — see its own docstring)
├── PSScriptAnalyzerSettings.psd1 ← lint config: ExcludeRules for intentional house-style
│                                     patterns (Write-Host, Global: scope), everything else
│                                     stays visible; CI fails only on Error severity
├── index.html · prompts.html← GitHub Pages portal (root URL)
├── .nojekyll
├── .vscode/                 ← settings.json, tasks.json, agent-instructions.md (whole-repo config)
├── .github/workflows/       ← test.yml (Pester + lint + JSON validation; triggers on
│                                profile/**, toolkit/**, root *.ps1, and this settings file)
├── .gitignore
│
├── docs/
│   ├── ARCHITECTURE.md      ← Mermaid UML diagrams (monorepo layout, loading flow, toolkit components)
│   ├── PURPOSE.md           ← design rationale & decisions
│   ├── MANUAL.md            ← full user guide
│   ├── ROADMAP.md           ← phases, known issues, contribution guide
│   └── PROMPT.md            ← original AI prompts that generated this project
│
├── profile/                 ← PROFILE ORCHESTRATION
│   ├── profile.ps1          ← MAIN ORCHESTRATOR — dot-sources everything below
│   ├── starship.toml        ← Starship prompt config (30+ modules)
│   │
│   ├── lib/
│   │   ├── output.ps1       ← Write-Step/Ok/Skip/Fail/Warn — shared by install.ps1/update.ps1
│   │   ├── paths.ps1        ← Resolve-DocumentsPath/Test-RootedPath/Get-NativeProfilePaths —
│   │   │                       Known-Folder-correct (OneDrive-safe) $PROFILE paths, validated
│   │   │                       against corrupted Known Folder registry values
│   │   ├── bootstrap.ps1    ← Invoke-BootstrapInjection — shared by install.ps1/update.ps1,
│   │   │                       repairs a stale bootstrap target (self-heal)
│   │   ├── encoding.ps1     ← Repair-FileEncoding — idempotently adds a UTF-8 BOM to non-ASCII
│   │   │                       source files (PS5.1 crashes parsing BOM-less UTF-8)
│   │   └── repair.ps1       ← Invoke-DotfilesRepair — the single self-heal entry point;
│   │                           composes bootstrap + encoding + (Windows) PSModulePath
│   │                           validation/reset into one pass. Called by install.ps1
│   │                           (preflight) and update.ps1 (every run, not just after a
│   │                           pull — a drifted PSModulePath or missing BOM can exist even
│   │                           when this repo is already current)
│   │
│   ├── core/                ← ALWAYS loaded (shared across all PS versions/hosts)
│   │   ├── aliases.ps1      ← git, docker, kubectl shortcuts
│   │   ├── functions.ps1    ← Edit-Profile, Reload-Profile, Get-SecretKey, mkcd, Test-Admin
│   │   ├── env.ps1          ← $env:EDITOR, PATH, $env:DOTFILES_TOOLS (derived from DOTFILES_PWSH)
│   │   ├── diag.ps1         ← ETW/PSDiagnostics tracing (Windows-only, early-returns elsewhere)
│   │   ├── perf.ps1         ← Measure-Profile, Clear-PSCache, Optimize-ModuleLoading, Get-ProfileSize
│   │   ├── status.ps1       ← Show-Status — global health dashboard, Test-PathHealth
│   │   └── extra.ps1.example← template for gitignored user overrides (copy to extra.ps1)
│   │
│   ├── ps5/profile.ps1      ← Windows PowerShell 5.1 only (PSReadLine v2, UTF-8)
│   ├── ps7/profile.ps1      ← PS 7+ only (PSReadLine v3, Starship/oh-my-posh, Terminal-Icons, PSFzf)
│   │
│   └── hosts/
│       ├── ConsoleHost.ps1  ← classic terminal (welcome banner, uptime, window title);
│       │                       sources wtprofile.ps1 itself (not via host detection)
│       ├── VSCode.ps1       ← VS Code integrated terminal (no banner, UTF-8)
│       ├── wtprofile.ps1    ← Windows Terminal utilities (zoxide, trash, Show-Help, …);
│       │                       only loads if $env:WT_SESSION is set
│       └── shell-integration.ps1 ← OSC 133 prompt markers; sourced from ps7/profile.ps1 directly
│
└── toolkit/                 ← INTERACTIVE TOOLBOX
    ├── bin/                 ← in PATH: menu.ps1 (→ Start-MainMenu), check.ps1 (→ Invoke-SystemCheck)
    ├── Toolkit/             ← PowerShell module: Toolkit.psd1 (37 FunctionsToExport), Toolkit.psm1
    │
    ├── lib/
    │   ├── common.ps1       ← Test-Admin, Write-Info/Success/Warn/Err, Confirm-Action
    │   ├── menu.ps1         ← Show-Menu — arrow-key nav, live status column via Detector,
    │   │                       box width clamped to [Console]::WindowWidth with text truncation
    │   ├── checkers.ps1     ← Get-DiskStatus, Get-ServiceStatus, Get-NetworkInfo, Get-TopProcesses (Windows-only, guarded)
    │   ├── config.ps1       ← Get-ToolkitConfig (defaults→JSON→env merge), Save-ToolkitConfig
    │   ├── modulepath.ps1   ← Get/Add/Remove/Reset/Export/Import/Test-PSModulePath (7 functions)
    │   └── detectors.ps1    ← Show-Menu live-status detectors + Invoke-IfAvailable guard
    │
    ├── menu/                ← standalone scripts (runnable directly or via module)
    │   ├── menu-main.ps1, menu-docker.ps1, menu-git.ps1, menu-terminal.ps1,
    │   │   menu-dotfiles.ps1, menu-pwsh.ps1, menu-vscode.ps1
    │
    ├── scripts/
    │   ├── Add-WTProfiles.ps1 ← Windows Terminal JSON fragment generator
    │   ├── Generate-Icons.ps1, configure.ps1, deps.ps1, windows.ps1, modernize.ps1, precheck.ps1
    │
    ├── configs/              ← settings.example.json (tracked default template), wt-schemes.json
    │                            (WT colors). settings.json is the user's LOCAL config (gitignored;
    │                            written by Save-ToolkitConfig — tracking it would break git pull)
    ├── tests/Toolkit.Tests.ps1 ← 86 Pester cases
    ├── githooks/              ← post-checkout/post-merge reminders, install.sh
    └── icons/README.md
```

---

## How it works (loading sequence)

```
PowerShell starts
  → $PROFILE (bootstrap snippet, at the Known-Folder-correct Documents path)
    → profile/profile.ps1
      → detect environment once: $isPSCore, $isWindowsHost
      → set $env:DOTFILES_PWSH (= profile/), derive $env:DOTFILES_TOOLS (sibling toolkit/)
      → fix PSModulePath (PS5.1 and PS7 both: prepend LOCALAPPDATA, never Documents)
      → dot-source lib/paths.ps1, core/*.ps1
      → dot-source ps5/ or ps7/ (based on $isPSCore)
      → dot-source hosts/ConsoleHost or VSCode (based on $host.Name)
      → optionally show load time ($env:PROFILE_BENCHMARK)
```

`toolkit/bin/menu.ps1`/`check.ps1` → `Import-Module Toolkit` → `Toolkit.psd1` → `Toolkit.psm1` →
dot-source `toolkit/lib/*.ps1` and `toolkit/menu/menu-*.ps1`.

---

## How to install

```powershell
irm https://raw.githubusercontent.com/martinpaprcka77/martinpaprcka77.github.io/main/remote-install.ps1 | iex
```

Or manually:
```powershell
git clone https://github.com/martinpaprcka77/martinpaprcka77.github.io.git ~/.config/powershell
~/.config/powershell/install.ps1
```

`install.ps1` is idempotent — supports `-WhatIf`, `-Force`, `-NoUpdates`, `-NoTerminal`.
`remote-install.ps1` uses `$env:DOTFILES_FORCE`/`$env:DOTFILES_NO_UPDATES`/`$env:DOTFILES_NO_TERMINAL`
instead (switches aren't reachable through `iex`).

---

## How to add a new feature

1. **Profile function/alias** → `profile/core/functions.ps1` or `profile/core/aliases.ps1`
2. **PS7-only** → `profile/ps7/profile.ps1`; **PS5-only** → `profile/ps5/profile.ps1`
3. **Host-specific** → `profile/hosts/ConsoleHost.ps1` or `VSCode.ps1`
4. **New profile core file** → drop a `.ps1` into `profile/core/` — it auto-loads
5. **New toolkit utility** → `toolkit/lib/common.ps1`; **new diagnostic** → `toolkit/lib/checkers.ps1`
6. **New menu item** → add to `toolkit/menu/menu-main.ps1`; **new submenu** → new `toolkit/menu/menu-whatever.ps1`
7. **After adding a toolkit function**: add to `Export-ModuleMember` in `Toolkit.psm1`, add to
   `FunctionsToExport` in `Toolkit.psd1`, add a test case in `toolkit/tests/Toolkit.Tests.ps1`
8. **User overrides** → copy `profile/core/extra.ps1.example` to `profile/core/extra.ps1` (gitignored)

---

## How to run tests

```powershell
Install-Module Pester -Force
Invoke-Pester ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1
```

Lint (same check CI runs, `PSScriptAnalyzerSettings.psd1` applies the repo's ExcludeRules):

```powershell
Install-Module PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path ~/.config/powershell -Recurse -Settings ~/.config/powershell/PSScriptAnalyzerSettings.psd1
```

CI fails only on Error-severity findings — Warnings are reported, not blocking (the settings
file's trailing comments explain which warning categories are deliberately left visible and why).

---

## Coding conventions

- **Comment-based help** on every function (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`)
- **Verb-Noun naming** — a few intentional shell-ergonomics exceptions (`mkcd`, `touch`, `ff`, `sed`, `k9`, …)
- **Error handling**: `try/catch` for network/external calls; `$ErrorActionPreference = 'Stop'` and
  `Set-StrictMode -Version Latest` only in `install.ps1`/`update.ps1` — **never** in `profile.ps1`
  or `core/*.ps1`, where one failing optional file must not abort the whole profile load
- **Idempotency**: use `Test-Path` before creating/modifying
- **No network calls in the profile** — keep startup fast
- **Cross-platform**: `$IsWindows`/`$IsLinux`/`$IsMacOS` are PS6+ only — guard with
  `$PSVersionTable.PSVersion.Major -ge 6` first, or PS5.1 throws under `Set-StrictMode`
- **Paths**: `Join-Path`, never string concatenation; prefer `$env:DOTFILES_PWSH`/`$env:DOTFILES_TOOLS`
  once a profile session exists — `bootstrap.ps1` and the injected snippet are deliberate exceptions
  (they run before those env vars exist)
- **Native `$PROFILE` paths**: never hardcode `$HOME\Documents\...` — use
  `Get-NativeProfilePaths`/`Resolve-DocumentsPath` from `profile/lib/paths.ps1`, which validates
  every candidate (`Test-RootedPath`) before use — a corrupted Known Folder registry value has been
  field-reported and must degrade to `$HOME\Documents`, not crash
- **Self-referential lookups inside `toolkit/`**: never assume `$env:DOTFILES_TOOLS` is set when
  locating a file that lives inside `toolkit/` itself (`scripts/*.ps1`, `.vscode/`) — fall back to
  `Split-Path $PSScriptRoot -Parent` (see `toolkit/lib/config.ps1`'s `$toolsRoot` pattern). A
  field-reported crash (`Join-Path $env:DOTFILES_TOOLS ...` with a `$null` env var) happened when
  the menu launched without the profile loaded (e.g. a WT custom profile running `menu-main.ps1` directly)
- **Alias/function naming**: check `Get-Command -CommandType Alias <name>` before adding a short
  function name — a built-in alias silently wins over a same-named function with no error
  (bit `gcm`/`gps` once; fix: `Remove-Item Alias:<name> -Force` before the function definition)
- **Menu items calling `profile/` functions from `toolkit/`** (`Show-Status`, `Measure-Profile`, …)
  go through `Invoke-IfAvailable` — `toolkit/` can in principle be loaded standalone
- **`#Requires -Version 5.1`** on every real entry point (`install.ps1`, `update.ps1`,
  `toolkit/bin/*.ps1`, and `remote-install.ps1` for its direct-invocation path — it's a silent
  no-op under `irm | iex`, since `#Requires` only enforces on file/call-operator invocation, not
  `Invoke-Expression`, verified empirically) — gives a clean native error instead of a cryptic
  mid-parse failure on an unsupported PowerShell. Not worth adding to `bootstrap.ps1`: that file
  is a reference copy, never itself executed as a script (see its own `.NOTES`)
- **State-changing functions get `SupportsShouldProcess`** (`-WhatIf`/`-Confirm`) — e.g.
  `Reset-PSModulePath`/`Remove-PSModulePath`. Skip it for functions PSScriptAnalyzer flags on verb
  alone but where confirm-before-running doesn't make sense (an interactive menu launcher, an ETW
  start/stop toggle) — document the exception in `PSScriptAnalyzerSettings.psd1` rather than
  bolting on a meaningless `ShouldProcess` gate

---

## Toolkit module — 37 exported functions

| Category | Functions |
|----------|-----------|
| Menu | `Start-MainMenu`, `Show-DockerMenu`, `Show-GitMenu`, `Show-TerminalMenu`, `Show-TerminalTroubleshootingMenu`, `Show-DotfilesMenu`, `Show-PwshMenu`, `Show-VSCodeMenu`, `Show-Menu` |
| Diagnostics | `Invoke-SystemCheck`, `Get-DiskStatus`, `Get-ServiceStatus`, `Get-NetworkInfo`, `Get-TopProcesses` |
| Utility | `Test-Admin`, `Get-ScriptDirectory`, `Confirm-Action` |
| Logging | `Write-Info`, `Write-Success`, `Write-Warn`, `Write-Err` |
| Config | `Get-ToolkitConfig`, `Save-ToolkitConfig`, `Merge-Hashtable` |
| PSModulePath | `Get-PSModulePath`, `Add-PSModulePath`, `Remove-PSModulePath`, `Reset-PSModulePath`, `Export-PSModulePath`, `Import-PSModulePath`, `Test-PSModulePath` |
| Detectors | `Get-ModuleStackStatus`, `Test-LegacyPowerShellGetPresent`, `Test-PSResourceGetReady`, `Get-DotfilesCompanionStatus`, `Get-ModulePathStatus`, `Invoke-IfAvailable` |

---

## Prompts that understand this project

- [docs/PROMPT.md](docs/PROMPT.md) — original AI prompts (historical)
- [Gist: master-prompt](https://gist.github.com/martinpaprcka77/1c74223f4e57b46977abd6df06d4e8fd) — regeneration prompt
- [prompts.html](https://martinpaprcka77.github.io/prompts.html) — task-specific prompt templates

---

## Related resources

| Resource | URL |
|----------|-----|
| **Repo / Portal** | https://github.com/martinpaprcka77/martinpaprcka77.github.io |
| **Gist: Install** | https://gist.github.com/martinpaprcka77/bafc2457fd9d93daf1b1b69c348e0cfd |
| **Gist: Cheatsheet** | https://gist.github.com/martinpaprcka77/b30ae161dfb693431a438e309f236467 |
| **Gist: Master prompt** | https://gist.github.com/martinpaprcka77/1c74223f4e57b46977abd6df06d4e8fd |
