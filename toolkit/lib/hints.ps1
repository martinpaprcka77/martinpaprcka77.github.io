<#
.SYNOPSIS
    One-time interactive hints system for new user onboarding.
.DESCRIPTION
    Manages hint display state and shows contextual tips explaining WHAT features do,
    WHY users should use them, and what to do NEXT. Each hint is shown once per
    installation, stored in hints config file.
.NOTES
    Cesta: ~/.config/powershell/toolkit/lib/hints.ps1
#>

$HintsConfigPath = Join-Path $env:DOTFILES_TOOLS 'config' 'hints.json'

function Get-HintsConfig {
    [CmdletBinding()]
    param()
    if (Test-Path $HintsConfigPath) {
        return Get-Content $HintsConfigPath -Raw | ConvertFrom-Json -AsHashtable
    }
    return @{}
}

function Save-HintsConfig {
    [CmdletBinding()]
    param([hashtable]$Config)
    $dir = Split-Path $HintsConfigPath -Parent
    if (-not (Test-Path $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    $Config | ConvertTo-Json | Set-Content $HintsConfigPath -Force
}

function Show-Hint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HintId,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string[]]$Lines,
        [string[]]$NextSteps
    )

    $config = Get-HintsConfig
    if ($config[$HintId]) {
        return
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ 💡 $($Title.PadRight(52)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    foreach ($line in $Lines) {
        Write-Host "   $line" -ForegroundColor White
    }

    if ($NextSteps) {
        Write-Host "`n   NEXT STEPS:" -ForegroundColor Yellow
        foreach ($step in $NextSteps) {
            Write-Host "   ▸ $step" -ForegroundColor Gray
        }
    }

    Write-Host "`n   Press any key to continue..." -ForegroundColor DarkGray
    $null = [Console]::ReadKey($true)

    $config[$HintId] = $true
    Save-HintsConfig $config
    Write-Host ""
}

function Test-HintShown {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$HintId)
    $config = Get-HintsConfig
    return $config.ContainsKey($HintId) -and $config[$HintId]
}

function Reset-Hints {
    [CmdletBinding()]
    param()
    Save-HintsConfig @{}
    Write-Host "✓ All hints reset. They will show again on next use." -ForegroundColor Green
}
