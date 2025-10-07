# Set ManagedBy to all groups in an OU, and allow the user to manage the groups members
param(
    [Parameter(Mandatory=$true)]
    [string]$OrganizationalUnit,
    [Parameter(Mandatory=$true)]
    [string]$ManagedByUser,
    [switch]$WhatIf
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host 'Setting ManagedBy for all groups in the specified OU' -ForegroundColor Yellow
Write-Host "OU: $OrganizationalUnit" -ForegroundColor Cyan
Write-Host "Managed By User: $ManagedByUser" -ForegroundColor Cyan

try {
    # Validate the OU exists
    $null = Get-ADOrganizationalUnit -Identity $OrganizationalUnit -ErrorAction Stop

    # Validate the user exists
    $userObject = Get-ADUser -Identity $ManagedByUser -ErrorAction Stop

    $groups = Get-ADGroup -Filter * -SearchBase $OrganizationalUnit
    Write-Host "Found $($groups.Count) groups to process" -ForegroundColor Green

    ForEach ($g in $groups) {
        try {
            if ($WhatIf) {
                Write-Host "WhatIf: Would set ManagedBy for group $($g.Name) to $ManagedByUser" -ForegroundColor Yellow
            } else {
                Set-ADGroup -Identity $g.DistinguishedName -ManagedBy $userObject.DistinguishedName
                # Note: Add-ADPermission is an Exchange cmdlet, not available in standard AD module
                # Use Set-ADObjectACL or similar for AD permissions
                Write-Host "Set ManagedBy for group: $($g.Name)" -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to set ManagedBy for group $($g.Name): $($_.Exception.Message)"
        }
    }
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
