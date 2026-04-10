<#
.SYNOPSIS
Adds all users from an OU to a target Active Directory group.

.DESCRIPTION
Validates the OU and group, enumerates users from the specified search base, and
adds each user to the requested group with optional WhatIf-style messaging.
#>

param(
    [string]$DistinguishedName,
    [string]$GroupName,
    [switch]$WhatIf
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$DistinguishedName) {
    $DistinguishedName = Read-Host -Prompt 'Please input the DistinguishedName of the desired OU you want to copy users from'
}
if (!$GroupName) {
    $GroupName = Read-Host -Prompt 'Please provide the Group Name you want to add the users to'
}

try {
    # Validate OU exists
    $null = Get-ADOrganizationalUnit -Identity $DistinguishedName -ErrorAction Stop

    # Validate group exists
    $null = Get-ADGroup -Identity $GroupName -ErrorAction Stop

    $users = Get-ADUser -SearchBase $DistinguishedName -Filter *
    Write-Information "Found $($users.Count) users in OU: $DistinguishedName" -InformationAction Continue

    foreach ($user in $users) {
        if ($WhatIf) {
            Write-Information "WhatIf: Would add $($user.Name) to group $GroupName" -InformationAction Continue
        } else {
            try {
                Add-ADGroupMember $GroupName -Members $user -ErrorAction Stop
                Write-Information "Added $($user.Name) to group $GroupName" -InformationAction Continue
            } catch {
                Write-Warning "Failed to add $($user.Name): $($_.Exception.Message)"
            }
        }
    }
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
