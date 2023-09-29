$OUSearchBase = Read-Host "Please provide the DN of the OU you want to seach"
$Path = Read-Host "Please provide a path, to save the csv file"
Write-Host "e.g. C:\Temp"
Get-ADUser -Filter * -SearchBase "$OUSearchBase" -ResultPageSize 0 -Prop CN,samaccountname,lastLogonTimestamp | Select CN,samaccountname,@{n="lastLogonDate";e={[datetime]::FromFileTime($_.lastLogonTimestamp)}} | Export-CSV -NoType "$path" + "\lastlogondate.csv"