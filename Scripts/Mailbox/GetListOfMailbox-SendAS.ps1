<#
.SYNOPSIS
    Get Send-As permissions for a mailbox
.DESCRIPTION
    This script retrieves all Send-As permissions granted on a specific mailbox.
.PARAMETER Identity
    The mailbox identity to check permissions for
.EXAMPLE
    .\GetListOfMailbox-SendAS.ps1 -Identity "john.doe@company.com"
#>

Param(
    [Parameter(Mandatory=$True, HelpMessage="Enter mailbox identity (email or display name)")]
    [String]$Identity
)

try {
    Write-Host "Getting Send-As permissions for mailbox: $Identity" -ForegroundColor Cyan

    $sendAsPermissions = Get-Mailbox -Identity $Identity -ErrorAction Stop | Get-ADPermission | Where-Object {$_.ExtendedRights -like "*Send-As*"}

    if ($sendAsPermissions) {
        Write-Host "✅ Found Send-As permissions:" -ForegroundColor Green
        $sendAsPermissions | Format-Table User, ExtendedRights, AccessRights -AutoSize
    } else {
        Write-Host "⚠️ No Send-As permissions found for $Identity" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
