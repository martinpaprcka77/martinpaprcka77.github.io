# NEEDS INPUT — Open Work Items

> This document tracks items marked as incomplete in `docs/ROADMAP.md`.
> Each entry explains what's needed and estimated scope.

---

## Phase 3: Rozšíření (🟡 In Progress)

### [ ] Live dashboard
**What**: Real-time CPU/RAM/Disk monitoring UI in interactive menu  
**Scope**: Medium  
**Notes**: Requires Windows API calls or `Get-Process`/`Get-Volume` polling; display in `Show-Menu` format  
**Dependencies**: None (Windows-only candidate)

### [ ] Síťová diagnostika
**What**: Network diagnostics — `Test-NetConnection` against key endpoints  
**Scope**: Small  
**Notes**: Batch test DNS, gateway, key services; add detector to health menu  
**Dependencies**: None (works on all platforms with PowerShell 5.1+)

### [ ] Více Docker příkazů
**What**: Extend Docker menu — `docker compose`, network management  
**Scope**: Medium  
**Notes**: New `menu-docker.ps1` items for compose up/down, network ls, container inspect  
**Dependencies**: Docker (optional)

### [ ] Transient prompt
**What**: Collapse prompt after command execution (Starship feature)  
**Scope**: Small  
**Notes**: Starship config (`starship.toml`): add `[line_break].disabled = false` and transient line prefix  
**Dependencies**: Starship 1.8+

---

## Phase 4: Integrace (🟢 Integration)

### [ ] PowerShell Gallery
**What**: Publish Toolkit module to PSGallery  
**Scope**: Small  
**Notes**:
- Requires PSGallery API key (martinpaprcka77 account)
- Automate via GitHub Actions (release trigger or on-demand)
- Update manifest version in `Toolkit.psd1`
- Write `PUBLISH.md` with manual steps + CI trigger logic

**Checklist**:
- [ ] Get PSGallery API key
- [ ] Set `$env:PSGALLERY_API_KEY` in GitHub Actions secrets
- [ ] Add `.github/workflows/publish.yml` (triggers on git tag `v*`)
- [ ] Update README.md with `Install-Module` instructions
- [ ] Verify module imports cleanly from gallery

---

## Phase 5: Ekosystém (✅ Key Items Done)

### [ ] Instalační skript pro Windows
**What**: Complete Windows setup from clean install  
**Scope**: Large  
**Notes**:
- GUI wizard or command-line options (`-Profile`, `-Terminal`, `-Vscode`, `-All`)
- Handles: Git install, PS7 install, profile bootstrap, WT setup, theme selection
- Currently split between `install.ps1` + `deps.ps1` + `windows.ps1`
- Consolidate into single `Setup-Windows.ps1` or similar

**Checklist**:
- [ ] Design unified entry point (CLI args)
- [ ] Test on clean Windows VM
- [ ] Add smoke tests (GitHub Actions matrix: Windows Server 2019, 2022)

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
