# 00 — PowerShell 7 bootstrap lifecycle (Windows 11)

> Scope: how a `pwsh.exe` session is born and configured, stage by stage, and the
> edge cases that silently hijack it. This is the host environment the toolbox runs
> **inside** — it is not this repo's own control flow. Read it first so the later
> docs (architecture, reference) have a frame.
>
> Local-only: every diagnostic in this repo observes this flow with local checks;
> nothing here reaches the network.
>
> **Live map:** [`../PowerShell-Startup-Map.html`](../PowerShell-Startup-Map.html) renders these
> stages as a green/yellow/red health dashboard (5 lanes, live). Feed it JSON from
> `ops/Get-PowerShellStartupHealth.ps1`.

## Stage taxonomy — the terms are not interchangeable

People say "bootstrap", "launcher", "loader", "host init", and "engine init"
as if they were the same thing. They are not — each is a distinct phase, owned by
a different actor, and that distinction is what lets you place a failure in the
exact subsystem that caused it.

| Term | What it actually means | Owned by |
|------|------------------------|----------|
| **OS bootstrap** | UEFI → Windows Boot Manager → kernel → Terminal/login | Windows, *not* PowerShell |
| **Launcher** | `pwsh.exe` parses switches (`-NoProfile`, `-File`, `-Command`), selects host, resolves its own path | PowerShell |
| **Loader** | Locate `$PSHOME`; load hostfxr → .NET runtime/CLR → `System.Management.Automation.dll` | pwsh host process |
| **Host initialization** | Create the runspace host (ConsoleHost / WT / VS Code / SSH) and its streams | host |
| **Engine bootstrap** | Create `SessionState`, register cmdlets, load providers, set automatic variables (`$PSHOME` `$PROFILE` `$HOME` `$PID` `$PSVersionTable`), execution policy | PowerShell engine |
| **Configuration bootstrap** | Read `powershell.config.json`, GPO, WDAC/AppLocker → `LanguageMode` | OS policy + engine |
| **Module bootstrap** | Build `PSModulePath`, register locations, enable auto-loading | engine |
| **Profile bootstrap** | Resolve and run the four `$PROFILE` tiers | user code |
| **Interactive initialization** | Enable auto-loading, start PSReadLine, show prompt, wait for input | engine + user |

## Canonical phases (0–8) and the five lanes

The poster's five lanes are a *presentation* grouping; the canonical model has
nine phases. Lane 2 holds both Loader and Host; lane 3 holds Engine and
Configuration; lane 4 holds Module and Profile.

| Phase | Mapped lane | Checkpoint | Silent skip? | Where this repo acts |
|-------|-------------|-----------|:---:|----------------------|
| 0. OS bootstrap (UEFI → kernel → Terminal) | *(before Lane 1)* | power on | — | *(Windows)* |
| 1. Launcher | **Lane 1 — Launcher** | `$PID` | no | `ops/Add-WTProfiles.ps1`, `Toolkit/Public/Menu/menu-terminal.ps1` |
| 2. Loader | **Lane 2 — Loader & Host** | `$PSVersionTable` | no (fatal) | *(host)* |
| 3. Host initialization | **Lane 2 — Loader & Host** | `$Host` | no | *(host / companion)* |
| 4. Engine bootstrap | **Lane 3 — Engine & Session State** | `$ExecutionContext` | yes | `ops/precheck.ps1` (observes) |
| 5. Configuration bootstrap | **Lane 3 — Engine & Session State** | `LanguageMode` | yes | `ops/precheck.ps1` (observes) |
| 6. Module bootstrap | **Lane 4 — Profiles & Modules** | `$env:PSModulePath` | yes | `Toolkit/Public/ModulePath.ps1` (`Get/Add/Remove/Reset/Export/Import/Test-PSModulePath`) |
| 7. Profile bootstrap | **Lane 4 — Profiles & Modules** | `$PROFILE` | yes | `Toolkit/Public/Menu/menu-dotfiles.ps1` (backup/restore), `ops/precheck.ps1` (observes) |
| 8. Interactive initialization | **Lane 5 — Interactive Shell** | `Get-Command` | yes | this repo's menus + diagnostics |

> The **silent-skip** column is the important one: phases 2–3 fail *loudly* (the
> process dies), but phases 4–8 fail *quietly* — PowerShell finishes booting
> **degraded** and you only notice when a specific alias or module is missing.

### Complete mapping

```text
WINDOWS BOOTSTRAP (phase 0)
│
├─ UEFI / POST
├─ Windows Kernel
└─ User launches pwsh.exe

POWERSHELL BOOTSTRAP
│
├─ 1. Launcher
│    ├─ Parse arguments
│    ├─ Select host
│    └─ Resolve executable
│
├─ 2. Loader
│    ├─ Locate PSHOME
│    ├─ Load .NET
│    └─ Load assemblies
│
├─ 3. Host Initialization
│    ├─ Create ConsoleHost
│    └─ Create Runspace
│
├─ 4. Engine Bootstrap
│    ├─ SessionState
│    ├─ Variables
│    └─ Providers
│
├─ 5. Configuration Bootstrap
│    ├─ Config JSON
│    ├─ GPO
│    └─ WDAC / AppLocker
│
├─ 6. Module Bootstrap
│    └─ Build PSModulePath
│
├─ 7. Profile Bootstrap
│    └─ Execute profile files
│
└─ 8. Interactive Initialization
     ├─ PSReadLine
     ├─ Prompt
     └─ Ready
```

> **Numbering note:** the poster and Mermaid flows below use the coarse
> **7-stage PowerShell** numbering (Host folded into Loader; Engine +
> Configuration under Session State; Module + Profile merged). The canonical
> **0–8** table above is the finer breakdown. The two map by *name*, not number.

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║          PowerShell 7 Bootstrap — Windows 11  (with edge cases)              ║
╚══════════════════════════════════════════════════════════════════════════════╝

   ┌──────────────┐
   │  Power On    │
   └──────┬───────┘
          ▼
   ┌──────────────┐      ⚠ EDGE: Fast Startup can skip a real cold boot;
   │ UEFI / POST  │         stale driver state persists between "shutdowns".
   └──────┬───────┘
          ▼
   ┌──────────────┐
   │  Windows     │
   │  Kernel      │
   └──────┬───────┘
          ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 1 ── LAUNCH  (user runs pwsh.exe / Windows Terminal / VS Code)         ║
╚══════════════════════════════════════════════════════════════════════════════╝
          │
          ▼
   ┌─────────────────────────┐
   │ Parse command-line args │
   └──────┬──────────────────┘
          │
    ┌─────┴──────┬───────────┬────────────┬──────────────┐
    ▼            ▼           ▼            ▼              ▼
 -NoProfile  -NoLogo    -Command      -File         (no flag)
    │            │           │            │              │
    │            │           │            │              │
    └────────────┴───────────┴────────────┴──────┬───────┘
                                                 ▼
  ⚠ EDGE: -NoProfile skips STAGE 5 & 6 entirely  │
     → aliases/modules from profile NEVER load   │
                                                 ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 2 ── LOADER / HOST INIT                                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
          │
          ▼
   ┌─────────────────────────┐
   │ Locate $PSHOME          │   default: C:\Program Files\PowerShell\7
   │ (pwsh.exe directory)    │
   └──────┬──────────────────┘
          │
    ┌─────┴───────────────────────────┬──────────────────────────┐
    ▼                                 ▼                          ▼
 x64 install                    ARM64 install              x86 (32-bit)
    │                                 │                          │
    └─────────────┬───────────────────┴──────────────┬───────────┘
                  ▼                                  ▼
        ┌──────────────────┐              ⚠ EDGE: "Side-by-side"
        │ Load .NET 8+     │                 installs — pwsh may pick
        │ runtime          │                 the WRONG $PSHOME if PATH
        └────────┬─────────┘                 has multiple entries.
                 │
    ┌────────────┴─────────────┐
    ▼                          ▼
 ✓ .NET present            ✗ .NET missing / corrupted
    │                          │
    │                          ▼
    │                  ┌─────────────────────────────┐
    │                  │ FATAL: pwsh.exe exits       │
    │                  │ "You must install .NET"     │
    │                  └─────────────────────────────┘
    ▼
   ┌──────────────────────────┐
   │ Determine host type      │  ConsoleHost / Windows Terminal / VS Code
   │ Create host window       │  / ISE-host / remote SSH
   └────────┬─────────────────┘
            │
   ⚠ EDGE: Antivirus / EDR blocks pwsh.exe on first launch
      → process killed before SessionState init, no error dialog

╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 3 ── SESSION STATE INIT  (checks + environment)                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
            │
            ▼
   ┌────────────────────────────┐
   │ Read powershell.config.json│
   └─────┬──────────────────────┘
         │
   ┌─────┴─────────┬──────────────┬─────────────────┐
   ▼               ▼              ▼                 ▼
 ✓ Valid        ✗ Malformed     GPO overrides    WDAC / AppLocker
   │            JSON            config           policy present
   │               │              │                 │
   │               ▼              ▼                 ▼
   │        ┌───────────┐  ┌────────────┐  ┌──────────────────────┐
   │        │ Warn +    │  │ Config     │  │ LanguageMode forced  │
   │        │ use       │  │ IGNORED,   │  │ to ConstrainedLanguage│
   │        │ defaults  │  │ GPO wins   │  │ → Add-Type, [Ref],   │
   │        └───────────┘  └────────────┘  │   COM, .NET types    │
   │                                       │   BLOCKED            │
   │                                       └──────────────────────┘
   ▼
   ┌────────────────────────────┐
   │ Set automatic variables    │
   │  $PSHOME  $HOME  $PROFILE  │
   │  $PSVersionTable           │
   └─────┬──────────────────────┘
         │
         ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 4 ── $env:PSModulePath  BUILD                                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
         │
         ▼
   ┌──────────────────────────────────────────────────────────────┐
   │ Default module search paths (semicolon-separated):            │
   │                                                               │
   │  1. C:\Users\<user>\Documents\PowerShell\Modules              │
   │  2. C:\Program Files\PowerShell\Modules                       │
   │  3. C:\Program Files\PowerShell\7\Modules                     │
   │  4. C:\Program Files\WindowsPowerShell\Modules   (PS 5.1)     │
   │  5. C:\WINDOWS\System32\WindowsPowerShell\v1.0\Modules        │
   └─────┬────────────────────────────────────────────────────────┘
         │
   ┌─────┴────────────┬─────────────────────┬────────────────────┐
   ▼                  ▼                     ▼                    ▼
 ✓ All exist     ⚠ OneDrive KFM       ⚠ Network share      ⚠ Machine-wide
   │             redirects Documents   (roaming profile)   PSModulePath GPO
   │                  │                     │                    │
   │                  ▼                     ▼                    ▼
   │        Path becomes:            Path becomes:        GPO overwrites
   │        C:\Users\<u>\OneDrive\   \\fileserver\...     user PSModulePath
   │          Documents\PowerShell\                       entirely
   │            Modules
   │             │                        │
   │             ▼                        ▼
   │      ┌──────────────────┐   ┌───────────────────────────┐
   │      │ Modules still    │   │ Offline / VPN down?       │
   │      │ work IF OneDrive │   │ → Import-Module FAILS     │
   │      │ files are        │   │ → slow startup (SMB       │
   │      │ "Always keep on  │   │   timeouts ~30s per path) │
   │      │ this device"     │   └───────────────────────────┘
   │      │                  │
   │      │ If Files On-     │
   │      │ Demand: module   │
   │      │ is a 0-byte stub │
   │      │ → Import fails   │
   │      └──────────────────┘
   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 5 ── PROFILE RESOLUTION                                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
         │
         ▼
   ┌──────────────────────────────────────────────────────────────┐
   │ Resolve $PROFILE paths (first found in each tier wins):       │
   │                                                               │
   │  AllUsersAllHosts       $PSHOME\profile.ps1                   │
   │  AllUsersCurrentHost    $PSHOME\Microsoft.PowerShell_profile  │
   │  CurrentUserAllHosts    $HOME\Documents\PowerShell\profile    │
   │  CurrentUserCurrentHost $HOME\...\Microsoft.PowerShell_profile│
   └─────┬────────────────────────────────────────────────────────┘
         │
   ┌─────┴──────────┬────────────────────┬──────────────────────┐
   ▼                ▼                    ▼                      ▼
 ✓ Standard     ⚠ OneDrive KFM       ⚠ Roaming/           ⚠ $HOME points
   Documents    redirected           network profile       to wrong place
     │                │                    │                      │
     │                ▼                    ▼                      ▼
     │        $PROFILE now           \\server\users\...   e.g. service
     │        points at OneDrive     → offline = profile   account, SYSTEM,
     │        → if not pinned,         SILENTLY skipped     or OneDrive
     │          profile is a stub     → no aliases, no      sync conflict
     │          → profile "loads"       modules, no errors
     │          but does NOTHING
     │                │                    │
     │                └────────┬───────────┘
     │                         ▼
     │              ┌──────────────────────────────────┐
     │              │ SYMPTOM: "my aliases are gone    │
     │              │ on my new PC but work on old one"│
     │              └──────────────────────────────────┘
     ▼
   ┌──────────────────────────────┐
   │ Execution Policy check       │
   └─────┬────────────────────────┘
         │
   ┌─────┴──────────┬───────────────────┬────────────────────┐
   ▼                ▼                   ▼                    ▼
 Restricted     RemoteSigned        AllSigned            Bypass /
 (default       profile.ps1         profile.ps1          Unrestricted
  on Win11       UNSIGNED            UNSIGNED
  client)          │                    │
    │              ▼                    ▼
    ▼        ┌───────────┐        ┌───────────┐
┌──────────┐ │ BLOCKED:  │        │ BLOCKED:  │
│ PROFILES │ │ not       │        │ not       │
│ SKIPPED  │ │ digitally │        │ digitally │
│ entirely │ │ signed    │        │ signed    │
└──────────┘ └───────────┘        └───────────┘
    │              │                    │
    └──────────────┴────────────────────┘
                   │
   ⚠ EDGE: Zone.Identifier / "Mark of the Web"
      Profile copied from internet / OneDrive → blocked even
      under RemoteSigned until Unblock-File is run.

╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 6 ── PROFILE EXECUTION  (in order, top → bottom)                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
                   │
                   ▼
   ┌───────────────────────────────────┐
   │ 1. AllUsersAllHosts               │  ← admin-controlled
   └────────────┬──────────────────────┘
                ▼
   ┌───────────────────────────────────┐
   │ 2. AllUsersCurrentHost            │
   └────────────┬──────────────────────┘
                ▼
   ┌───────────────────────────────────┐
   │ 3. CurrentUserAllHosts            │  ← user-controlled
   └────────────┬──────────────────────┘
                ▼
   ┌───────────────────────────────────┐
   │ 4. CurrentUserCurrentHost         │  ← highest precedence
   └────────────┬──────────────────────┘
                │
   ┌────────────┴─────────────┬──────────────────┬─────────────────┐
   ▼                          ▼                  ▼                 ▼
 Profile defines:         Profile throws    Profile sources    Profile sets
 - aliases                an error          another script     $PSModuleAuto
 - functions                 │              (missing file)      LoadingPreference
 - Import-Module             │                  │              = 'Nothing'
 - PSReadLine opts           ▼                  ▼                 │
 - prompt override      ┌──────────┐      ┌──────────┐            ▼
                        │ ERROR    │      │ Silent   │      ┌──────────────┐
                        │ written  │      │ fail,    │      │ Modules NEVER│
                        │ to stderr│      │ rest of  │      │ auto-load;   │
                        │ BUT shell│      │ profile  │      │ must Import- │
                        │ still    │      │ ABORTED  │      │ Module by    │
                        │ starts   │      └──────────┘      │ hand         │
                        └──────────┘                        └──────────────┘
                        ⚠ EDGE: a broken profile does NOT
                           stop PowerShell — it just looks
                           "half configured"

╔══════════════════════════════════════════════════════════════════════════════╗
║ STAGE 7 ── INTERACTIVE SESSION READY                                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
                │
                ▼
   ┌──────────────────────────────────────────────┐
   │  • PSReadLine active, prompt shown            │
   │  • Aliases + functions from profiles live     │
   │  • Modules auto-load on first cmdlet use      │
   │    (unless disabled / constrained)            │
   └──────────────────────────────────────────────┘
```

## Edge-case cheat sheet (symptom → cause → fix)

| Symptom | Likely cause | Fix |
|---|---|---|
| "My aliases vanished on my new PC" | OneDrive KFM moved `Documents`; profile is a Files-On-Demand stub | Right-click profile → *Always keep on this device*, or set `$PROFILE` explicitly |
| Slow startup (~30 s) | `PSModulePath` includes an unreachable UNC path | Remove network path from `PSModulePath`, or ensure VPN is up |
| `profile.ps1 cannot be loaded because running scripts is disabled` | Execution Policy = `Restricted` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Profile loads but does nothing | `Zone.Identifier` Mark-of-the-Web on the file | `Unblock-File $PROFILE` |
| `Add-Type` / `[Reflection.Assembly]` blocked | WDAC / AppLocker forced `ConstrainedLanguage` | Check `$ExecutionContext.SessionState.LanguageMode`; talk to admin |
| `pwsh.exe` exits immediately with no error | AV/EDR killed process, or missing .NET runtime | Check Event Viewer → Application; reinstall .NET Desktop Runtime |
| Wrong `$PSHOME` / features missing | Multiple side-by-side PS 7 installs on `PATH` | Pin full path in Windows Terminal profile, or fix `PATH` order |
| Modules never auto-load | `$PSModuleAutoLoadingPreference = 'None'` set in profile | Remove that line, or `Import-Module` explicitly |
| Profile works in console but not in VS Code | Different host → `Microsoft.VSCode_profile.ps1` is a separate file | Duplicate logic, or dot-source the console profile from the VS Code one |

> Key insight: **stages 3–6 each have a "silent skip" branch.** PowerShell is
> deliberately forgiving — a missing profile, an unreachable module path, or a
> policy block usually does *not* stop the shell. It just starts *less
> configured*, which is why these failures are hard to notice until a specific
> alias or module is missing. `ops/precheck.ps1` exists to surface exactly
> these stages locally.

---

## Bootstrap flow (Mermaid)

The same stages 1–7 as a rendered flowchart, including the two exits
(missing .NET, blocked profiles).

```mermaid
flowchart TD
    A[Power On] --> B[UEFI / POST]
    B --> C[Windows Kernel]
    C --> D[Stage 1: Launch pwsh.exe]

    D --> E[Parse Command-Line Arguments]
    E --> F{-NoProfile?}
    F -->|Yes| Z1[Skip Profile Resolution and Execution]
    F -->|No| G[Stage 2: Loader and Host Initialization]

    G --> H[Locate PSHOME]
    H --> I[Load .NET Runtime]
    I --> J{.NET Available?}
    J -->|No| X1[Fatal Exit<br/>Install or Repair .NET]
    J -->|Yes| K[Determine Host Type<br/>ConsoleHost / WT / VS Code / SSH]

    K --> L[Stage 3: Session State Initialization]
    L --> M[Read powershell.config.json]
    M --> N{Valid Config?}
    N -->|No| N1[Warn and Use Defaults]
    N -->|Yes| O[Apply Configuration]
    N1 --> P
    O --> P

    P[Initialize Variables<br/>PSHOME HOME PROFILE PSVersionTable]
    P --> Q[Stage 4: Build PSModulePath]
    Q --> R[User Modules]
    Q --> S[Program Files Modules]
    Q --> T[Built-in Modules]
    Q --> U[Windows PowerShell Modules]

    R --> V[Stage 5: Profile Resolution]
    S --> V
    T --> V
    U --> V

    V --> W[Resolve Four Profile Locations]
    W --> X{Execution Policy Allows?}
    X -->|No| X2[Profiles Skipped or Blocked]
    X -->|Yes| Y[Stage 6: Profile Execution]

    Y --> Y1[AllUsersAllHosts]
    Y1 --> Y2[AllUsersCurrentHost]
    Y2 --> Y3[CurrentUserAllHosts]
    Y3 --> Y4[CurrentUserCurrentHost]
    Y4 --> Y5{Profile Error?}
    Y5 -->|Yes| Y6[Error Written to stderr<br/>Shell Continues]
    Y5 -->|No| Y7[Profile Complete]

    Z1 --> Z
    X2 --> Z
    Y6 --> Z
    Y7 --> Z

    Z[Stage 7: Interactive Session Ready]
    Z --> AA[Prompt Visible]
    AA --> AB[PSReadLine Active]
    AB --> AC[Aliases and Functions Loaded]
    AC --> AD[Module Auto-loading Available]
```

## Silent-skip map (Mermaid)

Symptom-first view: where a stage can degrade *without* stopping the shell.

```mermaid
flowchart LR
    A[PowerShell Starts] --> B{Launch Issue?}
    B -->|Process Exits| C[Check .NET Runtime]
    B -->|Process Exits| D[Check AV or EDR Logs]
    B -->|Runs| E[Profile Loaded?]

    E -->|No| F[Check -NoProfile Flag]
    E -->|No| G[Check Execution Policy]
    E -->|No| H[Verify PROFILE Path]
    E -->|No| I[Check OneDrive KFM]

    E -->|Yes| J[Aliases Present?]
    J -->|No| K[Inspect Profile Errors]
    J -->|No| L[Check Dot-Sourced Scripts]
    J -->|No| M[Check Roaming Paths]

    J -->|Yes| N[Modules Loading?]
    N -->|No| O[Inspect PSModulePath]
    N -->|No| P[Check VPN or UNC Shares]
    N -->|No| Q[Check AutoLoadingPreference]

    N -->|Yes| R[Language Features Working?]
    R -->|No| S[Check LanguageMode]
    S --> T{ConstrainedLanguage?}
    T -->|Yes| U[WDAC or AppLocker Policy]
    T -->|No| V[Investigate Module or Runtime Issues]

    R -->|Yes| W[Healthy Session]
```

## Diagnostic decision tree (dark mode + clickable)

Symptom → diagnosis → fix, colour-coded for dark themes. Use it top-down on a
specific machine.

> **Renderer note:** `classDef` colours render everywhere Mermaid does (GitHub,
> Azure DevOps, MkDocs, Obsidian). The `click` directives are honoured by MkDocs
> Material, Obsidian, and the Mermaid Live Editor; **GitHub strips click
> interactions** for security, so there the nodes render coloured but not
> clickable. Links still work in the live [`../PowerShell-Startup-Map.html`](../PowerShell-Startup-Map.html).

```mermaid
flowchart TD
    A[PowerShell Problem Reported]
    A --> B{Does pwsh.exe open?}

    B -->|No| C[Check Event Viewer]
    B -->|No| D[Verify .NET Runtime]
    B -->|No| E[Check AV / EDR Logs]
    C --> C1[Repair .NET Runtime]
    D --> C1
    E --> C2[Whitelist pwsh.exe]

    B -->|Yes| F{Prompt Appears Quickly?}
    F -->|No| G[Measure Startup Time]
    G --> H[Profile Import Delays]
    G --> I[UNC or VPN Paths]
    G --> J[OneDrive Sync Delays]
    H --> H1[Remove Slow Imports]
    I --> I1[Remove Dead Network Paths]
    J --> J1[Pin Files Offline]

    F -->|Yes| K{Aliases Missing?}
    K -->|Yes| L[Inspect PROFILE]
    L --> M[Test-Path PROFILE]
    M --> N[Check Execution Policy]
    N --> O[Check OneDrive KFM]
    O --> O1[Always Keep on Device]
    N --> N1[Set RemoteSigned]
    L --> L1[Correct PROFILE Path]

    K -->|No| P{Modules Missing?}
    P -->|Yes| Q[Inspect PSModulePath]
    Q --> R[Test Import-Module]
    R --> S[Verify VPN / UNC Access]
    Q --> Q1[Fix Module Paths]
    S --> S1[Restore Connectivity]

    P -->|No| T{Add-Type Blocked?}
    T -->|Yes| U[Check LanguageMode]
    U --> V{ConstrainedLanguage?}
    V -->|Yes| W[WDAC / AppLocker Policy]
    W --> W1[Request Policy Exception]
    V -->|No| X[Investigate Module Conflict]

    T -->|No| Y{VS Code Different?}
    Y -->|Yes| Z[Review VS Code Profile]
    Z --> Z1[Dot-Source Shared Profile]
    Y -->|No| AA[Healthy Session]

    click C "https://learn.microsoft.com/windows/client-management/troubleshoot-event-viewer" "Open Event Viewer Troubleshooting"
    click D "https://learn.microsoft.com/powershell/" "PowerShell Documentation"
    click N "https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-executionpolicy" "Execution Policy"
    click Q "https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_PSModulePath" "PSModulePath"
    click U "https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_language_modes" "Language Modes"
    click W "https://learn.microsoft.com/windows/security/application-security/application-control/" "Application Control"
    click Z "https://code.visualstudio.com/docs/languages/powershell" "VS Code PowerShell Extension"

    classDef healthy fill:#1B5E20,stroke:#66BB6A,color:#ffffff,stroke-width:2px;
    classDef decision fill:#F9A825,stroke:#FFD54F,color:#000000,stroke-width:2px;
    classDef issue fill:#8E2424,stroke:#EF5350,color:#ffffff,stroke-width:2px;
    classDef diagnostic fill:#0D47A1,stroke:#64B5F6,color:#ffffff,stroke-width:2px;
    classDef fix fill:#6A1B9A,stroke:#BA68C8,color:#ffffff,stroke-width:2px;

    class AA healthy;
    class B,F,K,P,T,V decision;
    class C,D,E,G,H,I,J,L,M,N,O,Q,R,S,U,W,X,Z diagnostic;
    class C1,C2,H1,I1,J1,L1,N1,O1,Q1,S1,W1,Z1 fix;
```

### Colour legend

| Colour | Meaning |
|--------|---------|
| 🟢 Green | Healthy / expected outcome |
| 🟡 Amber | Decision point |
| 🔵 Blue | Diagnostic action |
| 🟣 Purple | Remediation step |
| 🔴 Red | Failure condition |

### Optional dark theme (Mermaid v10+ sites)

```yaml
theme: base
themeVariables:
  background: "#0D1117"
  primaryColor: "#1F6FEB"
  primaryTextColor: "#FFFFFF"
  primaryBorderColor: "#58A6FF"
  lineColor: "#8B949E"
  secondaryColor: "#238636"
  tertiaryColor: "#21262D"
  edgeLabelBackground: "#161B22"
```

### Symptom → fix quick links

Remediation nodes can be made clickable to internal anchors (edit the `click`
targets to match your published sections).

```mermaid
flowchart LR
    A[Aliases Missing] --> B[Check PROFILE]
    B --> C[Fix PROFILE Path]
    B --> D[Set RemoteSigned]
    B --> E[Unblock Profile]

    click B "https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles" "Profile Diagnostics"
    click C "https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles" "Fix PROFILE Path"
    click D "https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-executionpolicy" "Execution Policy Fix"
    click E "https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/unblock-file" "Remove Mark-of-the-Web"
```

## Diagnostic commands

All of these are **local-only** (no network I/O).

```powershell
# Which PowerShell am I actually running?
$PSHOME
$PSVersionTable

# Which profiles exist?
$PROFILE
$PROFILE.CurrentUserAllHosts
$PROFILE.CurrentUserCurrentHost

# Execution policy
Get-ExecutionPolicy -List

# Language mode
$ExecutionContext.SessionState.LanguageMode

# Module search paths
$env:PSModulePath -split ';'

# Profile timing
Measure-Command { . $PROFILE }

# See all profile files
$PROFILE | Format-List *

# Verify profile exists
Test-Path $PROFILE

# Check for Mark-of-the-Web
Get-Item $PROFILE -Stream *

# Remove Mark-of-the-Web
Unblock-File $PROFILE
```

> **Live version:** open [`../PowerShell-Startup-Map.html`](../PowerShell-Startup-Map.html) and load JSON from
> `ops/Get-PowerShellStartupHealth.ps1` to color these same stages
> green/yellow/red for your current machine.
