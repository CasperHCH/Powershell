<#
.SYNOPSIS
    JIRA Workflow Cleanup Script

.DESCRIPTION
    This script identifies and removes unused workflows from JIRA to improve performance
    and maintain a clean workflow configuration. It includes safety checks and logging.

.PARAMETER JiraBaseUrl
    The base URL of your JIRA instance (e.g., https://jira.company.com)

.PARAMETER Username
    JIRA username for authentication (if not provided, will prompt)

.PARAMETER CredentialFile
    Path to encrypted credential file (optional alternative to interactive login)

.PARAMETER DryRun
    If specified, only shows what would be deleted without actually deleting

.PARAMETER SkipBackup
    If specified, skips workflow backup before deletion

.EXAMPLE
    .\JIRA_CleanUpWorkflows.ps1 -JiraBaseUrl "https://jira.company.com" -DryRun

.EXAMPLE
    .\JIRA_CleanUpWorkflows.ps1 -JiraBaseUrl "https://jira.company.com" -Username "admin@company.com"

.EXAMPLE
    .\JIRA_CleanUpWorkflows.ps1 -JiraBaseUrl "https://jira.company.com" -CredentialFile ".\jira_creds.xml"

.EXAMPLE
    # Create credential file for reuse
    Get-Credential | Export-Clixml -Path "jira_creds.xml"
    .\JIRA_CleanUpWorkflows.ps1 -JiraBaseUrl "https://jira.company.com" -CredentialFile "jira_creds.xml"

.NOTES
    Author: Enhanced Script
    Version: 2.0
    Requires: PowerShell 5.1+, JIRA Admin permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$JiraBaseUrl = "https://your-jira-server.com",

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$CredentialFile,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBackup,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\JiraWorkflowCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Enhanced logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $LogPath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    Add-Content -Path $LogFile -Value $logMessage
}

# Helper function to create credential files
function New-JiraCredentialFile {
    param(
        [string]$FilePath = ".\jira_creds_$(Get-Date -Format 'yyyyMMdd').xml"
    )

    Write-Host "Creating new JIRA credential file..." -ForegroundColor Yellow
    $cred = Get-Credential -Message "Enter JIRA Admin Credentials"
    if ($cred) {
        try {
            $cred | Export-Clixml -Path $FilePath
            Write-Host "Credential file created: $FilePath" -ForegroundColor Green
            Write-Host "Use with: -CredentialFile '$FilePath'" -ForegroundColor Green
            return $FilePath
        } catch {
            Write-Host "Failed to create credential file: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    return $null
}

# Initialize script
Write-Log "=== JIRA Workflow Cleanup Script Started ===" "INFO"
Write-Log "Parameters: JiraBaseUrl=$JiraBaseUrl, Username=$Username, DryRun=$DryRun, SkipBackup=$SkipBackup" "INFO"

# Global variables
$creds = $null
$session = $null
$workflowsToDelete = @()
$backupPath = ".\JiraWorkflowBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

####Handle authentication credentials
Write-Log "Setting up authentication credentials..." "INFO"

try {
    # Method 1: Use credential file if provided
    if ($CredentialFile -and (Test-Path $CredentialFile)) {
        Write-Log "Loading credentials from file: $CredentialFile" "INFO"
        try {
            $creds = Import-Clixml -Path $CredentialFile
            Write-Log "Successfully loaded credentials for user: $($creds.UserName)" "SUCCESS"
        } catch {
            Write-Log "Failed to load credential file: $($_.Exception.Message)" "ERROR"
            throw "Invalid credential file format. Use Export-Clixml to create proper credential files."
        }
    }
    # Method 2: Use provided username and prompt for password
    elseif ($Username) {
        Write-Log "Using provided username: $Username" "INFO"
        $securePassword = Read-Host "Enter password for $Username" -AsSecureString
        $creds = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
        Write-Log "Credentials created for user: $Username" "SUCCESS"

        # Offer to save credentials for future use
        $saveChoice = Read-Host "Save credentials to encrypted file for future use? (y/N)"
        if ($saveChoice -eq 'y' -or $saveChoice -eq 'Y') {
            $saveFile = ".\jira_creds_$(Get-Date -Format 'yyyyMMdd').xml"
            try {
                $creds | Export-Clixml -Path $saveFile
                Write-Log "Credentials saved to: $saveFile" "SUCCESS"
                Write-Log "Use -CredentialFile '$saveFile' parameter for future runs" "INFO"
            } catch {
                Write-Log "Failed to save credentials: $($_.Exception.Message)" "WARNING"
            }
        }
    }
    # Method 3: Interactive credential prompt
    else {
        Write-Log "No credentials provided. Prompting for interactive input..." "INFO"
        $creds = Get-Credential -Message "Enter JIRA Admin Credentials for $JiraBaseUrl"
        if ($null -eq $creds) {
            throw "No credentials provided. Script cannot continue."
        }
        Write-Log "Interactive credentials provided for user: $($creds.UserName)" "SUCCESS"

        # Offer to save credentials for future use
        $saveChoice = Read-Host "Save credentials to encrypted file for future use? (y/N)"
        if ($saveChoice -eq 'y' -or $saveChoice -eq 'Y') {
            $saveFile = ".\jira_creds_$(Get-Date -Format 'yyyyMMdd').xml"
            try {
                $creds | Export-Clixml -Path $saveFile
                Write-Log "Credentials saved to: $saveFile" "SUCCESS"
                Write-Log "Use -CredentialFile '$saveFile' parameter for future runs" "INFO"
            } catch {
                Write-Log "Failed to save credentials: $($_.Exception.Message)" "WARNING"
            }
        }
    }

    # Validate credentials object
    if ($null -eq $creds -or $null -eq $creds.UserName -or $null -eq $creds.Password) {
        throw "Invalid credentials provided."
    }

} catch {
    Write-Log "Failed to handle credentials: $($_.Exception.Message)" "ERROR"
    Write-Log "Credential options:" "INFO"
    Write-Log "  1. Use -Username parameter and enter password interactively" "INFO"
    Write-Log "  2. Use -CredentialFile parameter with encrypted credential file" "INFO"
    Write-Log "  3. Run without parameters for interactive credential prompt" "INFO"
    Write-Log "  Create credential file with: Get-Credential | Export-Clixml -Path 'creds.xml'" "INFO"
    exit 1
}

####Create session to work in
Write-Log "Creating JIRA session..." "INFO"
try {
    $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
    $sessionHeaders = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }

    $sessionBody = @{
        username = $creds.UserName
        password = $creds.GetNetworkCredential().Password
    } | ConvertTo-Json

    $session = Invoke-RestMethod -Method Post -Uri $SessionUri -Body $sessionBody -Headers $sessionHeaders -ErrorAction Stop
    Write-Log "JIRA session created successfully. Session Name: $($session.session.name)" "SUCCESS"

    # Create session headers for subsequent requests
    $apiHeaders = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
        'Cookie' = "$($session.session.name)=$($session.session.value)"
    }
} catch {
    Write-Log "Failed to create JIRA session: $($_.Exception.Message)" "ERROR"
    exit 1
}

####Collect workflows
Write-Log "Collecting workflow information..." "INFO"
try {
    # Get all workflows
    $WorkflowUri = "$JiraBaseUrl/rest/api/2/workflow"
    $workflows = Invoke-RestMethod -Method Get -Uri $WorkflowUri -Headers $apiHeaders -ErrorAction Stop
    Write-Log "Found $($workflows.Count) workflows in JIRA" "INFO"

    # Get workflow schemes to identify which workflows are in use
    $WorkflowSchemeUri = "$JiraBaseUrl/rest/api/2/workflowscheme"
    $workflowSchemes = Invoke-RestMethod -Method Get -Uri $WorkflowSchemeUri -Headers $apiHeaders -ErrorAction Stop
    Write-Log "Found $($workflowSchemes.values.Count) workflow schemes" "INFO"

    # Get projects to see which workflow schemes are assigned
    $ProjectUri = "$JiraBaseUrl/rest/api/2/project"
    $projects = Invoke-RestMethod -Method Get -Uri $ProjectUri -Headers $apiHeaders -ErrorAction Stop
    Write-Log "Found $($projects.Count) projects" "INFO"

} catch {
    Write-Log "Failed to collect workflow information: $($_.Exception.Message)" "ERROR"
    exit 1
}

####Analyze workflows for cleanup
Write-Log "Analyzing workflows for cleanup..." "INFO"

# Create sets of workflows in use
$workflowsInUse = @{}
$systemWorkflows = @("jira", "classic default workflow")

# Check workflow schemes for used workflows
foreach ($scheme in $workflowSchemes.values) {
    try {
        $schemeDetailUri = "$JiraBaseUrl/rest/api/2/workflowscheme/$($scheme.id)/workflow"
        $schemeDetails = Invoke-RestMethod -Method Get -Uri $schemeDetailUri -Headers $apiHeaders -ErrorAction Stop

        if ($schemeDetails.issueTypeMappings) {
            foreach ($mapping in $schemeDetails.issueTypeMappings.PSObject.Properties) {
                $workflowName = $mapping.Value
                $workflowsInUse[$workflowName] = $true
            }
        }
        if ($schemeDetails.defaultWorkflow) {
            $workflowsInUse[$schemeDetails.defaultWorkflow] = $true
        }
    } catch {
        Write-Log "Warning: Could not get details for workflow scheme $($scheme.id): $($_.Exception.Message)" "WARNING"
    }
}

# Identify unused workflows
foreach ($workflow in $workflows) {
    $isSystemWorkflow = $systemWorkflows -contains $workflow.name.ToLower()
    $isInUse = $workflowsInUse.ContainsKey($workflow.name)
    $isDraft = $workflow.name -like "*[Draft]*" -or $workflow.name -like "*draft*"

    if (-not $isSystemWorkflow -and -not $isInUse) {
        $workflowsToDelete += [PSCustomObject]@{
            Name = $workflow.name
            Description = $workflow.description
            IsDraft = $isDraft
            LastModified = $workflow.lastModifiedDate
        }
    }
}

Write-Log "Analysis complete. Found $($workflowsToDelete.Count) workflows that appear to be unused:" "INFO"
foreach ($wf in $workflowsToDelete) {
    Write-Log "  - $($wf.Name) $(if($wf.IsDraft){'(Draft)'})" "INFO"
}

####Backup workflows before deletion
if (-not $SkipBackup -and $workflowsToDelete.Count -gt 0) {
    Write-Log "Creating backup of workflows to be deleted..." "INFO"
    try {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null

        foreach ($workflow in $workflowsToDelete) {
            $workflowDetailUri = "$JiraBaseUrl/rest/api/2/workflow/$($workflow.Name)"
            $workflowDetail = Invoke-RestMethod -Method Get -Uri $workflowDetailUri -Headers $apiHeaders -ErrorAction Stop
            $backupFile = Join-Path $backupPath "$($workflow.Name.Replace(' ', '_')).json"
            $workflowDetail | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
            Write-Log "Backed up workflow: $($workflow.Name)" "INFO"
        }
        Write-Log "Workflow backup completed: $backupPath" "SUCCESS"
    } catch {
        Write-Log "Failed to backup workflows: $($_.Exception.Message)" "ERROR"
        if (-not $DryRun) {
            Write-Log "Aborting deletion due to backup failure. Use -SkipBackup to override." "ERROR"
            exit 1
        }
    }
}

####Delete workflows
if ($workflowsToDelete.Count -eq 0) {
    Write-Log "No workflows found for cleanup." "INFO"
} elseif ($DryRun) {
    Write-Log "DRY RUN: Would delete the following $($workflowsToDelete.Count) workflows:" "WARNING"
    foreach ($workflow in $workflowsToDelete) {
        Write-Log "  - Would delete: $($workflow.Name)" "WARNING"
    }
} else {
    Write-Log "Starting workflow deletion..." "WARNING"
    $deletedCount = 0
    $failedDeletions = @()

    foreach ($workflow in $workflowsToDelete) {
        try {
            $deleteUri = "$JiraBaseUrl/rest/api/2/workflow/$($workflow.Name)"
            Invoke-RestMethod -Method Delete -Uri $deleteUri -Headers $apiHeaders -ErrorAction Stop
            Write-Log "Successfully deleted workflow: $($workflow.Name)" "SUCCESS"
            $deletedCount++
        } catch {
            $errorMsg = "Failed to delete workflow '$($workflow.Name)': $($_.Exception.Message)"
            Write-Log $errorMsg "ERROR"
            $failedDeletions += $workflow.Name
        }
    }

    Write-Log "Workflow deletion completed. Deleted: $deletedCount, Failed: $($failedDeletions.Count)" "INFO"
    if ($failedDeletions.Count -gt 0) {
        Write-Log "Failed deletions: $($failedDeletions -join ', ')" "WARNING"
    }
}

####Reindex JIRA (if workflows were deleted)
if (-not $DryRun -and $deletedCount -gt 0) {
    Write-Log "Starting JIRA reindex to optimize performance..." "INFO"
    try {
        $reindexUri = "$JiraBaseUrl/rest/api/2/reindex"
        $reindexBody = @{
            type = "BACKGROUND"
            indexComments = $false
            indexChangeHistory = $false
            indexWorklogs = $false
        } | ConvertTo-Json

        $reindexResult = Invoke-RestMethod -Method Post -Uri $reindexUri -Headers $apiHeaders -Body $reindexBody -ErrorAction Stop
        Write-Log "Reindex started successfully. Progress ID: $($reindexResult.progressUrl)" "SUCCESS"
        Write-Log "Monitor reindex progress at: $JiraBaseUrl/secure/admin/IndexAdmin.jspa" "INFO"
    } catch {
        Write-Log "Failed to start reindex: $($_.Exception.Message)" "WARNING"
        Write-Log "Please manually reindex JIRA at: $JiraBaseUrl/secure/admin/IndexAdmin.jspa" "INFO"
    }
}

####Close session
if ($session) {
    try {
        $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
        Invoke-RestMethod -Method Delete -Uri $SessionUri -Headers $apiHeaders -ErrorAction SilentlyContinue
        Write-Log "JIRA session closed successfully" "SUCCESS"
    } catch {
        Write-Log "Warning: Failed to properly close JIRA session: $($_.Exception.Message)" "WARNING"
    }
}

# Script completion summary
Write-Log "=== JIRA Workflow Cleanup Script Completed ===" "SUCCESS"
Write-Log "Summary:" "INFO"
Write-Log "  - Workflows analyzed: $($workflows.Count)" "INFO"
Write-Log "  - Workflows identified for cleanup: $($workflowsToDelete.Count)" "INFO"
if (-not $DryRun) {
    Write-Log "  - Workflows deleted: $deletedCount" "INFO"
    Write-Log "  - Failed deletions: $($failedDeletions.Count)" "INFO"
    if (-not $SkipBackup -and $workflowsToDelete.Count -gt 0) {
        Write-Log "  - Backup location: $backupPath" "INFO"
    }
}
Write-Log "  - Log file: $LogPath" "INFO"

if ($DryRun) {
    Write-Log "This was a DRY RUN. No changes were made to JIRA." "WARNING"
    Write-Log "Run without -DryRun parameter to perform actual cleanup." "INFO"
}
