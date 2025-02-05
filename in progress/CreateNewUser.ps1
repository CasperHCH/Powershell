#Installs AD modules
import-module activedirectory

Write-host  -ForegroundColor Yellow

$First=Read-Host 'Enter First and Middle Name'
$Last=Read-Host 'Enter Last Name'
$Initials=Read-Host 'Enter Initials'
$Title=Read-Host 'Enter Job Title'
$Mobile=Read-Host 'Enter the Mobile Phone Number. Press Space then Enter if information is not available'
$Department=Read-Host 'Enter the users department. Press Space then Enter if information is not available'
$DirectDial=Read-Host 'Enter the users direct dial number. Press Space then Enter if information is not available'

    Write-Host  -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
    

    $Selection = Read-Host 
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                    'You chose option #1 - AT - Austria, Wiener Neudorf'
                    $UserPrincipalName=$Initials+'@eeteuroparts.at'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#End Option 1
                                
            '2' {#Option 2 is selected
                    'You chose option #2 - BE - Benelux, Diegem'
                    $UserPrincipalName=$Initials+'@eeteuroparts.be'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#end option 2

            '3' {#Option 3 is selected
                    'You chose option #3 - CH - Switzerland, Hünenber'
                    $UserPrincipalName=$Initials+'@eeteuroparts.ch'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#End Option 3
                                
            '4' {#Option 4 is selected
                    'You chose option #4 - CZ - Czech Republic, Praha'
                    $UserPrincipalName=$Initials+'@eeteuroparts.cz'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#end option 4

            '5' {#Option 5 is selected
                    'You chose option #5 - DE - Germany, Dusseldorf'
                    $UserPrincipalName=$Initials+'@eeteuroparts.de'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                    
                }#End Option 5
                                
            '6' {#Option 6 is selected
                    'You chose option #6 - DE - Germany, Frankfurt'
                    $UserPrincipalName=$Initials+'@eeteuroparts.de'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#end option 6

            '7' {#Option 7 is selected
                    'You chose option #7 - DK - Denmark, Birkeørd'
                    $UserPrincipalName=$Initials+'@eeteuroparts.dk'
                    $Path=
                    $OfficePhone=
                    $Fax=
                    $StreetAddress=
                    $POBox=
                    $City=
                    $State=
                    $PostalCode=
                    $Company=
                    $WWWHomePage=
                    start-sleep -milliseconds 10000
                }#End Option 7
                                
            '8' {#Option 8 is selected
                    'You chose option #8 - ES - Spain, Madrid'
                    $UserPrincipalName=$Initials+'@eet.es'
                }#end option 8
                
            '9' {#Option 9 is selected
                    'You chose option #9 - ES - Spain, Portugal'
                    $UserPrincipalName=$Initials+'@eet.es'
                }#End Option 9
                                
            '10' {#Option 10 is selected
                    'You chose option #10 - FI - Finland, Espoo'
                    $UserPrincipalName=$Initials+'@eeteuroparts.fi'
                }#end option

            '11' {#Option 11 is selected
                    'You chose option #11 - FR - France, Lyon'
                    $UserPrincipalName=$Initials+'@eeteuroparts.fr'
                }#End Option 11
                                
            '12' {#Option 12 is selected
                    'You chose option #12 - FR - France, Paris'
                    $UserPrincipalName=$Initials+'@eeteuroparts.fr'
                }#end option 12

            '13' {#Option 13 is selected
                    'You chose option #13 - IE - Ireland, Ballycoolin'
                    $UserPrincipalName=$Initials+'@eeteuroparts.ie'
                }#End Option 13          
                 
            '14' {#Option 14 is selected
                    'You chose option #14 - INT - International, Århus'
                    $UserPrincipalName=$Initials+'@eeteuroparts.com'
                }#end option 14

            '15' {#Option 15 is selected
                    'You chose option #15 - IT - Italy, Milano'
                    $UserPrincipalName=$Initials+'@eeteuroparts.it'
                }#End Option 15         
                 
            '16' {#Option 16 is selected
                    'You chose option #16 - NL - Nederland, AC Utrecht'
                    $UserPrincipalName=$Initials+'@eeteuroparts.nl'
                }#end option 16

            '17' {#Option 17 is selected
                    'You chose option #17 - NO - Norway, Oslo'
                    $UserPrincipalName=$Initials+'@eeteuroparts.no'
                }#End Option 17
                                 
            '18' {#Option 18 is selected
                    'You chose option #18 - PL - Poland, Gdańsk'
                    $UserPrincipalName=$Initials+'@eeteuroparts.pl'
                }#end option 18

            '19' {#Option 19 is selected
                    'You chose option #19 - PL - Poland, Piaseczno'
                    $UserPrincipalName=$Initials+'@eeteuroparts.pl' 
                }#End Option 19
                              
                 
            '20' {#Option 20 is selected
                    'You chose option #20 - SE - Sweden, Göteborg '
                    $UserPrincipalName=$Initials+'@eeteuroparts.se'
                }#end option 20


            '21' {#Option 21 is selected
                    'You chose option #21 - SE - Sweden, Malmö'
                    $UserPrincipalName=$Initials+'@eeteuroparts.se'
                }#End Option 21
               
                
                 
            '22' {#Option 22 is selected
                    'You chose option #22 - SE  - Sweden, Stockholm'
                    $UserPrincipalName=$Initials+'@eeteuroparts.se'
                }#end option 22


            '23' {#Option 23 is selected
                    'You chose option #23 - UK - United Kingdom, Lydd'
                    $UserPrincipalName=$Initials+'@eeteuroparts.co.uk'
                }#End Option 23
               
                
                 
            '24' {#Option 24 is selected
                'You chose option #24 - UK - United Kingdom, Shrewsbury'
                    $UserPrincipalName=$Initials+'@eeteuroparts.co.uk'
                }#end option 24


            '25' {#Option 25 is selected
                    'You chose option #25 - UK - United Kingdom, Uxbridge'
                    $UserPrincipalName=$Initials+'@eeteuroparts.co.uk'
                }#End Option 25
               
                
                 
            '26' {#Option 26 is selected
                    'You chose option #26 - UK - United Kingdom, ERNITEC'
                    $UserPrincipalName=$Initials+'@ernitec.com'
                }#end option 26

            '27' {#Option 27 is selected
                    'You chose option #26 - UK - United Kingdom, ERNITEC'
                    $UserPrincipalName=$Initials+'@eetgroup.com'
                }#end option 27


        Default {Write-Host  -ForegroundColor Red}
        }#End Switch

#Pre-set fields generic to all users regardless of location

$FirstLower=$First.ToLower()
$LastLower=$Last.ToLower()
$SAMAccountName=$FirstLower+'.'+$LastLower
$DisplayName=$First+' '+$Last
$Mailnickname=$First+$Last
$RemoteRoutingAddress=$Initials+'-online-01@eetgroup-.mail.onmicrosoft.com'
$ProxyEmailAddress=$FirstLower+'.'+$LastLower+'@contoso.onmicrosoft.com'
$EmailAddress=$FirstLower+'.'+$LastLower+'@contoso.co.uk'

#This maybe of use if the company domain has changed but is still used for mailflow.
$oldEmailAddress=$FirstLower+'.'+$LastLower+'@tailspintoys.co.uk'

#This section prompts you to enter a password - this is the users initial password
$password=Read-Host  -AsSecureString



#Create user section - this builds the AD account using the fields above
New-ADUser -SAMAccountName $SAMAccountName -name $DisplayName -GivenName $First -Surname $Last -UserPrincipalName $UserPrincipalName -DisplayName $DisplayName -Department $Department -Path $Path -Company $Company -EmployeeID $EmployeeID -Fax $Fax -OfficePhone $OfficePhone -HomePhone $DirectDial -Mobile $Mobile -StreetAddress $StreetAddress -City $City -POBox $PObox -State $State -PostalCode $PostalCode -ChangePasswordAtLogon -OtherAttributes @{title=$title;mail=$EmailAddress;wwwHomePage=$WWWHomePage;c=;co=;ipPhone=$InternalExtension;info=$qualifications}

#This section adds the users email addresses. The primary email address should be SMTP in caps, secondary addresses in lowercase.
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses=}
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses=}
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses=}

#pauses the script to allow AD to replicate
start-sleep -milliseconds 5000

#Adds user into standard company groups
 Add-ADGroupMember -Identity  -Members $SAMAccountName
 Add-ADGroupMember -Identity  -Members $SAMAccountName
 Add-ADGroupMember -Identity  -Members $SAMAccountName

#Adds user into location specific security groups
If ($Location -eq 'Exeter')
 {
Add-ADGroupMember -Identity  -Members $SAMAccountName

}

ElseIf ($Location -eq 'Plymouth')
 {
Add-ADGroupMember -Identity  -Members $SAMAccountName
 }

ElseIf ($Location -eq 'Truro')
 {
Add-ADGroupMember -Identity  -Members $SAMAccountName
 }

ElseIf ($Location -eq 'Bristol')
 {
Add-ADGroupMember -Identity  -Members $SAMAccountName
}

Start-sleep -milliseconds 5000
Set-ADAccountPassword -identity $SAMAccountName -NewPassword $password -Reset
Start-sleep -milliseconds 5000
Enable-ADAccount -Identity $SAMAccountName



#This section forces and AD to 365 Delta sync from the domain controller, then pauses the script to make sure the sync has completed.
Invoke-Command -Computer Contoso-AD1 -Scriptblock {Start-ADSyncSyncCycle -PolicyType Delta}
start-sleep -milliseconds 10000



#This part of the script connects to a Powershell session via the on-prem exchange 2013 server (hybrid environment).
$Session = New-PSSession –ConfigurationName Microsoft.Exchange –ConnectionUri http://contoso-mbx1/powershell -Authentication Kerberos
Import-PSSession $Session -DisableNameChecking -AllowClobber

#This part creates the Office365 mailbox though the on-premise exchange 2013 server (hybrid mode)
Enable-RemoteMailbox -identity $SAMAccountName –remoteroutingaddress $RemoteRoutingAddress

#This bit turns on mailbox archiving - check your licencing arrangement!
Enable-RemoteMailbox $SAMAccountName -Archive

#Forces the script to pause whilst 365 account is setup
start-sleep -milliseconds 10000

#Connects to Office 365 portal. Will prompt for valid admin credentials. Manually running $AccountSKU Will report back number of licences used / available.
import-module MsOnline
Connect-MsolService
$AccountSKU = Get-MsolAccountSKU
$AccountSKU
$UserLicence = Get-MsolUser -UserPrincipalName $UserPrincipalName

#This sets the users location; needed before licences can be assigned
 Set-MsolUser -UserPrincipalName $UserPrincipalName -UsageLocation GB

Write-host 
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses 
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses 
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses 
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses 
start-sleep -milliseconds 5000

#Cleans up Exchange on premise script session
Remove-PSSession $Session
$Credential = Get-Credential
$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri  -Credential $credential -Authentication  -AllowRedirection
Import-PSSession $ExchangeSession
start-sleep -milliseconds 5000
Get-Mailbox -identity $SAMAccountName | Set-Mailbox -LitigationHoldEnabled $True
start-sleep -milliseconds 5000

#Cleans up connection to 365 servers
Remove-PSSession $ExchangeSession

write-host 
start-sleep -milliseconds 10000
