# Účel a návrhová filozofie

## Proč tento projekt vznikl

Standardní PowerShell profil (`$PROFILE`) má několik zásadních problémů, které tento projekt řeší:

### 1. OneDrive přepisuje vše

Windows 11 (a částečně Windows 10) přesměrovává `Documents` do OneDrivu. To znamená:
- `$HOME\Documents\PowerShell\` → `$HOME\OneDrive\Documents\PowerShell\`
- `$HOME\Documents\WindowsPowerShell\` → `$HOME\OneDrive\Documents\WindowsPowerShell\`

PowerShell 7 navíc ukládá moduly do `$HOME\Documents\PowerShell\Modules` — tedy do OneDrivu. To způsobuje:
- Pomalé načítání modulů (síťové zpoždění OneDrivu)
- Konflikty při synchronizaci mezi stroji
- Problémy s přístupem offline

**Řešení:** Profily jsou v `~/.config/powershell/` (mimo OneDrive). `PSModulePath` je opraven na
`%LOCALAPPDATA%\...\Modules` (PS5.1 i PS7). Na některých strojích může být i samotné Known Folder
API (registr `User Shell Folders`) poškozené — `profile/lib/paths.ps1`'s `Resolve-DocumentsPath`
ověřuje výsledek (`Test-RootedPath`) a padá zpátky na `$HOME\Documents`, místo aby zkolabovala na
zdánlivě platné, ale ve skutečnosti nepoužitelné hodnotě.

### 2. Jeden monolitický profil

Výchozí přístup "jeden soubor `$PROFILE`" neškáluje. Při přidávání funkcí, aliasů a nastavení se z profilu stane nepřehledný soubor o stovkách řádků.

**Řešení:** Modulární architektura:
- `profile/core/` — sdílené napříč všemi prostředími
- `profile/ps5/` / `profile/ps7/` — verze-specifické
- `profile/hosts/` — hostitel-specifické

### 3. Nepřenositelnost mezi stroji

Každý stroj má vlastní kopii profilu. Změny se ručně kopírují nebo se na ně zapomíná.

**Řešení:** Vše verzováno v Gitu. Jeden příkaz (`irm .../remote-install.ps1 | iex`) nastaví nový
stroj bez ohledu na to, odkud se spouští.

### 4. Manuální nastavení Windows Terminálu

Přidání profilů do Windows Terminálu vyžadovalo ruční editaci `settings.json`, náchylnou k
chybám (JSON syntax, komentáře `//`, správné GUID).

**Řešení:** `toolkit/scripts/Add-WTProfiles.ps1` generuje JSON fragment extension (WT 1.24+) —
žádné GUID, žádná editace uživatelova `settings.json`.

### 5. Cross-repo coupling (vyřešeno sloučením)

Dokud existovaly `dotfiles-powershell` a `dotfiles-tools` odděleně, menu volalo funkce
(`Show-Status`, `Measure-Profile`, …), které existovaly jen v druhém repozitáři — vždy hrozilo
selhání, pokud nebyl "companion" profil načtený. `$env:DOTFILES_TOOLS`/`$env:DOTFILES_PWSH` byly
dva nezávislé zdroje pravdy, které se mohly rozejít.

**Řešení:** Jeden repozitář, dva podadresáře (`profile/`, `toolkit/`). `$env:DOTFILES_TOOLS` se
nyní vždy odvozuje z `$env:DOTFILES_PWSH` (sourozenecký adresář) — nemůže se rozejít. Ostatní
self-referenční vyhledávání (skripty uvnitř `toolkit/`) používají `$PSScriptRoot`-relativní
fallback místo spoléhání na env proměnnou.

## Návrhová rozhodnutí

### Proč `~/.config/powershell/` a ne `$PROFILE`?

- Konvence XDG (`~/.config/`) je standard na Linuxu a čím dál častější i na Windows.
- Je to mimo OneDrive.
- Umožňuje verzovat celý adresář, ne jen jeden soubor.
- Beze změny i po sloučení do jednoho repa — `profile/` a `toolkit/` jsou teď jen podadresáře
  téhož klonu.

### Proč jeden repozitář (dřív dva)?

Původně dva repozitáře — oddělení zájmů, nezávislá instalace, jiná frekvence změn. V praxi to
ale vytvářelo přesně tu cross-repo-coupling třídu chyb popsanou výše, a bootstrapper musel klonovat
dvě věci místo jedné. Sloučení do jednoho repa (`profile/` + `toolkit/` podadresáře) tohle
strukturálně odstraňuje — jedna session, jeden modulový scope, žádné hádání "je druhý repo
načtený?". Portál (`index.html`) zůstává na kořenové URL, protože sloučení proběhlo do
`martinpaprcka77.github.io` samotného, ne do nového repozitáře.

Zvažováno bylo i zachování dvou repozitářů — pokud ekosystém v budoucnu naroste natolik, že si
zaslouží nezávislé release cykly, rozdělení zpět je zdokumentovaná možnost v `docs/ROADMAP.md`,
ne provedený krok.

### Proč `%LOCALAPPDATA%\...\Modules`?

- `LOCALAPPDATA` je vždy lokální (není v OneDrivu).
- Je to doporučené umístění pro uživatelské moduly ve Windows.
- PowerShell tam standardně nehledá, tak to explicitně přidáváme — pro PS5.1 i PS7, s odlišnými
  podadresáři (`WindowsPowerShell`/`PowerShell`), protože moduly nejsou vždy kompatibilní napříč
  verzemi.

### Proč `Get-SecretKey` místo plaintextu?

- API klíče v kódu = bezpečnostní riziko.
- `Microsoft.PowerShell.SecretManagement` je standardní trezor.
- Fallback na `$env:VAR` umožňuje testování bez trezoru.

### Proč benchmark profilu?

- Výkon profilu je kritický — čekání 2 sekundy při každém otevření terminálu je nepřijatelné.
- Měření umožňuje identifikovat pomalé části.
- Výchozí vypnuto (žádná režie).

## Co tento projekt NENÍ

- **Není to framework** — je to minimální sada skriptů, ne závislost.
- **Není to "one-size-fits-all"** — každý si to může upravit; je to výchozí bod, ne dogma.
- **Není to náhrada za `oh-my-posh` nebo `starship`** — ty lze přidat volitelně v `profile/ps7/profile.ps1`.
