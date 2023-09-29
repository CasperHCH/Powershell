# Send email to JIRA Project Lead, based on projects with # amount of issues in them

# Import needed modules, and install if needed
If(-not(Get-InstalledModule ImportExcel -ErrorAction silentlycontinue)){
    Install-Module ImportExcel -Confirm:$False -Force
}

# What XLSX file should users and project name be drawn from?
# Match proper provided FullName path for XLSX file
Do {$XLSXFileLocation = Read-Host "Please provide the XLSX file location, to draw data from"} 
Until ((Test-Path $XLSXFileLocation) -and $XLSXFileLocation -match '.xlsx')


# Ensure that the user inputs an Integer as the Issue Count
while(1)
    {
    try{
        [uint16]$LessThanIssueCount = Read-Host  -Prompt "Send email to Project Leads, where Issue Count is Less Than"

        write-Host "You are about to send emails to all project leads, where the Project has Less Than "" $LessThanIssueCount "" Issues within it"

        $selection = Read-Host "Contiue? Yes(Default, Enter) / No"
        Switch($selection){
            'Yes'{
                 Write-Host "You have selected YES, the script will continue"
                 break}
            'No'{
            # Set the variable to something not an integer
            $LessThanIssueCount = 'a'
                }
           Default {
                 Write-Host "You have selected YES, the script will continue"
                 break}
            }#End Switch statement

        break

        }# End Try
        catch{
            Write-Host "Please insert a number"
        }
    }# End While

#Read the desired disable date
do
{
    Write-Host "By what date do you want to hear back from the Project Leads?"
    $date= read-host "Use the format (i.e.: '25/12/2012 09:00', '25 oct 2012 9:00'; If only a date is entered, the time will be set to 00:00):"

    $date = $date -as [datetime]

    if (!$date) {
        "Not A valid date and time"
    }
} while ($date -isnot [datetime])



#$XLSXFileLocation = "C:\temp\projectTest.xlsx" # Created for testing purposes


# Send email function
function SendNotification
    {
    
    # Define local Exchange server info for message relay. 
    # Ensure that any servers running this script have permission to relay.
        $smtpserver = “smtp.gmail.com”
        $username = "atlassian_support@miracle.dk"
        $Pass = "w^0!j11xojdrPB%Y"
        $FromAddress = "atlassian_support@miracle.dk"
        $BCCAddress = "atlassian_support@miracle.dk"
        
    
    # CREATE OBJECTS TO BE USED
       $msg = new-object Net.Mail.MailMessage
       $smtp = new-object Net.Mail.SmtpClient($smtpServer, 587)
       
    
    # Enable SSL
       $smtp.EnableSsl = $true 
    
    # Adding Credentials to send email
       $smtp.Credentials = New-Object System.Net.NetworkCredential("$username", $Pass); # Put username without the @GMAIL.com or – @gmail.com - if enterprise with separate domain use full email, e.g. support@mydomain.com

    # Where should the email be sent to
    # Use variable previously HARDCODED
       $msg.From = $FromAddress
    # Send email to, will be defined by CSV file
       $msg.To.Add($ToAddress)
       $msg.Bcc.Add($BCCAddress)
        
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
# XLSX File Location is drawn from Read-Host at top
# Can be modified to include specific columns to draw data from
# 
    $XLSXFile = Import-Excel -path "$XLSXFileLocation"
    if($XLSXFile){write-host "file imported"}
    
  
# Send Email to each Project Lead in the list
foreach ($x in $XLSXFile){#Start foreach

if($x.'issue count' -lt $LessThanIssueCount){#Start IF

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
<p>Dear $LeadDisplayName,<br />The Atlassian team is in the process of cleaning up our JIRA environment.<br />In this process, we have found that the project $ProjectName have less than $LessThanIssueCount issues within it, <br />and therefore doesn't seem to be in use.</p>
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
<p><br />If we haven't heard from you by the $date, we will proceed to delete the project.</p>
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