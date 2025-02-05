#Set ManagedBy to all groups in a OU, and allow the user to manage the groups members.
Write-Host 'Please input the  of the desired OU you want to Add ManagedBy to' -ForegroundColor Yellow -BackgroundColor black
Write-Host   -ForegroundColor Red -BackgroundColor black
$distinguishedName = Read-Host 

$MangedByUser = Read-Host 

$groups = Get-ADGroup -filter * -SearchBase 
ForEach ($g in $groups) 
{
    set-adgroup -Identity  -ManagedBy 
    Add-ADPermission -Identity  -User  -AccessRights WriteProperty -Properties 
    Write-Host  -ForegroundColor Green
}
