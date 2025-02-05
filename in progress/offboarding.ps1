<# --- Import modules --- #>

Import-Module ActiveDirectory


### EXCHANGE ###

# Functions to connect / disconnect Remote Exchange Management Shell
Function Connect-ExchPowershell {
    $RPSession = New-PSSession -Name  -ConfigurationName Microsoft.Exchange -ConnectionURI http://BQ-MBX-02/Powershell
    Import-PSSession $RPSession -Prefix local
} #end function

Function Disconnect-ExchPowershell {
    Get-PSSession -Name  | Remove-PSSession
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
Function Connect-O365Powershell {
    $O365Session = New-PSSession -Name  -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
}

Function Disconnect-O365Powerhell {
    Get-PSSession -Name  | Remove-PSSession
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
Function Connect-LyncPowershell {
    $CSSession = New-PSSession -Name  -ConnectionUri  -Credential (Get-Credential)
    Import-PSSession $CSSession
} #end function

Function Disconnect-LyncPowershell {
    Get-PSSession -Name  | Remove-PSSession
} #end function

## END LYNC ##

# Path for safekeeping User AD Groups
$path1 = 
$path2 = 
$pathFinal = $path1 + $din + $path2

# Check if folder exist, if not, create it
$path1 = 
If(!(test-path $path1))
{
      New-Item -ItemType Directory -Force -Path $path1
}

# Check if file exist, if it does, delete it
$file = 
If(!(test-path $file))
{
     Remove-Item -Path $file -Recurse
}


# read username
$DisableUserName = read-host 

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
	$d = read-host 
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
    Move-ADObject -Identity $dn -TargetPath 
    Write-Host ( + $din + )

}

#Show a menu, allowing the user to select a month the user should be deleted etc.
function Show-Delete-Menu([string]$Title)
{#Start Function
    Write-Host 
    Write-Host 
    Write-Host 
    Write-Host 
    Write-Host 
    Write-Host 
    Write-Host 
    $TargetOUMonth = Read-Host 
    switch ($TargetOUMonth)
        {
            '1' {#Option 1 is selected
                $TargetOUMonth = 
                'You chose option #1'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '2' {#Option 2 is selected
                $TargetOUMonth = 
                'You chose option #2'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
            '3' {#Option 3 is selected
                $TargetOUMonth = 
                'You chose option #3'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '4' {#Option 4 is selected
                $TargetOUMonth = 
                'You chose option #4'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '5' {#Option 5 is selected
                $TargetOUMonth = 
                'You chose option #5'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '6' {#Option 6 is selected
                $TargetOUMonth = 
                'You chose option #6'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '7' {#Option 7 is selected
                $TargetOUMonth = 
                'You chose option #7'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '8' {#Option 8 is selected
                $TargetOUMonth = 
                'You chose option #8'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

            '9' {#Option 9 is selected
                $TargetOUMonth = 
                'You chose option #9'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                 
           '10' {#Option 10 is selected
                $TargetOUMonth = 
                'You chose option #10'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '11' {#Option 11 is selected
                $TargetOUMonth = 
                'You chose option #11'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                } 

           '12' {#Option 12 is selected
                $TargetOUMonth = 
                'You chose option #12'
                MoveUserToWantedDeletionOU($TargetOUMonth)
                }
                #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host  -ForegroundColor Red
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
 
    # Assign 21 byte array of all zeros to the logonHours attribute of the user
    set-aduser -identity  -Replace @{logonHours=$LH}
    

    # Get the list of permissions (group names) and export them to a CSV file for safekeeping
    $groupinfo = get-aduser $sam -Properties memberof | select name, 
    @{ n=; e={($_.memberof | foreach{get-adgroup $_}).name}}
    
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
    Write-Host ( + $din +  + $pathFinal)
    
    # Strip the permissions from the account
    Get-ADUser $User -Properties MemberOf | Select -Expand MemberOf | %{Remove-ADGroupMember $_ -member $User}
    Write-Host ( + $din + )
    
    Show-Delete-menu()
    }

    else{
    #set account expiration
        Set-ADAccountExpiration -Identity  -DateTime 
    
}
}#End DisableUser



<# --- Exchange email account section --- #>

function Show-Forward-Menu([string]$Title)
{#Start Function
    Write-Host 
    Write-Host 

    $Selection = Read-Host 
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                'This is the default, and nothing will be done'
                
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                $ReceiverEmail = Read-Host 
                #Check if the disable us
                if(get-localmailbox $DisableUserName){
                Set-Mailbox $DisableUserName -DeliverToMailboxAndForward $ReceiverEmail
                write-host 
                }
                if(get-cloudmailbox $DisableUserName){
                Set-CloudMailbox $DisableUserName -DeliverToMailboxAndForward $ReceiverEmail
                write-host 
                
                }
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host  -ForegroundColor Red
          Show-Forward-Menu($Title)
          }
     }
}#End Function

#Provide the manager or a custom user with full access to the users mailbox
function Show-Forward-Menu([string]$Title)
{#Start Function
    Write-Host 
    Write-Host 

    $Selection = Read-Host 
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                'You chose option #1'
                if(get-LocalMailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host 
                }
                
                if(get-cloudmailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $UManagerSAM -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host 
                }

                
                
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                while(1){
                $GrantFullAccessTo = Read-Host            
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
                write-host 
                }
                
                if(get-cloudmailbox $DisableUserName){
                Add-MailboxPermission -Identity $DisableUserName -User $GrantFullAccessToUser.SamAccountName -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                write-host 
                }

                
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host  -ForegroundColor Red
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
    Write-Host 
    Write-Host 

    $Selection = Read-Host 
    switch ($Selection)
        {
            '1' {#Option 1 is selected
            'You chose option #1'
            $OoOMessage =    

                
                SetOutOfOfficeMessage($OoOMessage)
                Show-Forward-Menu()
                }
                 
            '2' {#Option 2 is selected
                'You chose option #2'
                write-host 
                    #Create a file to contain the custom OoO message
                    $file = 
                    
                    #Read the host to a new line in the file, for each line break
                    #Exit the while loop when the script runner types done on an empty line
                    While($i -ne )
                    {
	                    If ($i -ne $NULL) 
                            {
		                        $i | Out-File $file -append
                            }
	                    $i = Read-Host 
                    }
                
                # Replace line breaks from `n (Normal txt breaks) to <br> html breaks
                $file2 = Get-Content -Path C:\temp\tomail.txt -Raw
                $file3 = $file2.Replace(,) | out-file -FilePath C:\temp\tomail.txt
                
                #Read the custom OoO message into a variable
                $OoOMessage = Get-Content -Path $file
                
                #Call function to set the OoO Message with variable
                SetOutOfOfficeMessage($OoOMessage)
                }
          #a none valid option was chosen, thus reverting to Default, and rerunning the menu
          Default {Write-Host  -ForegroundColor Red
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
Show-OoOMessage-Menu()

<# --- !! --- REMOVE MODULES --- !! --- #>
##disconnect from and remove required modules##
Disconnect-ExchPowershell
Disconnect-LyncPowershell
Disconnect-O365Powerhell
