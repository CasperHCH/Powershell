<#
.SYNOPSIS
    Get Send-On-Behalf-To permissions for a mailbox
.DESCRIPTION
    This script retrieves Send-On-Behalf-To permissions for a specific mailbox.
.PARAMETER Identity
    The mailbox identity to check permissions for
.EXAMPLE
    .\GetListOfMailbox-SendOnBehalfTo.ps1 -Identity "john.doe@contoso.com"
#>

Param(
    [Parameter(Mandatory=$True, HelpMessage="Enter mailbox identity (email or display name)")]
    [String]$Identity
)

try {
    Write-Host "Getting Send-On-Behalf-To permissions for mailbox: $Identity" -ForegroundColor Cyan

    $mailbox = Get-Mailbox -Identity $Identity -ErrorAction Stop

    Write-Host "✅ Mailbox Information:" -ForegroundColor Green
    $mailbox | Format-List DisplayName, GrantSendOnBehalfTo

    if ($mailbox.GrantSendOnBehalfTo.Count -gt 0) {
        Write-Host "Send-On-Behalf-To permissions granted to:" -ForegroundColor Yellow
        $mailbox.GrantSendOnBehalfTo | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "⚠️ No Send-On-Behalf-To permissions found" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
