<#
.SYNOPSIS
    Git management menu.
.NOTES
    Cesta: ~/.config/powershell/toolkit/menu/menu-git.ps1
#>

function Show-GitMenu {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Err "Git is not installed or not in PATH."
        return
    }
    $items = [ordered]@{
        '1.  Check Status' = @{ Action = { git status; Read-Host "`nStiskni Enter..." }; Desc = 'Working tree status' }
        '2.  Log' = @{ Action = { git log --oneline --graph --decorate -20; Read-Host "`nStiskni Enter..." }; Desc = 'Last 20 commits with graph' }
        '3.  Branches' = @{ Action = { git branch -a; Read-Host "`nStiskni Enter..." }; Desc = 'All local and remote branches' }
        '4.  Remotes' = @{ Action = { git remote -v; Read-Host "`nStiskni Enter..." }; Desc = 'Remote URLs' }
        '5.  Stash' = @{ Action = { git stash list; Read-Host "`nStiskni Enter..." }; Desc = 'Saved stashes' }
        '6.  Quick Commit' = @{ Action = { $m = Read-Host 'Commit message'; git commit -am $m 2>&1; Read-Host "`nStiskni Enter..." }; Desc = 'Add all + commit with message' }
        '7.  Clean' = @{ Action = {
            Write-Warn "This will: git stash clear + git clean -fd ([!]️ irreversible)"
            $c = Read-Host "Continue? (y/N)"
            if ($c -eq 'y') { git stash clear 2>&1; git clean -fd 2>&1; Write-Success "Cleaned." }
            Read-Host "`nStiskni Enter..."
        }; Desc = 'Clear stashes + remove untracked files' }
        '8.   Back' = @{ Action = { return }; Desc = 'Return to main menu' }
    }
    Show-Menu -Title 'GIT' -Items $items
}

if ($MyInvocation.InvocationName -ne '.') { Initialize-MenuMenu 'Show-GitMenu' }
