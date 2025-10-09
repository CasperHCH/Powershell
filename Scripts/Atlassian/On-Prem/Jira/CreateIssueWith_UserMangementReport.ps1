#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
Write-LogInfo -LogPath $sLogFile -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -Message ' '
  # If module is imported say that and do nothing
  if (Get-Module | Where-Object {$_.Name -eq $m}) {
    write-host "Module $m is already imported" -ForegroundColor Green
  }
  else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
      Import-Module $m
      Write-Host "Module $m imported from local system" -ForegroundColor Yellow
    }
    else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
        Install-Module -Name $m -Force -Scope CurrentUser
        Import-Module $m
        Write-Host "Module $m installed and imported from PowerShell Gallery" -ForegroundColor Cyan
      }
      else {

        # If the module is not imported, not available and not in the online gallery then abort
        write-host "Module $m is not available. Please install manually." -ForegroundColor Red
        EXIT 1
      }
    }
  }
}

Import-ModuleIfAvailable JiraPS

# SECURE CREDENTIAL HANDLING
# Get credentials securely - never hardcode passwords!
Write-Host "Jira Authentication Required" -ForegroundColor Cyan

# Try to get stored credentials first
$credentialPath = "$env:USERPROFILE\.jira_credentials.xml"
if (Test-Path $credentialPath) {
    try {
        Write-Host "Loading stored credentials..." -ForegroundColor Green
        $creds = Import-Clixml -Path $credentialPath
    } catch {
        Write-Warning "Failed to load stored credentials: $($_.Exception.Message)"
        $creds = $null
    }
}

# If no stored credentials, prompt for new ones
if (-not $creds) {
    Write-Host "Please enter your Jira credentials:" -ForegroundColor Yellow
    $creds = Get-Credential -Message "Enter Jira Service Account credentials" -UserName "service-account@domain.com"
    
    if ($creds) {
        # Offer to save credentials securely
        $save = Read-Host "Save credentials for future use? (y/N)"
        if ($save -match '^[yY]') {
            try {
                $creds | Export-Clixml -Path $credentialPath -Force
                Write-Host "Credentials saved securely to: $credentialPath" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to save credentials: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Error "Credentials are required to continue"
        exit 1
    }
}

Set-JiraConfigServer 'https://jira.miracle.dk'
New-JiraSession -Credential $creds
#Use JiraPS to create ticket manually
# Get-ChildItem -path "C:\Reports" | Rename-Item -NewName { [io.path]::ChangeExtension($_.name, ".txt") }
# Get the latest report file from the Reports directory
$filePath = Get-ChildItem "C:\Reports" | Sort-Object LastWriteTime | Select-Object -Last 1
$issueSummary = "User Management Report"
$issueDescription = "Deactivate after 180 days of inactivity"
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
		Write-Host "Failed to attach file to Jira issue: $($_.Exception.Message)" -ForegroundColor Red
	}
}
catch{
	Write-Host "Error in Jira issue creation process: $($_.Exception.Message)" -ForegroundColor Red
}
