# Roadmap

Plánované funkce a směr vývoje. Priority: 🔴 vysoká · 🟡 střední · 🟢 nízká · ✅ hotovo

---

## Fáze 1: Základ (✅ hotovo)

- ✅ Modulární PowerShell profil (`profile/`)
- ✅ Idempotentní instalátor (`install.ps1` — WhatIf, Force, backup, summary)
- ✅ Update mechanism (`update.ps1` — git fetch + reload + bootstrap self-heal)
- ✅ Toolkit modul — **36 exportovaných funkcí**
- ✅ Interaktivní menu — 7 submenu (Startup, Dotfiles, Git, Terminal, PowerShell, VS Code) + přímá systémová diagnostika
- ✅ Moderní menu engine — šipky ↑↓, zvýraznění, popisky, inline režim, ořez na šířku konzole
- ✅ Arrow-key menu s popisky u každé položky
- ✅ Živá detekce stavu přímo v menu (`Detector` na položku — modul stack, PSModulePath, dostupnost
  companion profilu) — bez nutnosti spouštět samostatný diagnostický příkaz
- ✅ Jednopříkazový vzdálený bootstrapper (`remote-install.ps1`, `irm | iex`), Known-Folder-korektní
  detekce cest (funguje i s přesměrovaným OneDrive Documents, i s poškozenou Known Folder
  registrovou hodnotou)
- ✅ CRUD operace na všech menu (Check, Backup, Restore, Reset, Clean)
- ✅ Systémová diagnostika (disky, služby, síť, procesy)
- ✅ Starship prompt (Rust) s `starship.toml` konfigurací (30+ modulů)
- ✅ oh-my-posh jako fallback
- ✅ 73 Pester testů (70 modul/chování + 3 repo invarianty; full coverage včetně smoke testů)
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
- ✅ **Shell integration** — OSC 133 markery, scrollbar marks, exit code coloring
- ✅ **VS Code integrace** — `.vscode/settings.json`, `tasks.json`, `agent-instructions.md`
- ✅ **`precheck.ps1`** — 30+ inventory kontrol před instalací
- ✅ **`configure.ps1`** — 5-step interaktivní wizard
- ✅ **zoxide** — smart directory jumper (náhrada za `z.ps1`)
- ✅ **wtprofile.ps1** — CTT-inspired Windows Terminal enhanced profile
- ✅ **core/perf.ps1** — Measure-Profile, Clear-PSCache, Optimize-ModuleLoading, Get-ProfileSize
- ✅ **core/status.ps1** — globální health dashboard (6 sekcí, 20+ kontrol)
- ✅ **core/extra.ps1.example** — šablona pro uživatelské přizpůsobení
- ✅ Konfigurační vrstva — `Configuration.ps1` (defaults → JSON → $env:TOOLKIT_*)
- ✅ **7 barevných WT schémat** z windowsterminalthemes.dev

---

## Fáze 3: Rozšíření (🟡 rozšiřováno)

- ✅ **Systémový přehled** — `Get-SystemSummary` (jednorázový snapshot OS/CPU/RAM/uptime); plný real-time dashboard nahrazen snapshottem
- ✅ **Síťová diagnostika** — `Test-NetworkEndpoint` (TCP 443 + latence; jediná síťová funkce, mimo local-only Diagnostics)
- ❌ **Transient prompt** — **NEDOSTUPNÉ**: transient/collapsing prompt je funkce oh-my-posh,
  ne Starshipu. Dřívější blok `[transient_prompt]` ve `profile/starship.toml` byl neplatný klíč —
  Starship ho odmítá a při každé inicializaci promptu hlásil
  `[WARN] (starship::config): Error in 'StarshipRoot' at 'transient_prompt': Unknown key`
  (nikoli „tiše ignorováno“, jak tvrdil komentář v souboru). Ověřeno na starship 1.26.0: klíč
  chybí v `starship print-config --default` a `print-config` ho zahodí; A/B test na kopii
  `profile/` potvrdil kauzalitu (s blokem WARN, bez bloku ticho). Blok odstraněn, `[line_break]`
  ponechán. Transient prompt tedy zůstává jen na fallback větvi oh-my-posh
  (`profile/ps7/profile.ps1`).
- ✅ **PSResourceGet migration** — `modernize.ps1` zvládá kompletní migraci
- ✅ **AddToHistoryHandler** — vlastní PSReadLine history filter (v `wtprofile.ps1`, blokuje API klíče, tokeny, hesla)

---

## Fáze 4: Integrace (🟢)

- ✅ **Git hooks** — post-checkout, post-merge skripty (`toolkit/githooks/`)
- [x] **CI/CD** — GitHub Actions pro Pester testy, PSScriptAnalyzer lint (Error severity blokuje,
  Warning jen reportuje), validaci JSON (`.github/workflows/test.yml`, scoped na `toolkit/**` +
  `profile/**` + kořenové `*.ps1` + `PSScriptAnalyzerSettings.psd1` — dřívější scope kořenové
  skripty jako `install.ps1` vůbec nepokrýval)
- ✅ **Sjednocený self-heal** — `Invoke-DotfilesRepair` (`profile/lib/repair.ps1`) skládá bootstrap +
  encoding + (Windows) PSModulePath kontrolu/reset do jednoho průchodu, volaného z `install.ps1`
  (preflight) a `update.ps1` (při každém běhu, ne jen po pullu — drift PSModulePath nebo chybějící
  BOM může existovat i na aktuálním commitu)
- ✅ **Manifest hygiene** — `Toolkit.psd1`: reálný `Author`, `CompatiblePSEditions`, verze 1.1.0;
  `#Requires -Version 5.1` na všech reálných entry-pointech (`install.ps1`, `update.ps1`,
  `toolkit/bin/*.ps1`); `Remove-PSModulePath`/`Reset-PSModulePath` získaly `SupportsShouldProcess`
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
- ✅ **Instalační skript pro Windows** — `install.ps1` + `Setup-Windows.ps1` (setup z čisté instalace)
- ✅ **Dokumentační web** — statický web (`index.html`, `charts.html`, `prompts.html`) nad Markdown dokumentací
- [ ] **Možné budoucí rozdělení zpět na 2 repa** — pokud ekosystém naroste natolik, že si zaslouží
  nezávislé release cykly, je to zdokumentovaná možnost, ne plán. Zatím zůstává jeden repo.

---

## Známé problémy

| Problém | Stav | Plán |
|---------|------|------|
| `deps.ps1` + `windows.ps1` — Windows-only | ✅ Vyřešeno | Platform guardy |
| `windows.ps1 -WhatIf` přesto restartoval Explorer | ✅ Vyřešeno | Prompt respektuje `$WhatIfPreference` |
| `gcm`/`gps` git zkratky nikdy nefungovaly (tiché stínění vestavěnými PS aliasy) | ✅ Vyřešeno | `Remove-Item Alias:` před definicí funkce |
| `Diagnostics.ps1`/`Console.ps1` bez platform guardu — pád na Linuxu/macOS | ✅ Vyřešeno | `$isWindowsHost` guard (řádek dřív odkazoval na `checkers.ps1`/`common.ps1` — jména z doby před přejmenováním na `Toolkit/Public/*.ps1`) |
| `Reset-PSModulePath` vracel `Documents\...` — přesně OneDrive-postiženou cestu | ✅ Vyřešeno | `$env:LOCALAPPDATA\...\Modules` místo Documents |
| 7 PSModulePath Pester testů selhávalo na Linuxu/macOS | ✅ Vyřešeno | Testovací fixtures používaly `C:\Mods\...` — dvojtečka kolidovala s `[IO.Path]::PathSeparator` (`:` na Linuxu/macOS, `;` na Windows); fixtures teď volí `C:\Mods\...` na Windows a `/Mods/...` jinde. (Původní tvrzení „86/86 testů prochází na obou platformách“ bylo neověřené a nesouhlasilo s tehdejším stavem — aktuální číslo viz `toolkit/docs/20-reference.md`, které generuje `build/Generate-Docs.ps1`) |
| Menu skripty padaly na `$null` `$env:DOTFILES_TOOLS`, pokud menu běželo bez načteného profilu | ✅ Vyřešeno (field-reported) | Fallback `$toolsRoot = if ($env:DOTFILES_TOOLS) {...} else { Split-Path $PSScriptRoot -Parent }` |
| `Show-Menu` box se rozbil (přetekl přes hranici konzole), když `Detector` vrátil dlouhý text | ✅ Vyřešeno (field-reported) | `$boxWidth` ořezán na `[Console]::WindowWidth`, `Desc`/`Detector` text zkrácen s výpustkou (`…`) |
| `Resolve-DocumentsPath` padal na poškozené Known Folder registrové hodnotě | ✅ Vyřešeno (field-reported) | `Test-RootedPath` validuje každého kandidáta před použitím |
| Cross-repo coupling — menu volalo funkce existující jen v druhém repu | ✅ Vyřešeno sloučením | Jeden repo, `profile/` + `toolkit/`; zbylé self-referenční lookupy používají `$PSScriptRoot` |
| Windows PowerShell 5.1 (`powershell.exe`, ne `pwsh`) padal na parse error ve skriptech s pomlčkou/emoji (`—`, `✅`…) | ✅ Vyřešeno (field-reported) | Bez UTF-8 BOM čte WinPS 5.1 soubor v systémové ANSI codepage — víceb bajtový UTF-8 znak se rozpadne na nesmyslné bajty a rozhodí tokenizer. Všech 59 souborů s ne-ASCII obsahem BOM má; zbylé 3 čistě ASCII soubory (`toolkit/build/Build.ps1`, `toolkit/build/Test.ps1`, `tools/devmenu/devmenu.ps1`) ho nepotřebují. **Audit 3:** tvrzení „všech 45 souborů“ bylo nepravdivé — repo má 62 `.ps1`/`.psm1`/`.psd1` souborů a `Toolkit/Public/Output.ps1`, `Toolkit/Public/ShellInfo.ps1` i `Toolkit/Toolkit.psd1` BOM neměly (hlásil je `PSUseBOMForUnicodeEncodedFile`); doplněno spuštěním `Repair-FileEncoding`, které je idempotentní — opakovaný běh hlásí 0 oprav |
| `remote-install.ps1` u existující instalace ze starého (pre-merge) repa jen tiše `git pull`-oval ve starém originu — instalátor zůstal navždy stará dvourepová verze | ✅ Vyřešeno (field-reported) | Detekce `git remote get-url origin` proti novému URL; při neshodě `git remote set-url` + `git fetch` + `git reset --hard origin/main` místo prostého pull |
| `profile.ps1`/`remote-install.ps1` špatně detekovaly Windows na PS5.1 (`$PSVersionTable.OS -match 'Windows'` je `$null` → `$false` na 5.1) — PSModulePath OneDrive-fix se tiše přeskočil | ✅ Vyřešeno (audit) | `$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }` ve všech třech instalátorech i profilu |
| `Save-ToolkitConfig` přepisoval verzovaný `config/settings.json` → `configure` zašpinil strom → další `update.ps1`/`remote-install` (`git pull --ff-only` / `reset --hard`) selhal nebo tiše zahodil konfiguraci | ✅ Vyřešeno (audit) — **opraveno až v auditu 2** | `settings.json` je gitignored lokální soubor; shipuje se `settings.example.json` jako šablona; `Get-ToolkitConfig` bez souboru použije hardcoded defaults. **Audit 2:** řádek výše tvrdil „vyřešeno“, ale `toolkit/config/settings.json` byl v gitu stále verzovaný a `settings.example.json` vůbec neexistoval — tedy ani jeden krok opravy nebyl nasazen a `configure.ps1` (→ `Save-ToolkitConfig`) strom skutečně zašpiňoval. Nyní: soubor odverzován (`git rm --cached`) + přidán do `toolkit/.gitignore` (i `settings.json.backup`), založen `toolkit/config/settings.example.json` s obsahem shodným s hardcoded defaults (čerstvý klon se tedy chová stejně), a invariantní test v `toolkit/tests/Toolkit.Tests.ps1` tuto dvojici hlídá |
| `rp` alias se na Windows PowerShell 5.1 nepodařilo nastavit — `Set-Alias -Force` vyhodil „The AllScope option cannot be removed from the alias 'rp'“ při každém načtení profilu | ✅ Vyřešeno (audit 2) | `rp` je na 5.1 vestavěný alias s `Options=ReadOnly,AllScope` (na PS7 AllScope není, proto se chyba projevila jen na 5.1). `Remove-Item Alias:rp -Force` před definicí — stejný vzor, jaký soubor už používal pro `gcm`/`gps` |
| 3-argumentové `Join-Path` (pozice `-AdditionalChildPath`, jen PS 6+) rozbíjelo skripty na Windows PowerShell 5.1 — „A positional parameter cannot be found that accepts argument 'Toolkit.psd1'“ | ✅ Vyřešeno (audit 2) | Skutečně padalo `toolkit/build/Build.ps1` a `Setup-Windows.ps1` (oba dosažitelné z 5.1). Přepsáno na vnořený 2-argumentový tvar (styl, který repo už používal jinde) v `build/{Build,Generate-Docs,Test}.ps1`, `ops/Get-PowerShellStartupHealth.ps1`, `Setup-Windows.ps1`; invariantní test v Pester suite to hlídá repo-wide a hned zachytil jeden výskyt v nově přeneseném `tools/devmenu/devmenu.ps1` |
| `toolkit/ops/modernize.ps1 -WhatIf` přesto zapsal `POWERSHELL_TELEMETRY_OPTOUT=1` do **User** prostředí (trvalá změna) — volání `[System.Environment]::SetEnvironmentVariable` nebylo za `ShouldProcess` | ✅ Vyřešeno (audit 2) | Stejná třída chyby, jakou repo už evidovalo u `windows.ps1 -WhatIf`. Zápis obalen `$PSCmdlet.ShouldProcess(...)`; `-WhatIf` teď hlásí `What if: … POWERSHELL_TELEMETRY_OPTOUT` |
| `tools/Validate-Links.ps1` se nikdy nespustil — `[CmdletBinding()]` + vlastní `[switch]$Verbose` → `MetadataError: A parameter with the name 'Verbose' was defined multiple times`; po opravě spadl i na posledním řádku `exit if ($issues) { 1 } else { 0 }` (`The term 'if' is not recognized…`) | ✅ Vyřešeno (audit 2) | `-Verbose` je common parametr od `CmdletBinding` — vlastní deklarace odstraněna, čtení přes `$VerbosePreference`; `exit` nahrazen `if ($issues) { exit 1 } else { exit 0 }`. **Audit 3 dokončil opravu:** `$link = $m.Groups[1].Value -or $m.Groups[2].Value` — v PowerShellu je `-or` boolean, ne null-coalescing, takže `$link` byl vždy `$true` a každý odkaz se pak testoval jako literál `True` (report hlásil „Broken link: True“ pro celý repo). Heuristika „undefined function“ přepsána na AST: definice funkcí napříč repem (obě formy — `function X {` i `function X(...)`), jména testovaná v repu přes `Get-Command <name>` a commandy deklarované dostupnými moduly, takže builtin cmdlety ani dot-sourcované helpery se už nehlásí. Odkazy se řeší relativně ke svému souboru (s fallbackem na root) a skenuje se rekurzivně (91 souborů místo 12). Výsledek: 327 valid / 0 issues / `exit 0`. **Zůstává mimo CI** — heuristika závisí na nainstalovaných modulech (na stroji bez PSFzf se `Set-PsFzfOption` legitimně jeví jako nedefinovaný) |
| Dokumentace tvrdila 69 Pester testů / 33 exportovaných funkcí a odkazovala na neexistující soubory (`config.ps1`, `checkers.ps1`, `common.ps1`, `toolkit/menu/menu-*.ps1`, `configs/settings.json`) | ✅ Vyřešeno (audit 2) | Čísla i cesty srovnány se skutečností v `AGENTS.md` a tomto souboru; `toolkit/docs/20-reference.md` je generovaný (`build/Generate-Docs.ps1`) a byl zastaralý (tvrdil 69 testů / 68 pass / 1 fail) — regenerován |
| `remote-install.ps1` migrace se spouštěla na JAKÉKOLI neshodě originu — SSH klon (`git@…`) i fork se hard-resetoval | ✅ Vyřešeno (audit) | Migrace jen když origin odpovídá `dotfiles-powershell\|dotfiles-tools` (skutečný pre-merge případ) |
| `Show-Menu` řadil položky `Sort-Object` → menu s 10+ položkami se zobrazilo 1,10,11,2,3… | ✅ Vyřešeno (audit) | Zachová se pořadí vložení (`[ordered]` klíče), žádné `Sort-Object` |
| Přímé spuštění `menu-*.ps1` (WT profil „Menu") padalo — `Initialize-MenuMenu` bylo definované uvnitř modulu, který ještě nebyl načtený | ✅ Vyřešeno (audit) | Guard v každém `Toolkit/Public/Menu/menu-*.ps1` inline `Import-Module` + volání; `Initialize-MenuMenu` odstraněna (export 38 → 37, později → 36) |
| `Repair-FileEncoding` chyběl jako runtime pojistka (BOM se opravoval jen ručně) | ✅ Vyřešeno (audit) | `profile/lib/encoding.ps1` — idempotentní, volaný z `install.ps1` i `update.ps1` |
| ~~`config.ps1` četl `configs\settings.json` → na Linuxu/macOS literální jméno souboru~~ — **korekce**: empiricky ověřeno, že `Join-Path` normalizuje `\` na platformní oddělovač i na Linuxu/macOS, takže původní tvar nebyl rozbitý; nešlo o skutečný bug | N/A (falešný nález) | Vnořený `Join-Path (Join-Path $toolsRoot 'config') 'settings.json'` zůstal — odpovídá stylu zbytku repa, ale je to kosmetika, ne oprava (soubor se dnes jmenuje `Toolkit/Public/Configuration.ps1`) |
| `Test-PathHealth` (`core/status.ps1`) — chybějící `if ($isWindowsHost) {` způsobovala parse error celého souboru (nesouhlas počtu závorek), takže `Show-Status` se nikdy nenačetl a menu trvale hlásilo „not loaded" i po správné instalaci | ✅ Vyřešeno (audit) | Chybějící `if` blok obnoven kolem User/Machine PATH overlap kontroly |
| `toolkit/ops/Generate-Icons.ps1` ignoroval `-WhatIf` — skript měl jen `param()` bez `CmdletBinding`, takže `-WhatIf` spadl do `$args` a skript přesto přepsal všechny tři PNG (exit 0, bez varování); navíc `if (-not $IsWindows)` bez verzového guardu → na Windows PowerShell 5.1 mylně hlásil „requires Windows (System.Drawing)“ | ✅ Vyřešeno (audit 3) | `[CmdletBinding(SupportsShouldProcess)]` + `ShouldProcess` u každé ikony (a poctivé hlášení „Žádné ikony nebyly vygenerovány (-WhatIf)“), `$isWindowsHost` verzový guard. Ověřeno: `-WhatIf` nemění mtime souborů, reálný běh generuje, a na 5.1 skript nově projde |
| `toolkit/ops/precheck.ps1` volal `Get-AppxPackage` bez guardu — v pwsh 7 ten cmdlet neexistuje (modul Appx je jen ve Windows PowerShellu), takže se do reportu vypsala červená chyba a WT se hlásil jako nenainstalovaný, přestože hned další kontrola WT našla přes jeho `settings.json` | ✅ Vyřešeno (audit 3) | `Get-Command Get-AppxPackage` + fallback na MSIX package directory / `wt.exe` |
| `toolkit/ops/precheck.ps1` kontroloval `~/.config/powershell/profile.ps1`, který v monorepu neexistuje (hlavní orchestrátor je `profile/profile.ps1`), a odkazoval na dávno smazaný repo `dotfiles-powershell` → trvalý `FAIL` s matoucí radou | ✅ Vyřešeno (audit 3) | Cesta opravena na `.../powershell/profile/profile.ps1` (shodná s tím, co injektuje `bootstrap.ps1`), text rady přepsán |
| `profile/hosts/ConsoleHost.ps1` — uvítací box měl řádky široké 37/26/34 znaků proti 26znakové hranici (padding se aplikoval před připojením labelu „PowerShell “/„Uptime: “) → rozjetý pravý okraj | ✅ Vyřešeno (audit 3) | Buňky se skládají nejdřív a `$maxLen` se počítá z nejdelší z nich; všech 5 řádků má stejnou šířku (ověřeno na PS7 i 5.1) |
| `Show-Status` volal `Test-HintShown`/`Show-Hint`, které nebyly nikdy a nikde implementované (ani v legacy repech) → červená chyba `The term 'Test-HintShown' is not recognized` při každém spuštění dashboardu | ✅ Vyřešeno (audit 3) | Doplněny `Test-HintShown`/`Show-Hint`/`Get-HintStateDir` do `profile/core/functions.ps1`; značka „už zobrazeno“ žije mimo repo (`%LOCALAPPDATA%\dotfiles-powershell\hints`, jinde `$HOME/.local/state/...`), aby nešpinila pracovní strom |
| `toolkit/ops/{Add-WTProfiles,deps,windows}.ps1` — `if (-not $IsWindows)` bez verzového guardu → na Windows PowerShell 5.1 (což *je* Windows) skript mylně skončil s „requires Windows“ | ✅ Vyřešeno (audit 3) | `$isWindowsHost` verzový guard (stejný idiom jako `install.ps1`/`profile.ps1`); u `windows.ps1` je to obzvlášť pikantní — 5.1 je jediný host, kde Appx vůbec existuje |
| `toolkit/ops/windows.ps1 -RemoveBloatware` — `Get-AppxPackage`/`Remove-AppxPackage` bez guardu na dostupnost: na pwsh 7 vypsal 27× červené „not recognized“ a všech 27 balíčků ohlásil jako „Not installed“ | ✅ Vyřešeno (audit 3) | `$appxAvailable` z `Get-Command Get-AppxPackage`/`Remove-AppxPackage`; bez Appx se sekce přeskočí s jasnou zprávou |
| `toolkit/Toolkit/Public/Diagnostics.ps1` — `Get-NetworkInfo` spoléhal na `Get-NetIPAddress` z modulu NetTCPIP, který v PowerShellu 7 není na `PSModulePath` → volání vždy skončilo v `catch` s matoucím hlášením | ✅ Vyřešeno (audit 3) | `Get-Command Get-NetIPAddress` guard s výslovnou zprávou, že jde o modul dostupný jen ve Windows PowerShellu |
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
