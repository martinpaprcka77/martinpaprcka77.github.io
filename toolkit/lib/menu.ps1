<#
.SYNOPSIS
    Modern interactive menu engine with arrow-key navigation and descriptions.
.DESCRIPTION
    Renders a highlighted menu using box-drawing characters. Supports:
    - ↑↓ arrow keys to move selection
    - Enter to confirm (inline mode: runs action, keeps menu visible)
    - Number keys for direct selection
    - Escape / q to exit
    - Descriptions: each item can have a dimmed hint shown when highlighted
    - Configurable color scheme via Get-ToolkitConfig
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
    if ($keys.Count -eq 0) { Write-Warn "Menu has no items."; return }

    # ── Load color config ──────────────────────────────────────
    $accent = 'Cyan'
    $highlightFg = 'Black'
    $highlightBg = 'Cyan'
    try {
        $cfg = Get-ToolkitConfig -ErrorAction SilentlyContinue
        if ($cfg -and $cfg.menu.colorScheme) {
            $accent = $cfg.menu.colorScheme
            $highlightFg = 'Black'
            $highlightBg = $accent
        }
    } catch { }

    # ── Dimensions ─────────────────────────────────────────────
    $maxLabelWidth = ($keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    # Check descriptions too
    $maxDescWidth = ($normalized.Values | ForEach-Object { $_.Desc.Length } | Measure-Object -Maximum).Maximum
    # Detector width: evaluated once here (not per-frame) purely to size the
    # box consistently — the actual displayed values are still recomputed
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
    # otherwise pushes the box past the console width, the terminal wraps the
    # line, and the box-drawing border breaks (field-reported). Leave room
    # for the "  │ "/"│" frame (6 cols); never go narrower than a sane floor.
    $maxAvailableWidth = [Math]::Max(20, [Console]::WindowWidth - 6)
    $boxWidth = [Math]::Min($naturalWidth, $maxAvailableWidth)

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

    # ── Render loop ────────────────────────────────────────────
    do {
        [Console]::SetCursorPosition(0, [Console]::CursorTop)
        $startTop = [Console]::CursorTop

        # ── Header ─────────────────────────────────────────────
        Write-Host ''
        Write-Host "  ╭$('─' * $boxWidth)╮" -ForegroundColor DarkGray
        Write-Host "  │ " -ForegroundColor DarkGray -NoNewline
        Write-Host $Title.PadRight($boxWidth - 1) -ForegroundColor $accent -NoNewline
        Write-Host '│' -ForegroundColor DarkGray
        Write-Host '  ├' -ForegroundColor DarkGray -NoNewline
        Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray -NoNewline
        Write-Host '┤' -ForegroundColor DarkGray

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

        # ── Items ──────────────────────────────────────────────
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $key = $keys[$i]
            $item = $normalized[$key]
            $det = $detectorCache[$key]
            $detTextRaw = if ($det -and $det.Text) { "$($det.Icon) $($det.Text)" } else { '' }

            # Fit Desc + Detector text into the box width, trimming the
            # detector text first, then the description, instead of letting
            # a long status string push the row past the console width.
            $extraBudget = [Math]::Max(0, $boxWidth - $key.Length - 4)
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

            $detLen = if ($detText) { $detText.Length + 2 } else { 0 }
            $pad = [Math]::Max(0, $boxWidth - $key.Length - ($desc.Length + 2) - $detLen)

            if ($i -eq $selected) {
                Write-Host '  │ ' -ForegroundColor DarkGray -NoNewline
                Write-Host '▸' -ForegroundColor $accent -NoNewline
                Write-Host " $key " -ForegroundColor $highlightFg -BackgroundColor $highlightBg -NoNewline
                if ($desc) {
                    Write-Host ' ' -BackgroundColor $highlightBg -NoNewline
                    Write-Host $desc -ForegroundColor $highlightFg -BackgroundColor $highlightBg -NoNewline
                }
                if ($detText) {
                    Write-Host '  ' -BackgroundColor $highlightBg -NoNewline
                    Write-Host $detText -ForegroundColor $highlightFg -BackgroundColor $highlightBg -NoNewline
                }
                Write-Host (' ' * [Math]::Max(0, $pad - 1)) -BackgroundColor $highlightBg
                Write-Host '│' -ForegroundColor DarkGray
            } else {
                Write-Host '  │  ' -ForegroundColor DarkGray -NoNewline
                Write-Host $key -ForegroundColor White -NoNewline
                if ($desc) {
                    Write-Host '  ' -NoNewline
                    Write-Host $desc -ForegroundColor DarkGray -NoNewline
                }
                if ($detText) {
                    Write-Host '  ' -NoNewline
                    Write-Host $detText -ForegroundColor DarkGray -NoNewline
                }
                Write-Host (' ' * [Math]::Max(0, $pad)) -NoNewline
                Write-Host '│' -ForegroundColor DarkGray
            }
        }

        # ── Footer ─────────────────────────────────────────────
        Write-Host '  ╰' -ForegroundColor DarkGray -NoNewline
        Write-Host ('─' * $boxWidth) -ForegroundColor DarkGray -NoNewline
        Write-Host '╯' -ForegroundColor DarkGray
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
                    Write-Host ('─' * ($boxWidth + 8)) -ForegroundColor DarkGray
                    & $item.Action
                    Write-Host ('─' * ($boxWidth + 8)) -ForegroundColor DarkGray
                    Write-Host ''
                    # Continue the loop — menu redraws
                    [Console]::CursorVisible = $false
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
                            Write-Host ('─' * ($boxWidth + 8)) -ForegroundColor DarkGray
                            & $item.Action
                            Write-Host ('─' * ($boxWidth + 8)) -ForegroundColor DarkGray
                            Write-Host ''
                            [Console]::CursorVisible = $false
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
