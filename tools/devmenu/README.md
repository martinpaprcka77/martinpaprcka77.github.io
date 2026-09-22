# devmenu

A portable, location-independent launcher menu for `pi`, `pwsh`, `wt`, and `cmd`
on Windows. It shows a dashboard of available targets and starts the one you pick
in a new window.

## Requirements

- Windows
- PowerShell 7 (`pwsh`) on `PATH`
- Optional: Windows Terminal (`wt`) for its own entry

## Run

```powershell
.\devmenu.cmd
# or
pwsh -NoProfile -ExecutionPolicy Bypass -File .\devmenu.ps1
```

The menu stays open after launching, so you can start several targets in a row.

### Keys

| Input | Action |
| --- | --- |
| `1`..`N` | Launch that target in a new window |
| `r` | Refresh PATH availability |
| `l` | Toggle detail (arguments and fragment source) |
| `d` | Show the diagnostics report |
| `q` | Quit |

Targets that are not on `PATH` are marked `[ ]` and are never launched.

### Working directory

Launched processes start in your current directory by default. Override it:

```powershell
pwsh -File .\devmenu.ps1 -Dir C:\src
```

## Diagnostics

Press `d` in the menu, or run with `-Diagnose` for a one-shot report, to see
what devmenu detected:

```powershell
pwsh -File .\devmenu.ps1 -Diagnose
```

| Section | Detects |
| --- | --- |
| environment | OS product/version/build, architecture, user@host, current dir, terminal host |
| powershell | running version/edition/path, plus every `pwsh`, `pwsh-preview`, and `powershell` on `PATH` |
| windows terminal | whether `wt` is present, its path, and the installed **stable** and **canary** versions |
| config | whether targets are `default` or `changed`, fragment files, and which targets were added/overridden/removed |
| locations | script path/root, shim, readme, architecture doc, fragment dir, sample files, and the pi settings path |

Detection is read-only and launches nothing. The Windows Terminal version is read
from the AppModel registry package keys; the OS version from the `CurrentVersion`
registry key; PowerShell installs from `Get-Command -All`. The OS product is
reported as **Windows 11** when the build is 22000 or newer, since the registry
still says "Windows 10" on Windows 11.

## Portability

Everything is resolved relative to the script itself, never the current
directory or an absolute path:

- script root: `$PSScriptRoot`
- fragments: `<script root>/devmenu.d/*.json`

That means you can move, rename, or drop `devmenu.ps1` anywhere (or symlink it
onto `PATH`) and it keeps working. `devmenu.cmd` locates the script with `%~dp0`.

## Fragments

Add or override targets without editing the script. Drop JSON files into
`devmenu.d/` next to the script; they are read in filename order and merged over
the built-in targets by `name` (case-insensitive).

```json
{
  "targets": [
    { "name": "pi",   "arguments": [] },
    { "name": "pwsh", "arguments": ["-NoLogo", "-NoProfile"] },
    { "name": "bash", "arguments": ["-l"] },
    { "name": "cmd",  "enabled": false }
  ]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | yes | Command resolved on `PATH`; also the merge key |
| `arguments` | no | Fixed arguments passed to the command |
| `enabled` | no | `false` removes a target (defaults to `true`) |

A top-level array is also accepted. A later fragment or the script wins over an
earlier one. Use `-FragmentDir <path>` to load fragments from elsewhere.

## Test

```powershell
pwsh -NoProfile -File .\devmenu.ps1 -SelfTest
```

Exits `0` when every assertion passes, `1` otherwise. Covers fragment parsing and
merging, target resolution, launch-spec construction, and script-root detection.

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the component and
sequence diagrams (Mermaid).
