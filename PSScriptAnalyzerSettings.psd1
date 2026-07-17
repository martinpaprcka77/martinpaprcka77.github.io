@{
    # PSScriptAnalyzer settings for the PowerShell Dotfiles Ecosystem.
    # Used by CI (.github/workflows/test.yml) and picked up automatically by
    # editors/extensions that look for this file at the repo root (VS Code's
    # PowerShell extension, `Invoke-ScriptAnalyzer -Path .` with no -Settings
    # override). CI fails only on Error severity — the long-standing informal
    # bar this repo has used since before this file existed — Warning-severity
    # findings are reported but don't block.

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # This whole toolkit is Write-Host-based by design — Show-Menu, the
        # Write-Step/Ok/Skip/Fail/Warn house style, every menu/checker/script —
        # because it's a colored, interactive console UX, not output meant to
        # be captured/piped. Write-Output/Write-Information would lose the
        # color and, for Show-Menu's [Console]::SetCursorPosition-driven
        # partial redraws, would not work at all. ~180 occurrences; converting
        # away is a whole-repo rewrite of the UX, not a lint fix.
        'PSAvoidUsingWriteHost',

        # profile/hosts/shell-integration.ps1's OSC 133 prompt-state variables
        # (__LastHistoryId, __OriginalPrompt) must survive across separate
        # invocations of the wrapped $function:prompt — that requires literal
        # Global: scope; a module-scoped or script-scoped variable would not
        # persist the way this needs.
        'PSAvoidGlobalVars'
    )

    # NOT excluded (intentionally — these still surface as Warnings in CI so
    # regressions get caught automatically instead of only in a future manual
    # audit):
    #   PSUseShouldProcessForStateChangingFunctions — 2 real gaps were closed
    #     this pass (Remove-PSModulePath, Reset-PSModulePath); 3 remain as
    #     verb-heuristic false positives (Start-MainMenu is an interactive
    #     launcher, Start/Stop-PSProfiling are ETW toggles — neither needs
    #     -WhatIf/-Confirm semantics) but the rule stays on to catch the next
    #     genuinely state-changing function that's missing it.
    #   PSUseApprovedVerbs — Reload-Profile is a documented, public,
    #     muscle-memory function name (README/CLAUDE.md, `rp` alias); renaming
    #     it is a breaking change out of scope for a lint pass. Leave-Menu/
    #     Redraw-Item (menu.ps1) and __Terminal-Get-LastExitCode are private,
    #     unexported helpers where the verb doesn't affect discoverability.
    #   PSAvoidUsingEmptyCatchBlock, PSUseSingularNouns,
    #   PSAvoidUsingCmdletAliases, PSPossibleIncorrectComparisonWithNull,
    #   PSUseDeclaredVarsMoreThanAssignments — low-count, pre-existing,
    #     not touched by this pass; left visible rather than silenced.
}
