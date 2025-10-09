<#
Prerequisites Needed – 
1)	Either run this on an Exchange Server with an Admin account or use New-PSSession to an Exchange Server running with an Admin Account.
2)	You must be able to use - Import-Module ActiveDirectory.

Example Enter the UserID of the Requester & of the person you want the Mobile Report for.

PS C:\> Get-Mobile

cmdlet Get-Mobile at command pipeline position 1
Supply values for the following parameters:
Requester: tbolton
UserID: tbolton

#>

Function Get-Mobile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string]$Requester,
        [Parameter(Mandatory=$True)]
        [string]$UserID
    )

    PROCESS {

# Date
$Date = (get-date).ToString()

# Get Requester Info via their UserID
$RequesterEmail=(Get-ADUser $Requester -Properties mail).Mail
$RequesterFirstName=(Get-ADUser $Requester -Properties GivenName).GivenName

# Get Tech who is running this script information to CC Email to.
#$MyName = $env:username
#$MyEmail = (Get-ADUSer $MyName -Properties mail).mail

# Get DisplayName of User via their UserID
$TheUserName=(Get-ADUser $UserID -Properties DisplayName).DisplayName
$TheUserEmail=(Get-ADUser $UserID -Properties mail).Mail
#$TheUserName=$TheUser.DisplayName

# Email Settings
$SmtpServer = 
$SmtpFrom = 
$SmtpTo = 
#$SmtpBcc = New-Object System.Net.Mail.MailAddress 
$MessageSubject = 

$Message = New-Object System.Net.Mail.MailMessage $Smtpfrom, $Smtpto
# Add BCC
#$Message.Bcc.Add($SmtpBcc)

$Message.Subject = $MessageSubject
$Message.IsBodyHTML = $true

#### HTML Output Formatting #######
 
$a = @@

# This is what will pull the information on the Mobile Devices being used by $UserID and will create the message body.
$Message.Body = Get-MobileDeviceStatistics -Mailbox $TheUserEmail | 
select DeviceType,DeviceModel,DeviceFriendlyName,DeviceOS,DeviceUserAgent,LastSyncAttemptTime,Lastsuccesssync,NumberOfFoldersSynced | ConvertTo-HTML -PreContent , -Head $a

$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)

}
}

###############################################################
