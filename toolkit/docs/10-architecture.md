# Architektura dotfiles-tools

> Kontext: [00-bootstrap.md](00-bootstrap.md) popisuje fáze 1–7 spouštění PowerShellu; tento dokument popisuje, jak je postavený toolbox, který v té session běží.

## Komponentový diagram

```mermaid
graph TB
    subgraph "PATH (bin/)"
        MM["menu.ps1<br/>→ Start-MainMenu"]
        CHKD["check.ps1<br/>→ Invoke-SystemCheck"]
    end

    subgraph "Toolkit Module"
        PSM1["Toolkit.psm1<br/>(dot-sources Public/ + Private/)"]
        PSD1["Toolkit.psd1<br/>(manifest)"]
    end

    subgraph "Toolkit/Public (source functions)"
        COMMON["Console.ps1<br/>Write-*, …"]
        MENU["Show-Menu.ps1<br/>Show-Menu engine"]
        CHECKERS["Diagnostics.ps1<br/>Get-DiskStatus, …"]
    end

    subgraph "Toolkit/Public/Menu (standalone scripts)"
        MAIN["menu-main.ps1<br/>Start-MainMenu"]
        GIT_M["menu-git.ps1<br/>Show-GitMenu"]
    end

    subgraph "ops/"
        WT["Add-WTProfiles.ps1<br/>Windows Terminal setup"]
        ICONS["Generate-Icons.ps1<br/>PNG generator"]
    end

    subgraph "External"
        WT_JSON["settings.json<br/>(Windows Terminal)"]
    end

    MM -->|"Import-Module"| PSD1
    CHKD -->|"Import-Module"| PSD1
    PSD1 --> PSM1
    PSM1 -->|"dot-source"| COMMON
    PSM1 -->|"dot-source"| MENU
    PSM1 -->|"dot-source"| CHECKERS
    MAIN -->|"Import-Module"| PSD1
    GIT_M -->|"Import-Module"| PSD1
    WT -->|"čte/zapisuje"| WT_JSON
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
        WT->>WT: Sestavit profily: Menu, Projekty (shell integration),<br/>PowerShell 7 (jen aktualizuje vestavěný profil jménem)
        WT->>FS: Načíst config/wt-schemes.json (single source of truth)
        WT->>FS: Zálohovat existující fragment (.backup.<timestamp>)
        WT->>FS: Zapsat fragment bez BOM (UTF8Encoding)
        WT-->>U: Hotovo — restart WT pro projevení
    end
```

## Menu engine (Show-Menu)

Skutečná implementace používá **arrow-key navigaci přes `[Console]::ReadKey`**, ne číslované
`Read-Host` vstupy (číselné zkratky fungují taky, jako doplněk). Každá položka může nést
volitelný `Detector` scriptblock, který se vyhodnotí znovu při každém překreslení a zobrazí
živý stavový sloupec (✅/⚠️/❌ + text) vedle popisu.

```mermaid
flowchart TD
    START["Show-Menu -Title 'X' -Items @{...}"] --> NORM["Normalizovat položky<br/>(Action, Desc, Detector)"]
    NORM --> LOOP["Render loop"]
    LOOP --> DET["Vyhodnotit Detector<br/>pro každou položku (try/catch)"]
    DET --> DRAW["Vykreslit box: nadpis, položky<br/>+ Desc + živý stavový sloupec"]
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
    GIT_M["GIT MENU<br/>Show-GitMenu"]
    CHECK["DIAGNOSTIKA<br/>Invoke-SystemCheck"]
    DOTFILES["DOTFILES<br/>Show-DotfilesMenu"]
    TERMINAL["TERMINAL<br/>Show-TerminalMenu"]
    PWSH["POWERSHELL<br/>Show-PwshMenu"]
    VSCODE["VS CODE<br/>Show-VSCodeMenu"]

    MAIN -->|"1"| DOTFILES
    MAIN -->|"2"| CHECK
    MAIN -->|"3"| GIT_M
    MAIN -->|"4"| TERMINAL
    MAIN -->|"5"| PWSH
    MAIN -->|"6"| VSCODE
    MAIN -->|"7"| EXIT["Konec"]

    GIT_M -->|"1"| GST["git status"]
    GIT_M -->|"2"| GLO["git log"]
    GIT_M -->|"3"| GBR["git branch -a"]
    GIT_M -->|"4"| GRM["git remote -v"]
    GIT_M -->|"5"| GSL["git stash list"]
    GIT_M -->|"6"| GCM["git commit -am"]
    GIT_M -->|"7"| BACK
```

## Vztah bin/ ↔ Toolkit/Public+Private

```
bin/menu.ps1                  bin/check.ps1
    │                           │
    │ Import-Module             │ Import-Module
    ▼                           ▼
┌─────────────────────────────────────────┐
│           Toolkit.psd1 (manifest)       │
│  FunctionsToExport: 36 functions         │
└─────────────────────────────────────────┘
    │
    │ RootModule
    ▼
┌─────────────────────────────────────────┐
│           Toolkit.psm1 (module)         │
│  dot-sources Private/ + Public/          │
│  (exports declared in the manifest)      │
└─────────────────────────────────────────┘
    │
    │ dot-source
    ▼
┌──────────────┐ ┌────────────────┐ ┌──────────────────┐
│ Console.ps1  │ │ Show-Menu.ps1  │ │ Diagnostics.ps1  │
└──────────────┘ └────────────────┘ └──────────────────┘
```

## Profily Windows Terminal (fragment extension, párováno jménem)

Žádné GUID — WT fragment extensions párují profily podle `name`. `Menu`/`Projekty` jsou nové
vlastní profily (shell integration povolena). `PowerShell 7` **aktualizuje
existující vestavěný profil stejného jména** — záměrně jen o `icon`/`tabTitle`, nikdy o
font/colorScheme/shell-integration, aby se tiše nepřepsalo uživatelovo vlastní nastavení.

| Profil | Typ | Příkaz |
|--------|-----|--------|
| Menu | nový, vlastní | `pwsh.exe` → `menu-main.ps1` |
| Projekty | nový, vlastní | `pwsh.exe` → `~/Projects/work` |
| PowerShell 7 | update vestavěného | `pwsh.exe` → `~` |
