<#
.SYNOPSIS
    Modern interactive menu engine with arrow-key navigation and descriptions.
.DESCRIPTION
    Renders a polished box-drawn frame with column-aligned items, a colored
    `›` cursor on the selected row, and support for:
    - ↑↓ arrow keys + Home/End + Page Up/Down to navigate
    - Enter to confirm (inline mode: runs action, keeps menu visible)
    - Number keys for direct selection
    - / to activate search/filter mode with live matching
    - Escape, q, or Ctrl+C to exit
    - Descriptions: each item can have a dimmed hint shown in its own column
    - Detectors: live status icons (✅⚠️❌) refreshed every render frame
    - Configurable accent color via Get-ToolkitConfig
    - Auto-redraw on terminal resize
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
    # Preserve the caller's insertion order (they pass an [ordered] hashtable
    # precisely so items stay 1,2,3,…). Sorting the keys lexically reordered
    # 10+ item menus to 1,10,11,2,3,… and floated no-number rows to the top.
    $keys = @($normalized.Keys)
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

    # ── Enter alternate screen buffer (no scroll pollution) ────
    $vt = $Host.UI.SupportsVirtualTerminal
    if ($vt) { [Console]::Write("`e[?1049h`e[?25l") }
    else { $prevCursor = [Console]::CursorVisible; [Console]::CursorVisible = $false }
    $selected = 0
    $searchMode = $false
    $searchQuery = ''
    $prevBufferWidth = [Console]::WindowWidth
    $prevSelected = -1  # Track previous selection for partial redraw
    $footer = '↑↓ navigate  ↵ select  Home/End ⇱⇲  Page↑↓  / search  Esc/q exit'
    # The pre-loop draw below renders the first frame, so the loop starts NOT
    # dirty — $dirty only turns on for a resize or search toggle. (Starting
    # dirty made the loop's full-redraw path repaint the whole frame on top of
    # the pre-loop draw, doubling it on first render.)
    $dirty = $false

    # ── Cleanup function used by all exits ───────────────────
    function Leave-Menu {
        if ($vt) { [Console]::Write("`e[?25h`e[?1049l") }
        else { [Console]::CursorVisible = $prevCursor; if (-not $Inline) { Clear-Host } }
    }
    $menuTop = [Console]::CursorTop

    # ── Redraw a single item row ────────────────────────────
    function Redraw-Item {
        param([int]$Index, [string[]]$Keys, [hashtable]$Normalized, [hashtable]$DetectorCache,
              [int]$Selected, [int]$MaxLabelWidth, [int]$MaxDescWidth, [int]$ExtraBudget,
              [string]$Accent)
        $key = $Keys[$Index]
        $item = $Normalized[$key]
        $det = $DetectorCache[$key]
        $detTextRaw = if ($det -and $det.Text) { "$($det.Icon) $($det.Text)" } else { '' }
        $desc = $item.Desc; $detText = $detTextRaw
        $combinedLen = $desc.Length + $(if ($detText) { $detText.Length + 2 } else { 0 })
        if ($combinedLen -gt $ExtraBudget) {
            $detRoom = [Math]::Max(0, $ExtraBudget - $desc.Length - 2)
            $detText = if ($detText -and $detRoom -gt 0) { Get-TruncatedText $detText $detRoom } else { '' }
            if ($desc.Length -gt $ExtraBudget) { $desc = Get-TruncatedText $desc $ExtraBudget; $detText = '' }
        }
        $row = [Console]::CursorTop
        [Console]::SetCursorPosition(2, $row)
        if ($Index -eq $Selected) {
            Write-Host '│  › ' -ForegroundColor DarkGray -NoNewline
            Write-Host $key.PadRight($MaxLabelWidth) -ForegroundColor $Accent -NoNewline
            Write-Host '  ' -NoNewline
            Write-Host $desc.PadRight($MaxDescWidth) -ForegroundColor 'White' -NoNewline
            if ($detText) { Write-Host '  ' -NoNewline; Write-Host $detText -ForegroundColor $Accent -NoNewline }
            Write-Host '  │' -ForegroundColor DarkGray
        } else {
            Write-Host '│     ' -NoNewline
            Write-Host $key.PadRight($MaxLabelWidth) -ForegroundColor 'Gray' -NoNewline
            Write-Host '  ' -NoNewline
            Write-Host $desc.PadRight($MaxDescWidth) -ForegroundColor 'DarkGray' -NoNewline
            if ($detText) { Write-Host '  ' -NoNewline; Write-Host $detText -ForegroundColor 'DarkGray' -NoNewline }
            Write-Host '  │' -ForegroundColor DarkGray
        }
    }

    # ── Render header + footer once ─────────────────────────
    Write-Host "  ╭─ $Title " -ForegroundColor $accent -NoNewline
    Write-Host ('─' * [Math]::Max(0, $boxWidth - $Title.Length - 1)) -ForegroundColor DarkGray
    Write-Host "  │" -ForegroundColor DarkGray

    $detectorCache = @{}
    foreach ($k in $keys) {
        $d = $normalized[$k].Detector
        if ($d) { $detectorCache[$k] = try { & $d } catch { @{ Icon = '❌'; Text = 'detection failed' } } }
    }

    # Two header lines were just written ("╭─ Title" then "│"), so the cursor is
    # two rows below the header — anchor $startTop on the actual header row so the
    # full-redraw path (SetCursorPosition 0,$startTop) repaints it in place rather
    # than one row low.
    $startTop = [Console]::CursorTop - 2  # Row of header
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Redraw-Item -Index $i -Keys $keys -Normalized $normalized -DetectorCache $detectorCache `
            -Selected 0 -MaxLabelWidth $maxLabelWidth -MaxDescWidth $maxDescWidth `
            -ExtraBudget $extraBudget -Accent $accent | Out-Null
    }
    Write-Host '  ╰' -ForegroundColor DarkGray -NoNewline
    Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray -NoNewline
    Write-Host '╯' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "  $footer" -ForegroundColor DarkGray
    $endTop = [Console]::CursorTop  # Track bottom of menu
    Write-Host ''
    $prevSelected = 0

    # ── Input loop — partial update only ──────────────────────
    do {
        # Only check for resize on full redraw trigger
        if ([Console]::WindowWidth -ne $prevBufferWidth) {
            $prevBufferWidth = [Console]::WindowWidth
            $dirty = $true
        }

        if ($dirty) {
            # Resize or search — full redraw
            $boxWidth = [Math]::Min($naturalWidth, [Math]::Max(20, [Console]::WindowWidth - 6))
            $extraBudget = [Math]::Max(0, $boxWidth - $maxLabelWidth - 2)
            # Refresh detector status on every full redraw so the live column
            # reflects current state (function-local cache, never $script:).
            $detectorCache = @{}
            foreach ($k in $keys) {
                $d = $normalized[$k].Detector
                if ($d) { $detectorCache[$k] = try { & $d } catch { @{ Icon = '❌'; Text = 'detection failed' } } }
            }
            [Console]::SetCursorPosition(0, $startTop)
            Write-Host "  ╭─ $Title " -ForegroundColor $accent -NoNewline
            Write-Host ('─' * [Math]::Max(0, $boxWidth - $Title.Length - 1)) -ForegroundColor DarkGray
            Write-Host "  │" -ForegroundColor DarkGray
            for ($i = 0; $i -lt $keys.Count; $i++) {
                Redraw-Item -Index $i -Keys $keys -Normalized $normalized -DetectorCache $detectorCache `
                    -Selected $selected -MaxLabelWidth $maxLabelWidth -MaxDescWidth $maxDescWidth `
                    -ExtraBudget $extraBudget -Accent $accent | Out-Null
            }
            # Search prompt row (only while filtering) lives inside the full
            # redraw — entering/exiting search and each keystroke set $dirty, so
            # it repaints here instead of being appended every loop iteration
            # (which duplicated the footer and drifted the box downward).
            if ($searchMode) {
                Write-Host "  │  🔍 Search: $searchQuery" -ForegroundColor Yellow -NoNewline
                Write-Host (' ' * [Math]::Max(0, $boxWidth - $searchQuery.Length - 10)) -NoNewline
                Write-Host '│' -ForegroundColor DarkGray
            }
            Write-Host '  ╰' -ForegroundColor DarkGray -NoNewline
            Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray -NoNewline
            Write-Host '╯' -ForegroundColor DarkGray
            Write-Host ''
            Write-Host "  $footer" -ForegroundColor DarkGray
            Write-Host ''
            $dirty = $false
        }

        # ── Clear below (handle shrunken renders) ──────────────
        $endTop = [Console]::CursorTop
        # Only clear if we shrunk — avoid scroll-inducing loop
        $remaining = $startTop + $keys.Count + 6 - $endTop
        if ($remaining -gt 1) {
            for ($r = $endTop; $r -lt $endTop + $remaining -and $r -lt [Console]::BufferHeight - 1; $r++) {
                [Console]::SetCursorPosition(0, $r)
                Write-Host (' ' * ($boxWidth + 6)) -NoNewline
            }
        }
        [Console]::SetCursorPosition(0, $endTop)

        # ── Read key ───────────────────────────────────────────
        $keyInfo = [Console]::ReadKey($true)
        
        # Handle terminal resize — redraw immediately
        if ([Console]::WindowWidth -ne $prevBufferWidth) {
            $prevBufferWidth = [Console]::WindowWidth
            $boxWidth = [Math]::Min($naturalWidth, [Math]::Max(20, [Console]::WindowWidth - 6))
            $extraBudget = [Math]::Max(0, $boxWidth - $maxLabelWidth - 2)
        }
        
        # Search mode: capture alphanumeric input. Every change sets $dirty so
        # the full-redraw path repaints the search row + updated selection.
        # $hits (not the automatic $Matches, which -match populates) holds the
        # matching row indexes; the query is regex-escaped so a typed '.' or '('
        # can't throw.
        if ($searchMode) {
            if ($keyInfo.Key -eq 'Escape') { $searchMode = $false; $searchQuery = ''; $dirty = $true }
            elseif ($keyInfo.Key -eq 'Enter') { $searchMode = $false; $dirty = $true }
            else {
                if ($keyInfo.Key -eq 'Backspace') {
                    if ($searchQuery.Length -gt 0) { $searchQuery = $searchQuery.Substring(0, $searchQuery.Length - 1) }
                } elseif ($keyInfo.KeyChar -ne 0 -and -not [Char]::IsControl($keyInfo.KeyChar)) {
                    $searchQuery += $keyInfo.KeyChar
                } else {
                    continue
                }
                $pattern = [regex]::Escape($searchQuery)
                $hits = @(0..($keys.Count - 1) | Where-Object { $keys[$_] -match $pattern })
                if ($hits.Count -gt 0) { $selected = $hits[0] }
                $dirty = $true
            }
            continue
        }
        
        switch ($keyInfo.Key) {
            'UpArrow'    { $selected = if ($selected -gt 0) { $selected - 1 } else { $keys.Count - 1 } }
            'DownArrow'  { $selected = if ($selected -lt $keys.Count - 1) { $selected + 1 } else { 0 } }
            'Home'       { $selected = 0 }
            'End'        { $selected = $keys.Count - 1 }
            'PageUp'     { $selected = [Math]::Max(0, $selected - 10) }
            'PageDown'   { $selected = [Math]::Min($keys.Count - 1, $selected + 10) }
            'OemQuestion' { # / key
                $searchMode = $true; $searchQuery = ''; $dirty = $true
            }
            'Enter'      {
                $chosenKey = $keys[$selected]
                $item = $normalized[$chosenKey]
                if (-not $vt) { [Console]::CursorVisible = $prevCursor }
                if ($Inline) {
                    # Inline mode: clear menu area minimally, run action
                    $clearTo = [Math]::Min($endTop, [Console]::BufferHeight - 1)
                    for ($r = $startTop; $r -le $clearTo; $r++) {
                        [Console]::SetCursorPosition(0, $r)
                        Write-Host (' ' * ($boxWidth + 6)) -NoNewline
                    }
                    [Console]::SetCursorPosition(0, $startTop)
                    & $item.Action
                    Write-Host ''
                    # Menu redraws below the action's output
                    if (-not $vt) { [Console]::CursorVisible = $false }
                    $menuTop = [Console]::CursorTop
                } else {
                    & $item.Action
                    Leave-Menu; return
                }
            }
            'Escape'     { Leave-Menu; return }
            'Q'          { Leave-Menu; return }
            'C'          {
                # Ctrl+C — also exit
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) { Leave-Menu; return }
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
                        if (-not $vt) { [Console]::CursorVisible = $prevCursor }
                        if ($Inline) {
                            $clearTo = [Math]::Min($endTop, [Console]::BufferHeight - 1)
                            for ($r = $startTop; $r -le $clearTo; $r++) {
                                [Console]::SetCursorPosition(0, $r)
                                Write-Host (' ' * ($boxWidth + 6)) -NoNewline
                            }
                            [Console]::SetCursorPosition(0, $startTop)
                            & $item.Action
                            Write-Host ''
                            if (-not $vt) { [Console]::CursorVisible = $false }
                            $menuTop = [Console]::CursorTop
                        } else {
                            & $item.Action
                            Leave-Menu; return
                        }
                    }
                }
            }
        }
        # ── Partial redraw: only update affected rows on nav ──
        if ($prevSelected -ne $selected -and -not $dirty -and -not $searchMode) {
            # $startTop is the header row, +1 is the "│" spacer, so items start
            # at +2. (Kept in sync with the -2 header anchor above.)
            $rowBase = $startTop + 2
            [Console]::SetCursorPosition(0, $rowBase + $prevSelected)
            Redraw-Item -Index $prevSelected -Keys $keys -Normalized $normalized -DetectorCache $detectorCache `
                -Selected $selected -MaxLabelWidth $maxLabelWidth -MaxDescWidth $maxDescWidth `
                -ExtraBudget $extraBudget -Accent $accent | Out-Null
            [Console]::SetCursorPosition(0, $rowBase + $selected)
            Redraw-Item -Index $selected -Keys $keys -Normalized $normalized -DetectorCache $detectorCache `
                -Selected $selected -MaxLabelWidth $maxLabelWidth -MaxDescWidth $maxDescWidth `
                -ExtraBudget $extraBudget -Accent $accent | Out-Null
            [Console]::SetCursorPosition(0, $endTop)
        }
        $prevSelected = $selected
    } while ($true)
}
