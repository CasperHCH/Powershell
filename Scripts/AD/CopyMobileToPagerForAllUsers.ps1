#Check AD users for a Mobile number.
#If it exist - copy it to the Pager field.
#Unless Pagerfield is already filled or not the same as the mobile number.
Write-Host 
$users = Get-ADUser -SearchBase  -Filter 'Mobile -like ' -ResultSetSize 5000 -Properties displayname, sAMAccountName, Mobile, Pager |Where {$_.Pager -eq $null -or $_.Pager -ne $_.mobile}| Select pager, mobile, sAMAccountName, displayname
foreach ($user in $Users) {
    Set-ADUser $user.sAMAccountName -Clear pager
    Set-ADUser $user.sAMAccountName -Add @{pager = $User.mobile}
    write-host $user.displayname -ForegroundColor Yellow
   }
