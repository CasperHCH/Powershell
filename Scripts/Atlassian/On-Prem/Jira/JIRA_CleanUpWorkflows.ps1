####Needed global Variables
$creds = ''
$CredPath = 

####Check to see if Credentials exists to run the script

#Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $CredPath | Measure-Object
if ($TestCredsPath.count -eq '0'){
$creds = Get-Credential -Message | New-StoredCredential -target $CredPath -Comment 
}else{
$creds = (Get-StoredCredential -Target $CredPath)
}

####Create session to work in
Invoke-RestMethod -Method Post -Uri  -Credential $creds

####Collect workflows
# https://docs.atlassian.com/software/jira/docs/api/REST/8.7.1/#api/2/workflow-getAllWorkflows

Invoke-RestMethod -Method Get -Uri 

####Manipulate workflows


####Delete needed workflows


#Reindex


####Close session
Invoke-RestMethod -Method delete -Uri
