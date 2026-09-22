<#
.SYNOPSIS
    Obecné pomocné funkce.
.DESCRIPTION
    Kolekce utilitních funkcí používaných napříč Toolkit modulem.
.NOTES
    Cesta: ~/Projects/tools/Toolkit/Public/Console.ps1
#>

<#
.SYNOPSIS
    Zobrazí barevnou zprávu s prefixem.
#>
function Write-Info {
    param([string]$Message)
    Write-TkMessage -Level Info -Message $Message
}

<#
.SYNOPSIS
    Zobrazí úspěšnou zprávu.
#>
function Write-Success {
    param([string]$Message)
    Write-TkMessage -Level Ok -Message $Message
}

<#
.SYNOPSIS
    Zobrazí varovnou zprávu.
#>
function Write-Warn {
    param([string]$Message)
    Write-TkMessage -Level Warn -Message $Message
}

<#
.SYNOPSIS
    Zobrazí chybovou zprávu.
#>
function Write-Err {
    param([string]$Message)
    Write-TkMessage -Level Fail -Message $Message
}

<#
.SYNOPSIS
    Požádá uživatele o potvrzení (Y/N).
.DESCRIPTION
    Vrátí $true pro Y/Yes, $false jinak.
#>
function Confirm-Action {
    param([string]$Prompt)
    $response = Read-Host "$Prompt (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}
