# Roadmap

Plánované funkce a směr vývoje. Priority: 🔴 vysoká · 🟡 střední · 🟢 nízká · ✅ hotovo

---

## Fáze 1: Základ (✅ hotovo)

- ✅ Modulární PowerShell profil (`profile/`)
- ✅ Idempotentní instalátor (`install.ps1` — WhatIf, Force, backup, summary)
- ✅ Update mechanism (`update.ps1` — git fetch + reload + bootstrap self-heal)
- ✅ Toolkit modul — **38 exportovaných funkcí**
- ✅ Interaktivní menu — 6 submenus (Dotfiles, Docker, Git, Terminal, PowerShell, VS Code) + přímá systémová diagnostika
- ✅ Moderní menu engine — šipky ↑↓, zvýraznění, popisky, inline režim, ořez na šířku konzole
- ✅ Arrow-key menu s popisky u každé položky
- ✅ Živá detekce stavu přímo v menu (`Detector` na položku — modul stack, PSModulePath, dostupnost
  companion profilu) — bez nutnosti spouštět samostatný diagnostický příkaz
- ✅ Jednopříkazový vzdálený bootstrapper (`remote-install.ps1`, `irm | iex`), Known-Folder-korektní
  detekce cest (funguje i s přesměrovaným OneDrive Documents, i s poškozenou Known Folder
  registrovou hodnotou)
- ✅ CRUD operace na všech menu (Check, Backup, Restore, Reset, Clean)
- ✅ Systémová diagnostika (disky, služby, síť, procesy)
- ✅ Windows Terminal profily — JSON fragment extensions (WT 1.24+)
- ✅ 7 barevných schémat (One Half Dark, Dracula, Nord, TokyoNight, Catppuccin Mocha, Gruvbox Dark, Solarized Dark)
- ✅ WT shell integration (OSC 133 markery, showMarksOnScrollbar, autoMarkPrompts) — jen na
  vlastních profilech (Menu, Projekty), nikdy implicitně na existujících výchozích profilech uživatele
- ✅ Starship prompt (Rust) s `starship.toml` konfigurací (30+ modulů)
- ✅ oh-my-posh jako fallback
- ✅ Generování ikon (`Generate-Icons.ps1`)
- ✅ 75 Pester testů (full coverage včetně smoke testů pro všech 7 menu)
- ✅ Bezpečné ukládání klíčů (`Get-SecretKey` — SecretManagement + env fallback)
- ✅ `extra.ps1` pattern — uživatelské přizpůsobení mimo Git
- ✅ AGENTS.md + CLAUDE.md v kořeni repozitáře
- ✅ GitHub Pages portál (kořenová URL `martinpaprcka77.github.io`)
- ✅ AI Prompts stránka — 8 modelů, 5 typů úloh
- ✅ Gisty (install, cheatsheet, master-prompt)

---

## Fáze 2: 2026 vylepšení (✅ hotovo)

- ✅ **Cascadia Code Nerd Font auto-installer** — `deps.ps1` stahuje a instaluje
- ✅ **`deps.ps1`** — winget auto-installer (Git, PS7, WT, VS Code, Starship, zoxide)
- ✅ **`windows.ps1`** — Windows defaults (Explorer, taskbar, privacy, bloatware)
- ✅ **WT JSON fragment** — nahrazuje staré editování settings.json
- ✅ **Shell integration** — OSC 133 markery, scrollbar marks, exit code coloring
- ✅ **VS Code integrace** — `.vscode/settings.json`, `tasks.json`, `agent-instructions.md`
- ✅ **`precheck.ps1`** — 30+ inventory kontrol před instalací
- ✅ **`configure.ps1`** — 5-step interaktivní wizard
- ✅ **zoxide** — smart directory jumper (náhrada za `z.ps1`)
- ✅ **wtprofile.ps1** — CTT-inspired Windows Terminal enhanced profile
- ✅ **core/perf.ps1** — Measure-Profile, Clear-PSCache, Optimize-ModuleLoading, Get-ProfileSize
- ✅ **core/status.ps1** — globální health dashboard (6 sekcí, 20+ kontrol)
- ✅ **core/extra.ps1.example** — šablona pro uživatelské přizpůsobení
- ✅ Konfigurační vrstva — `config.ps1` (defaults → JSON → $env:TOOLKIT_*)
- ✅ **7 barevných WT schémat** z windowsterminalthemes.dev

---

## Fáze 3: Rozšíření (🟡 rozšiřováno)

- [ ] **Live dashboard** — real-time CPU/RAM/Disk monitoring
- [ ] **Síťová diagnostika** — `Test-NetConnection` na klíčové endpointy
- [ ] **Více Docker příkazů** — `docker compose`, network management
- [ ] **Transient prompt** — kolaps promptu po provedení příkazu (Starship)
- ✅ **PSResourceGet migration** — `modernize.ps1` zvládá kompletní migraci
- ✅ **AddToHistoryHandler** — vlastní PSReadLine history filter (v `wtprofile.ps1`, blokuje API klíče, tokeny, hesla)

---

## Fáze 4: Integrace (🟢)

- ✅ **WSL profily** — automatická detekce ve WT fragmentu (`Add-WTProfiles.ps1`)
- ✅ **Git hooks** — post-checkout, post-merge skripty (`toolkit/githooks/`)
- [x] **CI/CD** — GitHub Actions pro Pester testy, validaci JSON (`.github/workflows/test.yml`,
  scoped na `toolkit/**` + `profile/**`)
- [ ] **PowerShell Gallery** — publikovat Toolkit modul
- ✅ **Komunitní příspěvky** — šablona pro issues a pull requests (`.github/`)

---

## Fáze 5: Ekosystém (✅ klíčová položka hotovo)

- ✅ **Web bootstrap** — `irm <url> | iex` jednopříkazová instalace (`remote-install.ps1`) — stále
  vyžaduje Git (klonuje repo); plně gitless varianta (stažení ZIP místo klonu) zůstává otevřená
  jako budoucí vylepšení
- ✅ **Sloučení do jednoho repa** — `dotfiles-powershell` + `dotfiles-tools` sloučeny do
  `martinpaprcka77.github.io` (`profile/` + `toolkit/` podadresáře). Odstranilo to cross-repo
  coupling (menu volající funkce, které existovaly jen v druhém repu) a zjednodušilo bootstrapper
  na jeden clone. Portál zůstává na kořenové URL (sloučeno do repa, ne vytvořen nový).
  Staré repozitáře (`dotfiles-powershell`, `dotfiles-tools`) zůstávají na GitHubu s README
  odkazem na nové umístění — žádný nástroj na archivaci repa nebyl v tomto prostředí k dispozici,
  takže "archivace" znamená jen odkaz, ne skutečné uzamčení repozitáře.
- ✅ **Unifikace ostatních dotfiles** — `git/` (globální gitignore + Claude nastavení) a `chezmoi/`
  (`chezmoi.toml`) absorbovány do monorepa jako `git/` a `chezmoi/` podadresáře. `install.ps1`
  vytváří directory junctions na `~/.config/git` a `~/.config/chezmoi`, takže nástroje (git,
  chezmoi) nadále nacházejí své konfigurace na původních cestách.
- [ ] **Instalační skript pro Windows** — kompletní setup z čisté instalace
- [ ] **Dokumentační web** — statický web generovaný z Markdown dokumentace
- [ ] **Možné budoucí rozdělení zpět na 2 repa** — pokud ekosystém naroste natolik, že si zaslouží
  nezávislé release cykly, je to zdokumentovaná možnost, ne plán. Zatím zůstává jeden repo.

---

## Známé problémy

| Problém | Stav | Plán |
|---------|------|------|
| `Add-WTProfiles.ps1` vyžaduje Windows Terminal | ✅ Vyřešeno | Guard na `$IsLinux -or $IsMacOS` |
| `Add-WTProfiles.ps1` — parse error, skript se vůbec nespustil | ✅ Vyřešeno | Loose statements uvnitř `@{ }` literálu přesunuty ven |
| `Generate-Icons.ps1` vyžaduje .NET Framework | ✅ Vyřešeno | `$IsWindows` guard |
| `deps.ps1` + `windows.ps1` — Windows-only | ✅ Vyřešeno | Platform guardy |
| `windows.ps1 -WhatIf` přesto restartoval Explorer | ✅ Vyřešeno | Prompt respektuje `$WhatIfPreference` |
| `gcm`/`gps` git zkratky nikdy nefungovaly (tiché stínění vestavěnými PS aliasy) | ✅ Vyřešeno | `Remove-Item Alias:` před definicí funkce |
| `checkers.ps1`/`common.ps1` bez platform guardu — pád na Linuxu/macOS | ✅ Vyřešeno | `$isWindowsHost` guard |
| `Reset-PSModulePath` vracel `Documents\...` — přesně OneDrive-postiženou cestu | ✅ Vyřešeno | `$env:LOCALAPPDATA\...\Modules` místo Documents |
| 7 PSModulePath Pester testů selhávalo na Linuxu/macOS | ✅ Vyřešeno | Testovací fixtures používaly `C:\Mods\...` — dvojtečka kolidovala s `[IO.Path]::PathSeparator` (`:` na Linuxu/macOS, `;` na Windows); fixtures teď volí `C:\Mods\...` na Windows a `/Mods/...` jinde, 75/75 testů prochází na obou platformách |
| Menu skripty padaly na `$null` `$env:DOTFILES_TOOLS`, pokud menu běželo bez načteného profilu | ✅ Vyřešeno (field-reported) | Fallback `$toolsRoot = if ($env:DOTFILES_TOOLS) {...} else { Split-Path $PSScriptRoot -Parent }` |
| `Show-Menu` box se rozbil (přetekl přes hranici konzole), když `Detector` vrátil dlouhý text | ✅ Vyřešeno (field-reported) | `$boxWidth` ořezán na `[Console]::WindowWidth`, `Desc`/`Detector` text zkrácen s výpustkou (`…`) |
| `Resolve-DocumentsPath` padal na poškozené Known Folder registrové hodnotě | ✅ Vyřešeno (field-reported) | `Test-RootedPath` validuje každého kandidáta před použitím |
| Cross-repo coupling — menu volalo funkce existující jen v druhém repu | ✅ Vyřešeno sloučením | Jeden repo, `profile/` + `toolkit/`; zbylé self-referenční lookupy používají `$PSScriptRoot` |
| Windows PowerShell 5.1 (`powershell.exe`, ne `pwsh`) padal na parse error ve skriptech s pomlčkou/emoji (`—`, `✅`…) | ✅ Vyřešeno (field-reported) | Bez UTF-8 BOM čte WinPS 5.1 soubor v systémové ANSI codepage — víceb bajtový UTF-8 znak se rozpadne na nesmyslné bajty a rozhodí tokenizer. Všech 45 `.ps1`/`.psm1`/`.psd1` souborů teď má UTF-8 BOM |
| `remote-install.ps1` u existující instalace ze starého (pre-merge) repa jen tiše `git pull`-oval ve starém originu — instalátor zůstal navždy stará dvourepová verze | ✅ Vyřešeno (field-reported) | Detekce `git remote get-url origin` proti novému URL; při neshodě `git remote set-url` + `git fetch` + `git reset --hard origin/main` místo prostého pull |
| Cesty s diakritikou nejsou testovány | Netestováno | Přidat testy |
| PS5 nepodporuje `&&` a `||` | Omezení PS5 | Používat `;` nebo `if` |

---

## Jak přispět

1. Fork repozitáře
2. Vytvoř branch (`feature/muj-nastroj`)
3. Přidej testy do `toolkit/tests/`
4. Aktualizuj `docs/MANUAL.md` a `README.md`
5. Otevři Pull Request

Pravidla:
- Všechny skripty musí mít comment-based help
- Idempotentní operace kde to dává smysl
- Respektovat výkon profilu (žádné pomalé importy)
- Cross-platform guardy (`$IsWindows` / `$IsLinux`)
