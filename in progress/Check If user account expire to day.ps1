################################
####### Check if an User #######
####### Expired today    #######
################################

$ListOfUsers = get-aduser -Filter * -Properties AccountExpirationDate | select Name, sAMAccountName, UserPrincipalName, distinguishedName, @{Name=“AccountExpires”;Expression={[datetime]::FromFileTime($_.Accountexpires)}}
$i = 0
foreach ($U in $ListOfUsers)
{
#$DisableUserOnDate = [datetime]$U.AccountExpires
$i += 1
if ($U.AccountExpires -eq (get-date).Date)
    {        Write-Host "$($U.Name) has an expirationdate equal to today"    }
    else {
    
    write-host "$($i)"
    
    }

}