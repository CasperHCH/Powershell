Get-ChildItem -path "C:\Atlassian\jira-home\plugins\user-management-reports" | rename-item -newname { [io.path]::ChangeExtension($_.name, ".txt") }
$file = gci "C:\Atlassian\jira-home\plugins\user-management-reports" | sort LastWriteTime | select -last 1
$currentDate = get-date
$Summary = "Jira - User Management Report - Deactivate after 180 days of inactivity"
$Description = @"
This message was sent from Jira. \n Attached is a log of all actions taken by User Management as triggered by Scheduled User Actions scheme 'Deactivate after 180 days of inactivity' on $($currentDate.Date). \n Scheme Name: Deactivate after 180 days of inactivity. \n Triggered by: Schedule. \n By time since last login: 180 days without logging in. \n Actions on users: Disable Users. Generate report files in home directory: Enabled \n Path is: <jira-home>\plugins\user-management-reports \n 
"@

acli Miracle_Jira --action run --input "--action createIssue --project "MHD" --type "Task" --summary "$($summary)" --description "$($description)" --input "-a addAttachment --issue @issue@ --file $file"