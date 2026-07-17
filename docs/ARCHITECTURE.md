# Architektura

Ekosystém žije v jednom repozitáři (`martinpaprcka77.github.io`) se dvěma hlavními
podadresáři — `profile/` (orchestrace profilu) a `toolkit/` (interaktivní nástroje) — plus
`site/` obsah (`index.html`, `prompts.html`) pro GitHub Pages na kořenové URL.

## Monorepo layout

```mermaid
graph TB
    ROOT["martinpaprcka77.github.io/<br/>(repo root, klonováno do ~/.config/powershell)"]
    ROOT --> SITE["index.html · prompts.html<br/>(GitHub Pages)"]
    ROOT --> BOOT["install.ps1 · remote-install.ps1<br/>update.ps1 · bootstrap.ps1"]
    ROOT --> DOCS["docs/"]
    ROOT --> VSC[".vscode/"]
    ROOT --> CI[".github/workflows/"]
    ROOT --> PROFILE["profile/"]
    ROOT --> TOOLKIT["toolkit/"]

    PROFILE --> P1["profile.ps1 (orchestrátor)"]
    PROFILE --> P2["core/ · ps5/ · ps7/ · hosts/ · lib/"]

    TOOLKIT --> T1["bin/ · Toolkit/ · lib/ · menu/"]
    TOOLKIT --> T2["scripts/ · configs/ · tests/"]

    PROFILE -.->|"$env:DOTFILES_TOOLS<br/>(sibling dir)"| TOOLKIT
```

`$env:DOTFILES_PWSH` (nastaveno `profile.ps1`) ukazuje na `profile/`; `$env:DOTFILES_TOOLS`
se z něj odvozuje jako sourozenecký adresář `toolkit/` — obě proměnné jsou tedy vždy v souladu
(dřív, ve dvou repozitářích, šlo o dva nezávislé zdroje pravdy, které se mohly rozejít).

## Diagram načítání profilu

```mermaid
flowchart TD
    A["PowerShell start"] --> B{"$PROFILE existuje?"}
    B -->|ano| C["Bootstrap: dot-source profile/profile.ps1"]
    B -->|ne| Z["Nic – prázdná session"]

    C --> D["profile.ps1"]
    D --> E["Detekce prostředí: $isPSCore, $isWindowsHost"]
    E --> F["Nastavit $env:DOTFILES_PWSH<br/>Odvodit $env:DOTFILES_TOOLS (sourozenec)"]
    F --> G["Opravit PSModulePath<br/>(LOCALAPPDATA na začátek, PS5.1 i PS7)"]
    G --> H["Dot-source lib/paths.ps1, core/*.ps1"]

    H --> I{"PSVersion ≥ 6?"}
    I -->|ano| J["Dot-source ps7/profile.ps1"]
    I -->|ne| K["Dot-source ps5/profile.ps1"]

    J --> L{"$host.Name obsahuje 'Code'?"}
    K --> L

    L -->|ano| M["Dot-source hosts/VSCode.ps1"]
    L -->|ne| N["Dot-source hosts/ConsoleHost.ps1"]

    M --> O{"PROFILE_BENCHMARK?"}
    N --> O

    O -->|true| P["Zobrazit dobu načtení"]
    O -->|false| Q["Hotovo"]
    P --> Q
```

## Mapa proměnných prostředí

| Proměnná | Nastavuje | Hodnota | Použití |
|----------|-----------|---------|---------|
| `$env:DOTFILES_PWSH` | `profile.ps1` | `~/.config/powershell/profile` | Cesta k profilové části |
| `$env:DOTFILES_TOOLS` | `profile.ps1` / `core/env.ps1` | `~/.config/powershell/toolkit` | Cesta k toolkit části (sourozenec `DOTFILES_PWSH`) |
| `$env:EDITOR` | `core/env.ps1` | `code` / `nvim` / `vim` / `notepad` | Výchozí editor |
| `$env:PROFILE_BENCHMARK` | Uživatel | `true` / (prázdné) | Měření doby načtení |
| `$env:TERM` | `hosts/VSCode.ps1` | `vscode` | Indikátor VS Code terminálu |
| `$env:PSModulePath` | `profile.ps1` (PS5.1 i PS7) | + `%LOCALAPPDATA%\...\Modules` | Oprava OneDrive |

## Flow instalace (install.ps1)

```mermaid
sequenceDiagram
    actor U as Uživatel
    participant I as install.ps1
    participant B as Invoke-BootstrapInjection
    participant G as Git
    participant FS as Souborový systém
    participant ENV as Prostředí

    U->>I: .\install.ps1
    I->>G: git pull --ff-only (self, repo root)

    I->>B: Invoke-BootstrapInjection
    loop 4 profilové cesty (Known-Folder-korektní)
        B->>FS: Existuje profil?
        alt existuje
            B->>FS: Obsahuje AKTUÁLNÍ bootstrap (profile/profile.ps1)?
            alt ne (chybí nebo zastaralý)
                B->>FS: Zálohovat, nahradit/přidat bootstrap
            end
        else neexistuje
            B->>FS: Vytvořit s bootstrapem
        end
    end

    I->>ENV: Přidat toolkit/bin do USER PATH
    I->>ENV: Aktualizovat $env:PATH v session

    U->>I: Potvrdit WT nastavení?
    I->>G: Spustit toolkit/scripts/Add-WTProfiles.ps1
```

`update.ps1` volá `Invoke-BootstrapInjection` po každém pullu (bez `-Force`) — pokud je
existující bootstrap na starou (pre-monorepo) cestu, automaticky se opraví, aniž by uživatel
musel vědět, že má znovu spustit `install.ps1`.

## Detekce verze a hostitele

```powershell
# Verze PowerShellu
if ($PSVersionTable.PSVersion.Major -ge 6) { "ps7" } else { "ps5" }

# Hostitel
if ($host.Name -match 'Code') { 'VSCode' } else { 'ConsoleHost' }
```

---

## Toolkit — komponentový diagram

```mermaid
graph TB
    subgraph "PATH (toolkit/bin/)"
        MM["menu.ps1<br/>→ Start-MainMenu"]
        CHKD["check.ps1<br/>→ Invoke-SystemCheck"]
    end

    subgraph "Toolkit Module"
        PSM1["Toolkit.psm1<br/>(dot-sources lib/)"]
        PSD1["Toolkit.psd1<br/>(manifest, 37 funkcí)"]
    end

    subgraph "toolkit/lib/ (source functions)"
        COMMON["common.ps1<br/>Test-Admin, Write-*, …"]
        MENU["menu.ps1<br/>Show-Menu engine"]
        CHECKERS["checkers.ps1<br/>Get-DiskStatus, …"]
        DETECT["detectors.ps1<br/>Invoke-IfAvailable guard"]
    end

    subgraph "toolkit/menu/ (standalone scripts)"
        MAIN["menu-main.ps1<br/>Start-MainMenu"]
        DOCKER["menu-docker.ps1<br/>Show-DockerMenu"]
        GIT_M["menu-git.ps1<br/>Show-GitMenu"]
    end

    subgraph "toolkit/scripts/"
        WT["Add-WTProfiles.ps1<br/>Windows Terminal setup"]
        ICONS["Generate-Icons.ps1<br/>PNG generator"]
    end

    subgraph "External"
        WT_JSON["WT JSON fragment"]
        SECRETS["SecretManagement<br/>vault"]
        PROFILE_HALF["profile/ (sibling dir)<br/>Show-Status, Measure-Profile, …"]
    end

    MM -->|"Import-Module"| PSD1
    CHKD -->|"Import-Module"| PSD1
    PSD1 --> PSM1
    PSM1 -->|"dot-source"| COMMON
    PSM1 -->|"dot-source"| MENU
    PSM1 -->|"dot-source"| CHECKERS
    MAIN -->|"Import-Module"| PSD1
    DOCKER -->|"Import-Module"| PSD1
    GIT_M -->|"Import-Module"| PSD1
    WT -->|"čte/zapisuje"| WT_JSON
    CHECKERS -->|"Get-SecretKey (volitelné)"| SECRETS
    DETECT -->|"Invoke-IfAvailable"| PROFILE_HALF
```

## Datový tok: Add-WTProfiles.ps1

Reálná implementace **negeneruje settings.json editaci ani neodstraňuje `//` komentáře** — to
byl starší návrh. Od WT 1.24+ se používá **JSON fragment extension**
(`%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json`), kterou WT čte
automaticky bez zásahu do uživatelova `settings.json`. Profily se párují podle `name`, ne GUID —
žádné GUID se nikde negenerují ani nepoužívají.

```mermaid
sequenceDiagram
    actor U as Uživatel
    participant WT as Add-WTProfiles.ps1
    participant FS as Souborový systém

    U->>WT: .\Add-WTProfiles.ps1 [-WhatIf] [-Force]
    WT->>FS: Existuje fragment a není -Force?
    alt existuje, bez -Force
        WT-->>U: Skip — použij -Force
    else pokračuje
        WT->>WT: Detekce WSL distribucí (wsl -l -q)
        WT->>WT: Sestavit profily: Menu, Projekty (shell integration),<br/>PowerShell 7, WinPS 5.1 (bez shell-integration overrides —<br/>tyto dva jen aktualizují existující vestavěné profily jménem)
        WT->>FS: Načíst toolkit/configs/wt-schemes.json (single source of truth)
        WT->>FS: Zálohovat existující fragment (.backup.<timestamp>)
        WT->>FS: Zapsat fragment bez BOM (UTF8Encoding)
        WT-->>U: Hotovo — restart WT pro projevení
    end
```

## Menu engine (Show-Menu)

Skutečná implementace používá **arrow-key navigaci přes `[Console]::ReadKey`**, ne číslované
`Read-Host` vstupy (číselné zkratky fungují taky, jako doplněk). Každá položka může nést
volitelný `Detector` scriptblock, který se vyhodnotí znovu při každém překreslení a zobrazí
živý stavový sloupec (✅/⚠️/❌ + text) vedle popisu. Šířka boxu je ořezána na
`[Console]::WindowWidth`; příliš dlouhý `Desc`/`Detector` text se zkrátí s výpustkou (`…`),
aby dlouhá zpráva nezalomila řádek a nerozbila rámeček.

```mermaid
flowchart TD
    START["Show-Menu -Title 'X' -Items @{...}"] --> NORM["Normalizovat položky<br/>(Action, Desc, Detector)"]
    NORM --> LOOP["Render loop"]
    LOOP --> DET["Vyhodnotit Detector<br/>pro každou položku (try/catch)"]
    DET --> FIT["Zkrátit Desc/Detector<br/>na šířku konzole"]
    FIT --> DRAW["Vykreslit box: nadpis, položky<br/>+ Desc + živý stavový sloupec"]
    DRAW --> KEY["[Console]::ReadKey"]
    KEY --> ARROWS{"↑/↓?"}
    ARROWS -->|ano| MOVE["Posunout výběr"] --> LOOP
    ARROWS -->|ne| ENTERQ{"Enter / číslo?"}
    ENTERQ -->|ano| EXEC["Spustit Action"]
    ENTERQ -->|ne| ESCQ{"Esc / q?"}
    ESCQ -->|ano| END["Konec"]
    ESCQ -->|ne| LOOP
    EXEC --> INLINE{"-Inline?"}
    INLINE -->|ano| LOOP
    INLINE -->|ne| END
```

## Hierarchie menu

```mermaid
graph LR
    MAIN["HLAVNÍ MENU<br/>Start-MainMenu"]
    STATUS["STATUS<br/>Show-Status"]
    DOTFILES_M["DOTFILES MENU<br/>Show-DotfilesMenu"]
    SYS_M["SYSTÉM<br/>Invoke-SystemCheck"]
    DOCKER_M["DOCKER MENU<br/>Show-DockerMenu"]
    GIT_M["GIT MENU<br/>Show-GitMenu"]
    TERM_M["TERMINAL MENU<br/>Show-TerminalMenu"]
    PWSH_M["POWERSHELL MENU<br/>Show-PwshMenu"]
    VSCODE_M["VS CODE MENU<br/>Show-VSCodeMenu"]

    MAIN -->|"1"| STATUS
    MAIN -->|"2"| DOTFILES_M
    MAIN -->|"3"| SYS_M
    MAIN -->|"4"| DOCKER_M
    MAIN -->|"5"| GIT_M
    MAIN -->|"6"| TERM_M
    MAIN -->|"7"| PWSH_M
    MAIN -->|"8"| VSCODE_M
    MAIN -->|"9"| EXIT["Konec"]

    DOCKER_M -->|"1-5"| DPS["docker ps/images/stats/disk/logs"]
    DOCKER_M -->|"7-8"| DCP["docker compose up/down"]
    DOCKER_M -->|"9-10"| DNET["docker network ls / prune"]
    DOCKER_M -->|"11"| BACK["Zpět"]

    GIT_M -->|"1-5"| GST["git status/log/branches/remotes/stash"]
    GIT_M -->|"6-7"| GCM["git commit/clean"]
    GIT_M -->|"8"| BACK
```

## Vztah bin/ ↔ Toolkit ↔ lib/

```
toolkit/bin/menu.ps1          toolkit/bin/check.ps1
    │                           │
    │ Import-Module             │ Import-Module
    ▼                           ▼
┌─────────────────────────────────────────┐
│           Toolkit.psd1 (manifest)       │
│  FunctionsToExport: 37 functions         │
└─────────────────────────────────────────┘
    │
    │ RootModule
    ▼
┌─────────────────────────────────────────┐
│           Toolkit.psm1 (module)         │
│  dot-sources all lib/*.ps1               │
│  Export-ModuleMember -Function @(...)    │
└─────────────────────────────────────────┘
    │
    │ dot-source
    ▼
┌────────────┐ ┌────────────┐ ┌──────────────┐
│ common.ps1 │ │ menu.ps1   │ │ checkers.ps1  │
└────────────┘ └────────────┘ └──────────────┘
```

## Profily Windows Terminal (fragment extension, párováno jménem)

Žádné GUID — WT fragment extensions párují profily podle `name`. `Menu`/`Projekty` jsou nové
vlastní profily (shell integration povolena). `PowerShell 7`/`Windows PowerShell 5.1` **aktualizují
existující vestavěné profily stejného jména** — záměrně jen o `icon`/`tabTitle`, nikdy o
font/colorScheme/shell-integration, aby se tiše nepřepsalo uživatelovo vlastní nastavení.

| Profil | Typ | Příkaz |
|--------|-----|--------|
| Menu | nový, vlastní | `pwsh.exe` → `toolkit/menu/menu-main.ps1` |
| Projekty | nový, vlastní | `pwsh.exe` → `~/Projects/work` |
| PowerShell 7 | update vestavěného | `pwsh.exe` → `~` |
| Windows PowerShell 5.1 | update vestavěného | `powershell.exe` → `~` |
| WSL: `<distro>` | auto-detekováno (`wsl -l -q`) | `wsl.exe -d <distro>` |
