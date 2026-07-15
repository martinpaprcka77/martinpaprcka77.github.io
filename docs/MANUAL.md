# Manuál — PowerShell Dotfiles Ecosystem

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
fungují jako doplněk, ne jako jediný způsob ovládání. Aktuální 9-položková struktura je
podrobně popsaná v [§15](#15-aktuální-menu-struktura); zde jen stručný přehled:

| # | Položka | Akce |
|---|---------|------|
| 1 | 📊 Status | `Show-Status` (vyžaduje načtený profil (profile/)) |
| 2 | ⚡ Dotfiles | Otevře Dotfiles submenu |
| 3 | 🔍 Systém | Spustí `Invoke-SystemCheck` |
| 4 | 🐳 Docker | Otevře Docker submenu |
| 5 | 📋 Git | Otevře Git submenu |
| 6 | 🖥️ Terminal | Otevře Terminal submenu |
| 7 | 💻 PowerShell | Otevře PowerShell submenu |
| 8 | 📝 VS Code | Otevře VS Code submenu |
| 9 | 🚪 Exit | Ukončí menu |

### Použití

```powershell
# Přes bin wrapper (doporučeno)
menu

# Přes modul
Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1
Start-MainMenu

# Přímé spuštění skriptu
~/.config/powershell/toolkit/menu/menu-main.ps1
```

---

## 3. Docker menu (`Show-DockerMenu`)

### Položky

| # | Akce | Příkaz |
|---|------|--------|
| 1 | Běžící kontejnery | `docker ps -a` |
| 2 | Images | `docker images` |
| 3 | Využití zdrojů | `docker stats --no-stream` |
| 4 | Využití disku | `docker system df` |
| 5 | Logy kontejneru | `docker logs --tail 50 <název>` |
| 6 | Zpět | Návrat do hlavního menu |

### Použití

```powershell
# Přes hlavní menu: volba 1
menu → 1

# Přímo
~/.config/powershell/toolkit/menu/menu-docker.ps1
```

---

## 4. Git menu (`Show-GitMenu`)

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

## 5. Systémová diagnostika (`check` / `Invoke-SystemCheck`)

Spustí kompletní kontrolu systému:

```powershell
check
```

### Co kontroluje

| Kontrola | Funkce | Výstup |
|----------|--------|--------|
| **Disky** | `Get-DiskStatus` | DeviceID, Size(GB), Free(GB), Used% |
| **Služby** | `Get-ServiceStatus` | WinRM, W3SVC, Docker, Spooler, WSearch |
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

## 6. Windows Terminal profily (`Add-WTProfiles.ps1`)

Vygeneruje **JSON fragment extension** — Microsoftem doporučený způsob od WT 1.24+. Nikdy needituje
uživatelovo `settings.json` přímo, takže nemusí odstraňovat `//` komentáře ani nic parsovat/zapisovat
zpět do existujícího souboru. Žádné GUID — profily se párují podle `name`.

### Co dělá

1. Zkontroluje, jestli fragment už existuje (`-Force` pro přepsání)
2. Detekuje WSL distribuce (`wsl -l -q`) a přidá jim vlastní profily
3. Sestaví profily: `Menu`, `Projekty` (nové, vlastní — s povolenou shell integrací),
   `PowerShell 7`, `Windows PowerShell 5.1` (**aktualizují existující vestavěné profily** stejného
   jména — záměrně jen `icon`/`tabTitle`, nikdy font/colorScheme/shell-integration, aby se tiše
   nepřepsalo uživatelovo vlastní nastavení výchozích profilů)
4. Načte barevná schémata z `configs/wt-schemes.json` (single source of truth)
5. Zálohuje existující fragment (`.backup.<timestamp>`)
6. Uloží fragment bez BOM (UTF-8) do `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json`

### Použití

```powershell
# Normální spuštění
~/.config/powershell/toolkit/scripts/Add-WTProfiles.ps1

# Suchý běh (WhatIf) — zobrazí, co by udělal, nic nemění
~/.config/powershell/toolkit/scripts/Add-WTProfiles.ps1 -WhatIf

# Přepsat existující fragment
~/.config/powershell/toolkit/scripts/Add-WTProfiles.ps1 -Force
```

### Přidané/aktualizované profily

| Název | Typ | Spouští | Výchozí adresář |
|-------|-----|---------|------------------|
| Menu | nový, vlastní | `pwsh.exe` | `~/.config/powershell/toolkit` |
| Projekty | nový, vlastní | `pwsh.exe` | `~/Projects/work` |
| PowerShell 7 | update vestavěného | `pwsh.exe` | `~` |
| Windows PowerShell 5.1 | update vestavěného | `powershell.exe` | `~` |
| WSL: `<distro>` | auto-detekováno | `wsl.exe -d <distro>` | `//wsl$/Ubuntu/home` |

### Obnova ze zálohy

```powershell
# Záloha je vedle fragmentu:
# dotfiles.json.backup.20260708-120000

Copy-Item "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json.backup.*" `
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json"
```

---

## 7. Generování ikon (`Generate-Icons.ps1`)

Vygeneruje 4 placeholder PNG ikony (32×32 px) pomocí `System.Drawing`.

```powershell
~/.config/powershell/toolkit/scripts/Generate-Icons.ps1

# Vlastní výstupní adresář
~/.config/powershell/toolkit/scripts/Generate-Icons.ps1 -OutputDir "D:\my-icons"
```

### Vygenerované ikony

| Soubor | Písmeno | Barva pozadí |
|--------|---------|-------------|
| `menu.png` | M | DodgerBlue |
| `projects.png` | P | ForestGreen |
| `pwsh7.png` | 7 | DarkCyan |
| `pwsh5.png` | 5 | SteelBlue |

---

## 8. Bezpečnost — API klíče

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

## 9. Utility funkce

### `Test-Admin`
```powershell
if (Test-Admin) { Write-Host "Máš admin práva" }
```

### `Get-ScriptDirectory`
```powershell
$dir = Get-ScriptDirectory  # adresář volajícího skriptu
```

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

## 10. Pester testy

```powershell
# Spuštění testů (vyžaduje Pester)
Install-Module Pester -Force
Invoke-Pester ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1
```

---

## 11. Rozšíření

### Přidání nového nástroje do menu

```powershell
# V menu-main.ps1 přidej položku:
$items = [ordered]@{
    # ... existující ...
    '4' = { & "~\.config\powershell\toolkit\bin\muj-nastroj.ps1" }
}

# Vytvoř bin/muj-nastroj.ps1:
# Import-Module ~/.config/powershell/toolkit/Toolkit/Toolkit.psd1 -Force
# ... tvůj kód ...
```

### Přidání nové funkce do Toolkit

```powershell
# 1. Vytvoř funkci v lib/ (nebo nový .ps1)
# 2. Přidej jméno funkce do:
#    - Toolkit.psm1: Export-ModuleMember -Function @(...)
#    - Toolkit.psd1: FunctionsToExport = @(...)
```

---

## 12. CRUD operace — Check, Backup, Restore, Reset, Clean

Každé submenu obsahuje konzistentní operace pro správu:

### 📊 Check Status
```powershell
# Globální dashboard (menu → 1. Status)
Show-Status

# Nebo z PowerShell submenu:
menu → 6. PowerShell → 1. Check Status
```
Kontroluje: Dotfiles profily, WT fragment, VS Code configs, moduly, Git repozitáře, Docker.

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
# Smazání starých záloh: menu → 2. Dotfiles → 6. Clean Backups
# Docker prune:         menu → 3. Docker → 7. Prune
# Git clean:            menu → 4. Git → 7. Clean
```

---

## 13. Performance nástroje

### Measure-Profile
```powershell
# Detailní měření doby načtení profilu (menu → 6. PowerShell → 5. Performance → 1. Run Benchmark)
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

## 14. Status Dashboard

```powershell
# Globální health check (menu → 1. Status)
Show-Status
```

Kontroluje 6 oblastí s 20+ indikátory:
- **Dotfiles**: profil, bootstrap, PATH, env proměnné
- **Terminal**: fragment, profily, schémata, shell integration
- **PowerShell**: verze, PSReadLine, Toolkit, Starship, moduly
- **VS Code**: code v PATH, committed configs
- **Git**: instalace, oba repozitáře
- **Docker**: instalace, běžící kontejnery

Výstup: ✅ OK / ⚠️ Warning / ❌ Fail s barevným kódováním.

---

## 15. Aktuální menu struktura

```
HLAVNÍ MENU (9 položek)
├── 1. 📊 Status        → Show-Status (globální dashboard)
├── 2. ⚡ Dotfiles       → install, update, backup, restore, clean, configure, deps, windows (9 položek)
├── 3. 🔍 Systém         → Invoke-SystemCheck (disky, služby, síť, procesy)
├── 4. 🐳 Docker         → check, containers, images, stats, disk, logs, prune (7 položek)
├── 5. 📋 Git            → check, log, branches, remotes, stash, commit, clean (7 položek)
├── 6. 🖥️  Terminal       → check, generate, backup, restore, reset, schemes, fonts (7 položek)
├── 7. 💻 PowerShell     → check, edit, reload, backup, restore, performance, modules (7 položek)
├── 8. 📝 VS Code        → check, settings, tasks, agent, backup, restore, extensions, open (8 položek)
└── 9. 🚪 Exit
```

Všechny položky mají popisky zobrazené při zvýraznění. Menu používá arrow-key navigaci (↑↓) a inline režim (výstup se zobrazuje pod menu).
