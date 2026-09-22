# Roadmap dotfiles-tools

Plánované funkce a směr vývoje. Priority: 🔴 vysoká · 🟡 střední · 🟢 nízká · ✅ hotovo

---

## Fáze 1: Základ (✅ hotovo)

- ✅ Modulární PowerShell profil (`dotfiles-powershell`)
- ✅ Idempotentní instalátor (`install.ps1` — WhatIf, Force, backup, summary)
- ✅ Update mechanism (`update.ps1` — git fetch + reload)
- ✅ Toolkit modul — **33 exportovaných funkcí**
- ✅ Interaktivní menu — 7 submenu (Startup, Dotfiles, Git, Terminal, PowerShell, VS Code, Diagnostika)
- ✅ Moderní menu engine — šipky ↑↓, zvýraznění, popisky, inline režim
- ✅ Arrow-key menu s popisky u každé položky
- ✅ Živá detekce stavu přímo v menu (`Detector` na položku — modul stack, PSModulePath, dostupnost
  companion profilu) — bez nutnosti spouštět samostatný diagnostický příkaz
- ✅ Jednopříkazový vzdálený bootstrapper (`remote-install.ps1`, `irm | iex`), Known-Folder-korektní
  detekce cest (funguje i s přesměrovaným OneDrive Documents)
- ✅ CRUD operace na všech menu (Check, Backup, Restore, Reset, Clean)
- ✅ Systémová diagnostika (disky, služby, síť, procesy)
- ✅ Windows Terminal profily — JSON fragment extensions (WT 1.24+)
- ✅ 7 barevných schémat (One Half Dark, Dracula, Nord, TokyoNight, Catppuccin Mocha, Gruvbox Dark, Solarized Dark)
- ✅ WT shell integration (OSC 133 markery, showMarksOnScrollbar, autoMarkPrompts) — jen na
  vlastních profilech (Menu, Projekty), nikdy implicitně na existujících výchozích profilech uživatele
- ✅ Starship prompt (Rust) s `starship.toml` konfigurací (30+ modulů)
- ✅ oh-my-posh jako fallback
- ✅ Generování ikon (`Generate-Icons.ps1`)
- ✅ 69 Pester testů (Mock pokrytí, config, PSModulePath, menu chybové cesty)
- ✅ Bezpečné ukládání klíčů (`Get-SecretKey` — SecretManagement + env fallback)
- ✅ `extra.ps1` pattern — uživatelské přizpůsobení mimo Git
- ✅ AGENTS.md + CLAUDE.md v obou repozitářích
- ✅ GitHub Pages portal (`martinpaprcka77.github.io`)
- ✅ AI Prompts stránka — 8 modelů, 5 typů úloh
- ✅ 4 gisty (install, cheatsheet, prompt, master-prompt)

---

## Fáze 2: 2026 vylepšení (✅ hotovo)

- ✅ **Cascadia Code Nerd Font auto-installer** — `deps.ps1` stahuje a instaluje
- ✅ **`deps.ps1`** — winget auto-installer (Git, PS7, WT, VS Code, Starship, zoxide)
- ✅ **`windows.ps1`** — Windows defaults (Explorer, taskbar, privacy, bloatware)
- ✅ **WT JSON fragment** — nahrazuje staré editování settings.json
- ✅ **Shell integration** — OSC 133 markery, scrollbar marks, exit code coloring
- ✅ **VS Code integrace** — `.vscode/settings.json`, `tasks.json`, `agent-instructions.md`
- ✅ **`precheck.ps1`** — 20+ inventory kontrol před instalací
- ✅ **`configure.ps1`** — 5-step interaktivní wizard
- ✅ **zoxide** — smart directory jumper (náhrada za `z.ps1`)
- ✅ **wtprofile.ps1** — CTT-inspired Windows Terminal enhanced profile
- ✅ **core/perf.ps1** — Measure-Profile, Clear-PSCache, Optimize-ModuleLoading, Get-ProfileSize
- ✅ **core/status.ps1** — globální health dashboard (6 sekcí, 20+ kontrol)
- ✅ **core/extra.ps1.example** — šablona pro uživatelské přizpůsobení
- ✅ Konfigurační vrstva — `Configuration.ps1` (defaults → JSON → $env:TOOLKIT_*)
- ✅ **7 barevných WT schémat** z windowsterminalthemes.dev

---

## Fáze 3: Rozšíření (🟡 plánováno)

- [ ] **Linux podpora** — otestovat cesty pro Linux (`~/.config/`, `/home/`)
- [ ] **macOS podpora** — otestovat s PowerShell 7 na macOS
- ✅ **Systémový přehled** — `Get-SystemSummary` (jednorázový snapshot OS/CPU/RAM/uptime); plný real-time dashboard nahrazen snapshottem
- ✅ **Síťová diagnostika** — `Test-NetworkEndpoint` (TCP 443 + latence; jediná síťová funkce, mimo local-only Diagnostics)
- [ ] **Transient prompt** — kolaps promptu po provedení příkazu (Starship)
- [ ] **PSResourceGet migration** — plný přechod z PowerShellGet
- [ ] **AddToHistoryHandler** — vlastní PSReadLine history filter

---

## Fáze 4: Integrace (🟢)

- ✅ **Git hooks** — `githooks/` (`post-checkout`, `post-merge`, `install.sh`)
- ✅ **CI/CD** — GitHub Actions (`.github/workflows/test.yml`): Pester + PSScriptAnalyzer + JSON validace
- [ ] **PowerShell Gallery** — publikovat Toolkit modul
- ✅ **Komunitní příspěvky** — `.github/ISSUE_TEMPLATE/bug-report.md` + `PULL_REQUEST_TEMPLATE.md`

---

## Fáze 5: Ekosystém (🟢)

- ✅ **Web bootstrap** — `irm <url> | iex` jednopříkazová instalace (`remote-install.ps1` v
  dotfiles-powershell) — stále vyžaduje Git (klonuje repo); plně gitless varianta (stažení ZIP
  místo klonu) zůstává otevřená jako budoucí vylepšení
- ✅ **Instalační skript pro Windows** — `install.ps1` + `Setup-Windows.ps1`
- ✅ **Dokumentační web** — statický web (`index.html`, `charts.html`, `prompts.html`)
- ✅ **Sloučení do jednoho repa** — hotovo: `profile/` + `toolkit/` v `martinpaprcka77.github.io`.

---

## Známé problémy

| Problém | Stav | Plán |
|---------|------|------|
| `Add-WTProfiles.ps1` vyžaduje Windows Terminal | ✅ Vyřešeno | Guard na `-not $IsWindows` |
| `Add-WTProfiles.ps1` — parse error, skript se vůbec nespustil | ✅ Vyřešeno | Loose statements uvnitř `@{ }` literálu přesunuty ven |
| `Generate-Icons.ps1` vyžaduje .NET Framework | ✅ Vyřešeno | `$IsWindows` guard |
| `deps.ps1` + `windows.ps1` — Windows-only | ✅ Vyřešeno | Platform guardy |
| `windows.ps1 -WhatIf` přesto restartoval Explorer | ✅ Vyřešeno | Prompt respektuje `$WhatIfPreference` |
| `gcm`/`gps` git zkratky nikdy nefungovaly (tiché stínění vestavěnými PS aliasy) | ✅ Vyřešeno | `Remove-Item Alias:` před definicí funkce |
| `Diagnostics.ps1`/`Console.ps1` bez platform guardu — pád na Linuxu/macOS | ✅ Vyřešeno | `-not $IsWindows` guard |
| `Reset-PSModulePath` vracel `Documents\...` — přesně OneDrive-postiženou cestu | ✅ Vyřešeno | `$env:LOCALAPPDATA\PowerShell\Modules` místo Documents |
| 7 PSModulePath Pester testů selhává na Linuxu/macOS | Známé, netýká se Windows | Testovací fixtures používají `C:\Mods\...` — dvojtečka koliduje s `[IO.Path]::PathSeparator` (`:` na Linuxu/macOS, `;` na Windows); na reálném Windows testy procházejí, jde jen o testovací data, ne o chybu v kódu |
| Menu skripty (`menu-terminal.ps1`/`menu-dotfiles.ps1`/`menu-vscode.ps1`) padaly na `$null` `$env:DOTFILES_TOOLS`, pokud menu běželo bez načteného companion profilu | ✅ Vyřešeno (field-reported) | Fallback `$toolsRoot = if ($env:DOTFILES_TOOLS) {...} else { Split-Path $PSScriptRoot -Parent }` — stejný vzor jako už měl `Toolkit/Public/Configuration.ps1` |
| `Show-Menu` box se rozbil (přetekl přes hranici konzole), když `Detector` vrátil dlouhý text | ✅ Vyřešeno (field-reported) | `$boxWidth` ořezán na `[Console]::WindowWidth`, `Desc`/`Detector` text zkrácen s výpustkou (`…`) |
| Cesty s diakritikou nejsou testovány | Netestováno | Přidat testy |

---

## Jak přispět

1. Fork repozitáře
2. Vytvoř branch (`feature/muj-nastroj`)
3. Přidej testy do `tests/`
4. Aktualizuj `docs/30-manual.md` a `README.md`
5. Otevři Pull Request

Pravidla:
- Všechny skripty musí mít comment-based help
- Idempotentní operace kde to dává smysl
- Respektovat výkon profilu (žádné pomalé importy)
- Cross-platform guardy (`-not $IsWindows`)
