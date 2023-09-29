    # Define local Exchange server info for message relay. 
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = “smtp.gmail.com”
        $FromAddress = "atlassian_support@miracle.dk" 
        $Username = "atlassian_support@miracle.dk"
        $Pass = "xrnmmwvyxdlxmcpd" 
        $ToAddress
		
# Add Email body @" = Start of Body
# "@ = End of Body
# There can be no "String" infront of "@
# HTML Body can be generated here: https://html-online.com/editor/
		$EmailBody = @"
<p>Så er det igen blevet tid til at rydde op i inaktive brugere.</p>
<p>Al dokumenteret info omkring denne opgave findes her:</p>
<p>Se her, for at generer en liste over alle brugere, husk det kun er eksterne vi er interesseret i:</p>
<p><a href="https://confluence.miracle.dk/display/ATLASSIAN/Aktive+Users">https://confluence.miracle.dk/display/ATLASSIAN/Aktive+Users</a></p>
<p>For at se hvordan brugerne disables, så kig her, husk at nogle er service konti, som ikke skal deaktiveres.<strong>NOT</strong> to disable:&nbsp;</p>
<p><a href="https://confluence.miracle.dk/display/ATLASSIAN/Deaktivering+af+brugere">https://confluence.miracle.dk/display/ATLASSIAN/Deaktivering+af+brugere</a></p>
<p>Den første manuelle opgave på denne opgave er denne:</p>
<p><a href="https://jira.miracle.dk/browse/MIRATL-11">https://jira.miracle.dk/browse/MIRATL-11</a></p>
<p>Husk at dokumentere hvad der er gjort, hvis ikke dokumentationem stemmer, og opdater så denne</p>
<table style="height: 106px;" border="0" width="248" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="width: 244px;">Med venlig hilsen - Best Regards<br /><br />
<table style="height: 43px;" border="0" width="227" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="width: 223px;"><span style="font-family: Arial, sans-serif;"><strong>Miracle's PO Atlassian Team</strong></span><br />E-mail:&nbsp;helpdesk@miracle.dk</td>
</tr>
</tbody>
</table>
</td>
</tr>
<tr>
<td style="width: 244px;"><img src="https://ci6.googleusercontent.com/proxy/LdIHTasQydobUBPoG4d0FMcV2ajx5THSbWOlcwqUUmIC120DJTlfARvLEV4Xdx8eKdMPiIv2fRDkZDfjIYaZEXxqmjkUJKVMukE=s0-d-e1-ft#http://miracle.dk/images/miracleas/logos/miracle400.png" width="100" /><span style="color: #38761d;"><br /></span></td>
</tr>
</tbody>
</table>
"@
    
    # CREATE OBJECTS TO BE USED
       $msg = new-object Net.Mail.MailMessage
       $smtp = new-object Net.Mail.SmtpClient($smtpServer, 587)
       
    
    # Enable SSL
       $smtp.EnableSsl = $true 
    
    # Adding Credentials to send email
       $smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Pass); # Put username without the @GMAIL.com or – @gmail.com

    # Where should the email be sent to
    # Use variable previously HARDCODED
       $msg.From = $FromAddress
    # Send email to previously hardcoded
       $msg.To.Add($ToAddress)
       
    # Allow HTML code within Body 
       $msg.IsBodyHTML = $true
    
    # Set Subject - HARDCODED, could be set to Variable
    # Set Project name from CSV File
       $msg.Subject = "Automated Request: Atlassian User Clean Up"
    
    # Add Text to the email Body, will be defined later to allow for individual variables
    # E.g. Project Names, Project Lead Name, etc.
       $msg.Body = $EmailBody
    
    # Send email
       $Smtp.Send($msg)