<#
.SYNOPSIS
Exports last logon data for users in an Active Directory OU.

.DESCRIPTION
Retrieves users from the specified OU, converts the lastLogonTimestamp value into
a readable date, and exports the result set to CSV.
#>

param(
    [string]$OUSearchBase,
    [string]$OutputPath = "C:\Temp\LastLogonReport.csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$OUSearchBase) {
    $OUSearchBase = Read-Host "Enter the DistinguishedName of the OU to search"
}
if (!$OutputPath) {
    $OutputPath = Read-Host "Enter the full path for the output CSV file"
}

try {
    Write-Information "Gathering last logon data for users in OU: $OUSearchBase" -InformationAction Continue

    $users = Get-ADUser -Filter * -SearchBase $OUSearchBase -ResultPageSize 0 -Properties CN,samaccountname,lastLogonTimestamp

    $results = $users | Select-Object CN,samaccountname,@{n="LastLogon";e={[datetime]::FromFileTime($_.lastLogonTimestamp)}}

    $results | Export-CSV -NoTypeInformation -Path $OutputPath

    Write-Information "Report exported to: $OutputPath" -InformationAction Continue
    Write-Information "Total users processed: $($users.Count)" -InformationAction Continue
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
