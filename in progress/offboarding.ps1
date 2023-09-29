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
    $O365Session = New-PSSession -Name "O365Session" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
}

Function Disconnect-O365Powerhell {
    Get-PSSession -Name "O365Session" | Remove-PSSession
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
Function Connect-LyncPowershell {
    $CSSession = New-PSSession -Name "CSSession" -ConnectionUri "https://LyncAdmin.eetgroup.com/OcsPowershell" -Credential (Get-Credential)
    Import-PSSession $CSSession
} #end function

Function Disconnect-LyncPowershell {
    Get-PSSession -Name "CSSession" | Remove-PSSession
} #end function

## END LYNC ##

# Path for safekeeping User AD Groups
$path1 = "\\file\EET\G1-IT-OPPERATIONS\Dokumentation\Disabled_Users"
$path2 = "-AD-DisabledUserPermissions.csv"
$pathFinal = $path1 + $din + $path2

# Check if folder exist, if not, create it
$path1 = "\\file\EET\G1-IT-OPPERATIONS\Dokumentation\Disabled_Users"
If(!(test-path $path1))
{
      New-Item -ItemType Directory -Force -Path $path1
}

# Check if file exist, if it does, delete it
$file = "C:\temp\tomail.txt"
If(!(test-path $file))
{
     Remove-Item -Path $file -Recurse
}


# read username
$DisableUserName = read-host "enter username of the user you want to disable"

# Get the properties of the account and set variables
$user = Get-ADuser $DisableUserName -properties canonicalName, distinguishedName, displayName, mailNickname, Company
$UManagerEmail=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties emailaddress).EmailAddress
$UManagerSAM=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties SamAccountName).SamAccountName
$UManagerName=(Get-AdUser (Get-aduser $DisableUserName -properties Manager).manager -properties Name).Name
$dn = $user.distinguishedName
$cn = $user.canonicalName
$din = $user.displayName
$UserAlias = $user.mailNickname
$UCompany = $user.Company

#Read the desired disable date
while(1){
	$d = read-host "Provide the date, the User Account should be disabled, in the format DD-MM-YYYY"
	Try{
		$DisableUserOnDate = [datetime]$d
		break
    }
	Catch{
		Write-Host 'Not a valid date, try again, use . or - or / or Space between the numbers' -fore red
    }
}


<# --- Active Directory account dispensation section --- #>



##Move user account to the previous selected month for deletion
function MoveUserToWantedDeletionOU($TargetOUMonth)
{
   # Move the account to the Disabled Users OU
    Move-ADObject -Identity $dn -TargetPath "$($TargetOUMonth)"
    Write-Host ("* " + $din + "'s Active Directory account moved to $($TargetOUMonth)")

}

#Show a menu, allowing the user to select a month the user should be deleted etc.
function Show-Delete-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================"
    Write-Host "January  : Press '1' for this option."
    Write-Host "February : Press '2' for this option."
    Write-Host "Marts    : Press '3' for this option."
    Write-Host "April    : Press '4' for this option."
    Write-Host "Maj      : Press '5' for this option."
    Write-Host "June     : Press '6' for this option."
    Write-Host "July     : Press '7' for this option."
    Write-Host "August   : Press '8' for this option."
    Write-Host "September: Press '9' for this option."
    Write-Host "November : Press '10' for this option."
    Write-Host "Oktober  : Press '11' for this option."
    Write-Host "December : Press '12' for this option."
    $TargetOUMonth = Read-Host "Please select a month, the user should be deleted"
    switch ($TargetOUMonth)
        {
            '1' {#Option 1 is selected
                $TargetOUMonth = "OU=01. Januar,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #1'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '2' {#Option 2 is selected
                $TargetOUMonth = "OU=02. Februar,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #2'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '3' {#Option 3 is selected
                $TargetOUMonth = "OU=03. Marts,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #3'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '4' {#Option 4 is selected
                $TargetOUMonth = "OU=04. April,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #4'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '5' {#Option 5 is selected
                $TargetOUMonth = "OU=05. Maj,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #5'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '6' {#Option 6 is selected
                $TargetOUMonth = "OU=06. Juni,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #6'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '7' {#Option 7 is selected
                $TargetOUMonth = "OU=07. Juli,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #7'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '8' {#Option 8 is selected
                $TargetOUMonth = "OU=08. August,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #8'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '9' {#Option 9 is selected
                $TargetOUMonth = "OU=09. September,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #9'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
           '10' {#Option 10 is selected
                $TargetOUMonth = "OU=10. Oktober,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #10'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '11' {#Option 11 is selected
                $TargetOUMonth = "OU=11. November,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #11'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '12' {#Option 12 is selected
                $TargetOUMonth = "OU=12. December,OU=Disabled Users,DC=eetnordic,DC=net"
                'You chose option #12'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter a digit between '1' and '12' " -ForegroundColor Red
          Show-Delete-Menu($Title)
          }
     }
   }#End Function


## Disable ad user, Reset the password, and add OU it comes from to description field
## Disable Logon Hours
## Rest Password
## Add OU path to User Description
## Export Group membership to CSV file
## Strip of all group memberships
function DisableUser
{
if ($DisableUserOnDate -eq (Get-Date).Date)
    {
    
    # Disable the account
        Disable-ADAccount $sam
        Write-Host ($din + "'s Active Directory account is disabled.")
    
    # Reset password
        Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "j4Z5iHeQzw4L593" -Force) $sam
        Write-Host ("* " + $din + "'s Active Directory password has been changed.")
    
    # Add the OU path where the account originally came from to the description of the account's properties
        $date = [datetime]::Today.ToString('dd-MM-yyyy')
        Set-ADUser $dn -Description ("Moved from: " + $cn + " - on $date")
        Write-Host ("* " + $din + "'s Active Directory account path saved.")


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
    
    $arrlist | select groupmembership | convertto-csv -NoTypeInformation | select -Skip 1 |out-file $pathFinal
    Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) exported and saved to " + $pathFinal)
    
    # Strip the permissions from the account
    Get-ADUser $User -Properties MemberOf | Select -Expand MemberOf | %{Remove-ADGroupMember $_ -member $User}
    Write-Host ("* " + $din + "'s Active Directory group memberships (permissions) stripped from account")
    
    Show-Delete-menu("User Deletion Month")
    }

    else{
    #set account expiration
        Set-ADAccountExpiration -Identity "$($DisableUserName)" -DateTime "$($DisableUserOnDate)"
    
}
}#End DisableUser



<# --- Exchange email account section --- #>

function Show-Forward-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================"
    Write-Host "(Default) NO         : Press '1' for this option."
    Write-Host "(YES) Enable Forward : Press '2' for this option."

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                'This is the default, and nothing will be done'
                
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                $ReceiverEmail = Read-Host "Please provide the email address"
                #Check if the disable us
                if(get-localmailbox $DisableUserName){
                Set-Mailbox $DisableUserName -DeliverToMailboxAndForward $ReceiverEmail
                write-host "Email has now been forwarded. It will still be delivered into the mailbox"
                }
                if(get-cloudmailbox $DisableUserName){
                Set-CloudMailbox $DisableUserName -DeliverToMailboxAndForward $ReceiverEmail
                write-host "Email has now been forwarded. It will still be delivered into the mailbox"
                
                }
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter either 1 or 2" -ForegroundColor Red
          Show-Forward-Menu($Title)
          }
     }
}#End Function

#Provide the manager or a custom user with full access to the users mailbox
function Show-Forward-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================"
    Write-Host "Give Manager full access: Press '1' for this option."
    Write-Host "Give a user full access : Press '2' for this option."

    $Selection = Read-Host "Please select an option"
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                if(get-LocalMailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host "$($UManagerSAM) has been granted Full Access to the mailbox"
                }
                
                if(get-cloudmailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host "$($UManagerSAM) has been granted Full Access to the mailbox"
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
	            	Write-Host 'Invalid entry, unable to locate a user with the provided username' -fore red
                   }
                }

                if(get-LocalMailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $GrantFullAccessToUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host "$($GrantFullAccessToUser.Name) has been granted Full Access to the mailbox"
                }
                
                if(get-cloudmailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $GrantFullAccessToUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host "$($GrantFullAccessToUser.Name) has been granted Full Access to the mailbox"
                }

                
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host "Invalid entry. Please enter either 1 or 2" -ForegroundColor Red
          Show-Forward-Menu($Title)
          }
     }
}#End Function



#Set out of office message, to selected value - either default or custom
function SetOutOfOfficeMessage()
{#Start Function
# Sets the out of office message, to either default or custom message
    if(get-LocalMailbox $DisableUserName){
        Set-LocalMailboxAutoReplyConfiguration -Identity $dn -AutoReplyState Enabled -ExternalAudience All -InternalMessage $OoOMessage -ExternalMessage $OoOMessage
        AddFullAccessToMailbox
    }
                
    if(get-cloudmailbox $DisableUserName){
        Set-CloudMailboxAutoReplyConfiguration -Identity $dn -AutoReplyState Enabled -ExternalAudience All -InternalMessage $OoOMessage -ExternalMessage $OoOMessage
        AddFullAccessToMailbox
    }
    


    #Remove the Out of office text file again if it exists
    If(!(test-path $file))
        {
            Remove-Item -Path $file -Recurse
        }
}#End Function

#Show a menu, allowing the script runner to select 
#between the default or a custom OoO Message
function Show-OoOMessage-Menu([string]$Title)
{#Start Function
    Write-Host "================ $Title ================"
    Write-Host "Use Default Out of Office Message : Press '1' for this option."
    Write-Host "Create an Out of Office Message   : Press '2' for this option."

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
                Show-Forward-Menu("Should the email be forwarded?")
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                write-host "Please provide the desired Out of Office message, once done type ""done"" on an empty line"
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





<# --- Skype for Business account section --- #>




<# --- !! --- LOAD MODULES --- !! --- #>
##Connect to and load required modules##
Connect-ExchPowershell
Connect-LyncPowershell
Connect-O365Powershell

<# --- !! --- EXECUTE SCRIPT --- !! --- #>
DisableUser
Show-OoOMessage-Menu("Add Out Of Office Message")

<# --- !! --- REMOVE MODULES --- !! --- #>
##disconnect from and remove required modules##
Disconnect-ExchPowershell
Disconnect-LyncPowershell
Disconnect-O365Powerhell