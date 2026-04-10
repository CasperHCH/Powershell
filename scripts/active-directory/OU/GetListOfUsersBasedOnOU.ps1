<#
.SYNOPSIS
Lists users from a specified Active Directory OU.

.DESCRIPTION
Returns basic user information from the given OU and optionally exports the list
to CSV when an output path is supplied.
#>

param(
    [string]$DistinguishedName,
    [string]$OutputPath
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$DistinguishedName) {
    $DistinguishedName = Read-Host -Prompt 'Please input the DistinguishedName of the desired OU you want to list users from:'
}

try {
    Write-Information "Retrieving users from OU: $DistinguishedName" -InformationAction Continue

    $users = Get-ADUser -SearchBase $DistinguishedName -Filter * | Select-Object Name,SamAccountName,UserPrincipalName

    if ($OutputPath) {
        $users | Export-CSV -NoTypeInformation -Path $OutputPath
        Write-Information "User list exported to: $OutputPath" -InformationAction Continue
    } else {
        $users | Format-Table -AutoSize
    }

    Write-Information "Total users found: $($users.Count)" -InformationAction Continue
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
