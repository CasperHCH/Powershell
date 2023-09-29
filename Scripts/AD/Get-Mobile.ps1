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
$Date = (get-date).ToString("MM-dd-yy")

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
$SmtpServer = "smtp.eetnordic.net"
$SmtpFrom = "exch@eetnordic.net"
$SmtpTo = "$RequesterEmail"
#$SmtpBcc = New-Object System.Net.Mail.MailAddress "$MyEmail"
$MessageSubject = "Mobile report for $TheUserName "

$Message = New-Object System.Net.Mail.MailMessage $Smtpfrom, $Smtpto
# Add BCC
#$Message.Bcc.Add($SmtpBcc)

$Message.Subject = $MessageSubject
$Message.IsBodyHTML = $true

#### HTML Output Formatting #######
 
$a = @"
<style>
body {
    color:#333333;
    font-family:Calibri,Tahoma;
    font-size: 10pt;
}
TABLE {
	border-width: 1px;
	text-align: center;
	border-style: solid;
	border-color: black;
	border-collapse: collapse;
}
th {
    font-weight:bold;
	border-width: 1px;
	padding: 10px;
	border-style: solid;
	border-color: black;
    color:#eeeeee;
    background-color:#333333;
}
td {
	font-weight:bold;
	border-width: 1px;
	padding: 10px;
	border-style: solid;
	border-color: black;
}
</style>
"@

# This is what will pull the information on the Mobile Devices being used by $UserID and will create the message body.
$Message.Body = Get-MobileDeviceStatistics -Mailbox $TheUserEmail | 
select DeviceType,DeviceModel,DeviceFriendlyName,DeviceOS,DeviceUserAgent,LastSyncAttemptTime,Lastsuccesssync,NumberOfFoldersSynced | ConvertTo-HTML -PreContent "<h2>Mobile Devices for $TheUserName</h2>","<h2>Date: $Date</h2>" -Head $a

$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)

}
}

###############################################################