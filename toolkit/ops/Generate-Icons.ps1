<#
.SYNOPSIS
    Vygeneruje placeholder ikony (32x32 PNG) pro menu/projekty/PS7.
.DESCRIPTION
    Používá System.Drawing pro vytvoření jednoduchých barevných ikon s písmeny.
    Vyžaduje Windows (System.Drawing).
.PARAMETER OutputDir
    Výstupní adresář (výchozí: ../icons).
.EXAMPLE
    .\Generate-Icons.ps1
    .\Generate-Icons.ps1 -OutputDir "C:\my-icons"
.NOTES
    Cesta: ~/Projects/tools/ops/Generate-Icons.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\icons')
)

$ErrorActionPreference = 'Stop'

# $IsWindows is a PS6+ automatic variable — it does NOT exist on Windows
# PowerShell 5.1 (which also has no $PSVersionTable.OS key), where `-not
# $IsWindows` evaluates the missing $null as $true. The unguarded check
# therefore rejected a perfectly valid *Windows* 5.1 session with a bogus
# "requires Windows" error (verified: powershell.exe -File Generate-Icons.ps1
# exited 1 on Windows). Guard on the version first, exactly as
# profile/profile.ps1 and install.ps1 do.
$isWindowsHost = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

# Cross-platform guard — System.Drawing is Windows-only
if (-not $isWindowsHost) {
    Write-Error "Generate-Icons.ps1 vyžaduje Windows (System.Drawing). Nelze spustit na Linux/macOS."
    exit 1
}

# System.Drawing is Windows-only. Load it up front — the old code probed
# with `New-Object System.Drawing.Bitmap 1,1` *before* Add-Type (which would
# itself throw), and leaked the bitmap when it did run.
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch {
    Write-Error "System.Drawing není dostupné. Spusťte na Windows s .NET Framework."
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$icons = @(
    @{ Name = 'menu.png';     Letter = 'M'; Bg = 'DodgerBlue';  Fg = 'White' },
    @{ Name = 'projects.png'; Letter = 'P'; Bg = 'ForestGreen'; Fg = 'White' },
    @{ Name = 'pwsh7.png';    Letter = '7'; Bg = 'DarkCyan';   Fg = 'White' }
)

$generated = 0
foreach ($icon in $icons) {
    $outputPath = Join-Path $OutputDir $icon.Name

    # State-changing (writes a PNG) -> must honour -WhatIf/-Confirm. Before
    # [CmdletBinding(SupportsShouldProcess)] was added, `-WhatIf` was not even a
    # parameter of this script: with only `param(...)` and no CmdletBinding,
    # `pwsh -File ops\Generate-Icons.ps1 -WhatIf` bound the switch into $args
    # and rewrote all three PNGs anyway, with exit code 0 and no warning
    # (verified: file mtimes changed under -WhatIf).
    if (-not $PSCmdlet.ShouldProcess($outputPath, 'Generate icon')) { continue }

    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAlias'

    # Background
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($icon.Bg))
    $g.FillRectangle($bgBrush, 0, 0, 32, 32)

    # Letter
    $fgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($icon.Fg))
    $font = [System.Drawing.Font]::new('Consolas', 18, [System.Drawing.FontStyle]::Bold)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = 'Center'
    $format.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF 0, 0, 32, 32
    $g.DrawString($icon.Letter, $font, $fgBrush, $rect, $format)

    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $generated++
    Write-Host "[+] $outputPath" -ForegroundColor Green

    $g.Dispose()
    $bitmap.Dispose()
    $bgBrush.Dispose()
    $fgBrush.Dispose()
    $font.Dispose()
    $format.Dispose()
}

if ($generated) {
    Write-Host "`nVygenerovány $generated ikony do: $OutputDir" -ForegroundColor Green
} else {
    # -WhatIf / declined -Confirm: don't claim a write that did not happen.
    Write-Host "`nŽádné ikony nebyly vygenerovány (-WhatIf)." -ForegroundColor Yellow
}
