<#
.SYNOPSIS
    Windows Terminal shell integration — OSC 133 prompt markers.
.DESCRIPTION
    Wraps the PowerShell prompt (including oh-my-posh if active) with
    OSC 133 escape sequences that tell Windows Terminal where each
    prompt, command, and output begins/ends. Enables:
    - Command marks in scrollbar (showMarksOnScrollbar)
    - Auto-mark prompts (autoMarkPrompts)
    - Ctrl+Up/Down to jump between commands
    - Select entire command/output
    - Right-click context menu on commands
.NOTES
    Source: https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration
    Active from: ps7/profile.ps1
    Cesta: ~/.config/powershell/profile/hosts/shell-integration.ps1
#>

Set-StrictMode -Version Latest

# Only activate in Windows Terminal (check WT_SESSION env var)
if (-not $env:WT_SESSION) { return }

$Global:__LastHistoryId = -1

function Global:__Terminal-Get-LastExitCode {
    if ($?) { return 0 }
    # Guard against no history yet / no recorded error — both are $null on a
    # fresh session before the first command runs, which throws under
    # Set-StrictMode when dereferenced directly.
    $LastHistoryEntry = Get-History -Count 1
    $lastError = if ($Error.Count -gt 0) { $Error[0] } else { $null }
    $IsPowerShellError = $lastError -and $LastHistoryEntry -and ($lastError.InvocationInfo.HistoryId -eq $LastHistoryEntry.Id)
    if ($IsPowerShellError) { return -1 }
    return $LastExitCode
}

# ── Save original prompt function (set by oh-my-posh or PSReadLine) ──
$Global:__OriginalPrompt = $function:prompt

function Global:prompt {
    $out = ''
    $gle = __Terminal-Get-LastExitCode
    $LastHistoryEntry = Get-History -Count 1

    # ── OSC 133;D — end of previous command ──
    if ($Global:__LastHistoryId -ne -1) {
        if ($LastHistoryEntry -and $LastHistoryEntry.Id -eq $Global:__LastHistoryId) {
            # No command was run (empty line, Ctrl+C) — no exit code
            $out += "$([char]0x1B)]133;D$([char]0x07)"
        } else {
            # Command finished — provide exit code (0=green mark, non-zero=red mark)
            $out += "$([char]0x1B)]133;D;$gle$([char]0x07)"
        }
    }

    # ── OSC 133;A — start of prompt ──
    $loc = $executionContext.SessionState.Path.CurrentLocation
    $out += "$([char]0x1B)]133;A$([char]0x07)"

    # ── OSC 9;9 — current working directory ──
    $out += "$([char]0x1B)]9;9;`"$loc`"$([char]0x07)"

    # ── Original prompt (oh-my-posh / PSReadLine) ──
    if ($Global:__OriginalPrompt) {
        $out += $Global:__OriginalPrompt.Invoke()
    }

    # ── OSC 133;B — end of prompt, start of command input ──
    $out += "$([char]0x1B)]133;B$([char]0x07)"

    if ($LastHistoryEntry) {
        $Global:__LastHistoryId = $LastHistoryEntry.Id
    }
    return $out
}
