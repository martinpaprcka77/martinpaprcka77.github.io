# Původní prompt

Tento soubor uchovává původní prompt, ze kterého byla vygenerována celá kódová základna. Slouží pro:
- **Reprodukovatelnost** — stejný prompt lze poslat jinému modelu a získat podobný výsledek.
- **Dokumentaci záměru** — zachycuje kompletní specifikaci v jednom souboru.
- **Iteraci** — při úpravách je vidět, co se změnilo oproti původnímu zadání.

> **Historická poznámka:** Tento prompt zadával vytvoření **dvou** Git repozitářů
> (`dotfiles-powershell` + `dotfiles-tools`). Ty byly později sloučeny do jednoho repozitáře
> (`profile/` + `toolkit/` podadresáře) — viz `docs/ROADMAP.md`, Fáze 5. Prompt je zachován
> v původním znění jako historický záznam, ne jako aktuální specifikaci struktury.

---

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
