<#
.SYNOPSIS
    Vygeneruje placeholder ikony (32x32 PNG) pro menu/projekty/PS5/PS7.
.DESCRIPTION
    Používá System.Drawing pro vytvoření jednoduchých barevných ikon s písmeny.
    Vyžaduje Windows (System.Drawing).
.PARAMETER OutputDir
    Výstupní adresář (výchozí: ../icons).
.EXAMPLE
    .\Generate-Icons.ps1
    .\Generate-Icons.ps1 -OutputDir "C:\my-icons"
.NOTES
    Cesta: ~/.config/powershell/toolkit/scripts/Generate-Icons.ps1
#>
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\icons')
)

$ErrorActionPreference = 'Stop'

# Cross-platform guard — System.Drawing is Windows-only
if ($PSVersionTable.PSVersion.Major -ge 6 -and ($IsLinux -or $IsMacOS)) {
    Write-Error "Generate-Icons.ps1 vyžaduje Windows (System.Drawing). Nelze spustit na Linux/macOS."
    exit 1
}

if (-not (New-Object System.Drawing.Bitmap 1,1)) {
    Write-Error "System.Drawing není dostupné. Spusťte na Windows s .NET Framework."
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$icons = @(
    @{ Name = 'menu.png';     Letter = 'M'; Bg = 'DodgerBlue';  Fg = 'White' },
    @{ Name = 'projects.png'; Letter = 'P'; Bg = 'ForestGreen'; Fg = 'White' },
    @{ Name = 'pwsh7.png';    Letter = '7'; Bg = 'DarkCyan';   Fg = 'White' },
    @{ Name = 'pwsh5.png';    Letter = '5'; Bg = 'SteelBlue';   Fg = 'White' }
)

Add-Type -AssemblyName System.Drawing

foreach ($icon in $icons) {
    $outputPath = Join-Path $OutputDir $icon.Name

    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAlias'

    # Background
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($icon.Bg))
    $g.FillRectangle($bgBrush, 0, 0, 32, 32)

    # Letter
    $fgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromName($icon.Fg))
    $font = New-Object System.Drawing.Font 'Consolas', 18, 'Bold'
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = 'Center'
    $format.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF 0, 0, 32, 32
    $g.DrawString($icon.Letter, $font, $fgBrush, $rect, $format)

    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "[+] $outputPath" -ForegroundColor Green

    $g.Dispose()
    $bitmap.Dispose()
    $bgBrush.Dispose()
    $fgBrush.Dispose()
    $font.Dispose()
    $format.Dispose()
}

Write-Host "`nVygenerovány 4 ikony do: $OutputDir" -ForegroundColor Green
