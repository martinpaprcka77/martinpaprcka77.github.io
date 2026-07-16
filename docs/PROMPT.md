# Prompty

Tento soubor uchovává prompty, ze kterých byla (a může být znovu) vygenerována celá kódová
základna. Slouží pro:
- **Reprodukovatelnost** — stejný prompt lze poslat jinému modelu a získat podobný výsledek.
- **Dokumentaci záměru** — zachycuje kompletní specifikaci v jednom souboru.
- **Iteraci** — při úpravách je vidět, co se změnilo oproti původnímu zadání.

Jsou zde dvě verze:
- **Aktuální prompt (jeden repozitář)** — regeneruje projekt v jeho *současné* podobě
  (`profile/` + `toolkit/` v jednom repu). Tohle použij, když chceš projekt znovu vytvořit
  nebo upravit.
- **Historický původní prompt (dva repozitáře)** — zadával vytvoření *dvou* repozitářů
  (`dotfiles-powershell` + `dotfiles-tools`), které byly později sloučeny. Zachován v původním
  znění jako historický záznam, **ne** jako aktuální specifikace struktury.

---

## Aktuální prompt — jeden repozitář

> Pošli tenhle prompt Claude, DeepSeek, GPT-4 nebo Reasonix pro regeneraci nebo úpravu celého
> projektu.

```
Jsi expert na PowerShell, správu dotfiles a Windows Terminal.
Vytvoř **kompletní a spustitelný** projekt, který realizuje následující zadání.
Generuj všechny soubory jako samostatné kódové bloky s uvedenou relativní cestou
od uživatelského adresáře (%USERPROFILE% resp. $HOME). Struktura musí být připravena
k okamžitému použití po naklonování do **jednoho** Git repozitáře.

## 1. Cíl
Vytvořit osobní PowerShell ekosystém, který:
- obchází OneDrive (profily i moduly),
- je plně verzovaný (Git),
- přenositelný mezi stroji (Windows, částečně Linux),
- obsahuje modulární profil, nástrojový toolbox a automatické nastavení Windows Terminálu,
- je v **jednom repozitáři** (dřív dva — sloučeny kvůli cross-repo coupling, viz níže).

## 2. Výsledný repozitář
Jeden repozitář, umístění: `~/.config/powershell/`, se dvěma podadresáři:
- `profile/` — orchestrace profilu
- `toolkit/` — interaktivní toolbox

## 3. Detailní požadavky

### A) Kořen repozitáře

#### install.ps1 — idempotentní instalátor
- WhatIf, Force, NoUpdates, NoTerminal parametry
- try/catch na git operace, preflight kontrola gitu na PATH
- Jediný self `git pull` (repo obsahuje install.ps1 sám v sobě — žádné klonování druhého repa)
- Zálohuje existující profily před změnou
- Vloží bootstrap do 4 profilových cest (Known-Folder-korektní, viz `profile/lib/paths.ps1`) přes
  sdílenou funkci `Invoke-BootstrapInjection` (viz `profile/lib/bootstrap.ps1`)
- Nastaví trvalou PATH (`toolkit/bin`)
- Shrnutí na konci

#### remote-install.ps1 — jednopříkazový bootstrapper
- Bezpečný přes `irm <url> | iex` — **bez** `SupportsShouldProcess` (`$PSCmdlet` je `$null`
  pod `Invoke-Expression`, i s `[CmdletBinding(SupportsShouldProcess)]`)
- Samostatný (inline Write-Step/Ok/Skip/Fail/Warn — nemůže dot-sourcovat `lib/output.ps1`,
  to je uvnitř repa, které teprve stahuje)
- Klonuje/aktualizuje sám sebe (jeden repo), pak předá řízení `install.ps1`
- Migrace ze starého repa: pokud už `~/.config/powershell` existuje, ale jeho `origin` míří na
  starý (pre-merge) repozitář, prostý `git pull` jen fast-forwarduje ve zmrazené historii toho
  starého repa — proto detekuj neshodu URL (`git remote get-url origin`) a udělej
  `git remote set-url` + `git fetch` + `git reset --hard origin/main` místo prostého pull
- Přepínače přes env proměnné: `$env:DOTFILES_FORCE`, `$env:DOTFILES_NO_UPDATES`,
  `$env:DOTFILES_NO_TERMINAL`

#### update.ps1
- git fetch + rev-list kontrola nových commitů
- ff-only pull
- Volá `Invoke-BootstrapInjection` (bez -Force) po každém pullu — **self-heal**: pokud bootstrap
  ukazuje na starou/neplatnou cestu, opraví se automaticky, uživatel nemusí vědět, že má znovu
  spustit install.ps1

### B) profile/ — profilová orchestrace

#### profile/profile.ps1 — hlavní orchestrátor
- Detekuje jednou na začátku: `$isPSCore` (PSVersion.Major -ge 6), `$isWindowsHost`
  (`$IsWindows` na PS7+, vždy `$true` na PS5.1 — tam `$IsWindows` neexistuje)
- Nastaví `$env:DOTFILES_PWSH` (= `profile/`), odvodí `$env:DOTFILES_TOOLS` jako sourozenecký
  adresář `toolkit/` (vždy v souladu — nemůže se rozejít jako dřív dva nezávislé env vary)
- Opraví `PSModulePath` na **PS5.1 i PS7** (LOCALAPPDATA, nikdy Documents — to je právě
  OneDrive-postižená cesta)
- Dot-sourcuje: `lib/paths.ps1` → `core/*.ps1` → `ps5/` nebo `ps7/` → `hosts/ConsoleHost` nebo `hosts/VSCode`
- Volitelně zobrazí dobu načtení (`$env:PROFILE_BENCHMARK`)

#### profile/lib/paths.ps1 — Known-Folder-korektní cesty
- `Resolve-DocumentsPath`: reálná cesta k Documents i při přesměrování OneDrive — odvozeno z
  `$PROFILE.CurrentUserAllHosts` (engine to už řeší správně), fallback na `[Environment]::
  GetFolderPath` a registry
- `Test-RootedPath`: validuje KAŽDÉHO kandidáta (drive-letter/UNC prefix, žádné zbytkové `%...%`)
  před použitím — reálný field-report: poškozená Known Folder registrová hodnota
  (`%C:\Users\x%\Documents`) přežila `ExpandEnvironmentVariables` beze změny a shodila `Join-Path`
- `Get-NativeProfilePaths`: 4 nativní `$PROFILE` cesty pro injekci bootstrapu

#### profile/lib/bootstrap.ps1
- `Invoke-BootstrapInjection` — sdílená mezi install.ps1/update.ps1, kontroluje OBSAH (ne jen
  přítomnost markeru) — stará/neplatná cesta se opraví i bez -Force

#### profile/core/aliases.ps1
- Git: g, gst, gco, gbr, gcm, gpl, gps, gdf, glo — POZOR: `gcm`/`gps` kolidují s vestavěnými
  aliasy (`Get-Command`/`Get-Process`); vestavěný alias tiše vyhrává nad stejnojmennou funkcí,
  proto nejdřív `Remove-Item Alias:gcm -Force -ErrorAction SilentlyContinue` (a totéž pro `gps`)
- Docker: dps, dpsa, dcu, dcd
- Kubernetes: k, kx, kns (pokud nainstalováno)
- Navigace: ll (Get-ChildItem)

#### profile/core/functions.ps1
- Edit-Profile, Reload-Profile, Get-SecretKey (SecretManagement vault + $env:VAR fallback),
  Test-Admin, mkcd

#### profile/core/env.ps1
- $env:EDITOR (code > nvim > vim > notepad)
- Přidá `toolkit/bin` do PATH (odvozeno z $env:DOTFILES_TOOLS)

#### profile/ps5/profile.ps1
- PSReadLine v2, UTF-8 kódování

#### profile/ps7/profile.ps1
- PSReadLine v3, Terminal-Icons, oh-my-posh, PSFzf (vše podmíněně, pokud nainstalováno)

#### profile/hosts/
- ConsoleHost.ps1: titulek okna, uvítání s uptimem
- VSCode.ps1: potlačení uvítání, UTF-8, TERM=vscode

### C) toolkit/ — interaktivní toolbox

#### toolkit/bin/
- `menu.ps1`: Import-Module Toolkit → Start-MainMenu
- `check.ps1`: Import-Module Toolkit → Invoke-SystemCheck

#### toolkit/lib/menu.ps1
- Show-Menu — TUI engine: minimalistický bezrámečkový seznam (titulek + tenká akcentová linka +
  sloupcově zarovnané položky, aktivní řádek značen barevným `›` kurzorem, žádný inverzní blok),
  navigace šipkami (`[Console]::ReadKey`), číselné zkratky fungují taky, volitelný `Detector`
  scriptblock na položku (živý stavový sloupec, vyhodnocen znovu při každém překreslení, cache
  function-local ne `$script:`). Pevná kotva `$menuTop` zachycená jednou před smyčkou, aby čistá
  navigace (šipky) nikdy neposunula seznam dolů; šířka ořezána na `[Console]::WindowWidth`,
  `Desc`/`Detector` text zkrácen s výpustkou (`…`), aby dlouhá zpráva nezalomila řádek

#### toolkit/lib/detectors.ps1
- `Get-ModuleStackStatus`, `Test-LegacyPowerShellGetPresent`, `Test-PSResourceGetReady`,
  `Get-DotfilesCompanionStatus` (graceful "⚠️ nenačteno" místo pádu, když toolkit běží
  samostatně bez profilu), `Get-ModulePathStatus`, `Invoke-IfAvailable`

#### toolkit/lib/checkers.ps1
- Get-DiskStatus, Get-ServiceStatus, Get-NetworkInfo, Get-TopProcesses, Invoke-SystemCheck
- Všechny funkce mají `$isWindowsHost` guard (pád na Linuxu/macOS bez něj)

#### toolkit/lib/config.ps1
- Get-ToolkitConfig (defaults → JSON → $env:TOOLKIT_* merge), Save-ToolkitConfig, Merge-Hashtable
- `$toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }`
  — self-referenční fallback, nikdy nepředpokládat, že env var je nastavená

#### toolkit/Toolkit/ (PowerShell modul)
- Toolkit.psd1: manifest s 36 FunctionsToExport
- Toolkit.psm1: dot-sourcuje lib/*.ps1 a menu/menu-*.ps1, Export-ModuleMember

#### toolkit/menu/
- menu-main.ps1, menu-docker.ps1, menu-git.ps1, menu-terminal.ps1, menu-dotfiles.ps1,
  menu-pwsh.ps1, menu-vscode.ps1 — každý self-referenční lookup uvnitř použije stejný
  `$toolsRoot` fallback jako lib/config.ps1 (field-reported crash: `Join-Path
  $env:DOTFILES_TOOLS ...` s `$null` env var, když menu běželo bez načteného profilu)

#### toolkit/scripts/
- Add-WTProfiles.ps1: **JSON fragment extension** (WT 1.24+), profily párované podle `name`
  (žádné GUID nikde), WhatIf, BOM-free zápis, platform guard, zálohuje existující fragment;
  vestavěné profily (PowerShell 7 / Windows PowerShell 5.1) aktualizuje jen o icon/tabTitle —
  **nikdy** implicitně o shell integration/colorScheme
- Generate-Icons.ps1: 32×32 PNG (System.Drawing), platform guard
- configure.ps1: 5-step interaktivní wizard
- modernize.ps1: PSResourceGet migrace, sdílí predikáty s lib/detectors.ps1

#### toolkit/tests/Toolkit.Tests.ps1
- 63 testů, Mock pokrytí (config, PSModulePath, menu chybové cesty). PSModulePath fixtures musí
  být platform-neutrální — `C:\Mods\...` na Windows, `/Mods/...` jinde (dvojtečka v drive-letter
  koliduje s `[IO.Path]::PathSeparator`, což je `:` na Linuxu/macOS)

### D) AGENTS.md + CLAUDE.md
- V kořeni repozitáře (ne v obou podadresářích) — dokumentace pro AI agenty popisuje CELÝ
  ekosystém (profile/ + toolkit/)

## 4. Konvence
- Comment-based help na všech funkcích
- try/catch na síťové/externí volání
- Idempotentní operace
- Cross-platform guardy ($IsWindows, $IsLinux)
- Join-Path pro cesty (nikdy string concatenation, nikdy 3+ pozičních argumentů — `-AdditionalChildPath`
  je jen PS6+, na PS5.1 spadne)
- **UTF-8 BOM povinný** na všech `.ps1`/`.psm1`/`.psd1` souborech s ne-ASCII znaky (pomlčky,
  emoji, šipky) — Windows PowerShell 5.1 (`powershell.exe`, ne `pwsh`) bez BOM čte soubor
  v systémové ANSI codepage, víceb­ajtový UTF-8 znak se rozpadne a shodí parser (field-reported
  parse error „string is missing the terminator")
- Žádné síťové operace v profilu (výkon)
- Self-referenční cesty (`toolkit/` hledající vlastní soubory) nikdy nepředpokládají, že
  `$env:DOTFILES_TOOLS` je nastavená — fallback na `$PSScriptRoot`

## 5. Výstup
Vygeneruj všechny soubory s hlavičkou `# Cesta: <relativní cesta>`.
Začni adresářovou strukturou (jako strom).
```

---

## Historický původní prompt — dva repozitáře

> **Historická poznámka:** Tento prompt zadával vytvoření **dvou** Git repozitářů
> (`dotfiles-powershell` + `dotfiles-tools`). Ty byly později sloučeny do jednoho repozitáře
> (`profile/` + `toolkit/` podadresáře) — viz `docs/ROADMAP.md`, Fáze 5. Prompt je zachován
> v původním znění jako historický záznam, ne jako aktuální specifikaci struktury.

```
Jsi expert na PowerShell, správu dotfiles a Windows Terminál. 
Vytvoř **kompletní a spustitelný** projekt, který realizuje následující zadání. 
Generuj všechny soubory jako samostatné kódové bloky s uvedenou relativní cestou 
od uživatelského adresáře (%USERPROFILE% resp. $HOME). Struktura musí být připravena 
k okamžitému použití po naklonování do dvou Git repozitářů.

## 1. Cíl
Vytvořit osobní PowerShell ekosystém, který:
- obchází OneDrive (profily i moduly),
- je plně verzovaný (Git),
- přenositelný mezi stroji (Windows, částečně Linux),
- obsahuje modulární profil, nástrojový toolbox a automatické nastavení Windows Terminálu.

## 2. Výsledné repozitáře
A) **dotfiles-powershell** - umístění: `~/.config/powershell/`
B) **dotfiles-tools** - umístění: `~/Projects/tools/`

## 3. Detailní požadavky

### A) dotfiles-powershell
- `profile.ps1`: hlavní skript, který detekuje verzi PS (5/7) a hostitele (ConsoleHost, VSCode) a dot-sourcuje:
  - všechny `.ps1` z `core/`
  - verzi specifický profil (`ps5/profile.ps1` nebo `ps7/profile.ps1`)
  - hostitelský profil z `hosts/` (pokud existuje)
  - nastaví `$env:DOTFILES_PWSH` a `$env:DOTFILES_TOOLS` na správné cesty
  - pro PS7 opraví `PSModulePath`, aby moduly nepadaly do OneDrive (přidá `%LOCALAPPDATA%\PowerShell\Modules` na začátek)
  - volitelně zobrazí dobu načtení, pokud `$env:PROFILE_BENCHMARK` je `$true`
- `install.ps1`: idempotentní instalační skript, který:
  - naklonuje/aktualizuje repozitáře `dotfiles-powershell` a `dotfiles-tools` (URL jsou placeholder `https://github.com/USER/dotfiles-powershell.git` a `https://github.com/USER/dotfiles-tools.git`)
  - vloží bootstrap do všech známých profilových souborů:
    - `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
    - `$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1`
    - `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
    - `$HOME\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1`
  - nastaví uživatelskou proměnnou `PATH` (trvale) tak, aby obsahovala `%USERPROFILE%\Projects\tools\bin`
  - nabídne spuštění `scripts\Add-WTProfiles.ps1` pro nastavení Windows Terminálu
- bootstrap (obsah vkládaný do profilů): minimální kód, který pouze dot-sourcuje `~/.config/powershell/profile.ps1`
- `core/aliases.ps1`: příklady aliasů (např. `Set-Alias ll Get-ChildItem`)
- `core/functions.ps1`: užitečné funkce (např. `Edit-Profile` otevře `code $PROFILE`, `Reload-Profile`)
- `core/env.ps1`: nastaví `$env:EDITOR`, přidá `~/Projects/tools/bin` do PATH, nastaví `$env:DOTFILES_TOOLS`
- `ps5/profile.ps1`: specifické nastavení pro Windows PowerShell 5.1 (např. import starších modulů)
- `ps7/profile.ps1`: moderní PS7 nastavení - import `PSReadLine`, `Terminal-Icons` (pokud nainstalováno), `oh-my-posh` (s podmínkou), prediktivní IntelliSense
- `hosts/ConsoleHost.ps1`: specifické pro klasickou konzoli (např. nastavení titulku, uvítání)
- `hosts/VSCode.ps1`: pro integrovaný terminál VS Code (např. potlačení uvítání, nastavení kódování)

### B) dotfiles-tools
- `bin/`: spustitelné skripty přidané do PATH:
  - `menu.ps1`: spustí `Start-MainMenu` z modulu Toolkit
  - `check.ps1`: spustí `Invoke-SystemCheck` z Toolkit
- `lib/`: zdrojové funkce (budou začleněny do Toolkit):
  - `common.ps1`: obecné pomocné funkce (např. `Test-Admin`, `Get-ScriptDirectory`)
  - `menu.ps1`: definice menu logiky
  - `checkers.ps1`: funkce pro kontroly (disk, služby, síť)
- `Toolkit/`: PowerShell modul:
  - `Toolkit.psm1`: dot-sourcuje všechny `.ps1` z `lib/` a exportuje veřejné funkce
  - `Toolkit.psd1`: manifest s `FunctionsToExport` zahrnující `Start-MainMenu`, `Invoke-SystemCheck`, `Show-DockerMenu`, `Show-GitMenu` atd.
- `menu/`: (alternativní uvnitř lib, ale může zůstat jako samostatné skripty, které volají funkce modulu)
  - `menu-main.ps1`: interaktivní číselné menu s položkami: Docker, Systém, Git, Nástroje, Konec; volá příslušné funkce
  - `menu-docker.ps1`, `menu-git.ps1`: submenu
- `checkers/`: samostatné skripty (volají funkce modulu) nebo přímé funkce - pro jednoduchost to zabudujeme do Toolkit
- `configs/`: ukázkový `settings.json` s výchozími hodnotami (např. téma menu)
- `scripts/`:
  - `Add-WTProfiles.ps1`: skript pro Windows Terminal, který:
    - najde `settings.json` (oba možné cesty)
    - zálohuje jej
    - odstraní komentáře `//`
    - přidá/aktualizuje 4 profily s pevnými GUID:
      - Menu (pwsh.exe, `%USERPROFILE%\Projects\tools\menu`, ikona `icons/menu.png`)
      - Projekty (pwsh.exe, `%USERPROFILE%\Projects\work`, ikona `icons/projects.png`)
      - PowerShell 7 (pwsh.exe, `%USERPROFILE%`, ikona `icons/pwsh7.png`)
      - Windows PowerShell 5.1 (powershell.exe, `%USERPROFILE%`, ikona `icons/pwsh5.png`)
    - ověří existenci ikon, jinak nastaví ikonu na `null`
    - uloží nastavení bez BOM
    - vygeneruje `profiles-fragment.json` do `scripts/`
- `icons/`: 4 placeholder PNG obrázky 32×32 px (každý s jedním písmenem: M, P, 7, 5). Vygeneruj binární (nebo alespoň vytvoř PowerShell skript, který je vygeneruje, např. `Generate-Icons.ps1`, který použije .NET `System.Drawing`).
- `tests/`: Pester testy pro Toolkit (alespoň kontrola, že `Start-MainMenu` existuje).
- `.gitignore`: ignorovat `configs/secrets.*`, `*.secret`, `.env`.

### C) Integrace s bezpečností
- Všechny API klíče se ukládají přes `Microsoft.PowerShell.SecretManagement` (trezor Default).
- V `core/functions.ps1` přidej funkci `Get-SecretKey`, která vrací klíč z trezoru nebo z `$env:VAR` (pro testování).
- V `.gitignore` zamez commitnutí citlivých souborů.

### D) Další vlastnosti
- Idempotentní instalace (opakované spuštění nezdvojí položky).
- Podpora pro `-WhatIf` v `Add-WTProfiles.ps1`.
- Všechny skripty musí mít comment-based help.
- Kód musí být čistý, s ošetřením chyb.
- Výsledný profil musí respektovat výkonová doporučení (líné importy, žádné síťové operace v profilu).

## 4. Výstup
Vygeneruj **všechny soubory** jako bloky kódu s hlavičkou `# Cesta: <relativní cesta>` a obsahem. 
Začni adresářovou strukturou (jako strom). 
Pokud to jde, vytvoř celý archiv, jinak jednotlivé bloky.
```

---

## Zkrácená varianta (dotfiles-tools)

Companion repozitář (`dotfiles-tools`) byl v té době generován samostatným, kondenzovaným
promptem se stejnou strukturou/cílem jako výše, jen s méně detaily v sekcích B–D — obsahově
podmnožina promptu nahoře, zachovávána zde jen pro úplnost historického záznamu.
