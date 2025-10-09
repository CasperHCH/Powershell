Get-ChildItem -path  | rename-item -newname { [io.path]::ChangeExtension($_.name, ) }
$file = Get-ChildItem "C:\Reports" | Sort-Object LastWriteTime | Select-Object -Last 1
$currentDate = get-date
$Description = @Deactivate after 180 days of inactivity@

acli Miracle_Jira --action createIssue --project  --file  --type  --summary  --description
