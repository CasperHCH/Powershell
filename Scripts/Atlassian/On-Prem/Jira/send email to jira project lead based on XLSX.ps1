# Send email to JIRA Project Lead, based on projects with # amount of issues in them

# Import needed modules, and install if needed
If(-not(Get-InstalledModule ImportExcel -ErrorAction silentlycontinue)){
    Install-Module ImportExcel -Confirm:$False -Force
}

# What XLSX file should users and project name be drawn from?
# Match proper provided FullName path for XLSX file
Do {$XLSXFileLocation = Read-Host } 
Until ((Test-Path $XLSXFileLocation) -and $XLSXFileLocation -match '.xlsx')


# Ensure that the user inputs an Integer as the Issue Count
while(1)
    {
    try{
        [uint16]$LessThanIssueCount = Read-Host  -Prompt 

        write-Host 

        $selection = Read-Host 
        Switch($selection){
            'Yes'{
                 Write-Host 
                 break}
            'No'{
            # Set the variable to something not an integer
            $LessThanIssueCount = 'a'
                }
           Default {
                 Write-Host 
                 break}
            }#End Switch statement

        break

        }# End Try
        catch{
            Write-Host 
        }
    }# End While

#Read the desired disable date
do
{
    Write-Host 
    $date= read-host 

    $date = $date -as [datetime]

    if (!$date) {
        
    }
} while ($date -isnot [datetime])



#$XLSXFileLocation =  # Created for testing purposes


# Send email function


# Import user list and information from .CSV file
# XLSX File Location is drawn from Read-Host at top
# Can be modified to include specific columns to draw data from
# 
    $XLSXFile = Import-Excel -path 
    if($XLSXFile){write-host }
    
  
# Send Email to each Project Lead in the list
foreach ($x in $XLSXFile){#Start foreach

if($x.'issue count' -lt $LessThanIssueCount){#Start IF

    $ToAddress = $x.'Lead Email'

    $LeadDisplayName = $x.'Lead display name'

    $ProjectName = $x.Name

    $ProjectKey = $x.Key

    $IssueCount = $x.'Issue count'
                    
# Add Email body @@ = End of Body
# There can be no  infront of 
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
