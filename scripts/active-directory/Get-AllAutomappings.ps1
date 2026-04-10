<#
.SYNOPSIS
Lists mailbox automapping delegates from Active Directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

Import-Module ActiveDirectory -ErrorAction Stop

$results = foreach ($user in Get-ADUser -Filter * -Properties msExchDelegateListLink, UserPrincipalName, DisplayName) {
    foreach ($delegateDn in @($user.msExchDelegateListLink)) {
        if ([string]::IsNullOrWhiteSpace($delegateDn)) {
            continue
        }

        $delegateUser = Get-ADUser -Identity $delegateDn -Properties UserPrincipalName, DisplayName -ErrorAction SilentlyContinue

        [pscustomobject]@{
            UserName                    = $user.DisplayName
            UserPrincipalName           = $user.UserPrincipalName
            DelegateDisplayName         = $delegateUser.DisplayName
            DelegateUserPrincipalName   = $delegateUser.UserPrincipalName
            DelegateDistinguishedName   = $delegateDn
        }
    }
}

if ($OutputPath) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
}
else {
    $results
}