<#
.SYNOPSIS
    Resolves the repository root (the folder that contains Toolkit/ and ops/).
.DESCRIPTION
    Private helper used by the menu functions so they no longer hard-code
    'Split-Path $PSScriptRoot -Parent' — which broke once the menus moved under
    Toolkit/Public/Menu/. Preference order:

      1. $env:DOTFILES_TOOLS, when it points at an existing folder
      2. Walk up from the current location until a folder contains Toolkit/Toolkit.psd1

    That works whether the caller sits at the repo root, in Toolkit/, or in a
    nested folder such as Toolkit/Public/Menu/.
.NOTES
    Cesta: ~/.config/powershell/toolkit/Toolkit/Private/Get-ToolkitRoot.ps1
#>
function Get-ToolkitRoot {
    [CmdletBinding()]
    param()

    if ($env:DOTFILES_TOOLS -and (Test-Path -LiteralPath $env:DOTFILES_TOOLS)) {
        return $env:DOTFILES_TOOLS
    }

    $dir = $PSScriptRoot
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir 'Toolkit\Toolkit.psd1')) { return $dir }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $PSScriptRoot
}
