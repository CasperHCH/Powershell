####Needed global Variables
param(
    [Parameter(Mandatory=$true)]
    [string]$JiraBaseUrl,
    [string]$CredPath = "JiraAPICleanup"
)

$creds = ''

####Check to see if Credentials exists to run the script

#Test if creds exist, if not create
try {
    $TestCredsPath = Get-StoredCredential -Target $CredPath -ErrorAction Stop
    $creds = $TestCredsPath
} catch {
    Write-Host "Creating new credentials for Jira API access" -ForegroundColor Yellow
    $creds = Get-Credential -Message "Enter Jira Admin Credentials" | New-StoredCredential -target $CredPath -Comment "Jira Administrator for API Cleanup"
}

####Create session to work in
$sessionUri = "$JiraBaseUrl/rest/auth/1/session"
Write-Host "Creating Jira session at: $sessionUri" -ForegroundColor Green
Invoke-RestMethod -Method Post -Uri $sessionUri -Credential $creds

####Collect workflows
# https://docs.atlassian.com/software/jira/docs/api/REST/8.7.1/#api/2/workflow-getAllWorkflows
$workflowUri = "$JiraBaseUrl/rest/api/2/workflow"
Write-Host "Fetching workflows from: $workflowUri" -ForegroundColor Cyan
$workflows = Invoke-RestMethod -Method Get -Uri $workflowUri -Credential $creds

####Manipulate workflows


####Delete needed workflows


#Reindex


####Close session
Invoke-RestMethod -Method delete -Uri
