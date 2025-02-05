$distinguishedName = Read-Host -Prompt 'Please input the  of the desired OU you want to copy users from'
$GroupName = Read-Host -Prompt 'Please provide the Group Name you want to add the users to'
Get-ADUser -SearchBase $distinguishedName -Filter * | % { Add-ADGroupMember $GroupName -Members $_}
