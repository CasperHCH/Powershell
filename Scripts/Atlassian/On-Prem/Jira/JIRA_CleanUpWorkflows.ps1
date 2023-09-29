####Needed global Variables
$creds = ''
$CredPath = "C:\Windows\Credentials\"

####Check to see if Credentials exists to run the script

#Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $CredPath | Measure-Object
if ($TestCredsPath.count -eq '0'){
$creds = Get-Credential -Message "Please provide the domain\username and password of the service account going to run this script"| New-StoredCredential -target $CredPath -Comment "Used for calling PS Scripts towards Atlassian systems"
}else{
$creds = (Get-StoredCredential -Target $CredPath)
}

####Create session to work in
Invoke-RestMethod -Method Post -Uri "https://jira.miracle.dk/rest/auth/1/session" -Credential $creds

####Collect workflows
# https://docs.atlassian.com/software/jira/docs/api/REST/8.7.1/#api/2/workflow-getAllWorkflows

Invoke-RestMethod -Method Get -Uri "https://jira.miracle.dk/rest/api/2/workflow"

####Manipulate workflows


####Delete needed workflows


#Reindex


####Close session
Invoke-RestMethod -Method delete -Uri "https://jira.miracle.dk/rest/auth/1/session"
