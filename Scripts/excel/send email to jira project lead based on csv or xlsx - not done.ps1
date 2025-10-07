# Send email to JIRA Project Lead, based on projects with no issues in them

# Import needed modules, and install if needed
If(-not(Get-InstalledModule ImportExcel -ErrorAction silentlycontinue)){
    Install-Module ImportExcel -Confirm:$False -Force
}

# What Excel file should users and project name be drawn from?
$XLSXFileLocation = Read-Host "Enter path to Excel file with project data"
if (-not $XLSXFileLocation) {
    $XLSXFileLocation = "C:\temp\projectTest.xlsx"
    Write-Host "Using default file: $XLSXFileLocation" -ForegroundColor Yellow
}

if (-not (Test-Path $XLSXFileLocation)) {
    Write-Error "Excel file not found: $XLSXFileLocation"
    exit 1
}

# Send email function
function Send-ProjectLeadEmail {
    param(
        [string]$ToAddress,
        [string]$LeadDisplayName,
        [string]$ProjectName,
        [int]$IssueCount
    )

    # Email configuration would go here - implement Send-MailMessage or similar
    Write-Host "Would send email to $LeadDisplayName ($ToAddress) about project $ProjectName with $IssueCount issues" -ForegroundColor Cyan
}

# Import user list and information from Excel file
# Excel File Location is drawn from Read-Host above
# Defining what columns to draw data from
Write-Host "Importing data from: $XLSXFileLocation" -ForegroundColor Cyan
$XLSXFile = Import-Excel -path $XLSXFileLocation
if($XLSXFile){
    Write-Host "Successfully imported $($XLSXFile.Count) records from Excel file" -ForegroundColor Green
} else {
    Write-Error "Failed to import data from Excel file"
    exit 1
}


# Send Email to each Project Lead in the list
foreach ($x in $XLSXFile){#Start foreach

if($x.'issue count' -lt 10){#Start IF

    $ToAddress = $x.'Lead Email'

    $LeadDisplayName = $x.'Lead display name'

    $ProjectName = $x.Name

    $ProjectKey = $x.Key

    $IssueCount = $x.'Issue count'

# Add Email body @@ = End of Body
# There can be no  infront of
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
<table border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td>Med venlig hilsen - Best Regards<br /><br />
<table border= width= cellspacing= cellpadding=>
<tbody>
<tr>
<td width=><strong><span style=>The Miracle&nbsp;Atlassian Team</span></strong><br /><br />E-mail:&nbsp;atlassian_support@miracle.dk<br /><a href= target= rel=><img src= width= height= /></a>&nbsp;<a href= target= rel=><img src= width= height= /></a>&nbsp;<a href= target= rel=><img src= width= height= /></a></td>
</tr>
</tbody>
</table>
</td>
</tr>
<tr>
<td><img src= width= /><br /><a href= target= rel=>info@miracle.dk</a>&nbsp;-&nbsp;<a href= target= rel=>www.miracle.dk</a>&nbsp;&nbsp;</td>
</tr>
</tbody>
</table>
Sending email to ($ProjectName) ($ToAddress)" -ForegroundColor Yellow
SendNotification
    }#End IF
}#End Foreach
