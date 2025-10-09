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
    Write-Host "Found $($users.Count) users in OU: $DistinguishedName" -ForegroundColor Green

    foreach ($user in $users) {
        if ($WhatIf) {
            Write-Host "WhatIf: Would add $($user.Name) to group $GroupName" -ForegroundColor Yellow
        } else {
            try {
                Add-ADGroupMember $GroupName -Members $user -ErrorAction Stop
                Write-Host "Added $($user.Name) to group $GroupName" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to add $($user.Name): $($_.Exception.Message)"
            }
        }
    }
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
