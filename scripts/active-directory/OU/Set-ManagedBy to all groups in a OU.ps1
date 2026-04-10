<#
.SYNOPSIS
Sets the ManagedBy attribute for all groups in an OU.

.DESCRIPTION
Validates the target OU and managing user, then applies the ManagedBy value to
every group found under the supplied organizational unit.
#>

# Set ManagedBy to all groups in an OU, and allow the user to manage the groups members
param(
    [Parameter(Mandatory=$true)]
    [string]$OrganizationalUnit,
    [Parameter(Mandatory=$true)]
    [string]$ManagedByUser,
    [switch]$WhatIf
)

Import-Module ActiveDirectory -ErrorAction Stop

Write-Information 'Setting ManagedBy for all groups in the specified OU' -InformationAction Continue
Write-Information "OU: $OrganizationalUnit" -InformationAction Continue
Write-Information "Managed By User: $ManagedByUser" -InformationAction Continue

try {
    # Validate the OU exists
    $null = Get-ADOrganizationalUnit -Identity $OrganizationalUnit -ErrorAction Stop

    # Validate the user exists
    $userObject = Get-ADUser -Identity $ManagedByUser -ErrorAction Stop

    $groups = Get-ADGroup -Filter * -SearchBase $OrganizationalUnit
    Write-Information "Found $($groups.Count) groups to process" -InformationAction Continue

    ForEach ($g in $groups) {
        try {
            if ($WhatIf) {
                Write-Information "WhatIf: Would set ManagedBy for group $($g.Name) to $ManagedByUser" -InformationAction Continue
            } else {
                Set-ADGroup -Identity $g.DistinguishedName -ManagedBy $userObject.DistinguishedName
                # Note: Add-ADPermission is an Exchange cmdlet, not available in standard AD module
                # Use Set-ADObjectACL or similar for AD permissions
                Write-Information "Set ManagedBy for group: $($g.Name)" -InformationAction Continue
            }
        } catch {
            Write-Error "Failed to set ManagedBy for group $($g.Name): $($_.Exception.Message)"
        }
    }
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
