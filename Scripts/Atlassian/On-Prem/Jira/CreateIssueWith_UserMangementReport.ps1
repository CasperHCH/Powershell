#Import Modules & Snap-ins
function Load-Module ($m) {
Write-LogInfo -LogPath $sLogFile -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -Message ' '
  # If module is imported say that and do nothing
  if (Get-Module | Where-Object {$_.Name -eq $m}) {
    write-host "Module $m is already imported."
  }
  else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
      Import-Module $m
    }
    else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
        Install-Module -Name $m -Force -Scope CurrentUser
        Import-Module $m
      }
      else {

        # If the module is not imported, not available and not in the online gallery then abort
        write-host "Module $m not imported, not available and not in an online gallery, exiting."
        EXIT 1
      }
    }
  }
}

Load-Module JiraPS

# CREATE CREDS!
# Define Credentials
[string]$userName = 'Atlassian-Service-Account'
[string]$userPassword = 'Z*r0GAV6@V2pI3ckS'

# Create credential Object
[SecureString]$secureString = $userPassword | ConvertTo-SecureString -AsPlainText -Force 
[PSCredential]$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $userName, $secureString

Set-JiraConfigServer 'https://jira.miracle.dk'
New-JiraSession -Credential $creds
#Use JiraPS to create ticket manually
Get-ChildItem -path "C:\Atlassian\jira-home\plugins\user-management-reports" | rename-item -newname { [io.path]::ChangeExtension($_.name, ".txt") }
$filePath = Get-ChildItem "C:\Atlassian\jira-home\plugins\user-management-reports" | sort LastWriteTime | select -last 1
#$filePath = "C:\temp\demo.pdf"
$issueSummary = "Jira - User Management Report Deactivate after 180 days of inactivity"
$issueDescription = @"
This message was sent from Jira.
Attached is a log of all actions taken by User Management as triggered by Scheduled User Actions scheme "Deactivate after 180 days of inactivity" on $($currentDate.Date).
Scheme Name: Deactivate after 180 days of inactivity.
Triggered by: Schedule.
By time since last login: 180 days without logging in.
Actions on users: Disable Users.
Generate report files in home directory: Enabled
Path is: <jira-home>\plugins\user-management-reports
"@
#collect all parameters
$parameters = @{
	Project = 'MHD'
	IssueType = 'Task'
	Reporter = 'Miracle_Support'
	Summary = $issueSummary
	Description = $issueDescription
}
#execution, ticket creation and issue attachment
try{
	$issue = New-JiraIssue @parameters -ErrorAction Stop -ErrorVariable JiraIssueCreate
	try{
		Add-JiraIssueAttachment -FilePath $filePath.FullName -Issue $issue.Key -ErrorAction Stop -ErrorVariable JiraAttachFile
	}
	catch{
		Write-Host "Error attaching file ($filePath)`n $JiraAttachFile"
	}
}
catch{
	Write-Host "Error creating JIRA issue`n $JiraIssueCreate"
}