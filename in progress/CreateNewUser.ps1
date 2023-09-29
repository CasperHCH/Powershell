#Installs AD modules
import-module activedirectory

Write-host "Please complete the following questions, Ensure spelling and case are accurate" -ForegroundColor Yellow

$First=Read-Host 'Enter First and Middle Name'
$Last=Read-Host 'Enter Last Name'
$Initials=Read-Host 'Enter Initials'
$Title=Read-Host 'Enter Job Title'
$Mobile=Read-Host 'Enter the Mobile Phone Number. Press Space then Enter if information is not available'
$Department=Read-Host 'Enter the users department. Press Space then Enter if information is not available'
$DirectDial=Read-Host 'Enter the users direct dial number. Press Space then Enter if information is not available'

    Write-Host "================== Select a Location ==================" -ForegroundColor Green
    Write-Host "AT  - Austria, Wiener Neudorf    : Press '1' for this option."-ForegroundColor Green
    Write-Host "BE  - Benelux, Diegem            : Press '2' for this option."-ForegroundColor Green
    Write-Host "CH  - Switzerland, Hünenberg     : Press '3' for this option."-ForegroundColor Green
    Write-Host "CZ  - Czech Republic, Praha      : Press '4' for this option."-ForegroundColor Green
    Write-Host "DE  - Germany, Dusseldorf        : Press '5' for this option."-ForegroundColor Green
    Write-Host "DE  - Germany, Frankfurt         : Press '6' for this option."-ForegroundColor Green
    Write-Host "DK  - Denmark, Birkeørd          : Press '7' for this option."-ForegroundColor Green
    Write-Host "ES  - Spain, Madrid              : Press '8' for this option."-ForegroundColor Green
    Write-Host "ES  - Spain, Portugal            : Press '9' for this option."-ForegroundColor Green
    Write-Host "FI  - Finland, Espoo             : Press '10' for this option."-ForegroundColor Green
    Write-Host "FR  - France, Lyon               : Press '11' for this option."-ForegroundColor Green
    Write-Host "FR  - France, Paris              : Press '12' for this option."-ForegroundColor Green
    Write-Host "IE  - Ireland, Ballycoolin       : Press '13' for this option."-ForegroundColor Green
    Write-Host "INT - International, Århus       : Press '14' for this option."-ForegroundColor Green
    Write-Host "IT  - Italy, Milano              : Press '15' for this option."-ForegroundColor Green
    Write-Host "NL  - Nederland, AC Utrecht      : Press '16' for this option."-ForegroundColor Green
    Write-Host "NO  - Norway, Oslo               : Press '17' for this option."-ForegroundColor Green
    Write-Host "PL  - Poland, Gdańsk             : Press '18' for this option."-ForegroundColor Green
    Write-Host "PL  - Poland, Piaseczno          : Press '19' for this option."-ForegroundColor Green
    Write-Host "SE  - Sweden, Göteborg           : Press '20' for this option."-ForegroundColor Green
    Write-Host "SE  - Sweden, Malmö              : Press '21' for this option."-ForegroundColor Green
    Write-Host "SE  - Sweden, Stockholm          : Press '22' for this option."-ForegroundColor Green
    Write-Host "UK  - United Kingdom, Lydd       : Press '23' for this option."-ForegroundColor Green
    Write-Host "UK  - United Kingdom, Shrewsbury : Press '24' for this option."-ForegroundColor Green
    Write-Host "UK  - United Kingdom, Uxbridge   : Press '25' for this option."-ForegroundColor Green
    Write-Host "UK  - United Kingdom, ERNITEC    : Press '26' for this option."-ForegroundColor Green
    Write-Host "EET Group                        : Press '27' for this option."-ForegroundColor Green
    

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                    'You chose option #1 - AT - Austria, Wiener Neudorf'
                    $UserPrincipalName=$Initials+'@eeteuroparts.at'
                    $Path="OU=Users,OU=AT,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+43 2236 374014"
                    $Fax=""
                    $StreetAddress="IZ NÖ-Süd, Str. 2, Obj. M7"
                    $POBox=""
                    $City="Wiener Neudorf"
                    $State=""
                    $PostalCode="2351"
                    $Company="EET Austria"
                    $WWWHomePage="www.eeteuroparts.at"
                    start-sleep -milliseconds 10000
                }#End Option 1
                                
            '2' {#Option 2 is selected
                    'You chose option #2 - BE - Benelux, Diegem'
                    $UserPrincipalName=$Initials+'@eeteuroparts.be'
                    $Path="OU=BE,OU=Users,OU=NL,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+32 (0) 2 888 89 01"
                    $Fax=""
                    $StreetAddress="Pegasuslaan 5"
                    $POBox=""
                    $City="Diegem"
                    $State="Belgium"
                    $PostalCode="1831"
                    $Company="EET Belgium"
                    $WWWHomePage="www.eeteuroparts.be"
                    start-sleep -milliseconds 10000
                }#end option 2

            '3' {#Option 3 is selected
                    'You chose option #3 - CH - Switzerland, Hünenber'
                    $UserPrincipalName=$Initials+'@eeteuroparts.ch'
                    $Path="OU=Users,OU=CH,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+41 41 785 13 13"
                    $Fax=""
                    $StreetAddress="Bösch 108"
                    $POBox=""
                    $City="Hünenberg"
                    $State=""
                    $PostalCode="6331"
                    $Company="EET Switzerland"
                    $WWWHomePage="www.eeteuroparts.ch"
                    start-sleep -milliseconds 10000
                }#End Option 3
                                
            '4' {#Option 4 is selected
                    'You chose option #4 - CZ - Czech Republic, Praha'
                    $UserPrincipalName=$Initials+'@eeteuroparts.cz'
                    $Path="OU=Users,OU=CZ,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+420 226 259 750"
                    $Fax=""
                    $StreetAddress="Čerčanská 640/30"
                    $POBox=""
                    $City="Praha 4 - Krč"
                    $State=""
                    $PostalCode="140 00"
                    $Company="EET Czech Republic"
                    $WWWHomePage="www.eeteuroparts.cz"
                    start-sleep -milliseconds 10000
                }#end option 4

            '5' {#Option 5 is selected
                    'You chose option #5 - DE - Germany, Dusseldorf'
                    $UserPrincipalName=$Initials+'@eeteuroparts.de'
                    $Path="OU=Dusseldorf,OU=Users,OU=DE,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+49 2 11 75 84 67 0"
                    $Fax="+49 2 11 75 84 67 29"
                    $StreetAddress="Elisabeth-Selbert-Straße 5a"
                    $POBox=""
                    $City="Langenfeld "
                    $State=""
                    $PostalCode="D-40764"
                    $Company="EET Germany"
                    $WWWHomePage="www.eeteuroparts.de"
                    start-sleep -milliseconds 10000
                    
                }#End Option 5
                                
            '6' {#Option 6 is selected
                    'You chose option #6 - DE - Germany, Frankfurt'
                    $UserPrincipalName=$Initials+'@eeteuroparts.de'
                    $Path="OU=Frankfurt,OU=Users,OU=DE,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+49 2173 20041-0"
                    $Fax=""
                    $StreetAddress="Geleitstr. 66"
                    $POBox=""
                    $City="Hanau "
                    $State=""
                    $PostalCode="D-63456"
                    $Company="EET Germany"
                    $WWWHomePage="www.eeteuroparts.de"
                    start-sleep -milliseconds 10000
                }#end option 6

            '7' {#Option 7 is selected
                    'You chose option #7 - DK - Denmark, Birkeørd'
                    $UserPrincipalName=$Initials+'@eeteuroparts.dk'
                    $Path="OU=Frankfurt,OU=Users,OU=DE,OU=EET_Nordic,DC=eetnordic,DC=net"
                    $OfficePhone="+49 2173 20041-0"
                    $Fax=""
                    $StreetAddress="Geleitstr. 66"
                    $POBox=""
                    $City="Hanau "
                    $State=""
                    $PostalCode="D-63456"
                    $Company="EET Germany"
                    $WWWHomePage="www.eeteuroparts.de"
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


        Default {Write-Host "Invalid entry. Please enter a digit between '1' and '27' " -ForegroundColor Red}
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
$password=Read-Host "Enter Users Password" -AsSecureString



#Create user section - this builds the AD account using the fields above
New-ADUser -SAMAccountName $SAMAccountName -name $DisplayName -GivenName $First -Surname $Last -UserPrincipalName $UserPrincipalName -DisplayName $DisplayName -Department $Department -Path $Path -Company $Company -EmployeeID $EmployeeID -Fax $Fax -OfficePhone $OfficePhone -HomePhone $DirectDial -Mobile $Mobile -StreetAddress $StreetAddress -City $City -POBox $PObox -State $State -PostalCode $PostalCode -ChangePasswordAtLogon -OtherAttributes @{title=$title;mail=$EmailAddress;wwwHomePage=$WWWHomePage;c="GB";co="United Kingdom";ipPhone=$InternalExtension;info=$qualifications}

#This section adds the users email addresses. The primary email address should be SMTP in caps, secondary addresses in lowercase.
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses="SMTP:$EmailAddresses"}
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses="smtp:$OldEmailAddress"}
Set-ADUser -identity $SAMAccountName -Add @{ProxyAddresses="smtp:$ProxyEmailAddresses"}

#pauses the script to allow AD to replicate
start-sleep -milliseconds 5000

#Adds user into standard company groups
 Add-ADGroupMember -Identity "Generic AD Security Group 1 SG" -Members $SAMAccountName
 Add-ADGroupMember -Identity "Generic AD Security Group 1 SG" -Members $SAMAccountName
 Add-ADGroupMember -Identity "Generic AD Security Group 1 SG" -Members $SAMAccountName

#Adds user into location specific security groups
If ($Location -eq 'Exeter')
 {
Add-ADGroupMember -Identity "Exeter Security Group" -Members $SAMAccountName

}

ElseIf ($Location -eq 'Plymouth')
 {
Add-ADGroupMember -Identity "Plymouth Security Group" -Members $SAMAccountName
 }

ElseIf ($Location -eq 'Truro')
 {
Add-ADGroupMember -Identity "Truro Security Group" -Members $SAMAccountName
 }

ElseIf ($Location -eq 'Bristol')
 {
Add-ADGroupMember -Identity "Bristol Security Group" -Members $SAMAccountName
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

Write-host "Assigning licences: Office 365 E3, MS ATP, Windows 10 and PowerBi Std"
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses "Contoso:ENTERPRISEPACK"
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses "Contoso:ATP_ENTERPRISE"
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses "Contoso:POWER_BI_STANDARD"
 Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses "Contoso:WIN10_PRO_ENT_SUB"
start-sleep -milliseconds 5000

#Cleans up Exchange on premise script session
Remove-PSSession $Session
$Credential = Get-Credential
$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid" -Credential $credential -Authentication "Basic" -AllowRedirection
Import-PSSession $ExchangeSession
start-sleep -milliseconds 5000
Get-Mailbox -identity $SAMAccountName | Set-Mailbox -LitigationHoldEnabled $True
start-sleep -milliseconds 5000

#Cleans up connection to 365 servers
Remove-PSSession $ExchangeSession

write-host "Allow 60 minutes for Microsoft / Office 365 to create the mailbox"
start-sleep -milliseconds 10000