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
    Write-Host "Gathering last logon data for users in OU: $OUSearchBase" -ForegroundColor Cyan

    $users = Get-ADUser -Filter * -SearchBase $OUSearchBase -ResultPageSize 0 -Properties CN,samaccountname,lastLogonTimestamp

    $results = $users | Select-Object CN,samaccountname,@{n="LastLogon";e={[datetime]::FromFileTime($_.lastLogonTimestamp)}}

    $results | Export-CSV -NoTypeInformation -Path $OutputPath

    Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
    Write-Host "Total users processed: $($users.Count)" -ForegroundColor Green
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
