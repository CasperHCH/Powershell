$distinguishedName = Read-Host -Prompt 'Please input the  of the desired OU you want to list users from:'
Get-ADUser -SearchBase $distinguishedName -Filter * | Select Name,SamAccountName
