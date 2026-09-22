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
fungují jako doplněk, ne jako jediný způsob ovládání. Aktuální 8-položková struktura je
podrobně popsaná v [§13](#13-aktuální-menu-struktura); zde jen stručný přehled:

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

## 3. Startup menu (`Show-StartupMenu`)

Procesově orientované submenu — mapuje fáze z `toolkit/docs/00-bootstrap.md`.

| # | Akce |
|---|------|
| 1 | Health report (fáze 1–7, lokální) |
| 2 | Module stack (fáze 4/6) |
| 3 | PSModulePath (fáze 4) |
| 4 | Profile & policy (fáze 5) |
| 5 | Discovery (fáze 7) |
| 6 | Otevřít startup mapu |
| 7 | Zpět |

### Použití

```powershell
# Přes hlavní menu: volba 1
menu → 1

# Přímo
~/.config/powershell/toolkit/Toolkit/Public/Menu/menu-startup.ps1
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

## 6. Bezpečnost — API klíče

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

## 7. Utility funkce

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

## 8. Pester testy

```powershell
# Spuštění testů (vyžaduje Pester)
Install-Module Pester -Force
Invoke-Pester ~/.config/powershell/toolkit/tests/Toolkit.Tests.ps1
```

---

## 9. Rozšíření

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
#    - Toolkit.psm1: FunctionsToExport -Function @(...)
#    - Toolkit.psd1: FunctionsToExport = @(...)
```

---

## 10. CRUD operace — Check, Backup, Restore, Reset, Clean

Každé submenu obsahuje konzistentní operace pro správu:

### 📊 Check Status
```powershell
# Globální dashboard (menu → 1. Status)
Show-Status

# Nebo z PowerShell submenu:
menu → 6. PowerShell → 1. Check Status
```
Kontroluje: Dotfiles profily, VS Code configs, moduly, Git repozitáře.

### 💾 Backup
```powershell
# Záloha všech profilů (menu → 2. Dotfiles → 4. Backup Profiles)
# Ukládá do: ~/.config/powershell/backups/

# Záloha profile.ps1 (menu → 6. PowerShell → 4. Backup Profile)
# Záloha VS Code configs (menu → 7. VS Code → 5. Backup Settings)
```

### ♻️ Restore
```powershell
# Obnova z časově označené zálohy:
# menu → Dotfiles/PowerShell/VS Code → Restore
# Vyber číslo zálohy ze seznamu
```

### ♻️ Reset
```powershell
# Vyčištění PowerShell cache:
menu → 6. PowerShell → 5. Performance → 4. Clear Cache
```

### 🧹 Clean
```powershell
# Smazání starých záloh: menu → 2. Dotfiles → 6. Clean Backups
# Git clean:            menu → 4. Git → 7. Clean
```

---

## 11. Performance nástroje

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

## 12. Status Dashboard

```powershell
# Globální health check (menu → 1. Status)
Show-Status
```

Kontroluje 5 oblastí s 20+ indikátory:
- **Dotfiles**: profil, bootstrap, PATH, env proměnné
- **PowerShell**: verze, PSReadLine, Toolkit, Starship, moduly
- **VS Code**: code v PATH, committed configs
- **Git**: instalace, oba repozitáře
- **Startup**: bootstrap fáze, lokální health report

Výstup: ✅ OK / ⚠️ Warning / ❌ Fail s barevným kódováním.

---

## 13. Aktuální menu struktura

```
HLAVNÍ MENU (8 položek)
├── 1. 🚀 Startup        → health, module stack, PSModulePath, profily & policy, discovery, shell info, mapa (7 položek)
├── 2. ⚡ Dotfiles       → backup, restore, clean, configure, deps, modernize, windows (7 položek)
├── 3. 🔍 Systém         → Invoke-SystemCheck (disky, služby, síť, procesy)
├── 4. 📋 Git            → status, log, branches, remotes, stash, commit, clean (7 položek)
├── 5. 🖥️  Terminal       → check, generate, backup, restore, reset, schemes, fonts (7 položek)
├── 6. 💻 PowerShell     → modules, modulepath (2 položky)
├── 7. 📝 VS Code        → check, settings, tasks, agent, backup, restore, extensions, open (8 položek)
└── 8. 🚪 Exit
```

Všechny položky mají popisky zobrazené při zvýraznění. Menu používá arrow-key navigaci (↑↓) a inline režim (výstup se zobrazuje pod menu).
