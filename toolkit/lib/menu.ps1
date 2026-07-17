<#
.SYNOPSIS
    Modern interactive menu engine with arrow-key navigation and descriptions.
.DESCRIPTION
    Renders a minimal, borderless list — a title, a thin accent underline, and
    a column-aligned item list with a colored `›` cursor on the selected row
    (no boxed frame, no inverse-block highlight). Supports:
    - ↑↓ arrow keys to move selection
    - Enter to confirm (inline mode: runs action, keeps menu visible)
    - Number keys for direct selection
    - Escape / q to exit
    - Descriptions: each item can have a dimmed hint shown in its own column
    - Configurable accent color via Get-ToolkitConfig
.PARAMETER Title
    Menu title displayed at the top.
.PARAMETER Items
    Ordered hashtable. Two formats supported:
    - Simple:  key = { scriptblock }
    - With desc/detector: key = @{ Action = { scriptblock }; Desc = "What it does";
      Detector = { @{ Icon = '✅'|'⚠️'|'❌'; Text = '...' } } }
    Detector is optional. It's re-evaluated once per render frame (every
    keypress) into a function-local cache — never $script:-scoped, keeping
    this engine's existing fully-stateless design. A throwing detector
    degrades to a '❌ detection failed' row instead of crashing the menu.
    Keep detector bodies cheap (Get-Command/Test-Path/cached config reads) —
    no network calls, no subprocess spawns; they run on every keypress.
.PARAMETER Inline
    If true, selecting an item runs its action WITHOUT clearing the screen,
    then returns to the menu (rolled/expanded feel). Default: false (full screen).
.EXAMPLE
    Show-Menu -Title "MAIN MENU" -Inline -Items ([ordered]@{
        "1. Docker" = @{ Action = { Show-DockerMenu }; Desc = "Container management" }
    })
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/menu.ps1
    Requires console host that supports [Console]::ReadKey (ConsoleHost, WT).
#>

function Show-Menu {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [hashtable]$Items,

        [switch]$Inline
    )

    # ── Normalize items to uniform structure ───────────────────
    $normalized = [ordered]@{}
    foreach ($k in $Items.Keys) {
        $v = $Items[$k]
        if ($v -is [scriptblock]) {
            $normalized[$k] = @{ Action = $v; Desc = '' }
        } elseif ($v -is [hashtable]) {
            $normalized[$k] = @{
                Action   = if ($v.Action -is [scriptblock]) { $v.Action } else { {} }
                Desc     = if ($v.Desc) { $v.Desc } else { '' }
                Detector = if ($v.Detector -is [scriptblock]) { $v.Detector } else { $null }
            }
        }
    }
    $keys = @($normalized.Keys | Sort-Object)
    if ($keys.Count -eq 0) { throw "Show-Menu: Items collection is empty — at least one menu item is required" }

    # ── Load color config ──────────────────────────────────────
    $accent = 'Cyan'
    try {
        $cfg = Get-ToolkitConfig -ErrorAction SilentlyContinue
        if ($cfg -and $cfg.menu.colorScheme) {
            $accent = $cfg.menu.colorScheme
        }
    } catch { }

    # ── Dimensions ─────────────────────────────────────────────
    $maxLabelWidth = ($keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    # Check descriptions too
    $maxDescWidth = ($normalized.Values | ForEach-Object { $_.Desc.Length } | Measure-Object -Maximum).Maximum
    # Detector width: evaluated once here (not per-frame) purely to size the
    # layout consistently — the actual displayed values are still recomputed
    # fresh every render frame in the loop below (see $detectorCache there).
    $maxDetectorWidth = 0
    foreach ($k in $keys) {
        $d = $normalized[$k].Detector
        if ($d) {
            $r = try { & $d } catch { @{ Icon = '❌'; Text = 'detection failed' } }
            if ($r -and $r.Text) { $maxDetectorWidth = [Math]::Max($maxDetectorWidth, $r.Text.Length + 4) }
        }
    }
    $naturalWidth = [Math]::Max($Title.Length, $maxLabelWidth + $maxDescWidth + $maxDetectorWidth) + 4
    # Clamp to the terminal's actual width — a long Desc/Detector string
    # otherwise pushes a row past the console width, the terminal wraps the
    # line, and the layout breaks (field-reported against the old boxed
    # version). Leave a small margin for the "  › " row prefix; never go
    # narrower than a sane floor.
    $maxAvailableWidth = [Math]::Max(20, [Console]::WindowWidth - 6)
    $boxWidth = [Math]::Min($naturalWidth, $maxAvailableWidth)
    # Fit budget for Desc + Detector text — depends only on $boxWidth/$maxLabelWidth
    # (both fixed above), so it's computed once here rather than per item per frame.
    $extraBudget = [Math]::Max(0, $boxWidth - $maxLabelWidth - 2)

    # Truncates $Text to fit $MaxLength, appending an ellipsis if it doesn't.
    # Local to Show-Menu — a rendering detail, not part of the public API.
    function Get-TruncatedText {
        param([string]$Text, [int]$MaxLength)
        if ($MaxLength -le 0) { return '' }
        if ($Text.Length -le $MaxLength) { return $Text }
        if ($MaxLength -eq 1) { return '…' }
        return $Text.Substring(0, $MaxLength - 1) + '…'
    }

    # ── Hide cursor ────────────────────────────────────────────
    $prevCursor = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    $selected = 0
    $footer = '↑↓ navigate  ↵ select  Esc/q exit'

    # Fixed redraw anchor — every frame redraws over the SAME rows, so pure
    # navigation (arrow keys, no action run) never moves the list. Previously
    # this was recomputed from "current cursor position" every frame, which
    # is wherever the PREVIOUS frame's cleanup left the cursor (just below
    # the list) — so the whole thing drifted one render-height further down
    # the screen on every single keypress, including arrow keys that change
    # nothing but the highlighted row (field-reported). Only Inline mode's
    # action-execution branches intentionally advance $menuTop afterward, so
    # the next redraw appears below the action's own output (the "rolled/
    # expanded feel" the docstring describes) — that shift is real, wanted
    # motion; the arrow-key drift was not.
    $menuTop = [Console]::CursorTop

    # ── Render loop ────────────────────────────────────────────
    do {
        [Console]::SetCursorPosition(0, $menuTop)
        $startTop = $menuTop

        # ── Header — plain title + thin accent underline, no box ───
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor $accent
        Write-Host "  $('─' * $boxWidth)" -ForegroundColor DarkGray

        # ── Detector cache — fresh every render frame (every keypress), so
        # displayed status never goes stale mid-session. Function-local, not
        # $script:-scoped: dies with this call, matching the rest of this
        # engine's stateless design. A throwing detector degrades to a
        # visible "detection failed" row instead of crashing the menu.
        $detectorCache = @{}
        foreach ($k in $keys) {
            $d = $normalized[$k].Detector
            if ($d) {
                $detectorCache[$k] = try { & $d } catch { @{ Icon = '❌'; Text = 'detection failed' } }
            }
        }

        # ── Items — column-aligned, cursor-marked, no inverse block ─
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $key = $keys[$i]
            $item = $normalized[$key]
            $det = $detectorCache[$key]
            $detTextRaw = if ($det -and $det.Text) { "$($det.Icon) $($det.Text)" } else { '' }

            # Fit Desc + Detector text into the available width, trimming the
            # detector text first, then the description, instead of letting
            # a long status string push the row past the console width.
            $desc = $item.Desc
            $detText = $detTextRaw
            $combinedLen = $desc.Length + $(if ($detText) { $detText.Length + 2 } else { 0 })
            if ($combinedLen -gt $extraBudget) {
                $detRoom = [Math]::Max(0, $extraBudget - $desc.Length - 2)
                $detText = if ($detText -and $detRoom -gt 0) { Get-TruncatedText $detText $detRoom } else { '' }
                if ($desc.Length -gt $extraBudget) {
                    $desc = Get-TruncatedText $desc $extraBudget
                    $detText = ''
                }
            }

            # Selected row gets a colored cursor + accent key instead of a
            # separate near-duplicate render branch — only the prefix/colors differ.
            if ($i -eq $selected) {
                $prefix = '  › '; $keyColor = $accent; $descColor = 'White'; $detColor = $accent
            } else {
                $prefix = '    '; $keyColor = 'Gray'; $descColor = 'DarkGray'; $detColor = 'DarkGray'
            }
            Write-Host $prefix -ForegroundColor $keyColor -NoNewline
            Write-Host $key.PadRight($maxLabelWidth) -ForegroundColor $keyColor -NoNewline
            if ($desc) {
                Write-Host '  ' -NoNewline
                Write-Host $desc.PadRight($maxDescWidth) -ForegroundColor $descColor -NoNewline
            } elseif ($maxDescWidth -gt 0) {
                Write-Host (' ' * ($maxDescWidth + 2)) -NoNewline
            }
            if ($detText) {
                Write-Host '  ' -NoNewline
                Write-Host $detText -ForegroundColor $detColor -NoNewline
            }
            Write-Host ''
        }

        # ── Footer ─────────────────────────────────────────────
        Write-Host ''
        Write-Host "  $footer" -ForegroundColor DarkGray

        # ── Clear below (handle shrunken renders) ──────────────
        $endTop = [Console]::CursorTop
        $maxRow = [Console]::BufferHeight - 1
        for ($r = $endTop; $r -le $startTop + $keys.Count + 8 -and $r -le $maxRow; $r++) {
            [Console]::SetCursorPosition(0, $r)
            Write-Host (' ' * ($boxWidth + 6)) -NoNewline
        }
        [Console]::SetCursorPosition(0, $endTop)

        # ── Read key ───────────────────────────────────────────
        $keyInfo = [Console]::ReadKey($true)
        switch ($keyInfo.Key) {
            'UpArrow'    { $selected = if ($selected -gt 0) { $selected - 1 } else { $keys.Count - 1 } }
            'DownArrow'  { $selected = if ($selected -lt $keys.Count - 1) { $selected + 1 } else { 0 } }
            'Enter'      {
                $chosenKey = $keys[$selected]
                $item = $normalized[$chosenKey]
                [Console]::CursorVisible = $prevCursor
                if ($Inline) {
                    # Inline mode: clear just the menu area, run action, then redraw
                    for ($r = $startTop; $r -le $endTop -and $r -le [Console]::BufferHeight - 1; $r++) {
                        [Console]::SetCursorPosition(0, $r)
                        Write-Host (' ' * ($boxWidth + 10)) -NoNewline
                    }
                    [Console]::SetCursorPosition(0, $startTop)
                    Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray
                    & $item.Action
                    Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray
                    Write-Host ''
                    # Continue the loop — menu redraws below the action's output
                    # (intentional advance, unlike the fixed anchor used for pure navigation)
                    [Console]::CursorVisible = $false
                    $menuTop = [Console]::CursorTop
                } else {
                    Clear-Host
                    & $item.Action
                    return
                }
            }
            'Escape'     {
                [Console]::CursorVisible = $prevCursor
                if (-not $Inline) { Clear-Host }
                return
            }
            'Q'          {
                [Console]::CursorVisible = $prevCursor
                if (-not $Inline) { Clear-Host }
                return
            }
            default {
                # Number key shortcut
                $num = $null
                if ($keyInfo.Key -ge 'D0' -and $keyInfo.Key -le 'D9') {
                    $num = [int]($keyInfo.Key - 'D0')
                } elseif ($keyInfo.Key -ge 'NumPad0' -and $keyInfo.Key -le 'NumPad9') {
                    $num = [int]($keyInfo.Key - 'NumPad0')
                }
                if ($num -ne $null) {
                    $match = $keys | Where-Object { $_ -match "^\s*${num}\." }
                    if ($match) {
                        $item = $normalized[$match]
                        [Console]::CursorVisible = $prevCursor
                        if ($Inline) {
                            for ($r = $startTop; $r -le $endTop -and $r -le [Console]::BufferHeight - 1; $r++) {
                                [Console]::SetCursorPosition(0, $r)
                                Write-Host (' ' * ($boxWidth + 10)) -NoNewline
                            }
                            [Console]::SetCursorPosition(0, $startTop)
                            Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray
                            & $item.Action
                            Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray
                            Write-Host ''
                            [Console]::CursorVisible = $false
                            $menuTop = [Console]::CursorTop
                        } else {
                            Clear-Host
                            & $item.Action
                            return
                        }
                    }
                }
            }
        }
    } while ($true)
}

<#
.SYNOPSIS
    Self-invocation guard for menu scripts. Dot-sources the Toolkit module
    if this script was invoked directly (not dot-sourced into a module).
.PARAMETER MenuFunction
    Name of the Show-*Menu function to call after module is loaded.
.EXAMPLE
    if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Show-DockerMenu' }
#>
function Initialize-MenuMenu {
    param([Parameter(Mandatory)][string]$MenuFunction)
    $modulePath = Join-Path $PSScriptRoot '..\Toolkit\Toolkit.psd1'
    if (Test-Path $modulePath) { Import-Module $modulePath -Force }
    & $MenuFunction
}
