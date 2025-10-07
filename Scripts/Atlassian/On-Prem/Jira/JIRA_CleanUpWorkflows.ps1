####Needed global Variables
$creds = ''
$CredPath = "JiraAdminCreds"
$JiraBaseUrl = "https://your-jira-server.com"

####Check to see if Credentials exists to run the script

#Test if creds exist, if not create
try {
    $TestCredsPath = Get-ChildItem $CredPath -ErrorAction Stop | Measure-Object
} catch {
    $TestCredsPath = @{count = 0}
}

if ($TestCredsPath.count -eq '0'){
    $creds = Get-Credential -Message "Enter Jira Admin Credentials" | New-StoredCredential -target $CredPath -Comment "Jira Administrator Credentials"
}else{
    $creds = (Get-StoredCredential -Target $CredPath)
}

####Create session to work in
$SessionUri = "$JiraBaseUrl/rest/auth/1/session"
Invoke-RestMethod -Method Post -Uri $SessionUri -Credential $creds

####Collect workflows
# https://docs.atlassian.com/software/jira/docs/api/REST/8.7.1/#api/2/workflow-getAllWorkflows
$WorkflowUri = "$JiraBaseUrl/rest/api/2/workflow"
Invoke-RestMethod -Method Get -Uri $WorkflowUri -Credential $creds

####Manipulate workflows


####Delete needed workflows


#Reindex


####Close session
Invoke-RestMethod -Method delete -Uri
