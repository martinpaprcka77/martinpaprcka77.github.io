# Manuál toolkit

> Kontext: [00-bootstrap.md](00-bootstrap.md) — fáze 1–7 spouštění PowerShellu a jejich časté chyby.

Kompletní uživatelská příručka pro všechny skripty a funkce.

---

## 1. Rychlý start

```powershell
# Po instalaci (a restartu shellu) jsou bin/ skripty v PATH:
menu          # hlavní menu
check        # systémová diagnostika
```

---

## 2. Hlavní menu (`menu` / `Start-MainMenu`)

Interaktivní menu s navigací šipkami (arrow-key, `[Console]::ReadKey`) — číselné zkratky
fungují jako doplněk, ne jako jediný způsob ovládání. Aktuální 8-položková struktura je
podrobně popsaná v [§14](#14-aktuální-menu-struktura); zde jen stručný přehled:

| # | Položka | Akce |
|---|---------|------|
| 1 | 🚀 Startup | Otevře Startup submenu (bootstrap proces: health, moduly, PSModulePath, profily, discovery) |
| 2 | ⚡ Dotfiles | Otevře Dotfiles submenu |
| 3 | 🔍 Systém | Spustí `Invoke-SystemCheck` |
| 4 | 📋 Git | Otevře Git submenu |
| 5 | 🖥️ Terminal | Otevře Terminal submenu |
| 6 | 💻 PowerShell | Otevře PowerShell submenu |
| 7 | 📝 VS Code | Otevře VS Code submenu |
| 8 | 🚪 Exit | Ukončí menu |

### Použití

```powershell
# Přes bin wrapper (doporučeno)
menu

# Přes modul
Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1
Start-MainMenu

# Přímé spuštění skriptu
~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-main.ps1
```

---

## 3. Git menu (`Show-GitMenu`)

### Položky

| # | Akce | Příkaz |
|---|------|--------|
| 1 | Status | `git status` |
| 2 | Log (20 položek) | `git log --oneline --graph --decorate -20` |
| 3 | Větve | `git branch -a` |
| 4 | Remoty | `git remote -v` |
| 5 | Stash | `git stash list` |
| 6 | Rychlý commit | `git commit -am <zpráva>` |
| 7 | Zpět | Návrat do hlavního menu |

### Použití

```powershell
# Přes hlavní menu: volba 3
menu → 3 → 6 → "Oprava chyby"
```

---

## 4. Systémová diagnostika (`check` / `Invoke-SystemCheck`)

Spustí kompletní kontrolu systému:

```powershell
check
```

### Co kontroluje

| Kontrola | Funkce | Výstup |
|----------|--------|--------|
| **Disky** | `Get-DiskStatus` | DeviceID, Size(GB), Free(GB), Used% |
| **Služby** | `Get-ServiceStatus` | WinRM, W3SVC, Spooler, WSearch |
| **Síť** | `Get-NetworkInfo` | InterfaceAlias, IPAddress, PrefixLength |
| **Procesy** | `Get-TopProcesses` | Top 10 podle CPU (Name, CPU(s), RAM(MB)) |

### Samostatné kontroly

```powershell
Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1

Get-DiskStatus       # jen disky
Get-ServiceStatus    # jen služby
Get-NetworkInfo      # jen síť
Get-TopProcesses     # jen procesy
```

---

## 5. Windows Terminal profily (`Add-WTProfiles.ps1`)

Vygeneruje **JSON fragment extension** — Microsoftem doporučený způsob od WT 1.24+. Nikdy needituje
uživatelovo `settings.json` přímo, takže nemusí odstraňovat `//` komentáře ani nic parsovat/zapisovat
zpět do existujícího souboru. Žádné GUID — profily se párují podle `name`.

### Co dělá

1. Zkontroluje, jestli fragment už existuje (`-Force` pro přepsání)
2. Sestaví profily: `Menu`, `Projekty` (nové, vlastní — s povolenou shell integrací),
   `PowerShell 7` (**aktualizuje existující vestavěný profil** stejného jména — záměrně jen
   `icon`/`tabTitle`, nikdy font/colorScheme/shell-integration, aby se tiše nepřepsalo
   uživatelovo vlastní nastavení výchozích profilů)
3. Načte barevná schémata z `config/wt-schemes.json` (single source of truth)
4. Zálohuje existující fragment (`.backup.<timestamp>`)
5. Uloží fragment bez BOM (UTF-8) do `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json`

### Použití

```powershell
# Normální spuštění
~/.config/powershell/toolkit/ops/Add-WTProfiles.ps1

# Suchý běh (WhatIf) — zobrazí, co by udělal, nic nemění
~/.config/powershell/toolkit/ops/Add-WTProfiles.ps1 -WhatIf

# Přepsat existující fragment
~/.config/powershell/toolkit/ops/Add-WTProfiles.ps1 -Force
```

### Přidané/aktualizované profily

| Název | Typ | Spouští | Výchozí adresář |
|-------|-----|---------|------------------|
| Menu | nový, vlastní | `pwsh.exe` | `~/.config/powershell/toolkit` |
| Projekty | nový, vlastní | `pwsh.exe` | `~/Projects/work` |
| PowerShell 7 | update vestavěného | `pwsh.exe` | `~` |

### Obnova ze zálohy

```powershell
# Záloha je vedle fragmentu:
# dotfiles.json.backup.20260708-120000

Copy-Item "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json.backup.*" `
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json"
```

---

## 6. Generování ikon (`Generate-Icons.ps1`)

Vygeneruje 3 placeholder PNG ikony (32×32 px) pomocí `System.Drawing`.

```powershell
~/.config/powershell/toolkit/ops/Generate-Icons.ps1

# Vlastní výstupní adresář
~/.config/powershell/toolkit/ops/Generate-Icons.ps1 -OutputDir "D:\my-icons"
```

### Vygenerované ikony

| Soubor | Písmeno | Barva pozadí |
|--------|---------|-------------|
| `menu.png` | M | DodgerBlue |
| `projects.png` | P | ForestGreen |
| `pwsh7.png` | 7 | DarkCyan |

---

## 7. Bezpečnost — API klíče

### Uložení klíče

```powershell
# Vyžaduje Microsoft.PowerShell.SecretManagement
Install-Module Microsoft.PowerShell.SecretManagement
Register-SecretVault -Name Default -ModuleName Microsoft.PowerShell.SecretStore
Set-Secret -Name MyApiKey -Vault Default -Secret "sk-..."
```

### Získání klíče

```powershell
$apiKey = Get-SecretKey -Name 'MyApiKey'
```

Funkce `Get-SecretKey` zkouší:
1. `Get-Secret` z `SecretManagement` vaultu
2. `$env:MyApiKey` (fallback pro CI/testování)

---

## 8. Utility funkce

### `Confirm-Action`
```powershell
if (Confirm-Action "Opravdu smazat?") { Remove-Item ... }
```

### `Write-Info` / `Write-Success` / `Write-Warn` / `Write-Err`
```powershell
Write-Info "Probíhá zpracování..."
Write-Success "Hotovo!"
Write-Warn "Nízké místo na disku"
Write-Err "Připojení selhalo"
```

---

## 9. Pester testy

```powershell
# Spuštění testů (vyžaduje Pester)
Install-Module Pester -Force
Invoke-Pester ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1
```

---

## 10. Rozšíření

### Přidání nového nástroje do menu

```powershell
# V menu-main.ps1 přidej položku:
$items = [ordered]@{
    # ... existující ...
    '4' = { & "~\Projects\tools\bin\muj-nastroj.ps1" }
}

# Vytvoř bin/muj-nastroj.ps1:
# Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1 -Force
# ... tvůj kód ...
```

### Přidání nové funkce do Toolkit

```powershell
# 1. Vytvoř funkci v Toolkit/Public/ (nebo nový .ps1)
# 2. Přidej jméno funkce do:
#    - Toolkit.psd1: FunctionsToExport = @(...)   # the only export list
```

---

## 11. CRUD operace — Check, Backup, Restore, Reset, Clean

Každé submenu obsahuje konzistentní operace pro správu:

### 📊 Check Status
```powershell
# Z PowerShell submenu:
menu → 5. PowerShell → 1. Modules
```
Kontroluje: Dotfiles profily, WT fragment, VS Code configs, moduly, Git repozitáře.

### 💾 Backup
```powershell
# Záloha všech profilů (menu → 2. Dotfiles → 4. Backup Profiles)
# Ukládá do: ~/.config/powershell/backups/

# Záloha WT fragmentu (menu → 5. Terminal → 3. Backup Fragment)
# Záloha profile.ps1 (menu → 6. PowerShell → 4. Backup Profile)
# Záloha VS Code configs (menu → 7. VS Code → 5. Backup Settings)
```

### ♻️ Restore
```powershell
# Obnova z časově označené zálohy:
# menu → Dotfiles/Terminal/PowerShell/VS Code → Restore
# Vyber číslo zálohy ze seznamu
```

### ♻️ Reset
```powershell
# Reset WT fragmentu na výchozí:
menu → 5. Terminal → 5. Reset to Default

# Vyčištění PowerShell cache:
menu → 6. PowerShell → 5. Performance → 4. Clear Cache
```

### 🧹 Clean
```powershell
# Smazání starých záloh: menu → 1. Dotfiles → 3. Clean Backups
# Git clean:            menu → 3. Git → 7. Clean
```

---

## 12. Performance nástroje

> Tyto funkce žijí v `profile/core/perf.ps1` — v **tomto** repu (monorepo `martinpaprcka77.github.io`),
> v adresáři `profile/`. Historie: dřív to byl samostatný repo `dotfiles-powershell`, proto se mu
> místy ještě říká „companion“.

### Measure-Profile
```powershell
# Měření doby načtení profilu (vyžaduje načtený profil)
Measure-Profile
# Výstup: breakdown podle sekcí, loaded moduly, doporučení
# Barevné hodnocení: 🟢 <500ms, 🟡 <1000ms, 🔴 >1000ms
```

### Optimize-ModuleLoading
```powershell
# Analýza načtených modulů + lazy loading návrhy
Optimize-ModuleLoading
```

### Clear-PSCache
```powershell
# Vyčištění corrupted cache (ModuleAnalysisCache, StartupProfileData)
Clear-PSCache
# Po spuštění restartuj PowerShell
```

### Get-ProfileSize
```powershell
# Velikost profilu (řádky, byty, soubory)
Get-ProfileSize
```

---

## 13. Status Dashboard

> `Show-Status` žije v `profile/core/status.ps1` — v **tomto** repu, v adresáři `profile/`
> (dřív samostatný repo `dotfiles-powershell`).

```powershell
# Globální health check (vyžaduje načtený companion profil)
Show-Status
```

Kontroluje 6 oblastí s 20+ indikátory:
- **Dotfiles**: profil, bootstrap, PATH, env proměnné
- **Terminal**: fragment, profily, schémata, shell integration
- **PowerShell**: verze, PSReadLine, Toolkit, Starship, moduly
- **VS Code**: code v PATH, committed configs
- **Git**: instalace, oba repozitáře

Výstup: ✅ OK / ⚠️ Warning / ❌ Fail s barevným kódováním.

---

## 14. Aktuální menu struktura

```
HLAVNÍ MENU (8 položek)
├── 1. 🚀 Startup       → health report, module stack, PSModulePath, profily & policy, discovery, shell info, mapa (7 položek)
├── 2. ⚡ Dotfiles       → backup, restore, clean, configure, deps, modernize, windows (7 položek)
├── 3. 🔍 Systém         → Invoke-SystemCheck (disky, služby, síť, procesy)
├── 4. 📋 Git            → status, log, branches, remotes, stash, commit, clean (7 položek)
├── 5. 🖥️  Terminal       → check, generate, backup, restore, reset, schemes, fonts (7 položek)
├── 6. 💻 PowerShell     → modules, modulepath (2 položky)
├── 7. 📝 VS Code        → check, settings, tasks, agent, backup, restore, extensions, open (8 položek)
└── 8. 🚪 Exit
```

Všechny položky mají popisky zobrazené při zvýraznění. Menu používá arrow-key navigaci (↑↓) a inline režim (výstup se zobrazuje pod menu).
