<#
.SYNOPSIS
    Nastavení proměnných prostředí.
.DESCRIPTION
    Inicializuje $env:EDITOR, přidá tools/bin do PATH, nastaví $env:DOTFILES_TOOLS.
.NOTES
    Cesta: ~/.config/powershell/profile/core/env.ps1
#>

# Editor
if (-not $env:EDITOR) {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $env:EDITOR = 'code'
    }
    elseif (Get-Command nvim -ErrorAction SilentlyContinue) {
        $env:EDITOR = 'nvim'
    }
    elseif (Get-Command vim -ErrorAction SilentlyContinue) {
        $env:EDITOR = 'vim'
    }
    else {
        $env:EDITOR = 'notepad'
    }
}

# Tools PATH (idempotent)
# Confirm DOTFILES_TOOLS first — Join-Path on $null produces relative paths.
# Monorepo: toolkit/ is a sibling of the profile dir under one root.
if (-not $env:DOTFILES_TOOLS) {
    $env:DOTFILES_TOOLS = if ($env:DOTFILES_PWSH) {
        Join-Path (Split-Path $env:DOTFILES_PWSH -Parent) 'toolkit'
    } else {
        Join-Path $HOME '.config\powershell\toolkit'
    }
}

$toolsBin = Join-Path $env:DOTFILES_TOOLS 'bin'
if ($toolsBin -notin ($env:PATH -split [IO.Path]::PathSeparator)) {
    $env:PATH = "$toolsBin$([IO.Path]::PathSeparator)$env:PATH"
}
