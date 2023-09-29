#Requires -RunAsAdministrator

<# --- Import modules --- #>

Import-Module ActiveDirectory


### EXCHANGE ###

# Functions to connect / disconnect Remote Exchange Management Shell
Function Connect-ExchPowershell {
    $RPSession = New-PSSession -Name "ExchSession" -ConfigurationName Microsoft.Exchange -ConnectionURI http://BQ-MBX-02/Powershell
    Import-PSSession $RPSession -Prefix local
} #end function

Function Disconnect-ExchPowershell {
    Get-PSSession -Name "ExchSession" | Remove-PSSession
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
Function Connect-O365Powershell {
Write-Host "You are being prompted for your Office 365 Login - Remember user@eetnordic.net" -ForegroundColor Yellow
    $O365Session = New-PSSession -Name "O365Session" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
}

Function Disconnect-O365Powerhell {
    Get-PSSession -Name "O365Session" | Remove-PSSession
}

###  END O365  ###


<# --- VARIABLES FOR AD ACCOUNT --- #>



# read username
$DisableUserName = read-host "enter username of the user you want to disable"

# Get the properties of the account and set variables
$user = Get-ADuser $DisableUserName -properties *
$UManagerEmail=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties emailaddress).EmailAddress
$UManagerSAM=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties SamAccountName).SamAccountName
$UManagerName=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties Name).Name
$UserEmail = $user.EmailAddress
$dn = $user.distinguishedName
$cn = $user.canonicalName
$din = $user.displayName
$UserAlias = $user.mailNickname
$UCompany = $user.Company
$sam = $user.SamAccountName
$DirectReports = $user.directReports
$Upn = $user.UserPrincipalName


<# --- END OF VARIABLES FOR AD ACCOUNT --- #>




# Path for safekeeping User AD Groups
$pathForADUserGroups1 = "\\file.eetnordic.net\EET\G1-IT-OPERATIONS\Dokumentation\Disabled_Users\"
$pathForADUserGroups2 = "-AD-DisabledUserPermissions.txt"
$pathForADUserGroupsFinal = $pathForADUserGroups1 + $din + $pathForADUserGroups2

# Check if folder exist, if not, create it
If(!(test-path $pathForADUserGroups1))
{
      New-Item -ItemType Directory -Force -Path $pathForADUserGroups1
}


# Path for safekeeping User Email Aliases
$pathForADUserEmailALias1 = "\\file.eetnordic.net\EET\G1-IT-OPERATIONS\Dokumentation\Disabled_Users\"
$pathForADUserEmailALias2 = "-AD-DisabledUserEmailAlias.txt"
$pathForADUserEmailALiasFinal = $pathForADUserEmailALias1 + $din + $pathForADUserEmailALias2


# Check if file exist, if it does, delete it
# File contains Custom OoO message
$file = "C:\temp\tomail.txt"
If(test-path $file)
{
     Remove-Item -Path $file -Recurse
}




#Read the desired disable date
while(1)
    {
	$d = read-host "Provide the date, the User Account should be disabled, in the format DD-MM-YYYY"
    	Try{
    
            # Extract the default Date/Time formatting from the local computer's "Culture" settings, and then create the format to use when parsing the date/time information pull from AD.
            $CultureDateTimeFormat = (Get-Culture).DateTimeFormat
            $DateFormat = $CultureDateTimeFormat.ShortDatePattern
            $DisableUserOnDate = [DateTime]::ParseExact($d,$DateFormat,[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
            write-host "You have selected the following date: $DisableUserOnDate" -ForegroundColor Yellow
            break
            }
    	Catch{
    		Write-Host "Not a valid date, try again, use '-' between the numbers" -ForegroundColor Red
            }
    }



<# --------------------------------- Active Directory account dispensation section --------------------------------- #>

##Check if the user is a manager, if so, move any users within to a different manager
function ChangeManager(){
if(!$DirectReports) { Write-Host "This user is not a manager, and havent got any Direct reports"-ForegroundColor Yellow } 
   else { 


    Write-Host "================ Change of Manager for all Direct Reports ================" -ForegroundColor Green
    Write-Host "Change Manager to next in line: Press '1' for this option."-ForegroundColor Green
    Write-Host "Change Manager to Custom User : Press '2' for this option."-ForegroundColor Green

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                    'You chose option #1 - Change Manager to next in line'
                    
                    foreach ($DR in $DirectReports) 
                    {
                       Set-ADUser $DR -Manager $UManagerSAM
                    }#End Foreach
                }#End Option 1
               
                
                 
            '2' {#Option 2 is selected
                'You chose option #2 - Change Manager to Custom User'
                
                while(1){
                $NewManager = Read-Host "Please provide the username of the user, that should be the new Manager for all the Direct Reports"
                try
                    {
                    if(Get-ADUser -Identity $NewManager)
                        {
                            Set-ADUser $DR -Manager $NewManager
                        }#End If
                    }#End Try
                    
                catch
                    {
                        Write-Host "The username is not recognised" -fore red}
                    }#End Catch
                
                }#end option 2
        Default {Write-Host "Invalid entry. Please enter either 1 or 2" -ForegroundColor Red}
        }#End Switch
    }#End Else
}#End Function



##Move user account to the previous selected month for deletion
function MoveUserToWantedDeletionOU($TargetOUMonth)
{
   # Move the account to the Disabled Users OU
    Move-ADObject -Identity $dn -TargetPath "$($TargetOUMonth)"
    Write-Host ("* " + $din + "'s Active Directory account moved to $($TargetOUMonth)") -ForegroundColor Yellow

}

#Show a menu, allowing the user to select a month the user should be deleted etc.
function Show-Delete-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================" -ForegroundColor Green
    Write-Host "January  : Press '1' for this option."-ForegroundColor Green
    Write-Host "February : Press '2' for this option."-ForegroundColor Green
    Write-Host "Marts    : Press '3' for this option."-ForegroundColor Green
    Write-Host "April    : Press '4' for this option."-ForegroundColor Green
    Write-Host "Maj      : Press '5' for this option."-ForegroundColor Green
    Write-Host "June     : Press '6' for this option."-ForegroundColor Green
    Write-Host "July     : Press '7' for this option."-ForegroundColor Green
    Write-Host "August   : Press '8' for this option."-ForegroundColor Green
    Write-Host "September: Press '9' for this option."-ForegroundColor Green
    Write-Host "November : Press '10' for this option."-ForegroundColor Green
    Write-Host "Oktober  : Press '11' for this option."-ForegroundColor Green
    Write-Host "December : Press '12' for this option."-ForegroundColor Green

    $TargetOUMonth = Read-Host "Please select a month, the user should be deleted"

    switch ($TargetOUMonth)
        {
            '1' {#Option 1 is selected
                $TargetOUMonth = "OU=01. Januar,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #1 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '2' {#Option 2 is selected
                $TargetOUMonth = "OU=02. Februar,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #2 - '+ $TargetOUMonth 
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '3' {#Option 3 is selected
                $TargetOUMonth = "OU=03. Marts,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #3 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '4' {#Option 4 is selected
                $TargetOUMonth = "OU=04. April,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #4 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '5' {#Option 5 is selected
                $TargetOUMonth = "OU=05. Maj,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #5 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '6' {#Option 6 is selected
                $TargetOUMonth = "OU=06. Juni,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #6 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '7' {#Option 7 is selected
                $TargetOUMonth = "OU=07. Juli,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #7 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '8' {#Option 8 is selected
                $TargetOUMonth = "OU=08. August,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #8 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '9' {#Option 9 is selected
                $TargetOUMonth = "OU=09. September,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #9 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
           '10' {#Option 10 is selected
                $TargetOUMonth = "OU=10. Oktober,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #10 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '11' {#Option 11 is selected
                $TargetOUMonth = "OU=11. November,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #11 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '12' {#Option 12 is selected
                $TargetOUMonth = "OU=12. December,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #12 - '+ $TargetOUMonth
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter a digit between '1' and '12' " -ForegroundColor Red
          Show-Delete-Menu($Title)
          }
     }
   }#End Function



## Disable ad user
## Disable Logon Hours
## Rest Password
## Add OU path to User Description
## Export Group membership to TXT file
## Strip of all group memberships
function DisableUser
{
if ($DisableUserOnDate -eq (Get-Date).Date)
    {
    
    # Disable the account
        Disable-ADAccount $sam
        Write-Host ($din + "'s Active Directory account is disabled.") -ForegroundColor Yellow
    
    # Reset password
        Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "j4Z5iHeQzw4L593" -Force) $sam
        Write-Host ("* " + $din + "'s Active Directory password has been changed.") -ForegroundColor Yellow
    
    # Add the OU path where the account originally came from to the description of the account's properties
        $date = [datetime]::Today.ToString('dd-MM-yyyy')
        Set-ADUser $dn -Description ("Moved from: " + $cn + " - on $date")
        Write-Host ("* " + $din + "'s Active Directory account path saved.") -ForegroundColor Yellow


   ## Set logon hours on the account, to disabled
    # Create an array of 21 bytes, each of 8 bits, representing the 168 hours in a week.
    # This is done to Deny user logon, at any hour of the day, any day of the week.
    $LH = New-Object 'Byte[]' 21

    # Populate binary array with all zeros. The user cannot logon during any hour of the week.
    # Since the array is all zeros, no conversion into UTC needed.
        For ($k = 0; $k -le 20; $k = $k + 1)
        {
            $LH[$k] = 0
        } 
    # Assign 21 byte array of all zeros to the logonHours attribute of the user
    set-aduser -identity "$($DisableUserName)" -Replace @{logonHours=$LH}    

    #Check if the user is a manager, and if so, change the direct reports to a different manager
    ChangeManager

    Show-Delete-menu("User Deletion Month")
    }

    else{
    #set account expiration
        Set-ADAccountExpiration -Identity "$($DisableUserName)" -DateTime $DisableUserOnDate

    
    }
}#End DisableUser

function RemoveADUserGroups
{
 # Get the list of permissions (group names) and export them to a CSV file for safekeeping
    $groupinfo = get-aduser $sam -Properties memberof | select name, 
    @{ n="GroupMembership"; e={($_.memberof | foreach{get-adgroup $_}).name}}
    
    $count = 0
    $arrlist =  New-Object System.Collections.ArrayList
    do{
        $null = $arrlist.add([PSCustomObject]@{
            # Name = $groupinfo.name
            GroupMembership = $groupinfo.GroupMembership[$count]
        })
        $count++
    }until($count -eq $groupinfo.GroupMembership.count)
    
    $arrlist | select groupmembership | convertto-csv -NoTypeInformation | select -Skip 1 |out-file $pathForADUserGroupsFinal
    Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) exported and saved to " + $pathForADUserGroupsFinal) -ForegroundColor Yellow
    
    # Strip the permissions from the account
    Get-ADUser $User -Properties MemberOf | Select -Expand MemberOf | %{Remove-ADGroupMember $_ -member $User} -Confirm:$false
    Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) stripped from account") -ForegroundColor Yellow
    }
<# --------------------------------- Exchange email account section --------------------------------- #>

## Export all Email aliases to an TXT file
function ExportEmailAliasToCSV
{
    try{
            #Check if user exist on Local prem
         if(Get-Mailbox -Identity $("$Upn"))
            {
               Get-Mailbox -Identity $("$Upn") | select -ExpandProperty emailaddresses alias |Out-File $pathForADUserEmailALiasFinal
            }
            }catch{}
            try{
            #Check if the user exist in O365
        if(get-cloudMailbox -Identity $("$Upn"))
           {
              Get-CloudMailbox -Identity $("$Upn") | select -ExpandProperty emailaddresses alias |Out-File $pathForADUserEmailALiasFinal
              
           }
        }
        
        catch{}
    
}


function Show-EmailForward-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================" -ForegroundColor Green
    Write-Host "(Default) NO         : Press '1' for this option."-ForegroundColor Green
    Write-Host "(YES) Enable Forward : Press '2' for this option."-ForegroundColor Green
    Write-Host "Skip this step       : Press '3' for this option."-ForegroundColor Green

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                write-host 'This is the default, No forward will be enabled' -ForegroundColor Yellow
                
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                 write-host 'An forward is about to be enabled' -ForegroundColor Yellow

                    while($ReceiverEmail -ne "skip"){
                    $ReceiverEmail = Read-Host "Please provide an email address, or type 'skip' to skip this step"
                    try{
                        if(get-localmailbox $ReceiverEmail)
                            {
                                #Check if the disable user exists onprem
                                if(get-localmailbox $Upn)
                                    {
                                        Set-Mailbox $Upn -DeliverToMailboxAndForward $ReceiverEmail
                                        write-host "Email has now been forwarded. It will still be delivered into the mailbox"-ForegroundColor Yellow
                                        $receiverEmail = "skip"
                                    }
                            }
                        if(get-cloudmailbox $ReceiverEmail)
                           {
                              #Check if the disabled user exists in Office 365
                              if(get-cloudmailbox $Upn){
                              Set-CloudMailbox $Upn -ForwardingAddress $ReceiverEmail -DeliverToMailboxAndForward $true
                              write-host "Email has now been forwarded. It will still be delivered into the mailbox"-ForegroundColor Yellow
                              $receiverEmail = "skip"
                              }
                           }
                        }
                        
                    catch{Write-Host "The email doesnt exist in our enviroment, please try again" -fore red}
                    
                    }
                }
            '3' {#Open 3 is selected
                'You chose option #3'
                Write-Host 'You have chosen to skip this step' -ForegroundColor Yellow
                }
               
                
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter either 1, 2 or 3" -ForegroundColor Red
          Show-EmailForward-Menu($Title)
          }
     }
}#End Function

#Provide the manager or a custom user with full access to the users mailbox
function AddFullAccessToMailbox([string]$Title)
{#Start Function
    Write-Host "================ $Title ================" -ForegroundColor Green
    Write-Host "Give Manager full access: Press '1' for this option."-ForegroundColor Green
    Write-Host "Give a user full access : Press '2' for this option."-ForegroundColor Green
    Write-Host "Give no one full access : Press '3' for this option" -ForegroundColor Green

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                
                if(get-LocalMailbox $upn){
                    Add-MailboxPermission -Identity $upn -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                    write-host "$($UManagerSAM) has been granted Full Access to the mailbox" -ForegroundColor Yellow
                    }
                
                    if(get-cloudmailbox $upn){
                        Add-MailboxPermission -Identity $upn -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                        write-host "$($UManagerSAM) has been granted Full Access to the mailbox"-ForegroundColor Yellow
                        }
               
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                    while(1){
                    $GrantFullAccessTo = Read-Host "Please provide the username of the user you want to grant full access"           
                    Try{
		                $GrantFullAccessToUser = Get-ADuser $GrantFullAccessTo -properties Name, SamAccountName
		                break
                       }
	                Catch{
	                	Write-Host 'Invalid entry, unable to locate a user with the provided username' -ForegroundColor red
                       }
                    }
                    try{
                    if(get-LocalMailbox $upn){
                        Add-MailboxPermission -Identity $upn -User $GrantFullAccessToUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                        write-host "$($GrantFullAccessToUser.Name) has been granted Full Access to the mailbox" -ForegroundColor Yellow
                    }
                    }catch{}
                    try{
                    if(get-cloudmailbox $upn){
                        Add-MailboxPermission -Identity $upn -User $GrantFullAccessToUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                        write-host "$($GrantFullAccessToUser.Name) has been granted Full Access to the mailbox" -ForegroundColor Yellow
                    }
                    }
                    catch{}
                
                }


            '3' {
                'You chose option #3'
                Write-Host "No one will be granted full access" -ForegroundColor Yellow

            
            }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter either 1 or 2 or 3" -ForegroundColor Red
          AddFullAccessToMailbox($Title)
          }
     }
}#End Function



#Set out of office message, to selected value - either default or custom
function SetOutOfOfficeMessage()
{#Start Function
# Get the properties of the account and set variables
$user = Get-ADuser $DisableUserName -properties canonicalName, distinguishedName, displayName, mailNickname, Company, EmailAddress, SamAccountName
$UManagerEmail=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties emailaddress).EmailAddress
$UManagerSAM=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties SamAccountName).SamAccountName
$UManagerName=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties Name).Name
$UserEmail = $user.EmailAddress
$dn = $user.distinguishedName
$cn = $user.canonicalName
$din = $user.displayName
$UserAlias = $user.mailNickname
$UCompany = $user.Company
$sam = $user.SamAccountName
$upn = $user.UserPrincipalName




# Sets the out of office message, to either default or custom message
    try{
    if(get-LocalMailbox $upn){
        Set-LocalMailboxAutoReplyConfiguration -Identity $upn -AutoReplyState Enabled -ExternalAudience All -InternalMessage $OoOMessage -ExternalMessage $OoOMessage
        AddFullAccessToMailbox("Grant full access to")
    }
    }catch{}

    try{                
    if(get-cloudmailbox $upn){
        Set-CloudMailboxAutoReplyConfiguration -Identity $upn -AutoReplyState Enabled -ExternalAudience All -InternalMessage $OoOMessage -ExternalMessage $OoOMessage
        AddFullAccessToMailbox("Grant full access to")
    }

    }
    catch{}


    #Remove the Out of office text file again if it exists
    If(test-path $file)
        {
            try{
            Remove-Item -Path $file -Recurse
            }
            catch{}
        }
}#End Function

#Show a menu, allowing the script runner to select 
#between the default or a custom OoO Message
function Show-OoOMessage-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================" -ForegroundColor Green
    Write-Host "Use Default Out of Office Message : Press '1' for this option."-ForegroundColor Green
    Write-Host "Create an Out of Office Message   : Press '2' for this option."-ForegroundColor Green

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
            'You chose option #1'
            $OoOMessage =    "Dear Sender.<br><br>
                              The receiver of this e-mail no longer works for $($UCompany).<br>
                              Please resend your mail to: $($UManagerEmail)<br><br>
                              Your mail will not be forwarded."

                
                SetOutOfOfficeMessage($OoOMessage)
                Show-EmailForward-Menu("Should the email be forwarded?")
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                write-host "Please provide the desired Out of Office message, once done type ""done"" on an empty line" -ForegroundColor Yellow
                    #Create a file to contain the custom OoO message
                    $file = "C:\temp\tomail.txt"
                    
                    #Read the host to a new line in the file, for each line break
                    #Exit the while loop when the script runner types done on an empty line
                    While($i -ne "done")
                    {
	                    If ($i -ne $NULL) 
                            {
		                        $i | Out-File $file -append
                            }
	                    $i = Read-Host "Text"
                    }
                
                # Replace line breaks from `n (Normal txt breaks) to <br> html breaks
                $file2 = Get-Content -Path C:\temp\tomail.txt -Raw
                $file3 = $file2.Replace("`n","<br>") | out-file -FilePath C:\temp\tomail.txt
                
                #Read the custom OoO message into a variable
                $OoOMessage = Get-Content -Path $file
                
                #Call function to set the OoO Message with variable
                SetOutOfOfficeMessage($OoOMessage)
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter either 1 or 2" -ForegroundColor Red
          Show-OoOMessage-Menu($Title)
          }
     }
}#End Function



<# --------------------------------- !! --- LOAD MODULES --- !! --------------------------------- #>

##Connect to and load required modules##
Connect-ExchPowershell

Connect-O365Powershell

<# --------------------------------- !! --- EXECUTE SCRIPT --- !! --------------------------------- #>
#Start AD part of the script
DisableUser
Write-Host "Script will now 'wait' for 10 seconds, to ensure the next commands will run correctly" -ForegroundColor Green
Start-Sleep -Seconds 10
write-host "The wait time is over, the Script will now continue"-ForegroundColor Green

#Start Exchange part of the script
if ($DisableUserOnDate -eq (Get-Date).Date){
Show-OoOMessage-Menu("Add Out Of Office Message")
ExportEmailAliasToCSV
RemoveADUserGroups
}
if($DisableUserOnDate -ne (Get-Date).Date){
Write-Host "Because the disable date is not equal to, today
The user account have been set to expire on the set date.
Nothing further will be done to the account at this point.
Please run this script again on the disable date, to
Set out of office message, forward etc."
}

Write-Host "The script is now Done" -ForegroundColor Cyan
<# --------------------------------- !! --- REMOVE MODULES --- !! --------------------------------- #>

##disconnect from and remove required modules##
Disconnect-ExchPowershell

Disconnect-O365Powerhell


# SIG # Begin signature block
# MIIPXgYJKoZIhvcNAQcCoIIPTzCCD0sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGdAMRntbkL7d5//bTAJwHpWm
# ZPygggzFMIIF5TCCBM2gAwIBAgITJQAAB18pNDQNK9T6twAAAAAHXzANBgkqhkiG
# 9w0BAQsFADBLMRMwEQYKCZImiZPyLGQBGRYDbmV0MRkwFwYKCZImiZPyLGQBGRYJ
# ZWV0bm9yZGljMRkwFwYDVQQDExBFRVQgR3JvdXAgU3ViIENBMB4XDTE5MDYyODA4
# NTg1MVoXDTIxMDYyNzA4NTg1MVowMjEwMC4GA1UEAxMnQ2FzcGVyIEhqb3J0aCBD
# aHJpc3RlbnNlbiBBZG1pbmlzdHJhdG9yMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAvK+8AVxkZIiTKbQFOsyBWVK/0a2Yr864LnbWHy7QFKpZfFcVY6X/
# ef++CDmg78ZdLarj2hcOfUqOFBlwIbh0BLcmdFAFwU7WCb1Yb1NiyhrIgH16D/l3
# USl5dIaGbNysrz3fJl8V57pZG6C3hOZjU4kt73jdM7C1BzAyZ8hsH5RxS6HLFtb7
# Chxh81LqHXAnJWmq6QZbVX2y0ZNLPgwyEyAqfD4yZgT4Xa8BkAaTrwSuYzNOncW9
# HFjl1vfKcqFUEfhuy9k78PFw0V2aCGF+5jlgtKGL46z4EFEmGVOt2eAKy7e53Gu8
# XzOT6Ccsh1DLnlu5xp35Ns3FRTx104wiFQIDAQABo4IC2TCCAtUwPAYJKwYBBAGC
# NxUHBC8wLQYlKwYBBAGCNxUI99Z8h/iMH9mJF4Hgsy6C8IQ5gQ+C9eJzhIzNGQIB
# aQIBAzATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNVHQ8EBAMCB4AwDAYDVR0TAQH/
# BAIwADAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBSGzkbt
# A2w0ns6vicHpag3PzRLdnjAfBgNVHSMEGDAWgBRBj6B94d5u5ZhabP6oFz+lQsCw
# aTCB3AYDVR0fBIHUMIHRMIHOoIHLoIHIhoHFbGRhcDovLy9DTj1FRVQlMjBHcm91
# cCUyMFN1YiUyMENBLENOPVBST0QtU1VCQ0EtMDEsQ049Q0RQLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# ZWV0bm9yZGljLERDPW5ldD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/
# b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwgfYGCCsGAQUFBwEBBIHp
# MIHmMIG3BggrBgEFBQcwAoaBqmxkYXA6Ly8vQ049RUVUJTIwR3JvdXAlMjBTdWIl
# MjBDQSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vydmlj
# ZXMsQ049Q29uZmlndXJhdGlvbixEQz1lZXRub3JkaWMsREM9bmV0P2NBQ2VydGlm
# aWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MCoG
# CCsGAQUFBzABhh5odHRwOi8vcGtpMS5lZXRub3JkaWMubmV0L29jc3AwMAYDVR0R
# BCkwJ6AlBgorBgEEAYI3FAIDoBcMFWNoai1hZG1AZWV0bm9yZGljLm5ldDANBgkq
# hkiG9w0BAQsFAAOCAQEAM7IhCVppWdb4eCHZCZVbMZ+qmsuMVXlfCnccfXwxP/Mc
# KwFN+oxf1T7oruyEbxYhbG+noSDzx/jyqgWd+kkZFbUCiFZ7SJonSDnqA2Kwq/C0
# bdIA1spJLXZ0HV3milBjQ2qM5gjMy3nnQYw9a2ngx4Ld18bJpIQzORKyFIso557P
# 19yRvWohWA5Qg9mBEQWUJ7BjWbLLm/SYwSlnHjr4eqZcKqV4m0vN98m5HdeS6jJc
# wHoEwPNfUAjyOUACdAb4LSgqIaXSE6qiqspY/J4uqd7UKiTp7qywRBj0P6pXbBnw
# iKGkN381RTMoTgYQMEkjITcdup7/OC8LewV8RK7O8TCCBtgwggTAoAMCAQICEzwA
# AAACp2Mbi4zdg2MAAAAAAAIwDQYJKoZIhvcNAQELBQAwHDEaMBgGA1UEAxMRRUVU
# IEdyb3VwIFJvb3QgQ0EwHhcNMTkwMjA2MDkyMjIxWhcNMjQwMjA2MDkzMjIxWjBL
# MRMwEQYKCZImiZPyLGQBGRYDbmV0MRkwFwYKCZImiZPyLGQBGRYJZWV0bm9yZGlj
# MRkwFwYDVQQDExBFRVQgR3JvdXAgU3ViIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEA2BhikY439/eE6CRdiGIn2jRm+KJ2+fDCYMLN/f/WZon4Xl5P
# HH+CAnBw5pC/Cv0xnMFhgJUhxDnLcm4GKnagOiAlxgE+ukzESzLigfOeMslvgXVt
# xi0g2Nf/Y4g4dCs+RT3kOt6gH+3r1SUkyI01zkkN576dR9hYq7P2YfWlREFOTZiA
# DKdBTLzZdZwz2foDInkIGFQBo4lEzOVbrZjyPaleXfIv7CJ5luMmN1tWZzREGk9F
# R3IQo2/4DtaaqDqy1jY9aLdlSiUP2+IlKMAR2huE3GWCDcyQOlJKi7AibFznTpzo
# zBwm8sLVs18/aMK6OPj1UV3+7l0fbcmhoYl2HwIDAQABo4IC4jCCAt4wEAYJKwYB
# BAGCNxUBBAMCAQAwHQYDVR0OBBYEFEGPoH3h3m7lmFps/qgXP6VCwLBpMBkGCSsG
# AQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTAD
# AQH/MB8GA1UdIwQYMBaAFNEanpkqTKdu+Q7qzwzlbNmFPr3+MIIBIwYDVR0fBIIB
# GjCCARYwggESoIIBDqCCAQqGgcdsZGFwOi8vL0NOPUVFVCUyMEdyb3VwJTIwUm9v
# dCUyMENBLENOPVBST0QtUk9PVENBLTAxLENOPUNEUCxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLGRjPWVldG5v
# cmRpYyxkYz1uZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVj
# dENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hj5odHRwOi8vcGtpMS5lZXRub3Jk
# aWMubmV0L0NlcnREYXRhL0VFVCUyMEdyb3VwJTIwUm9vdCUyMENBLmNybDCCASgG
# CCsGAQUFBwEBBIIBGjCCARYwgbgGCCsGAQUFBzAChoGrbGRhcDovLy9DTj1FRVQl
# MjBHcm91cCUyMFJvb3QlMjBDQSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixkYz1lZXRub3JkaWMs
# ZGM9bmV0P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0
# aW9uQXV0aG9yaXR5MFkGCCsGAQUFBzAChk1odHRwOi8vcGtpMS5lZXRub3JkaWMu
# bmV0L0NlcnREYXRhL1BST0QtUk9PVENBLTAxX0VFVCUyMEdyb3VwJTIwUm9vdCUy
# MENBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAyWGf9yQmujZDbugAxpqQIdPj1kab
# /znUHIHEyUkpfQ9bvCR3iWz57F7217oOemlpexIAz/1D1QIgAxdgHykX0gjaKOO3
# oS22sx/8l0hzQDoe0Oy1u6AOxJ/gtd/oEohAyldpg0Hfv60xdjFw+5zLzVbVQfaD
# 1odeX0ea+5R/w6X50PRCQTQNCvlq4U3JiZ5G2t0YsVqYa/uiRODy0pyW+RIBxuqE
# FVQLbVgymixf4GhnZ1PLkAcd0cUP+V68bywEApfim72XkCw7S+IRBaSVRwgZSD6g
# Zf4mgHsOUgSX6q7dqDrIIVP3Qv6FvcNYHTt6oZGM5GpZ/TP8g972RT8f5r1a85F9
# EDFJR9DmTZ3NK5Hc6jg0/KYNzDWuU1IZgmJytlUiVume5XKm1kYMzIFKh9wVdYK0
# WMWmBsyi40ycw7VMN3J23eLscARWXOQYzanLQ1hLdLUUo5T+KLaisfkRilxAueKD
# GKtgyJnM676QzDOdFr6beW/znpwxBbxVuO7FIDeZ1Ngz1LT5+zXq/vJ4P92L44m8
# H+cT1E9OSxGLrUFRW3FYce+wC31cw34ui3VUidk+5JneMFTJA+npXysEJwzt+9TE
# AxrmnoMeyNYqw4FSDE2aQRPDxlk+a5Pr+iZtzLes9tL6OaswA6FUAuwtGWNGv3rb
# ilNGOO713QEQjM4xggIDMIIB/wIBATBiMEsxEzARBgoJkiaJk/IsZAEZFgNuZXQx
# GTAXBgoJkiaJk/IsZAEZFgllZXRub3JkaWMxGTAXBgNVBAMTEEVFVCBHcm91cCBT
# dWIgQ0ECEyUAAAdfKTQ0DSvU+rcAAAAAB18wCQYFKw4DAhoFAKB4MBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGHU4OTw
# Pfp2t6HkLBYzabAkkCxhMA0GCSqGSIb3DQEBAQUABIIBALh0GBtl9ONDtdMWmXSv
# 9PHxLt/Yg9YJxrlAeopPzB2wQV9PzKzyQPUBQa3bDkDxL0asUV7Dhu0xfHtVx/2X
# uNgsQUG0AHXCl9X8X3+qJi7Xiv/z5ZbttE7RAgTAVt8Z1Y9djVOZB921EjZkJPrI
# RUlSHXB+orHMB7DHf0NA8EtDn4dwY2tIIMCrq5YqNxP7Ji2MOudEDZtAaHTiZ2s8
# OV61vRSemLSE7gYrwT4WUuga1Pn2RtvfYYezf/i1yNYVn4Xm8lzRmiwBZYJgJdgH
# Ij4C8/zRKg3LZWjmTCBs88EoywnQXLXUaumMXbJV1HX+gkUNFWEdIbRSmZAXrjxO
# IJY=
# SIG # End signature block
