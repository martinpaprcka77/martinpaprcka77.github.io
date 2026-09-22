# NEEDS INPUT — Open Work Items

> This document tracks items marked as incomplete in `docs/ROADMAP.md`.
> Each entry explains what's needed and estimated scope.

---

## Phase 3: Rozšíření (✅ Substantially Complete)

### [x] Live dashboard
**What**: Real-time CPU/RAM/Disk monitoring UI in interactive menu  
**Scope**: Medium  
**Notes**: Requires Windows API calls or `Get-Process`/`Get-Volume` polling; display in `Show-Menu` format  
**Dependencies**: None (Windows-only candidate)  
**Status**: ✅ Done (commit: 682a538 — `Watch-SystemMetrics` with configurable interval/samples)

### [x] Síťová diagnostika
**What**: Network diagnostics — `Test-NetConnection` against key endpoints  
**Scope**: Small  
**Notes**: Batch test DNS, gateway, key services; add detector to health menu  
**Dependencies**: None (works on all platforms with PowerShell 5.1+)  
**Status**: ✅ Done (commit: 35c80ab — `Test-NetworkHealth` tests DNS, GitHub, Google)

### [ ] Transient prompt — NOT AVAILABLE in Starship
**What**: Collapse prompt after command execution
**Scope**: N/A
**Notes**: This is an **oh-my-posh** feature, not a Starship one. The `[transient_prompt]` table is
not a valid Starship key: Starship rejects it and printed
`[WARN] (starship::config): Error in 'StarshipRoot' at 'transient_prompt': Unknown key` on every
prompt init (verified against starship 1.26.0 — the key is absent from `starship print-config
--default` and dropped by `starship print-config`; an A/B run of a copied `profile/` with and
without the block confirmed it is the cause). The block has been removed from
`profile/starship.toml`; `[line_break]` stays. The feature remains available only on the
oh-my-posh fallback path in `profile/ps7/profile.ps1`.
**Dependencies**: Starship has no equivalent; would need oh-my-posh as the active prompt
**Status**: ❌ Closed as not-supported-upstream (previous "✅ Done (commit: 32c22e3)" was wrong —
the config it added was invalid and noisily warned)

---

## Phase 4: Integrace (🟢 Integration)

### [x] PowerShell Gallery
**What**: Publish Toolkit module to PSGallery  
**Scope**: Small  
**Notes**:
- Requires PSGallery API key (martinpaprcka77 account)
- Automate via GitHub Actions (release trigger or on-demand)
- Update manifest version in `Toolkit.psd1`
- Write `PUBLISH.md` with manual steps + CI trigger logic

**Status**: ✅ Done (commit: 3519a6f)

**Completed**:
- [x] Added `.github/workflows/publish.yml` (triggers on `v*` tags or manual dispatch)
- [x] Created `docs/PUBLISHING.md` with setup guide + troubleshooting
- [x] Updated `.gitignore` for `*.nupkg` artifacts
- [ ] Get PSGallery API key (user action: create account + generate key)
- [ ] Set `$env:PSGALLERY_API_KEY` in GitHub Actions secrets (user action: repo settings)

---

## Phase 5: Ekosystém (✅ Core Items Done)

### [x] Instalační skript pro Windows
**What**: Complete Windows setup from clean install  
**Scope**: Large  
**Notes**:
- GUI wizard or command-line options (`-Profile`, `-Terminal`, `-Vscode`, `-All`)
- Handles: Git install, PS7 install, profile bootstrap, theme selection
- Currently split between `install.ps1` + `deps.ps1` + `windows.ps1`
- Consolidate into single `Setup-Windows.ps1` or similar

**Status**: ✅ Done (commit: e1c4cdb)

**Implemented**:
- [x] Unified `Setup-Windows.ps1` with CLI flags (-Profile, -Dependencies, -Defaults, -VSCode, -All)
- [x] Dependency detection + winget auto-install (Git, PS7, WT, Starship, zoxide)
- [x] Windows defaults (privacy, taskbar, Explorer) with registry edits
- [x] VS Code configuration (copy .vscode/ settings)
- [x] Idempotent — safe to re-run
- [ ] Test on clean Windows VM (user action: manual testing)
- [ ] Add CI smoke tests (future: GitHub Actions Windows VM)

### [ ] Dokumentační web
**What**: Static site generated from Markdown docs  
**Scope**: Large  
**Notes**:
- Current: hand-written `index.html` + GitHub Pages
- Goal: Docusaurus, Hugo, or similar from `docs/` folder
- Keep GitHub Pages at root URL; docs at `/docs/` subpath
- Auto-rebuild on main branch push via GitHub Actions

**Checklist**:
- [ ] Pick static site generator (Docusaurus recommended for PowerShell audience)
- [ ] Port `docs/MANUAL.md`, `ROADMAP.md`, etc. → generator format
- [ ] Test local build + GitHub Pages deploy
- [ ] Update CI to rebuild on docs change

### [ ] Možné budoucí rozdělení zpět na 2 repa
**What**: Split back into `dotfiles-powershell` + `dotfiles-tools` if justified  
**Scope**: Large architectural decision  
**Notes**: Not a plan, only an option if independent release cycles become necessary  
**Trigger**: Ecosystem grows beyond ~50 functions or release cadence diverges  
**Current status**: Consolidation stable; no split planned

---

## Known Issues (Already Resolved ✅)

All known issues from Phase 1–4 are resolved. See `docs/ROADMAP.md` "Známé problémy" for the audit trail.

---

## How to Contribute

Pick an open item, update its checklist, and open a PR. Reference this doc in your PR body:
```
Closes: #<issue> (if any)
Addresses: NEEDS-INPUT.md → [Item Name]
```

See `docs/ROADMAP.md` "Jak přispět" for full contribution guidelines.
