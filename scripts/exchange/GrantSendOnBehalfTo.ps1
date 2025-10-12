<#
.SYNOPSIS
    Grant Send-On-Behalf-To permissions to a mailbox
.DESCRIPTION
    This script adds Send-On-Behalf-To permissions to a mailbox without overwriting existing permissions.
.PARAMETER Identity
    The mailbox identity to modify permissions for
.PARAMETER Users
    Comma-separated list of users to grant Send-On-Behalf-To permissions
.EXAMPLE
    .\GrantSendOnBehalfTo.ps1 -Identity "john.doe@contoso.com" -Users "jane.smith@contoso.com,admin@contoso.com"
#>

Param(
    [Parameter(Mandatory=$True, HelpMessage="Enter mailbox identity (email or display name)")]
    [String]$Identity,
    [Parameter(Mandatory=$True, HelpMessage="Enter comma-separated list of users to grant permissions")]
    [String]$Users
)

try {
    Write-Host "Granting Send-On-Behalf-To permissions for mailbox: $Identity" -ForegroundColor Cyan

    # Get current mailbox and permissions
    $mailbox = Get-Mailbox -Identity $Identity -ErrorAction Stop
    $currentPermissions = $mailbox.GrantSendOnBehalfTo

    # Parse new users to add
    $newUsers = $Users -split ',' | ForEach-Object { $_.Trim() }

    # Combine existing and new permissions
    $allPermissions = @()
    if ($currentPermissions) {
        $allPermissions += $currentPermissions
    }

    foreach ($user in $newUsers) {
        if ($user -and $allPermissions -notcontains $user) {
            $allPermissions += $user
            Write-Host "  Adding: $user" -ForegroundColor Yellow
        } elseif ($allPermissions -contains $user) {
            Write-Host "  Already exists: $user" -ForegroundColor Cyan
        }
    }

    # Apply the permissions
    Set-Mailbox -Identity $Identity -GrantSendOnBehalfTo $allPermissions -ErrorAction Stop

    Write-Host "✅ Send-On-Behalf-To permissions updated successfully" -ForegroundColor Green

    # Display final permissions
    $updatedMailbox = Get-Mailbox -Identity $Identity
    Write-Host "Final permissions:" -ForegroundColor Green
    $updatedMailbox.GrantSendOnBehalfTo | ForEach-Object { Write-Host "  - $_" }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
