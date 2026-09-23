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
| **Module** | `toolkit/Toolkit` — 36 exported functions, v1.5.1 |
| **Tests** | 76 Pester cases in `toolkit/tests/Toolkit.Tests.ps1` (70 module/behaviour + 6 repo invariants) |
| **Dependencies** | Git; PowerShell 7+ (Windows) |
| **Lint** | `PSScriptAnalyzerSettings.psd1` at repo root; CI fails only on Error severity |

Previously split across two repos (`dotfiles-powershell`, `dotfiles-tools`) — merged here to
eliminate cross-repo coupling (menu items calling functions that only existed in the other repo)
and the two-sources-of-truth drift between `$env:DOTFILES_PWSH`/`$env:DOTFILES_TOOLS`. See
`docs/ROADMAP.md` Fáze 5 for the full rationale.

**Single source of truth (verified 2026-09-22).** This repo is the only place the profile, the
toolkit and the portal are maintained. Status of the leftovers:

- `martinpaprcka77/dotfiles-tools` on GitHub is **archived** (read-only).
- `martinpaprcka77/dotfiles-powershell` **no longer exists** on GitHub.
- A *working copy* of the old `dotfiles-tools` repo may still sit beside a checkout of this one
  (e.g. `C:\Dev\dotfiles-tools`). It is a stale **subset** of `toolkit/` here: same tree, but no
  `ShellInfo.ps1`/`Connectivity.ps1`, smaller `Diagnostics.ps1`, an older 11 KB
  `Toolkit.Tests.ps1` here supersedes, and no `docs/`, `icons/` or `PowerShell-Startup-Map.html`.
  **Never fix a bug there** — its own `README.md` points here on purpose.
- `tools/devmenu/` used to live outside version control; it is now a tracked part of this repo
  (identical code, plus one nested-`Join-Path` fix so it satisfies the repo invariant test).

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
│   │   ├── aliases.ps1      ← git, kubectl shortcuts
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
├── toolkit/                 ← INTERACTIVE TOOLBOX (self-contained module + ops)
    ├── Toolkit/             ← PowerShell module: Toolkit.psd1 (36 FunctionsToExport) + Toolkit.psm1
    │   ├── Private/         ← Get-ToolkitRoot (never exported)
    │   └── Public/          ← Console · Configuration · Diagnostics · Detectors · ModulePath · Output · Show-Menu
    │       └── Menu/        ← menu-main/startup/git/terminal/dotfiles/pwsh/vscode (dual-purpose)
    ├── bin/                 ← in PATH: menu.ps1 (→ Start-MainMenu), check.ps1 (→ Invoke-SystemCheck)
    ├── ops/                 ← Add-WTProfiles · Generate-Icons · deps · windows · modernize · precheck · configure · Get-PowerShellStartupHealth
    ├── config/              ← settings.example.json (committed template) + wt-schemes.json
    │                           settings.json is LOCAL + gitignored (Save-ToolkitConfig writes it)
    ├── build/               ← Build.ps1 (manifest parity) · Test.ps1 (verification gate) · Generate-Docs.ps1
    ├── tests/Toolkit.Tests.ps1 ← 76 Pester cases (70 module/behaviour + 6 repo invariants)
    ├── docs/                ← 00-bootstrap … 90-prompt + 20-reference (generated)
    ├── PowerShell-Startup-Map.html ← interactive startup health map
    └── githooks/            ← post-checkout/post-merge reminders, install.sh

└── tools/                   ← repo-maintenance + developer tooling (NOT part of the profile)
    ├── devmenu/             ← portable launcher menu for pi/pwsh/wt/cmd (devmenu.ps1,
    │                           devmenu.d/*.json fragments, docs/ARCHITECTURE.md);
    │                           `pwsh -File tools/devmenu/devmenu.ps1 -SelfTest` = 31 checks
    ├── gist-sources.ps1     ← canonical gist bodies shared by the two scripts below
    ├── Verify-Sync.ps1      ← read-only check: gists + repos match the canonical sources
    ├── Update-Gists.ps1     ← push gist-sources.ps1 content to the canonical gists
    └── Validate-Links.ps1   ← link/definition scan
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
dot-source `toolkit/Toolkit/Private/`, then `toolkit/Toolkit/Public/` (recursive, incl. `Public/Menu/`).

**The toolkit is opt-in.** `profile/` never imports it — it only sets `$env:DOTFILES_TOOLS`.
The module is loaded explicitly, by `toolkit/bin/*` (the `menu`/`check` shims) or `toolkit/ops/*`,
or by the user running `Import-Module toolkit/Toolkit/Toolkit.psd1`. Keep it that way so profile
startup stays lean; the profile's status dashboard guards on `Get-Command Get-ShellInfo`.

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

`install.ps1` is idempotent — supports `-WhatIf`, `-Force`, `-NoUpdates`.
`remote-install.ps1` uses `$env:DOTFILES_FORCE`/`$env:DOTFILES_NO_UPDATES`
instead (switches aren't reachable through `iex`).

---

## How to add a new feature

1. **Profile function/alias** → `profile/core/functions.ps1` or `profile/core/aliases.ps1`
2. **PS7-only** → `profile/ps7/profile.ps1`; **PS5-only** → `profile/ps5/profile.ps1`
3. **Host-specific** → `profile/hosts/ConsoleHost.ps1` or `VSCode.ps1`
4. **New profile core file** → drop a `.ps1` into `profile/core/` — it auto-loads
5. **New toolkit utility** → `toolkit/Toolkit/Public/Console.ps1` (generic helpers) or
   `Configuration.ps1`; **new diagnostic** → `toolkit/Toolkit/Public/Diagnostics.ps1`
6. **New menu item** → `toolkit/Toolkit/Public/Menu/menu-main.ps1`; **new submenu** → new
   `toolkit/Toolkit/Public/Menu/menu-<name>.ps1` (the whole `Public/` tree is dot-sourced
   recursively, so a new file needs no registration — but a new *exported* function does, see 7)
7. **After adding a toolkit function**: add to `FunctionsToExport` in `Toolkit.psm1`, add to
   `FunctionsToExport` in `Toolkit.psd1`, add a test case in `toolkit/tests/Toolkit.Tests.ps1`
8. **User overrides** → copy `profile/core/extra.ps1.example` to `profile/core/extra.ps1` (gitignored)

---

## How to run tests

One command runs the whole gate (manifest parity → Pester → analyzer), and exits non-zero on
any failure — use this before committing:

```powershell
pwsh -File ~/.config/powershell/toolkit/build/Test.ps1
# add -Detailed for per-test output
```

Individually:

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

**Toolchain notes (verified, not assumed):** the `Toolkit` module declares
`PowerShellVersion = 7.0` (it uses `??` and `ConvertFrom-Json -AsHashtable`), so the *module*
tests need `pwsh` 7+, Pester 5+ (`BeforeAll`/`-ForEach`/`Should -Exist` are 5.x syntax; the
Pester 3.4.0 that ships with Windows will not run this suite) and, for the 3-arg-`Join-Path`
and style-table invariants, nothing more. `profile/`, `install.ps1`, `update.ps1` and
`Setup-Windows.ps1` must keep working on **Windows PowerShell 5.1** as well — the repo
invariant test in the Pester suite enforces the `Join-Path` half of that automatically.
Two tests deliberately write nothing to the host: calls under test get `6>$null` because
`Write-Host` ignores `$InformationPreference`.

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
  `Split-Path $PSScriptRoot -Parent` (see `toolkit/Toolkit/Public/Configuration.ps1`'s `$toolsRoot` pattern). A
  field-reported crash (`Join-Path $env:DOTFILES_TOOLS ...` with a `$null` env var) happened when
  the menu launched without the profile loaded (e.g. a WT custom profile running `menu-main.ps1` directly)
- **System module paths**: derive them, never hardcode. `Join-Path $PSHOME 'Modules'` — a PowerShell 7
  installed from the Microsoft Store (MSIX) keeps its own modules under `$PSHOME\Modules` and
  `"$env:ProgramFiles\PowerShell\7\Modules"` does not exist there at all (verified on 7.6.6 MSIX). The
  literal silently disabled legacy-module detection, its cleanup and the PSModulePath baseline on
  exactly that install flavour; a repo-invariant test now fails on any non-comment occurrence
- **`exit` in a script meant to run via `irm | iex`**: `exit` tears down the *host*, so a failed
  bootstrap closed the user's console window instead of printing the error (verified: `iex 'exit 7'`
  exits the process with 7 and the next statement never runs). Use `return`, and `exit` only when
  `$MyInvocation.MyCommand.Path` is non-null (i.e. really invoked as a file, where an exit code means
  something) — `remote-install.ps1` does this via an `$invokedAsFile` flag
- **Alias/function naming**: check `Get-Command -CommandType Alias <name>` before adding a short
  function name — a built-in alias silently wins over a same-named function with no error
  (bit `gcm`/`gps` once; fix: `Remove-Item Alias:<name> -Force` before the function definition)
- **Menu items calling `profile/` functions from `toolkit/`** (`Show-Status`, `Measure-Profile`, …)
  guard inline with `if (Get-Command <name> -ErrorAction SilentlyContinue) { … }` — `toolkit/` can in
  principle be loaded standalone, so a bare call would throw
- **`#Requires -Version 5.1`** on every real root entry point (`install.ps1`, `update.ps1`,
  `Setup-Windows.ps1`, and `remote-install.ps1` for its direct-invocation path — it's a silent
  no-op under `irm | iex`, since `#Requires` only enforces on file/call-operator invocation, not
  `Invoke-Expression`, verified empirically) — gives a clean native error instead of a cryptic
  mid-parse failure on an unsupported PowerShell. `toolkit/bin/*.ps1` deliberately carries none:
  those shims only `Import-Module` the Toolkit module, which itself declares
  `PowerShellVersion = 7.0`, so claiming 5.1 there would be wrong. Not worth adding to
  `bootstrap.ps1` either: that file is a reference copy, never itself executed as a script
  (see its own `.NOTES`)
- **State-changing functions get `SupportsShouldProcess`** (`-WhatIf`/`-Confirm`) — e.g.
  `Reset-PSModulePath`/`Remove-PSModulePath`. Skip it for functions PSScriptAnalyzer flags on verb
  alone but where confirm-before-running doesn't make sense (an interactive menu launcher, an ETW
  start/stop toggle) — document the exception in `PSScriptAnalyzerSettings.psd1` rather than
  bolting on a meaningless `ShouldProcess` gate

---

## Toolkit module — 36 exported functions

| Category | Functions |
|----------|-----------|
| Menu | `Start-MainMenu`, `Show-StartupMenu`, `Show-GitMenu`, `Show-TerminalMenu`, `Show-DotfilesMenu`, `Show-PwshMenu`, `Show-VSCodeMenu`, `Show-Menu` |
| Diagnostics | `Invoke-SystemCheck`, `Get-DiskStatus`, `Get-ServiceStatus`, `Get-NetworkInfo`, `Get-TopProcesses` |
| Utility | `Confirm-Action` |
| Logging | `Write-TkMessage`, `Write-Info`, `Write-Success`, `Write-Warn`, `Write-Err` |
| Config | `Get-ToolkitConfig`, `Save-ToolkitConfig`, `Merge-Hashtable` |
| PSModulePath | `Get-PSModulePath`, `Add-PSModulePath`, `Remove-PSModulePath`, `Reset-PSModulePath`, `Export-PSModulePath`, `Import-PSModulePath`, `Test-PSModulePath` |
| Detectors | `Get-ModuleStackStatus`, `Test-LegacyPowerShellGetPresent`, `Test-PSResourceGetReady`, `Get-ModulePathStatus` |

---

## AI instructions & prompts (single source of truth)

**This file (`AGENTS.md`) is the only AI-instruction document.** Everything else is a
pointer or a prompt artifact, so there is nothing to keep in sync by hand.

Pointers (intentionally short — do not add instruction content to them):
- [`CLAUDE.md`](CLAUDE.md)
- [`.vscode/agent-instructions.md`](.vscode/agent-instructions.md)
- `toolkit/AGENTS.md`, `toolkit/CLAUDE.md`, `toolkit/.vscode/agent-instructions.md`

Prompt artifacts (content, not instructions):
- [docs/PROMPT.md](docs/PROMPT.md) — original ecosystem prompt (historical)
- [toolkit/docs/90-prompt.md](toolkit/docs/90-prompt.md) — original toolkit prompt (historical)
- [prompts.html](https://martinpaprcka77.github.io/prompts.html) — task-specific prompt templates
- [Gist: master-prompt](https://gist.github.com/martinpaprcka77/1c74223f4e57b46977abd6df06d4e8fd) — regeneration prompt
- `.github/agents/*.agent.md` — third-party Copilot agent pack (222 files), not maintained here

---

## Related resources

| Resource | URL |
|----------|-----|
| **Repo / Portal** | https://github.com/martinpaprcka77/martinpaprcka77.github.io |
| **Gist: Install** | https://gist.github.com/martinpaprcka77/bafc2457fd9d93daf1b1b69c348e0cfd |
| **Gist: Cheatsheet** | https://gist.github.com/martinpaprcka77/b30ae161dfb693431a438e309f236467 |
| **Gist: Master prompt** | https://gist.github.com/martinpaprcka77/1c74223f4e57b46977abd6df06d4e8fd |
