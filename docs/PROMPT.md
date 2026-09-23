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
- WhatIf, Force, NoUpdates parametry
- try/catch na git operace, preflight kontrola gitu na PATH
- Jediný self `git pull` (repo obsahuje install.ps1 sám v sobě — žádné klonování druhého repa)
- Zálohuje existující profily před změnou
- Volá jediný self-heal vstup `Invoke-DotfilesRepair` (viz `profile/lib/repair.ps1`), který skládá
  injekci bootstrapu do 4 profilových cest (Known-Folder-korektní, viz `profile/lib/paths.ps1`) +
  opravu UTF-8 BOM (`profile/lib/encoding.ps1`) + validaci/reset `PSModulePath` (Windows) do jednoho
  průchodu; injekci samotnou dělá `Invoke-BootstrapInjection` (`profile/lib/bootstrap.ps1`)
- Nastaví trvalou PATH (`toolkit/bin`)
- Shrnutí na konci

#### Setup-Windows.ps1 — nový stroj od nuly
- `#Requires -Version 5.1` **a** `#Requires -RunAsAdministrator` (registry defaulty, winget, Appx) —
  bez elevace skript odmítne běžet, což je správné chování, ne chyba
- `-All` / `-ProfileOnly` / `-Dependencies` / `-Defaults` / `-VSCode`; každý stav-měnící krok za
  `$PSCmdlet.ShouldProcess`, takže `-WhatIf` je úplný dry run

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
- Přepínače přes env proměnné: `$env:DOTFILES_FORCE`, `$env:DOTFILES_NO_UPDATES`

#### update.ps1
- git fetch + rev-list kontrola nových commitů
- ff-only pull
- Volá `Invoke-DotfilesRepair` (bez -Force) po každém pullu — **self-heal**: bootstrap, BOM i
  `PSModulePath` se zkontrolují/opraví při každém běhu, ne jen po skutečném pullu. Uživatel nemusí
  vědět, že má znovu spustit install.ps1

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
- Kubernetes: k, kx, kns (pokud nainstalováno)
- Navigace: ll (Get-ChildItem)

#### profile/core/functions.ps1
- Edit-Profile, Import-Profile (s aliasem `Reload-Profile`, na který míří `rp`), Get-SecretKey
  (SecretManagement vault + $env:VAR fallback), Test-Admin, mkcd
- Show-Hint / Test-HintShown / Get-HintStateDir — jednorázové nápovědy (first-run hinty).
  Značka „už zobrazeno“ žije MIMO repozitář (`%LOCALAPPDATA%\dotfiles-powershell\hints`, jinde
  `$HOME/.local/state/...`) — zápis do klonu by zašpinil strom a rozbil `git pull --ff-only`

#### profile/core/aliases.ps1 — pozor na vestavěné aliasy
- `rp` je na Windows PowerShell 5.1 vestavěný alias s `Options=ReadOnly,AllScope`
  (`Remove-ItemProperty`); `Set-Alias -Force` ho nedokáže přepsat a vyhodí „The AllScope option
  cannot be removed from the alias 'rp'“ při každém načtení profilu. Řešení: `Remove-Item
  Alias:rp -Force -ErrorAction SilentlyContinue` před definicí (na PS7 AllScope není, proto se
  chyba projeví jen na 5.1)

#### profile/core/env.ps1
- $env:EDITOR (code > nvim > vim > notepad)
- Přidá `toolkit/bin` do PATH (odvozeno z $env:DOTFILES_TOOLS)

#### profile/ps5/profile.ps1
- PSReadLine v2, UTF-8 kódování

#### profile/ps7/profile.ps1
- PSReadLine v3, Terminal-Icons, PSFzf (vše podmíněně, pokud nainstalováno)
- Prompt: **Starship** je primární (`starship init powershell`), oh-my-posh je jen fallback
- Transient/collapsing prompt je funkce oh-my-posh, **ne** Starshipu — `[transient_prompt]` je
  v Starshipu neplatný klíč (Starship ho odmítne a hlásí `Unknown key` při každé inicializaci),
  takže ve `starship.toml` nesmí být
- `$IsWindows` je PS6+ automatická proměnná → ve skriptech, které musí běžet i na PS5.1, guardovat
  verzí: `$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }`

#### profile/hosts/
- ConsoleHost.ps1: titulek okna, uvítání s uptimem (box se počítá z nejdelší buňky, aby všechny
  řádky měly stejnou šířku), sám dot-sourcuje `wtprofile.ps1`
- VSCode.ps1: potlačení uvítání, UTF-8, TERM=vscode
- wtprofile.ps1: Windows Terminal utility (zoxide, trash, Show-Help, vlastní PSReadLine historie) —
  načte se jen když je `$env:WT_SESSION` nastavená
- shell-integration.ps1: OSC 133 markery (prompt/command marks, exit code), dot-sourcovaný přímo
  z `ps7/profile.ps1`

### C) toolkit/ — interaktivní toolbox

#### toolkit/bin/
- `menu.ps1`: Import-Module Toolkit → Start-MainMenu
- `check.ps1`: Import-Module Toolkit → Invoke-SystemCheck

#### toolkit/Toolkit/Public/Show-Menu.ps1
- Show-Menu — TUI engine: minimalistický bezrámečkový seznam (titulek + tenká akcentová linka +
  sloupcově zarovnané položky, aktivní řádek značen barevným `›` kurzorem, žádný inverzní blok),
  navigace šipkami (`[Console]::ReadKey`), číselné zkratky fungují taky, volitelný `Detector`
  scriptblock na položku (živý stavový sloupec, vyhodnocen znovu při každém překreslení, cache
  function-local ne `$script:`). Pevná kotva `$menuTop` zachycená jednou před smyčkou, aby čistá
  navigace (šipky) nikdy neposunula seznam dolů; šířka ořezána na `[Console]::WindowWidth`,
  `Desc`/`Detector` text zkrácen s výpustkou (`…`), aby dlouhá zpráva nezalomila řádek

#### toolkit/Toolkit/Public/Detectors.ps1
- `Get-ModuleStackStatus`, `Get-ModulePathStatus` — jediné dva, které menu skutečně připojuje jako
  `Detector`; dále predikáty `Test-LegacyPowerShellGetPresent`, `Test-PSResourceGetReady`
- Musí být levné: jen `Get-Command`/`Test-Path`/cached config, žádné síťové volání ani spouštění
  procesů — detektor se vyhodnocuje při každém překreslení menu (tj. každý stisk klávesy)
- `Test-LegacyPowerShellGetPresent` hledá legacy moduly pod `$PSHOME\Modules`, **ne** pod literálem
  `"$env:ProgramFiles\PowerShell\7\Modules"`: PowerShell 7 z Microsoft Store (MSIX) drží vlastní
  moduly jinde a ten literál tam vůbec neexistuje (na MSIX 7.6.6 je `$PSHOME`
  `C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.6.0_x64__8wekyb3d8bbwe`), takže natvrdo
  zapsaná cesta detekci tiše vypnula. Pro standalone instalaci je `$PSHOME\Modules` totožná cesta

#### toolkit/Toolkit/Public/Diagnostics.ps1
- Get-DiskStatus, Get-ServiceStatus, Get-NetworkInfo, Get-TopProcesses, Invoke-SystemCheck,
  Get-SystemSummary
- Windows-only funkce guardují přes `$IsWindows` — bez verzového guardu je to zde bezpečné, protože
  manifest modulu deklaruje `PowerShellVersion = '7.0'`, takže `$IsWindows` vždy existuje (na rozdíl
  od samostatných skriptů mimo modul, kde platí `$isWindowsHost` idiom)
- `Get-NetworkInfo` navíc guarduje `Get-Command Get-NetIPAddress`: NetTCPIP je modul jen pro Windows
  PowerShell, v pwsh se nenačte ani na Windows

#### toolkit/Toolkit/Public/Configuration.ps1
- Get-ToolkitConfig (defaults → JSON → $env:TOOLKIT_* merge), Save-ToolkitConfig, Merge-Hashtable
- `$toolsRoot = if ($env:DOTFILES_TOOLS) { $env:DOTFILES_TOOLS } else { Split-Path $PSScriptRoot -Parent }`
  — self-referenční fallback, nikdy nepředpokládat, že env var je nastavená

#### toolkit/Toolkit/ (PowerShell modul)
- Toolkit.psd1: manifest s 36 FunctionsToExport a `PowerShellVersion = '7.0'`
- Toolkit.psm1: dot-sourcuje Toolkit/Private/ a Toolkit/Public/, exports deklarované v manifestu

#### toolkit/Toolkit/Public/Menu/
- menu-main.ps1, menu-startup.ps1, menu-git.ps1, menu-dotfiles.ps1,
  menu-terminal.ps1, menu-pwsh.ps1, menu-vscode.ps1 — každý self-referenční lookup uvnitř použije stejný
  `$toolsRoot` fallback jako Configuration.ps1 (field-reported crash: `Join-Path
  $env:DOTFILES_TOOLS ...` s `$null` env var, když menu běželo bez načteného profilu)
- Volání funkcí z `profile/` (Show-Status, Measure-Profile, Get-NativeProfilePaths…) jde inline přes
  `if (Get-Command <funkce> -ErrorAction SilentlyContinue) { … }` — `toolkit/` musí fungovat
  i samostatně, bez načteného profilu

#### toolkit/ops/
- configure.ps1 (5-step wizard), precheck.ps1 (inventura před instalací), modernize.ps1 (PSResourceGet
  migrace), deps.ps1, windows.ps1, Add-WTProfiles.ps1, Generate-Icons.ps1, Get-PowerShellStartupHealth.ps1
- modernize.ps1 si drží vlastní kopii seznamu legacy modulů, která musí odpovídat
  `Toolkit/Public/Detectors.ps1` — hlídá to repo-invariantní Pester test
- Stav-měnící skripty přijímají `-WhatIf` přes `[CmdletBinding(SupportsShouldProcess)]`; bez atributu
  `-WhatIf` tiše spadne do `$args` a skript přesto zapíše (ověřeno u `Generate-Icons.ps1`)

#### toolkit/build/ + toolkit/config/
- build/Build.ps1 (manifest ↔ source parity), build/Test.ps1 (jediná brána: parity → Pester →
  PSScriptAnalyzer), build/Generate-Docs.ps1 (generuje docs/20-reference.md, čísla se neudržují ručně)
- config/settings.example.json je verzovaná šablona; `config/settings.json` je lokální a gitignored
  (`Save-ToolkitConfig` ho zapisuje — verzovaný by zašpinil strom a rozbil `git pull --ff-only`)

#### toolkit/tests/Toolkit.Tests.ps1
- 75 testů (70 modul/chování + 5 repo invariant), Mock pokrytí (config, PSModulePath, menu chybové
  cesty). PSModulePath fixtures musí být platform-neutrální — `C:\Mods\...` na Windows, `/Mods/...`
  jinde (dvojtečka v drive-letter koliduje s `[IO.Path]::PathSeparator`, což je `:` na Linuxu/macOS)

### D) AGENTS.md + CLAUDE.md
- V kořeni repozitáře (ne v obou podadresářích) — dokumentace pro AI agenty popisuje CELÝ
  ekosystém (profile/ + toolkit/)

### E) tools/ — údržba repa (NENÍ součást profilu)
- `tools/devmenu/devmenu.ps1` — přenosné launcher menu (`pwsh -File tools/devmenu/devmenu.ps1
  -SelfTest` = 31 kontrol); `#Requires -Version 7`
- `tools/gist-sources.ps1` — kanonická těla gistů, ze kterých čtou oba skripty níže
- `tools/Verify-Sync.ps1` (read-only kontrola), `tools/Update-Gists.ps1` (push gistů),
  `tools/Validate-Links.ps1` (scan odkazů; `-Fix` experimentální)
- `PSScriptAnalyzerSettings.psd1` v kořeni — CI padá jen na Error severity, Warningy se jen reportují
- `.github/workflows/test.yml` — Pester + PSScriptAnalyzer + JSON validace; paths filtr pokrývá
  `profile/**`, `toolkit/**`, `*.ps1` a tento settings soubor

## 4. Konvence
- Comment-based help na všech funkcích
- try/catch na síťové/externí volání
- Idempotentní operace
- **Cross-platform guardy**: `$IsWindows`/`$IsLinux`/`$IsMacOS` jsou PS6+ automatické proměnné a na
  Windows PowerShell 5.1 **neexistují** (`-not $IsWindows` je tam `$true`, protože `$null` se
  vyhodnotí jako nepravda → skript na Windowsu mylně odmítne běžet). Vždy nejdřív verze:
  `$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }`
- Nebezpečné `Set-Alias -Force` na jméno, které je vestavěný alias (viz `rp`) — nejdřív
  `Remove-Item Alias:<jméno> -Force -ErrorAction SilentlyContinue`
- Stav-měnící skripty/funkce deklarují `[CmdletBinding(SupportsShouldProcess)]` a obalují akci
  `$PSCmdlet.ShouldProcess(...)`. Pozor: skript s pouhým `param()` žádný `-WhatIf` nepřijme —
  spadne do `$args` a **tiše se ignoruje**, přestože skript normálně zapíše
- Cesty: `Join-Path` (nikdy string concatenation, nikdy 3+ pozičních argumentů — `-AdditionalChildPath`
  je jen PS6+, na PS5.1 spadne)
- Systémové cesty PowerShellu odvozovat (`$PSHOME\Modules`), nikdy nezapisovat natvrdo
  `"$env:ProgramFiles\PowerShell\7\Modules"` — instalace z Microsoft Store (MSIX) má moduly jinde
- **UTF-8 BOM povinný** na všech `.ps1`/`.psm1`/`.psd1` souborech s ne-ASCII znaky (pomlčky,
  emoji, šipky) — Windows PowerShell 5.1 (`powershell.exe`, ne `pwsh`) bez BOM čte soubor
  v systémové ANSI codepage, vícebajtový UTF-8 znak se rozpadne a shodí parser (field-reported
  parse error „string is missing the terminator“)
- `exit` uvnitř skriptu, který se má dát spouštět přes `irm <url> | iex`, **zabije hostitelskou
  session** (ověřeno: `iex 'exit 7'` ukončí proces a následující příkaz se už nespustí) — použij
  `return` a `exit` jen když byl soubor skutečně spuštěn jako soubor
  (`$MyInvocation.MyCommand.Path` je pod `Invoke-Expression` `$null`)
- Žádné síťové operace v profilu (výkon)
- Self-referenční cesty (`toolkit/` hledající vlastní soubory) nikdy nepředpokládají, že
  `$env:DOTFILES_TOOLS` je nastavená — fallback na `$PSScriptRoot`
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
  - `Toolkit.psd1`: manifest s `FunctionsToExport` zahrnující `Start-MainMenu`, `Invoke-SystemCheck`, `Show-StartupMenu`, `Show-GitMenu` atd.
- `menu/`: (alternativní uvnitř lib, ale může zůstat jako samostatné skripty, které volají funkce modulu)
  - `menu-main.ps1`: interaktivní číselné menu s položkami: Startup, Dotfiles, Systém, Git, Terminal, PowerShell, VS Code, Konec; volá příslušné funkce
  - `menu-startup.ps1`, `menu-git.ps1`: submenu
- `checkers/`: samostatné skripty (volají funkce modulu) nebo přímé funkce - pro jednoduchost to zabudujeme do Toolkit
- `configs/`: ukázkový `settings.json` s výchozími hodnotami (např. téma menu)
- `tests/`: Pester testy pro Toolkit (alespoň kontrola, že `Start-MainMenu` existuje).
- `.gitignore`: ignorovat `configs/secrets.*`, `*.secret`, `.env`.

### C) Integrace s bezpečností
- Všechny API klíče se ukládají přes `Microsoft.PowerShell.SecretManagement` (trezor Default).
- V `core/functions.ps1` přidej funkci `Get-SecretKey`, která vrací klíč z trezoru nebo z `$env:VAR` (pro testování).
- V `.gitignore` zamez commitnutí citlivých souborů.

### D) Další vlastnosti
- Idempotentní instalace (opakované spuštění nezdvojí položky).
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
