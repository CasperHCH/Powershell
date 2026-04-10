<#
.SYNOPSIS
Copies Active Directory mobile values into the pager attribute.

.DESCRIPTION
Finds users with a mobile number under the specified search base and updates the
pager attribute when it is empty or out of sync with the mobile value.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchBase
)

Import-Module ActiveDirectory -ErrorAction Stop

$users = Get-ADUser -SearchBase $SearchBase -Filter 'Mobile -like "*"' -ResultSetSize 5000 -Properties DisplayName, SamAccountName, Mobile, Pager |
    Where-Object { $_.Mobile -and ($_.Pager -ne $_.Mobile) }

foreach ($user in $users) {
    if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Set pager to '$($user.Mobile)'")) {
        Set-ADUser -Identity $user.SamAccountName -Replace @{ Pager = $user.Mobile }
        Write-Verbose "Updated pager for $($user.DisplayName)"
    }
}

Write-Output "Processed $($users.Count) user(s)."