<#
.SYNOPSIS
    Specifické nastavení pro PowerShell 7+.
.DESCRIPTION
    Moderní PS7 nastavení – PSReadLine, Terminal-Icons, oh-my-posh,
    prediktivní IntelliSense, rychlejší completion.
.NOTES
    Cesta: ~/.config/powershell/profile/ps7/profile.ps1
#>

Set-StrictMode -Version Latest

#region PSReadLine
if ($null -ne (Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1)) {
    Import-Module PSReadLine

    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -ShowToolTips

    # Predictive IntelliSense
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView

    # Better tab completion
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
#endregion

#region Terminal-Icons
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}
#endregion

#region Starship prompt (cross-shell, Rust-powered)
# oh-my-posh alternative: https://starship.rs
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $starshipConfig = Join-Path $env:DOTFILES_PWSH 'starship.toml'
    if (Test-Path $starshipConfig) {
        $env:STARSHIP_CONFIG = $starshipConfig
    }
    Invoke-Expression (&starship init powershell)
}
elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Fallback: oh-my-posh if starship not installed
    $poshTheme = Join-Path $env:DOTFILES_PWSH 'theme.json'
    if (Test-Path $poshTheme) {
        oh-my-posh init pwsh --config $poshTheme | Invoke-Expression
    }
    else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}
#endregion

#region PSFzf (fuzzy finder integration)
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+t' -PSReadLineChordReverseHistory 'Ctrl+r'
}
#endregion

#region z (directory jumper)
$zPath = Join-Path $env:DOTFILES_PWSH 'z.ps1'
if (Test-Path $zPath) { . $zPath }
#endregion

#region WT Shell Integration (command marks, scrollbar marks, Ctrl+Up/Down)
$shellIntegration = Join-Path $env:DOTFILES_PWSH 'hosts\shell-integration.ps1'
if (Test-Path $shellIntegration) { . $shellIntegration }
#endregion

# PS7 profile loaded
