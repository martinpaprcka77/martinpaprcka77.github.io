# CLAUDE.md — PowerShell Dotfiles Ecosystem

> Memory file for Claude. Load this before working with the repo.

## Identity
This repo is the **whole PowerShell Dotfiles Ecosystem** — profile orchestration (`profile/`),
interactive toolbox (`toolkit/`), and the GitHub Pages portal (`index.html`/`prompts.html` at
repo root) — in one place. Clones to `~/.config/powershell/`.

Previously split across `dotfiles-powershell` + `dotfiles-tools`; merged here to eliminate
cross-repo coupling and the `$env:DOTFILES_PWSH`/`$env:DOTFILES_TOOLS` two-sources-of-truth drift.
Those repos remain on GitHub with a README pointer to this one — no archive tool was available in
the environment that did the merge, so that's the extent of "archiving."

## Key files
- `install.ps1` / `remote-install.ps1` — idempotent installer / one-command `irm | iex` bootstrapper
  (no `SupportsShouldProcess` in `remote-install.ps1` — `$PSCmdlet` is `$null` under `Invoke-Expression`)
- `update.ps1` — git pull + `Invoke-BootstrapInjection` self-heal + profile reload
- `profile/profile.ps1` — main orchestrator, dot-sources everything under `profile/`
- `profile/lib/paths.ps1` — `Resolve-DocumentsPath`/`Get-NativeProfilePaths`, Known-Folder-correct
  (OneDrive-safe) `$PROFILE` targets; every candidate validated with `Test-RootedPath` before use
  (a corrupted Known Folder registry value has been field-reported)
- `profile/lib/bootstrap.ps1` — `Invoke-BootstrapInjection`, shared by `install.ps1`/`update.ps1`;
  repairs a stale bootstrap target automatically, not just on first install
- `profile/core/functions.ps1` — Edit-Profile, Reload-Profile, Get-SecretKey, mkcd
- `profile/core/status.ps1` — health dashboard (`Test-PathHealth`, single `.git` check at repo root)
- `toolkit/lib/menu.ps1` — `Show-Menu` engine (arrow-key nav, live status column, width-clamped)
- `toolkit/lib/detectors.ps1` — Show-Menu status detectors + `Invoke-IfAvailable` guard
- `toolkit/Toolkit/Toolkit.psm1` + `.psd1` — module (38 functions)

## Module structure
```
toolkit/bin/*.ps1 → Import-Module Toolkit → Toolkit.psd1 → Toolkit.psm1 → dot-source toolkit/lib/*.ps1
```
To add a function: write it in `toolkit/lib/`, add to `Export-ModuleMember` in `.psm1`, add to
`FunctionsToExport` in `.psd1`.

## How to run
- After install: `menu` or `check` from anywhere
- Direct: `Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1`
- Tests: `Invoke-Pester ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1` (76 cases)
- Validate profile: `& $PROFILE` in a fresh session

## Architecture decisions
- `~/.config/powershell/` chosen over `Documents\` to bypass OneDrive — applies to the whole repo
- One repo (`profile/` + `toolkit/` subfolders), not two — eliminates the cross-repo coupling bug
  class (menu calling functions that only existed in the other repo) and keeps
  `$env:DOTFILES_TOOLS` always derived from `$env:DOTFILES_PWSH` (can't drift apart anymore).
  Possible future split back into 2 repos is a documented option in `docs/ROADMAP.md`, not a plan.
- `PSModulePath` fixed to avoid OneDrive pollution
- Host detection via `$host.Name -match 'Code'`
- Windows-only, PS7-only config — no cross-platform branching
- Before naming a short function/alias: check `Get-Command -CommandType Alias` first — a built-in
  alias silently wins over a same-named function (bit `gcm`/`gps` once, see AGENTS.md)
- Never trust a Known Folder/registry-derived path unvalidated — `Test-RootedPath` in
  `profile/lib/paths.ps1` checks every candidate before use, falling back instead of crashing
- Never assume `$env:DOTFILES_TOOLS` is set when a script inside `toolkit/` locates its own files
  — fall back to `Split-Path $PSScriptRoot -Parent` (see `toolkit/lib/config.ps1`)

## Doc links
- [AGENTS.md](AGENTS.md) — full AI agent guide
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Mermaid UML diagrams
- [docs/PURPOSE.md](docs/PURPOSE.md) — design rationale
- [docs/MANUAL.md](docs/MANUAL.md) — full user guide
- [docs/ROADMAP.md](docs/ROADMAP.md) — phases, known issues
- [docs/PROMPT.md](docs/PROMPT.md) — original AI prompts
