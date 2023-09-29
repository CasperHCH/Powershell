#Set ManagedBy to all groups in a OU, and allow the user to manage the groups members.
Write-Host 'Please input the "distinguishedName" of the desired OU you want to Add ManagedBy to' -ForegroundColor Yellow -BackgroundColor black
Write-Host  "beware that the later selected user will be granted ManagedBy to ALL groups within the OU" -ForegroundColor Red -BackgroundColor black
$distinguishedName = Read-Host " "

$MangedByUser = Read-Host "Please input the Username of the user who should have ManagedBy permission"

$groups = Get-ADGroup -filter * -SearchBase "$distinguishedName"
ForEach ($g in $groups) 
{
    set-adgroup -Identity "$g" -ManagedBy "$MangedByUser"
    Add-ADPermission -Identity "$g" -User "$MangedByUser" -AccessRights WriteProperty -Properties "Member"
    Write-Host "ManagedBy has been set to user '$MangedByUser' on '$g'" -ForegroundColor Green
}