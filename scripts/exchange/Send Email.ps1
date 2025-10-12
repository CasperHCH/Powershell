<#
.SYNOPSIS
    Send notification email about user cleanup task
.DESCRIPTION
    Sends a Danish notification email about inactive user cleanup procedures.
#>

param(
    [string]$SmtpServer = "smtp.gmail.com",
    [Parameter(Mandatory=$true)]
    [string]$FromAddress,
    [Parameter(Mandatory=$true)]
    [string]$Username,
    [Parameter(Mandatory=$true)]
    [SecureString]$Password,
    [Parameter(Mandatory=$true)]
    [string]$ToAddress
)

try {
    # Create credential object
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $Password)

    # Add Email body - Danish user cleanup notification
    $EmailBody = @"
<html><body>
<p>Så er det igen blevet tid til at rydde op i inaktive brugere.</p>
<p>Al dokumenteret info omkring denne opgave findes her:</p>
<p>Se her, for at generer en liste over alle brugere, husk det kun er eksterne vi er interesseret i:</p>
<p><a href="https://confluence.contoso.com/display/ATLASSIAN/Active+Users">https://confluence.contoso.com/display/ATLASSIAN/Active+Users</a></p>
<p>For at se hvordan brugerne disables, så kig her, husk at nogle er service konti, som ikke skal deaktiveres.<strong>NOT</strong> to disable:</p>
<p><a href="https://confluence.contoso.com/display/ATLASSIAN/User+Deactivation">https://confluence.contoso.com/display/ATLASSIAN/User+Deactivation</a></p>
<p>Den første manuelle opgave på denne opgave er denne:</p>
<p><a href="https://jira.contoso.com/browse/PROJ-11">https://jira.contoso.com/browse/PROJ-11</a></p>
<p>Husk at dokumentere hvad der er gjort, hvis ikke dokumentationem stemmer, og opdater så denne</p>
<table style="width: 100%;" border="0" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="padding: 10px;">Med venlig hilsen - Best Regards<br /><br />
<table style="width: 100%;" border="0" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="font-weight: bold;"><strong>Contoso Atlassian Team</strong><br />E-mail: helpdesk@contoso.com</td>
</tr>
</tbody>
</table>cal Exchange server info for message relay.
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = “smtp.gmail.com”
        $FromAddress =
        $Username =
        $Pass =
        $ToAddress

# Add Email body @@ = End of Body
# There can be no  infront of
<p>Så er det igen blevet tid til at rydde op i inaktive brugere.</p>
</td>
</tr>
</tbody>
</table>
</body></html>
"@

    # Send the email
    $mailParams = @{
        To = $ToAddress
        From = $FromAddress
        Subject = "Reminder: Inactive User Cleanup Task"
        Body = $EmailBody
        BodyAsHtml = $true
        SmtpServer = $SmtpServer
        Port = 587
        UseSSL = $true
        Credential = $Credential
    }

    Write-Host "Sending notification email to $ToAddress..." -ForegroundColor Cyan
    Send-MailMessage @mailParams
    Write-Host "✅ Notification email sent successfully" -ForegroundColor Green

} catch {
    Write-Host "❌ Error sending email: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
<p>For at se hvordan brugerne disables, så kig her, husk at nogle er service konti, som ikke skal deaktiveres.<strong>NOT</strong> to disable:&nbsp;</p>
<p><a href="https://confluence.contoso.com/display/ATLASSIAN/User+Deactivation">User Deactivation Guide</a></p>
<p>Den første manuelle opgave på denne opgave er denne:</p>
<p><a href="https://jira.contoso.com/browse/PROJ-11">Manual Task PROJ-11</a></p>
<p>Husk at dokumentere hvad der er gjort, hvis ikke dokumentationem stemmer, og opdater så denne</p>
<table style= border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td style=>Med venlig hilsen - Best Regards<br /><br />
<table style= border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td style=""><span style=""><strong>Contoso Atlassian Team</strong></span><br />E-mail:&nbsp;helpdesk@contoso.com</td>
</tr>
</tbody>
</table>
</td>
</tr>
<tr>
<td style=><img src= width= /><span style=><br /></span></td>
</tr>
</tbody>
</table>
Automated Request: Atlassian User Clean Up"

    # Add Text to the email Body, will be defined later to allow for individual variables
    # E.g. Project Names, Project Lead Name, etc.
       $msg.Body = $EmailBody

    # Send email
       $Smtp.Send($msg)
