# VS Code agent instructions for this repo

## PowerShell Dotfiles Ecosystem

This is a monorepo containing a modular PowerShell profile (`profile/`) and an interactive toolbox module (`toolkit/`).

### Key facts
- **Profile root**: `profile/profile.ps1` — dot-sources everything under `profile/`
- **Module root**: `toolkit/Toolkit/Toolkit.psd1` — 38 exported functions
- **Tests**: `Invoke-Pester toolkit/tests/Toolkit.Tests.ps1` — 76 test cases
- **Installer**: `install.ps1` — idempotent, supports `-WhatIf`, `-Force`, `-NoTerminal`
- **Bootstrap**: injected into `$PROFILE` by `install.ps1`, dot-sources `profile/profile.ps1`
- **Menu**: run `menu` after install, or `Import-Module toolkit/Toolkit/Toolkit.psd1`

### File structure (abridged)
- `.vscode/` — this dir: settings, tasks, agent instructions
- `profile/` — profile orchestration (core/, ps7/, hosts/, lib/)
- `toolkit/` — interactive toolbox (Toolkit module, menu/, scripts/, lib/)
- `git/` — global gitignore (`ignore`) + Claude agent settings
  (deployed as junction to `~/.config/git/`)
- `chezmoi/` — chezmoi config (`chezmoi.toml`,
  deployed as junction to `~/.config/chezmoi/`)
- `docs/` — architecture, purpose, manual, roadmap
- `index.html` — GitHub Pages portal at repo root

### Coding conventions
- Comment-based help on every function
- Verb-Noun naming (exceptions: mkcd, touch, ff, sed, k9)
- No network calls in profile startup
- Cross-platform: Windows-only, PS7-only — no `$IsLinux`/`$IsMacOS` guards needed
- Paths: `Join-Path`, never string concatenation
- No `$ErrorActionPreference = 'Stop'` or `Set-StrictMode` in profile files
