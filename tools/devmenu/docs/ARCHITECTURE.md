# devmenu architecture

`devmenu.ps1` is a single portable script. It resolves everything from
`$PSScriptRoot`, so it behaves the same wherever it is installed. The pieces are
pure functions (fragments → merge → resolve) wrapped by one interactive loop.

## Components

```mermaid
classDiagram
    class Invoke_Menu {
        +string Dir
        +string Root
        +scriptblock Lookup
        +object[] Defaults
        +string[] FragmentPaths
        -bool showDetail
        +run() int
    }
    class Read_TargetFragments {
        +string[] Paths
        +object[] run()
    }
    class Merge_Targets {
        +object[] Defaults
        +object[] Fragments
        +object[] run()
    }
    class Resolve_Targets {
        +object[] Targets
        +scriptblock Lookup
        +object[] run()
    }
    class New_LaunchSpec {
        +string Name
        +string[] Arguments
        +string Dir
        +hashtable run()
    }
    class Start_Target {
        +hashtable Spec
        +run()
    }
    class Show_Dashboard {
        +object[] Targets
        +string Dir
        +string Root
        +switch ShowDetail
        +run()
    }
    class Get_ScriptRoot {
        +string run()
    }
    class Get_OsInfo {
        +object run()
    }
    class Get_PowerShellInfo {
        +object run()
    }
    class Get_TerminalAppInfo {
        +object run()
    }
    class Get_ConfigState {
        +object[] Defaults
        +string[] FragmentPaths
        +object run()
    }
    class Get_Locations {
        +string Root
        +string FragmentDir
        +string[] FragmentPaths
        +object run()
    }
    class Show_Diagnostics {
        +object[] Defaults
        +string Root
        +string FragmentDir
        +string[] FragmentPaths
        +run()
    }

    Invoke_Menu --> Read_TargetFragments : loads
    Invoke_Menu --> Merge_Targets : merges
    Invoke_Menu --> Resolve_Targets : resolves
    Invoke_Menu --> Show_Dashboard : renders
    Invoke_Menu --> New_LaunchSpec : builds
    Invoke_Menu --> Show_Diagnostics : reports on 'd'
    New_LaunchSpec --> Start_Target : starts
    Invoke_Menu --> Get_ScriptRoot : roots paths
    Show_Diagnostics --> Get_OsInfo
    Show_Diagnostics --> Get_PowerShellInfo
    Show_Diagnostics --> Get_TerminalAppInfo
    Show_Diagnostics --> Get_ConfigState
    Show_Diagnostics --> Get_Locations
    Get_ConfigState --> Read_TargetFragments
    Get_ConfigState --> Merge_Targets
    Start_Target --> "OS process" : Start-Process
```

`Target` records flow between the stages:

| Stage | Produces |
| --- | --- |
| `Read-TargetFragments` | `{ Name, Arguments, Enabled, Source }` |
| `Merge-Targets` | enabled specs, wins by `Name` over built-ins |
| `Resolve-Targets` | `{ Name, Arguments, Available, Path, Source }` |
| `New-LaunchSpec` | `hashtable` ready for `Start-Process @Spec` |

## Interaction sequence

```mermaid
sequenceDiagram
    actor User
    participant Menu as Invoke-Menu
    participant Frag as Read-TargetFragments
    participant Merge as Merge-Targets
    participant Res as Resolve-Targets
    participant Spawn as Start-Target
    participant OS as Windows

    User->>Menu: run (optionally -Dir)
    Menu->>Frag: read devmenu.d/*.json
    Frag-->>Menu: fragment targets
    Menu->>Merge: built-ins + fragments
    Merge-->>Menu: merged specs
    loop until quit
        Menu->>Res: look up each target on PATH
        Res-->>Menu: Available + Path
        Menu-->>User: dashboard
        alt number
            User->>Menu: selection
            Menu->>Spawn: New-LaunchSpec + Start-Process
            Spawn->>OS: new window
        else r
            User->>Menu: refresh
        else l
            User->>Menu: toggle detail
        else q
            User->>Menu: quit
        end
    end
```

## Location independence

```mermaid
flowchart TD
    A[devmenu.ps1 invoked] --> B[Root = PSScriptRoot]
    B --> C[FragmentDir = Root/devmenu.d]
    C --> D[Load *.json in filename order]
    D --> E[Merge over built-in targets]
    E --> F[Resolve each Name on PATH]
    F --> G[Render dashboard with accurate paths]
    G --> H{Input}
    H -->|number| I[Start-Process in new window]
    H -->|r| F
    H -->|l| G
    H -->|q| J[Exit 0]
```

No stage reads the current directory for its own files; the current directory is
only used as the default working directory for launched processes.

## Detection sources

`Get-Diagnostics` (rendered by `Show-Diagnostics`) gathers, without launching
anything:

| Detector | Source |
| --- | --- |
| `Get-OsInfo` | `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`, `OSVersion`, runtime architecture, `WT_SESSION` |
| `Get-PowerShellInfo` | `$PSVersionTable`, `Get-Process -Id $PID`, `Get-Command -All` for `pwsh`/`pwsh-preview`/`powershell` |
| `Get-TerminalAppInfo` | `Get-Command wt`, AppModel `Repository\Packages` key names for stable/canary versions |
| `Get-ConfigState` | fragment files via `Read-TargetFragments` + `Merge-Targets` versus built-ins |
| `Get-Locations` | `$PSCommandPath`/`$PSScriptRoot` and known paths relative to the root |

```mermaid
sequenceDiagram
    actor User
    participant Menu as Invoke-Menu
    participant Diag as Show-Diagnostics
    participant OS as Get-OsInfo
    participant PS as Get-PowerShellInfo
    participant WT as Get-TerminalAppInfo
    participant Cfg as Get-ConfigState
    User->>Menu: d
    Menu->>Diag: render report
    Diag->>OS: read OS/terminal
    Diag->>PS: read PS installs
    Diag->>WT: read wt versions
    Diag->>Cfg: compare fragments vs built-ins
    Diag-->>User: environment / powershell / terminal / config / locations
```
