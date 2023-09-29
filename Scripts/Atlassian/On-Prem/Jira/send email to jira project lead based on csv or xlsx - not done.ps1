# Send email to JIRA Project Lead, based on projects with no issues in them

# Import needed modules, and install if needed
If(-not(Get-InstalledModule ImportExcel -ErrorAction silentlycontinue)){
    Install-Module ImportExcel -Confirm:$False -Force
}

# What CSV file should users and project name be drawn from?
#$XLSXFileLocation = Read-Host "Please provide the XLSX file location, to draw data from"
$XLSXFileLocation = "C:\temp\projectTest.xlsx"


# Send email function
function SendNotification
    {
    
    # Define local Exchange server info for message relay. 
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = “smtp.gmail.com”
        #$FromAddress = "atlassian_support@miracle.dk" 
        $Username = "chjensen91"
        $Pass = "xrnmmwvyxdlxmcpd" 
        
    
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
    # Send email to, will be defined by CSV file
       $msg.To.Add($ToAddress)
       $msg.Bcc.Add("atlassian_support@miracle.dk")
        
    # Allow HTML code within Body 
       $msg.IsBodyHTML = $true
    
    # Set Subject - HARDCODED, could be set to Variable
    # Set Project name from CSV File
       $msg.Subject = "Important: Is this $Project still in use?"
    
    # Add Text to the email Body, will be defined later to allow for individual variables
    # E.g. Project Names, Project Lead Name, etc.
       $msg.Body = $EmailBody
    
    # Send email
       $Smtp.Send($msg)
    }

# Import user list and information from .CSV file
# CSV File Location is drawn from Read-Host at top
# Defining what collums to draw data from
    $XLSXFile = Import-Excel -path C:\temp\projectTest.xlsx #"$XLSXFileLocation"
    if($XLSXFile){write-host "file imported"}
    
  
# Send Email to each Project Lead in the list
foreach ($x in $XLSXFile){#Start foreach

if($x.'issue count' -lt 10){#Start IF

    $ToAddress = $x.'Lead Email'

    $LeadDisplayName = $x.'Lead display name'

    $ProjectName = $x.Name

    $ProjectKey = $x.Key

    $IssueCount = $x.'Issue count'
                    
# Add Email body @" = Start of Body
# "@ = End of Body
# There can be no "String" infront of "@
# HTML Body can be generated here: https://html-online.com/editor/
$EmailBody = @"
<p>Dear $LeadDisplayName,<br />The Atlassian team is in the process of cleaning up our JIRA environment.<br />In this process, we have found that the project $ProjectName have less than 10 issues within it, <br />and therefore doesn't seem to be in use.</p>
<p>May we delete this project:</p>
<table>
<tbody>
<tr>
<td>Project Lead:</td>
<td>$LeadDisplayName</td>
</tr>
<tr>
<td>Project Name:</td>
<td>$ProjectName</td>
</tr>
<tr>
<td>Project Key:</td>
<td>$ProjectKey</td>
</tr>
<tr>
<td>Issue Count:</td>
<td>$IssueCount</td>
</tr>
</tbody>
</table>
<p><br />If we haven't heard from you by the 15th of November, we will proceed to delete the project.</p>
<p>Please advise us on email by replying to this email.</p>
<table border="0" width="350px" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td>Med venlig hilsen - Best Regards<br /><br />
<table border="0" width="200" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td width=""><strong><span style="font-family: Arial, sans-serif;">The Miracle&nbsp;Atlassian Team</span></strong><br /><br />E-mail:&nbsp;atlassian_support@miracle.dk<br /><a href="https://twitter.com/miracledenmark" target="_blank" rel="noopener"><img src="https://ci6.googleusercontent.com/proxy/veEaV6J7isdVw-GvsPj_FyTVRelkP4PgfXdD-bK13rCJynwxCQfQl4NMHaLt57rOK6JGHQYY9Ol5WQYn_WxOFq4-Hnq69Q=s0-d-e1-ft#http://miracle.dk/images/miracleas/twitter-icon.png" width="25" height="25" /></a>&nbsp;<a href="https://www.facebook.com/miracledenmark" target="_blank" rel="noopener"><img src="https://ci5.googleusercontent.com/proxy/yW0Zqmw8KvnnFd9lYAFPQLnhVRDm0muqgbS7tEo4JdeFiYpo6y5DdZRmlgMgavEV6ZK5UKhkv-jzR29wJ4A3NDWbzuID0gk=s0-d-e1-ft#http://miracle.dk/images/miracleas/facebook-icon.png" width="25" height="25" /></a>&nbsp;<a href="https://www.linkedin.com/company/27534?trk=tyah&amp;trkInfo=tas%3Amiracle%20A%2FS%2Cidx%3A2-1-3" target="_blank" rel="noopener"><img src="https://ci5.googleusercontent.com/proxy/DC0NkTBngqrYOOeKOQeeWW0aYKQu7uKqQHQZk4IR3s99FA-Nj6e_gKEgqJgvYE1TjvKsh1ybLPPe0wby6xKLlFDxGiCszlA=s0-d-e1-ft#http://miracle.dk/images/miracleas/linkedin-icon.png" width="25" height="25" /></a></td>
</tr>
</tbody>
</table>
</td>
</tr>
<tr>
<td><img src="https://ci6.googleusercontent.com/proxy/LdIHTasQydobUBPoG4d0FMcV2ajx5THSbWOlcwqUUmIC120DJTlfARvLEV4Xdx8eKdMPiIv2fRDkZDfjIYaZEXxqmjkUJKVMukE=s0-d-e1-ft#http://miracle.dk/images/miracleas/logos/miracle400.png" width="100" /><br /><a href="mailto:info@miracle.dk" target="_blank" rel="noopener">info@miracle.dk</a>&nbsp;-&nbsp;<a href="http://miracle.dk/" target="_blank" rel="noopener">www.miracle.dk</a>&nbsp;&nbsp;</td>
</tr>
</tbody>
</table>
"@
# Write to Console, where the email is headed
Write-Host "Sending email to ($ProjectName) ($ToAddress)" -ForegroundColor Yellow
SendNotification
    }#End IF
}#End Foreach