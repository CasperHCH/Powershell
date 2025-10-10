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

.PARAMETER PersonalAccessToken
    Personal Access Token for authentication (recommended for automation)

.PARAMETER UseBasicAuth
    Use Basic Authentication instead of session-based authentication

.PARAMETER DryRun
    If specified, shows what would be changed without actually making changes

.PARAMETER BackupUsers
    If specified, creates a backup of current user data before changes

.PARAMETER CheckUsersOnly
    If specified, only checks how many users exist without making any changes

.PARAMETER LogPath
    Path for the log file (defaults to timestamped file in current directory)

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -DryRun

.EXAMPLE
    # .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -Username "admin@company.com"

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -CredentialFile "creds.xml" -BackupUsers

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -CheckUsersOnly

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -PersonalAccessToken "your_token_here"

.EXAMPLE
    .\BulkChangeEmails.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -Username "admin@company.com" -UseBasicAuth

.NOTES
    Author: Enhanced Script
    Version: 2.1
    Requires: PowerShell 5.1+, JIRA Admin permissions

    Authentication Methods:
    1. Personal Access Token (recommended for automation)
    2. Cookie-based session authentication (default)
    3. Basic authentication (simple but less secure)

    CSV Format Supported:
    Comma-separated (CSV): OldEmail,NewEmail
    Semicolon-separated: OldEmail;NewEmail

    Example formats:
    old1@company.com,new1@company.com
    old2@company.com;new2@company.com

    The script automatically detects the delimiter used.

    Authentication Notes:
    - Personal Access Tokens are recommended for automation scripts
    - Basic Auth sends credentials with every request
    - Session auth requires login but is more efficient for multiple calls
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
    [string]$PersonalAccessToken,

    [Parameter(Mandatory = $false)]
    [switch]$UseBasicAuth,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$BackupUsers,

    [Parameter(Mandatory = $false)]
    [switch]$CheckUsersOnly,

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

# Test authentication by making a simple API call
function Test-JiraAuthentication {
    param(
        [hashtable]$Headers,
        [string]$BaseUrl
    )
    try {
        Write-Log "Testing JIRA authentication..." "INFO"
        $testUri = "$BaseUrl/rest/api/2/myself"
        $testResult = Invoke-RestMethod -Method Get -Uri $testUri -Headers $Headers -ErrorAction Stop
        Write-Log "Authentication test successful - logged in as: $($testResult.displayName) ($($testResult.emailAddress))" "SUCCESS"
        return $true
    } catch {
        Write-Log "Authentication test failed: $($_.Exception.Message)" "ERROR"

        # Provide specific guidance based on error
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Log "401 Unauthorized - Check your credentials or token" "ERROR"
        } elseif ($_.Exception.Response.StatusCode -eq 403) {
            Write-Log "403 Forbidden - Account may be locked or insufficient permissions" "ERROR"
        }

        return $false
    }
}

# Enhanced function to search for users with multiple methods
function Search-JiraUser {
    param(
        [string]$Email,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    $searchMethods = @(
        @{ Name = "User Picker"; Uri = "/rest/api/2/user/picker?query=" },
        @{ Name = "Users Search"; Uri = "/rest/api/2/users/search?query=" },
        @{ Name = "User Search Query"; Uri = "/rest/api/2/user/search?query=" },
        @{ Name = "User Search Username"; Uri = "/rest/api/2/user/search?username=" },
        @{ Name = "User Assignable"; Uri = "/rest/api/2/user/assignable/search?query=" },
        @{ Name = "Direct Email Search"; Uri = "/rest/api/2/user?username=" }
    )

    foreach ($method in $searchMethods) {
        try {
            $encodedEmail = [System.Web.HttpUtility]::UrlEncode($Email)
            $searchUri = "$BaseUrl$($method.Uri)$encodedEmail"
            Write-Log "Trying $($method.Name) method: $searchUri" "INFO"

            $result = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $Headers -ErrorAction Stop

            # Handle different response formats
            $user = $null
            if ($method.Name -eq "User Picker" -and $result.users -and $result.users.Count -gt 0) {
                $user = $result.users[0]
            } elseif ($result -is [Array] -and $result.Count -gt 0) {
                $user = $result[0]
            } elseif ($result -and $result.accountId) {
                $user = $result
            }

            if ($user -and -not [string]::IsNullOrEmpty($user.accountId)) {
                Write-Log "✓ User found using $($method.Name) method: $($user.displayName)" "SUCCESS"
                return $user
            } else {
                Write-Log "○ $($method.Name) method returned no results" "INFO"
            }
        } catch {
            $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
            Write-Log "✗ $($method.Name) method failed ($statusCode): $($_.Exception.Message)" "WARNING"

            # Log additional error details for 400 errors
            if ($statusCode -eq 400) {
                try {
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    if ($errorStream) {
                        $reader = New-Object System.IO.StreamReader($errorStream)
                        $errorDetails = $reader.ReadToEnd()
                        if ($errorDetails) {
                            Write-Log "   400 Error Details: $errorDetails" "WARNING"
                        }
                    }
                } catch {
                    # Ignore errors reading error details
                }
            }
            continue
        }
    }

    Write-Log "✗ No user found for email: $Email using any search method" "WARNING"
    return $null
}

# Load required assemblies
Add-Type -AssemblyName System.Web

# Initialize script
Write-Log "=== JIRA Bulk Email Update Script Started ===" "INFO"
Write-Log "Parameters: CsvPath=$CsvPath, JiraBaseUrl=$JiraBaseUrl, DryRun=$DryRun, BackupUsers=$BackupUsers, CheckUsersOnly=$CheckUsersOnly" "INFO"

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
    # Use Personal Access Token if provided
    if ($PersonalAccessToken) {
        Write-Log "Using Personal Access Token authentication" "INFO"
        # For PAT, we create a pseudo-credential object for consistency
        $creds = $null  # Will be handled differently in session creation
        Write-Log "Personal Access Token authentication configured" "SUCCESS"
    }
    # Use credential file if provided
    elseif ($CredentialFile -and (Test-Path $CredentialFile)) {
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

    # Validate credentials (except for PAT which is validated during API calls)
    if (-not $PersonalAccessToken -and ($null -eq $creds -or $null -eq $creds.UserName)) {
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

    # Filter out Excel errors and validate email formats
    $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    $excelErrors = @('#REFERENCE!', '#notfound', '#I/T', '#N/A', '#VALUE!', '#DIV/0!', '#NAME?', '#NULL!')
    $invalidEmails = @()
    $validUsers = @()

    foreach ($user in $users) {
        $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { '' }
        $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { '' }

        # Skip rows with Excel errors or empty emails
        if ($excelErrors -contains $oldEmail -or $excelErrors -contains $newEmail -or
            $oldEmail -like '<*>' -or $newEmail -like '<*>' -or
            [string]::IsNullOrWhiteSpace($oldEmail) -or [string]::IsNullOrWhiteSpace($newEmail)) {
            continue  # Skip these rows silently
        }

        # Validate email format for remaining rows
        $isValidOld = $oldEmail -match $emailRegex
        $isValidNew = $newEmail -match $emailRegex

        if (-not $isValidOld) {
            $invalidEmails += "Invalid OldEmail: '$oldEmail'"
        }
        if (-not $isValidNew) {
            $invalidEmails += "Invalid NewEmail: '$newEmail'"
        }

        # Only add users with valid email formats to processing list
        if ($isValidOld -and $isValidNew) {
            $validUsers += [PSCustomObject]@{
                OldEmail = $oldEmail
                NewEmail = $newEmail
            }
        }
    }

    # Update users array to only include valid entries
    $users = $validUsers
    $skippedRows = $($users.Count) - $($validUsers.Count)

    Write-Log "Filtered out Excel errors and invalid entries. Processing $($validUsers.Count) valid users." "INFO"
    if ($skippedRows -gt 0) {
        Write-Log "Skipped $skippedRows rows with Excel errors or invalid data." "WARNING"
    }

    if ($invalidEmails.Count -gt 0) {
        Write-Log "Found $($invalidEmails.Count) invalid email formats:" "WARNING"
        # Only show first 10 to avoid log spam
        $displayCount = [Math]::Min($invalidEmails.Count, 10)
        for ($i = 0; $i -lt $displayCount; $i++) {
            Write-Log "  - $($invalidEmails[$i])" "WARNING"
        }
        if ($invalidEmails.Count -gt 10) {
            Write-Log "  ... and $($invalidEmails.Count - 10) more invalid emails" "WARNING"
        }
    }

} catch {
    Write-Log "Failed to process CSV file: $($_.Exception.Message)" "ERROR"
    exit 1
}

####Create JIRA session for API calls
Write-Log "Setting up JIRA API authentication..." "INFO"
try {
    # Handle Personal Access Token authentication
    if ($PersonalAccessToken) {
        Write-Log "Using Personal Access Token authentication" "INFO"
        $apiHeaders = @{
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
            'Authorization' = "Bearer $PersonalAccessToken"
        }
        $session = $null  # No session needed for PAT
        Write-Log "Personal Access Token authentication configured" "SUCCESS"
    }
    # Handle Basic Authentication
    elseif ($UseBasicAuth) {
        Write-Log "Using Basic Authentication" "INFO"
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $creds.UserName, $creds.GetNetworkCredential().Password)))
        $apiHeaders = @{
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
            'Authorization' = "Basic $base64AuthInfo"
        }
        $session = $null  # No session needed for Basic Auth
        Write-Log "Basic Authentication configured" "SUCCESS"
    }
    # Handle Cookie-based (Session) Authentication
    else {
        Write-Log "Creating JIRA session for cookie-based authentication..." "INFO"
        $sessionHeaders = @{
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        $sessionBody = @{
            username = $creds.UserName
            password = $creds.GetNetworkCredential().Password
        } | ConvertTo-Json

        $SessionUri = "$JiraBaseUrl/rest/auth/1/session"

        # Enhanced session creation with better error handling
        try {
            $sessionResponse = Invoke-WebRequest -Method Post -Uri $SessionUri -Body $sessionBody -Headers $sessionHeaders -ErrorAction Stop
            $session = $sessionResponse.Content | ConvertFrom-Json

            # Check for CAPTCHA or authentication issues
            if ($sessionResponse.Headers['X-Seraph-LoginReason']) {
                $loginReason = $sessionResponse.Headers['X-Seraph-LoginReason']
                if ($loginReason -eq 'AUTHENTICATION_DENIED') {
                    throw "Authentication denied - CAPTCHA may be triggered. Please log in via web browser to resolve."
                }
            }

            Write-Log "JIRA session created successfully for user: $($session.loginInfo.loginCount) previous logins" "SUCCESS"

            # Create session headers for subsequent requests
            $apiHeaders = @{
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
                'Cookie' = "$($session.session.name)=$($session.session.value)"
            }
        } catch {
            # Handle specific session creation errors
            if ($_.Exception.Response.StatusCode -eq 401) {
                Write-Log "Authentication failed: Invalid username or password" "ERROR"
            } elseif ($_.Exception.Response.StatusCode -eq 403) {
                Write-Log "Access denied: Account may be locked or CAPTCHA triggered" "ERROR"
            } else {
                Write-Log "Session creation failed: $($_.Exception.Message)" "ERROR"
            }
            throw
        }
    }

    # Test authentication before proceeding
    if (-not (Test-JiraAuthentication -Headers $apiHeaders -BaseUrl $JiraBaseUrl)) {
        Write-Log "Authentication test failed. Cannot continue." "ERROR"
        exit 1
    }

} catch {
    Write-Log "Failed to set up JIRA authentication: $($_.Exception.Message)" "ERROR"
    Write-Log "Please verify your credentials and JIRA URL" "ERROR"

    # Check if it's a CAPTCHA issue
    if ($_.Exception.Message -match "CAPTCHA|AUTHENTICATION_DENIED") {
        Write-Log "CAPTCHA may be triggered. Please:" "ERROR"
        Write-Log "1. Log in via web browser to resolve CAPTCHA" "ERROR"
        Write-Log "2. Consider using Personal Access Token instead" "ERROR"
    }
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

# Session was created successfully, proceeding with user processing

# Check users only mode - validate existence without making changes
if ($CheckUsersOnly) {
    Write-Log "=== USER EXISTENCE CHECK MODE ===" "INFO"
    Write-Log "Checking which users exist in JIRA instance..." "INFO"

    $existingUsers = @()
    $missingUsers = @()
    $invalidUsers = @()

    foreach ($user in $users) {
        $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { $null }
        $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { $null }

        # Skip invalid entries
        if ([string]::IsNullOrWhiteSpace($oldEmail)) {
            $invalidUsers += [PSCustomObject]@{
                OldEmail = $oldEmail
                NewEmail = $newEmail
                Reason = "Missing OldEmail"
            }
            continue
        }

        try {
            Write-Log "Searching for user: $oldEmail" "INFO"
            $jiraUser = Search-JiraUser -Email $oldEmail -Headers $apiHeaders -BaseUrl $JiraBaseUrl

            if ($null -ne $jiraUser) {
                $existingUsers += [PSCustomObject]@{
                    OldEmail = $oldEmail
                    NewEmail = $newEmail
                    DisplayName = $jiraUser.displayName
                    AccountId = $jiraUser.accountId
                    Active = $jiraUser.active
                }
                Write-Log "✓ Found: $oldEmail -> $($jiraUser.displayName) (Active: $($jiraUser.active))" "SUCCESS"
            } else {
                $missingUsers += [PSCustomObject]@{
                    OldEmail = $oldEmail
                    NewEmail = $newEmail
                    Reason = "User not found in JIRA using any search method"
                }
                Write-Log "✗ Missing: $oldEmail - No user found using any search method" "WARNING"
            }
        } catch {
            $errorMessage = $_.Exception.Message
            $statusCode = "Unknown"

            # Extract status code if available
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }

            $missingUsers += [PSCustomObject]@{
                OldEmail = $oldEmail
                NewEmail = $newEmail
                Reason = "Search failed ($statusCode): $errorMessage"
            }
            Write-Log "✗ Error searching for $oldEmail (Status: $statusCode): $errorMessage" "ERROR"
        }
    }

    # Generate summary report
    Write-Log "=== USER EXISTENCE CHECK SUMMARY ===" "INFO"
    Write-Log "Total users in CSV: $($users.Count)" "INFO"
    Write-Log "Users found in JIRA: $($existingUsers.Count)" "SUCCESS"
    Write-Log "Users missing from JIRA: $($missingUsers.Count)" "WARNING"
    Write-Log "Invalid entries: $($invalidUsers.Count)" "ERROR"

    # Show active vs inactive users
    if ($existingUsers.Count -gt 0) {
        $activeUsers = $existingUsers | Where-Object { $_.Active -eq $true }
        $inactiveUsers = $existingUsers | Where-Object { $_.Active -eq $false }
        Write-Log "  - Active users: $($activeUsers.Count)" "SUCCESS"
        Write-Log "  - Inactive users: $($inactiveUsers.Count)" "WARNING"
    }

    # Create detailed reports
    $checkReportPath = ".\JiraUserExistenceCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $allCheckResults = @()

    foreach ($existing in $existingUsers) {
        $allCheckResults += [PSCustomObject]@{
            OldEmail = $existing.OldEmail
            NewEmail = $existing.NewEmail
            Status = "EXISTS"
            DisplayName = $existing.DisplayName
            AccountId = $existing.AccountId
            Active = $existing.Active
            Reason = ""
        }
    }

    foreach ($missing in $missingUsers) {
        $allCheckResults += [PSCustomObject]@{
            OldEmail = $missing.OldEmail
            NewEmail = $missing.NewEmail
            Status = "MISSING"
            DisplayName = ""
            AccountId = ""
            Active = ""
            Reason = $missing.Reason
        }
    }

    foreach ($invalid in $invalidUsers) {
        $allCheckResults += [PSCustomObject]@{
            OldEmail = $invalid.OldEmail
            NewEmail = $invalid.NewEmail
            Status = "INVALID"
            DisplayName = ""
            AccountId = ""
            Active = ""
            Reason = $invalid.Reason
        }
    }

    try {
        $allCheckResults | Export-Csv -Path $checkReportPath -NoTypeInformation -Encoding UTF8
        Write-Log "Detailed check report saved to: $checkReportPath" "SUCCESS"
    } catch {
        Write-Log "Failed to create check report: $($_.Exception.Message)" "WARNING"
    }

    # Show missing users details
    if ($missingUsers.Count -gt 0) {
        Write-Log "Missing Users Details:" "WARNING"
        foreach ($missing in $missingUsers) {
            Write-Log "  - $($missing.OldEmail): $($missing.Reason)" "WARNING"
        }
    }

    # Close session and exit (only needed for cookie-based auth)
    if ($session -and -not $PersonalAccessToken -and -not $UseBasicAuth) {
        try {
            $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
            Invoke-RestMethod -Method Delete -Uri $SessionUri -Headers $apiHeaders -ErrorAction SilentlyContinue
            Write-Log "JIRA session closed successfully" "SUCCESS"
        } catch {
            Write-Log "Warning: Failed to properly close JIRA session" "WARNING"
        }
    }

    Write-Log "=== USER EXISTENCE CHECK COMPLETED ===" "SUCCESS"
    exit 0
}

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

        $jiraUser = Search-JiraUser -Email $oldEmail -Headers $apiHeaders -BaseUrl $JiraBaseUrl

        if ($null -eq $jiraUser) {
            $currentUser.Status = "Failed"
            $currentUser.ErrorMessage = "User not found in JIRA instance using any search method"
            Write-Log "No user found for email: $oldEmail using any search method" "WARNING"
            $errorCount++
            $processedUsers += $currentUser
            continue
        }

        # Validate that we have a valid user object with required properties
        if ([string]::IsNullOrEmpty($jiraUser.accountId)) {
            $currentUser.Status = "Failed"
            $currentUser.ErrorMessage = "Invalid user data returned from search"
            Write-Log "Search returned invalid user data for email: $oldEmail" "ERROR"
            $errorCount++
            $processedUsers += $currentUser
            continue
        }

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

        # Provide more specific error context
        $statusCode = "Unknown"
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
        }

        if ($_.Exception.Message -match "401" -or $statusCode -eq 401) {
            Write-Log "Authentication failed for $oldEmail - Check JIRA permissions or session validity" "ERROR"
            $currentUser.ErrorMessage = "401 Unauthorized - Authentication or permission issue"
        } elseif ($_.Exception.Message -match "404" -or $statusCode -eq 404) {
            Write-Log "User or endpoint not found for $oldEmail - User may not exist" "ERROR"
            $currentUser.ErrorMessage = "404 Not Found - User does not exist"
        } elseif ($_.Exception.Message -match "403" -or $statusCode -eq 403) {
            Write-Log "Access forbidden for $oldEmail - Insufficient permissions" "ERROR"
            $currentUser.ErrorMessage = "403 Forbidden - Insufficient permissions"
        } elseif ($_.Exception.Message -match "400" -or $statusCode -eq 400) {
            Write-Log "Bad Request for $oldEmail - Check email format or API parameters" "ERROR"
            $currentUser.ErrorMessage = "400 Bad Request - Invalid request format or parameters"

            # Try to get detailed error information
            try {
                if ($_.Exception.Response) {
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorStream)
                    $errorDetails = $reader.ReadToEnd()
                    Write-Log "400 Bad Request details: $errorDetails" "ERROR"
                }
            } catch {
                Write-Log "Could not read detailed error information" "WARNING"
            }
        } else {
            Write-Log "Failed to process user $oldEmail (Status: $statusCode): $($_.Exception.Message)" "ERROR"
        }

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

####Close session (only needed for cookie-based auth)
if ($session -and -not $PersonalAccessToken -and -not $UseBasicAuth) {
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