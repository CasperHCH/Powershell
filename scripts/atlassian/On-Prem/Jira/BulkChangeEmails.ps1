<#
.SYNOPSIS
    Bulk update JIRA user email addresses from CSV file

.DESCRIPTION
    This script updates JIRA user email addresses in bulk by reading from a CSV file
    and using the JIRA REST API. It includes comprehensive logging, error handling,
    and validation to ensure safe and reliable email updates.

.PARAMETER CsvPath
    Path to the CSV file containing OldEmail and NewEmail columns

.PARAMETER JiraBaseUrl
    The base URL of your JIRA instance (e.g., https://jira.company.com)

.PARAMETER Username
    JIRA username for authentication (if not provided, will prompt)

.PARAMETER CredentialFile
    Path to encrypted credential file (alternative to interactive login)

.PARAMETER DryRun
    If specified, shows what would be changed without actually making changes

.PARAMETER BackupUsers
    If specified, creates a backup of current user data before changes

.PARAMETER LogPath
    Path for the log file (defaults to timestamped file in current directory)

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -DryRun

.EXAMPLE
    # .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -Username "admin@company.com"

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -CredentialFile "creds.xml" -BackupUsers

.NOTES
    Author: Enhanced Script
    Version: 2.0
    Requires: PowerShell 5.1+, JIRA Admin permissions

    CSV Format Supported:
    Comma-separated (CSV): OldEmail,NewEmail
    Semicolon-separated: OldEmail;NewEmail

    Example formats:
    old1@company.com,new1@company.com
    old2@company.com;new2@company.com

    The script automatically detects the delimiter used.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to CSV file with OldEmail,NewEmail columns")]
    [ValidateScript({
        if (Test-Path $_) { $true }
        else { throw "CSV file not found: $_" }
    })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, HelpMessage = "JIRA base URL (e.g., https://jira.company.com)")]
    [ValidateScript({
        if ($_ -match '^https?://') { $true }
        else { throw "JiraBaseUrl must start with http:// or https://" }
    })]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        if ([string]::IsNullOrEmpty($_) -or (Test-Path $_)) { $true }
        else { throw "Credential file not found: $_" }
    })]
    [string]$CredentialFile,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$BackupUsers,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\JiraBulkEmailUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

# Initialize script
Write-Log "=== JIRA Bulk Email Update Script Started ===" "INFO"
Write-Log "Parameters: CsvPath=$CsvPath, JiraBaseUrl=$JiraBaseUrl, DryRun=$DryRun, BackupUsers=$BackupUsers" "INFO"

# Global variables
$creds = $null
$session = $null
$updateCount = 0
$errorCount = 0
$skippedCount = 0
$backupPath = ".\JiraUserBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

####Handle authentication credentials
Write-Log "Setting up authentication credentials..." "INFO"

try {
    # Use credential file if provided
    if ($CredentialFile -and (Test-Path $CredentialFile)) {
        Write-Log "Loading credentials from file: $CredentialFile" "INFO"
        $creds = Import-Clixml -Path $CredentialFile
        Write-Log "Successfully loaded credentials for user: $($creds.UserName)" "SUCCESS"
    }
    # Use provided username and prompt for password
    elseif ($Username) {
        Write-Log "Using provided username: $Username" "INFO"
        $securePassword = Read-Host "Enter password for $Username" -AsSecureString
        $creds = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
        Write-Log "Credentials created for user: $Username" "SUCCESS"
    }
    # Interactive credential prompt
    else {
        Write-Log "No credentials provided. Prompting for interactive input..." "INFO"
        $creds = Get-Credential -Message "Enter JIRA Admin Credentials for $JiraBaseUrl"
        if ($null -eq $creds) {
            throw "No credentials provided. Script cannot continue."
        }
        Write-Log "Interactive credentials provided for user: $($creds.UserName)" "SUCCESS"
    }

    # Validate credentials
    if ($null -eq $creds -or $null -eq $creds.UserName) {
        throw "Invalid credentials provided."
    }
} catch {
    Write-Log "Failed to handle credentials: $($_.Exception.Message)" "ERROR"
    exit 1
}

####Validate and process CSV file
Write-Log "Processing CSV file: $CsvPath" "INFO"

try {
    # Auto-detect CSV delimiter (comma or semicolon)
    Write-Log "Detecting CSV delimiter format..." "INFO"
    $csvContent = Get-Content $CsvPath -TotalCount 5
    $headerLine = $csvContent[0]

    $delimiter = ","
    if ($headerLine -match ";") {
        $commaCount = ($headerLine.ToCharArray() | Where-Object { $_ -eq ',' }).Count
        $semicolonCount = ($headerLine.ToCharArray() | Where-Object { $_ -eq ';' }).Count

        if ($semicolonCount -gt $commaCount) {
            $delimiter = ";"
            Write-Log "Detected semicolon (;) delimiter" "INFO"
        } else {
            Write-Log "Detected comma (,) delimiter" "INFO"
        }
    } else {
        Write-Log "Using default comma (,) delimiter" "INFO"
    }

    # Import CSV with detected delimiter
    $users = Import-Csv $CsvPath -Delimiter $delimiter

    # Check if CSV has any data
    if ($users.Count -eq 0) {
        throw "CSV file is empty or contains only headers. No user records found to process."
    }

    # Validate CSV structure
    $requiredColumns = @('OldEmail', 'NewEmail')
    $csvColumns = $users[0].PSObject.Properties.Name
    $missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }

    if ($missingColumns.Count -gt 0) {
        throw "CSV file missing required columns: $($missingColumns -join ', '). Required: $($requiredColumns -join ', ')"
    }

    Write-Log "CSV file loaded successfully. Found $($users.Count) user records to process." "SUCCESS"

    # Validate email formats
    $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    $invalidEmails = @()

    foreach ($user in $users) {
        if ([string]::IsNullOrWhiteSpace($user.OldEmail) -or ($user.OldEmail -notmatch $emailRegex)) {
            $invalidEmails += "Invalid OldEmail: '$($user.OldEmail)'"
        }
        if ([string]::IsNullOrWhiteSpace($user.NewEmail) -or ($user.NewEmail -notmatch $emailRegex)) {
            $invalidEmails += "Invalid NewEmail: '$($user.NewEmail)'"
        }
    }

    if ($invalidEmails.Count -gt 0) {
        Write-Log "Found $($invalidEmails.Count) invalid email addresses:" "WARNING"
        foreach ($invalid in $invalidEmails) {
            Write-Log "  - $invalid" "WARNING"
        }
    }

} catch {
    Write-Log "Failed to process CSV file: $($_.Exception.Message)" "ERROR"
    exit 1
}

####Create JIRA session for API calls
Write-Log "Creating JIRA session..." "INFO"
try {
    $sessionHeaders = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }

    $sessionBody = @{
        username = $creds.UserName
        password = $creds.GetNetworkCredential().Password
    } | ConvertTo-Json

    $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
    $session = Invoke-RestMethod -Method Post -Uri $SessionUri -Body $sessionBody -Headers $sessionHeaders -ErrorAction Stop
    Write-Log "JIRA session created successfully" "SUCCESS"

    # Create session headers for subsequent requests
    $apiHeaders = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
        'Cookie' = "$($session.session.name)=$($session.session.value)"
    }
} catch {
    Write-Log "Failed to create JIRA session: $($_.Exception.Message)" "ERROR"
    Write-Log "Please verify your credentials and JIRA URL" "ERROR"
    exit 1
}

####Backup existing user data (if requested)
if ($BackupUsers) {
    Write-Log "Creating backup of user data before changes..." "INFO"
    $userBackups = @()

    foreach ($user in $users) {
        if ([string]::IsNullOrWhiteSpace($user.OldEmail)) { continue }

        try {
            $searchUri = "$JiraBaseUrl/rest/api/2/user/search?query=$($user.OldEmail)"
            $searchResult = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $apiHeaders -ErrorAction Stop

            if ($searchResult.Count -gt 0) {
                $userBackups += $searchResult[0]
            }
        } catch {
            Write-Log "Warning: Could not backup user data for $($user.OldEmail): $($_.Exception.Message)" "WARNING"
        }
    }

    if ($userBackups.Count -gt 0) {
        try {
            $userBackups | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupPath -Encoding UTF8
            Write-Log "User data backup created: $backupPath" "SUCCESS"
        } catch {
            Write-Log "Failed to create user backup: $($_.Exception.Message)" "WARNING"
        }
    }
}

####Process email updates
Write-Log "Starting email update process..." "INFO"
$processedUsers = @()

foreach ($user in $users) {
    $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { $null }
    $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { $null }
    $currentUser = [PSCustomObject]@{
        OldEmail = $oldEmail
        NewEmail = $newEmail
        Status = "Pending"
        AccountId = $null
        ErrorMessage = $null
    }

    # Validate required fields
    if ([string]::IsNullOrWhiteSpace($oldEmail) -or [string]::IsNullOrWhiteSpace($newEmail)) {
        $currentUser.Status = "Skipped"
        $currentUser.ErrorMessage = "Missing required email address"
        Write-Log "Skipping row with missing email data: Old='$oldEmail', New='$newEmail'" "WARNING"
        $skippedCount++
        $processedUsers += $currentUser
        continue
    }

    # Skip if emails are the same
    if ($oldEmail -eq $newEmail) {
        $currentUser.Status = "Skipped"
        $currentUser.ErrorMessage = "Old and new email addresses are identical"
        Write-Log "Skipping $oldEmail - emails are identical" "INFO"
        $skippedCount++
        $processedUsers += $currentUser
        continue
    }

    try {
        # Search for user by old email
        Write-Log "Processing user: $oldEmail -> $newEmail" "INFO"
        $searchUri = "$JiraBaseUrl/rest/api/2/user/search?query=$oldEmail"
        $userSearchResult = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $apiHeaders -ErrorAction Stop

        if ($userSearchResult.Count -eq 0) {
            $currentUser.Status = "Failed"
            $currentUser.ErrorMessage = "User not found"
            Write-Log "User not found for email: $oldEmail" "WARNING"
            $errorCount++
            $processedUsers += $currentUser
            continue
        }

        # Handle multiple users found
        if ($userSearchResult.Count -gt 1) {
            Write-Log "Warning: Multiple users found for $oldEmail. Using first match." "WARNING"
        }

        $jiraUser = $userSearchResult[0]
        $accountId = $jiraUser.accountId
        $currentUser.AccountId = $accountId

        Write-Log "Found user: $($jiraUser.displayName) (Account ID: $accountId)" "INFO"

        if ($DryRun) {
            $currentUser.Status = "DryRun"
            Write-Log "DRY RUN: Would update $oldEmail to $newEmail for user $($jiraUser.displayName)" "INFO"
        } else {
            # Prepare update payload
            $updatePayload = @{
                emailAddress = $newEmail
            } | ConvertTo-Json

            # Update user email
            $updateUri = "$JiraBaseUrl/rest/api/2/user?accountId=$accountId"
            $updateResult = Invoke-RestMethod -Method Put -Uri $updateUri -Headers $apiHeaders -Body $updatePayload -ErrorAction Stop

            $currentUser.Status = "Success"
            Write-Log "Successfully updated email: $oldEmail -> $newEmail (User: $($jiraUser.displayName))" "SUCCESS"
            $updateCount++
        }

    } catch {
        $currentUser.Status = "Failed"
        $currentUser.ErrorMessage = $_.Exception.Message
        Write-Log "Failed to update email for $oldEmail : $($_.Exception.Message)" "ERROR"
        $errorCount++
    }

    $processedUsers += $currentUser
}

####Generate summary report
Write-Log "=== Email Update Summary ===" "INFO"
Write-Log "Total records processed: $($users.Count)" "INFO"
Write-Log "Successful updates: $updateCount" "SUCCESS"
Write-Log "Failed updates: $errorCount" "ERROR"
Write-Log "Skipped records: $skippedCount" "WARNING"

if ($DryRun) {
    Write-Log "This was a DRY RUN - no actual changes were made" "WARNING"
}

# Create detailed report
$reportPath = ".\JiraEmailUpdateReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
try {
    $processedUsers | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Log "Detailed report saved to: $reportPath" "SUCCESS"
} catch {
    Write-Log "Failed to create detailed report: $($_.Exception.Message)" "WARNING"
}

# Show failed updates
$failedUpdates = $processedUsers | Where-Object { $_.Status -eq "Failed" }
if ($failedUpdates.Count -gt 0) {
    Write-Log "Failed Updates Details:" "ERROR"
    foreach ($failed in $failedUpdates) {
        Write-Log "  - $($failed.OldEmail): $($failed.ErrorMessage)" "ERROR"
    }
}

####Close session
if ($session) {
    try {
        $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
        Invoke-RestMethod -Method Delete -Uri $SessionUri -Headers $apiHeaders -ErrorAction SilentlyContinue
        Write-Log "JIRA session closed successfully" "SUCCESS"
    } catch {
        Write-Log "Warning: Failed to properly close JIRA session" "WARNING"
    }
}

Write-Log "=== JIRA Bulk Email Update Script Completed ===" "SUCCESS"

# Exit with appropriate code
if ($errorCount -gt 0) {
    exit 1
} else {
    exit 0
}