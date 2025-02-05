$OUSearchBase = Read-Host 
$Path = Read-Host 
Write-Host 
Get-ADUser -Filter * -SearchBase  -ResultPageSize 0 -Prop CN,samaccountname,lastLogonTimestamp | Select CN,samaccountname,@{n=;e={[datetime]::FromFileTime($_.lastLogonTimestamp)}} | Export-CSV -NoType  +
