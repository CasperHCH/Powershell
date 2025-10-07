# Define        $smtpserver = "smtp.gmail.com"
        $FromAddress = "your-username@your-domain.com"
        $Username = "your-username@your-domain.com"
        $Pass = "your-app-password"
        $ToAddress = "team-leads@your-domain.com"l Exchange server info for message relay.
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = "smtp.gmail.com"
        $FromAddress = "atlassian-admin@your-domain.com"
        $Username = "your-username@your-domain.com"
        $Pass = "your-app-password"  # Use App Password for Gmail
        $ToAddress = "team-leads@your-domain.com"e local Exchange server info for message relay.
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = “smtp.gmail.com”
        $FromAddress =
        $Username =
        $Pass =
        $ToAddress

# Add Email body @@ = End of Body
# There can be no  infront of
<p>Så er det igen blevet tid til at rydde op i inaktive brugere.</p>
<p>Al dokumenteret info omkring denne opgave findes her:</p>
<p>Se her, for at generer en liste over alle brugere, husk det kun er eksterne vi er interesseret i:</p>
<p><a href=>https://confluence.miracle.dk/display/ATLASSIAN/Aktive+Users</a></p>
<p>For at se hvordan brugerne disables, så kig her, husk at nogle er service konti, som ikke skal deaktiveres.<strong>NOT</strong> to disable:&nbsp;</p>
<p><a href=>https://confluence.miracle.dk/display/ATLASSIAN/Deaktivering+af+brugere</a></p>
<p>Den første manuelle opgave på denne opgave er denne:</p>
<p><a href=>https://jira.miracle.dk/browse/MIRATL-11</a></p>
<p>Husk at dokumentere hvad der er gjort, hvis ikke dokumentationem stemmer, og opdater så denne</p>
<table style= border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td style=>Med venlig hilsen - Best Regards<br /><br />
<table style= border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td style=><span style=><strong>Miracle's PO Atlassian Team</strong></span><br />E-mail:&nbsp;helpdesk@miracle.dk</td>
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
