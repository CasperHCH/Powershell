Get-ChildItem -path "C:\Atlassian\jira-home\plugins\user-management-reports" | rename-item -newname { [io.path]::ChangeExtension($_.name, ".txt") }
$file = gci "C:\Atlassian\jira-home\plugins\user-management-reports" | sort LastWriteTime | select -last 1
$currentDate = get-date
$Description = @"
<p>This message was sent from Jira.
Attached is a log of all actions taken by User Management as triggered by Scheduled User Actions scheme "Deactivate after 180 days of inactivity" on $($currentDate.Date).
Scheme Name: Deactivate after 180 days of inactivity.
Triggered by: Schedule.
By time since last login: 180 days without logging in.
Actions on users: Disable Users.
Generate report files in home directory: Enabled
Path is: <jira-home>\plugins\user-management-reports</p>
"@

acli Miracle_Jira --action createIssue --project "MHD" --file "$($file.FullName)" --type "Task" --summary "Jira - User Management Report - Deactivate after 180 days of inactivity" --description "$($description)"