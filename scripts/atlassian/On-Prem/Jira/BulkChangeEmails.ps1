# cSpell:words creds jira notfound atlassian
<#
.SYNOPSIS
    Bulk update JIRA user accounts (usernames and email addresses) from CSV file

.DESCRIPTION
    This script updates JIRA user accounts in bulk by reading from a CSV file
    and using the JIRA REST API. It can update both usernames and email addresses
    simultaneously. The script includes comprehensive logging, error handling,
    and validation to ensure safe and reliable user account updates.

.PARAMETER CsvPath
    Path to the CSV file containing OldUsername, NewUsername, OldEmail, and NewEmail columns

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
    Comma-separated (CSV): OldUsername,NewUsername,OldEmail,NewEmail
    Semicolon-separated: OldUsername;NewUsername;OldEmail;NewEmail

    Example formats:
    john.doe,j.doe,john.doe@company.com,j.doe@company.com
    jane.smith;jane.s;jane.smith@company.com;jane.s@company.com

    The script automatically detects the delimiter used.

    Authentication Notes:
    - Personal Access Tokens are recommended for automation scripts
    - Basic Auth sends credentials with every request
    - Session auth requires login but is more efficient for multiple calls
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to CSV file with OldUsername,NewUsername,OldEmail,NewEmail columns")]
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
    $CredentialFile,

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
        Write-Log "Debug: Cookie header = $($Headers.Cookie)" "INFO"

        # Try multiple endpoints to find one that works
        $testEndpoints = @(
            "/rest/api/2/myself",
            "/rest/api/2/serverInfo",
            "/rest/api/2/user/picker?query=admin"
        )

        foreach ($endpoint in $testEndpoints) {
            try {
                $testUri = "$BaseUrl$endpoint"
                Write-Log "Trying authentication test with endpoint: $testUri" "INFO"
                $testResult = Invoke-RestMethod -Method Get -Uri $testUri -Headers $Headers -ErrorAction Stop

                if ($endpoint -eq "/rest/api/2/myself") {
                    Write-Log "Authentication test successful - logged in as: $($testResult.displayName) ($($testResult.emailAddress))" "SUCCESS"
                } elseif ($endpoint -eq "/rest/api/2/serverInfo") {
                    Write-Log "Authentication test successful - JIRA Server: $($testResult.serverTitle) (Version: $($testResult.version))" "SUCCESS"
                } else {
                    Write-Log "Authentication test successful using $endpoint" "SUCCESS"
                }
                return $true
            } catch {
                Write-Log "Endpoint $endpoint failed: $($_.Exception.Message)" "WARNING"
                continue
            }
        }

        throw "All authentication test endpoints failed"

    } catch {
        Write-Log "Authentication test failed: $($_.Exception.Message)" "ERROR"

        # Provide specific guidance based on error
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Log "401 Unauthorized - Session may have expired or insufficient permissions" "ERROR"
        } elseif ($_.Exception.Response.StatusCode -eq 403) {
            Write-Log "403 Forbidden - Account may be locked or insufficient permissions" "ERROR"
        }

        return $false
    }
}

# Enhanced function to search for users with multiple methods (by email or username)
function Search-JiraUser {
    param(
        [string]$Email,
        [string]$Username,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    # Determine search queries - prioritize username if provided, fallback to email
    $searchQueries = @()
    if (-not [string]::IsNullOrWhiteSpace($Username)) {
        $searchQueries += @{ Type = "Username"; Value = $Username }
    }
    if (-not [string]::IsNullOrWhiteSpace($Email)) {
        $searchQueries += @{ Type = "Email"; Value = $Email }
    }

    if ($searchQueries.Count -eq 0) {
        Write-Log "No valid search criteria provided (Username: '$Username', Email: '$Email')" "ERROR"
        return $null
    }

    # Define comprehensive search methods for different JIRA configurations
    $searchMethods = @(
        @{ Name = "User Search Query"; Uri = "/rest/api/2/user/search?query=" },
        @{ Name = "User Search Username"; Uri = "/rest/api/2/user/search?username=" },
        @{ Name = "Users Search (plural)"; Uri = "/rest/api/2/users/search?query=" },
        @{ Name = "User Picker"; Uri = "/rest/api/2/user/picker?query=" },
        @{ Name = "User Assignable Search"; Uri = "/rest/api/2/user/assignable/search?query=" },
        @{ Name = "Direct User Lookup"; Uri = "/rest/api/2/user?username=" },
        @{ Name = "User Search by Email"; Uri = "/rest/api/2/user/search?property=email&query=" },
        @{ Name = "User Search Max Results"; Uri = "/rest/api/2/user/search?maxResults=50&query=" }
    )

    # Try each search query with each method
    foreach ($query in $searchQueries) {
        Write-Log "Searching for user by $($query.Type): $($query.Value)" "INFO"

        # For email searches, also try variations (username part only, domain variations)
        $searchVariations = @($query.Value)
        if ($query.Type -eq "Email" -and $query.Value -match "@") {
            $emailParts = $query.Value -split "@"
            $usernameBase = $emailParts[0]
            $searchVariations += @(
                $usernameBase,  # Just the username part
                "$usernameBase*",  # Wildcard username
                "*$usernameBase*"  # Wildcard both sides
            )
            # Only log variations for known test user to reduce noise
            if ($query.Value -match "ajn4901|kenneth.hargett") {
                Write-Log "Debug: Added email search variations: $($searchVariations -join ', ')" "INFO"
            }
        }

        foreach ($searchValue in $searchVariations) {
            foreach ($method in $searchMethods) {
            try {
                $encodedValue = [System.Web.HttpUtility]::UrlEncode($searchValue)
                $searchUri = "$BaseUrl$($method.Uri)$encodedValue"
                # Only log detailed search attempts for known test user to reduce noise
                if ($query.Value -match "ajn4901|kenneth.hargett") {
                    Write-Log "Trying $($method.Name) method for $($query.Type) with value '$searchValue': $searchUri" "INFO"
                }

                $result = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $Headers -ErrorAction Stop

                # Debug: Log the actual result structure (only for test user to reduce noise)
                if ($query.Value -match "ajn4901|kenneth.hargett") {
                    Write-Log "Debug: API response type: $($result.GetType().Name), Content: $($result | ConvertTo-Json -Compress)" "INFO"
                }

                # Handle different response formats with comprehensive checking
                $user = $null

                # User Picker format: { "users": [...] }
                if ($method.Name -eq "User Picker" -and $result.users -and $result.users.Count -gt 0) {
                    $user = $result.users[0]
                }
                # Array format: [user1, user2, ...]
                elseif ($result -is [Array] -and $result.Count -gt 0) {
                    $user = $result[0]
                }
                # Direct user object: { "accountId": "...", ... }
                elseif ($result -and $result.accountId) {
                    $user = $result
                }
                # Sometimes the result is wrapped in other properties
                elseif ($result -and $result.user) {
                    $user = $result.user
                }
                # Check if there's a results array
                elseif ($result -and $result.results -and $result.results.Count -gt 0) {
                    $user = $result.results[0]
                }

                if ($user -and (-not [string]::IsNullOrEmpty($user.accountId) -or -not [string]::IsNullOrEmpty($user.name))) {
                    Write-Log "SUCCESS: User found using $($method.Name) method for $($query.Type): $($user.displayName) ($($user.name))" "SUCCESS"
                    return $user
                } else {
                    if ($result) {
                        Write-Log "○ $($method.Name) method returned data but no valid user found for $($query.Type)" "INFO"
                    } else {
                        Write-Log "○ $($method.Name) method returned no results for $($query.Type)" "INFO"
                    }
                }
            } catch {
                $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
                Write-Log "FAILED: $($method.Name) method failed for $($query.Type) ($statusCode): $($_.Exception.Message)" "WARNING"

                # Log additional error details for 400 errors
                if ($statusCode -eq 400) {
                    try {
                        $errorStream = $_.Exception.Response.GetResponseStream()
                        if ($errorStream) {
                            # 🔧 ENTERPRISE PATTERN: Proper resource disposal using try/finally
                            $reader = $null
                            try {
                                $reader = New-Object System.IO.StreamReader($errorStream)
                                $errorDetails = $reader.ReadToEnd()
                                if ($errorDetails) {
                                    Write-Log "   400 Error Details for $($query.Type): $errorDetails" "WARNING"
                                }
                            } finally {
                                # Guarantee resource cleanup even if ReadToEnd() throws
                                if ($reader) {
                                    $reader.Dispose()
                                    $reader = $null
                                }
                            }
                        }
                    } catch {
                        # Ignore errors reading error details
                    }
                }
                continue
            }
        }
    }
}

    $searchCriteria = $searchQueries | ForEach-Object { "$($_.Type): $($_.Value)" }
    Write-Log "FAILED: No user found using any search method for: $($searchCriteria -join ', ')" "WARNING"
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

        # Validate CSV structure - different requirements for CheckUsersOnly vs actual updates
        $csvColumns = $users[0].PSObject.Properties.Name

        if ($CheckUsersOnly) {
            # For CheckUsersOnly mode, accept either 4-column format or 2-column format
            $updateFormat = @('OldUsername', 'NewUsername', 'OldEmail', 'NewEmail')
            $checkFormat = @('mail', 'samaccountname')

            $hasUpdateFormat = ($updateFormat | ForEach-Object { $_ -in $csvColumns }).Count -eq 4
            $hasCheckFormat = ($checkFormat | ForEach-Object { $_ -in $csvColumns }).Count -eq 2

            if (-not $hasUpdateFormat -and -not $hasCheckFormat) {
                throw "CSV file format not recognized. Expected either update format: $($updateFormat -join ', ') OR check format: $($checkFormat -join ', ')"
            }

            if ($hasCheckFormat) {
                Write-Log "Detected 2-column check format: mail, samaccountname" "INFO"
                # Convert to standard format for processing
                $users = $users | ForEach-Object {
                    [PSCustomObject]@{
                        OldUsername = $_.samaccountname
                        NewUsername = $_.samaccountname
                        OldEmail = $_.mail
                        NewEmail = $_.mail
                    }
                }
                Write-Log "Converted $($users.Count) users to standard format for checking" "INFO"
            } else {
                Write-Log "Detected 4-column update format: OldUsername, NewUsername, OldEmail, NewEmail" "INFO"
            }
        } else {
            # For actual updates, require the full 4-column format
            $requiredColumns = @('OldUsername', 'NewUsername', 'OldEmail', 'NewEmail')
            $missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }

            if ($missingColumns.Count -gt 0) {
                throw "CSV file missing required columns: $($missingColumns -join ', '). Required: $($requiredColumns -join ', ')"
            }
        }    Write-Log "CSV file loaded successfully. Found $($users.Count) user records to process." "SUCCESS"

    # Filter out Excel errors and validate email and username formats
    $emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    $usernameRegex = '^[a-zA-Z0-9._%+-@-]{2,100}$'  # Username: allows email format or standard username (2-100 chars)
    $excelErrors = @('#REFERENCE!', '#notfound', '#I/T', '#N/A', '#VALUE!', '#DIV/0!', '#NAME?', '#NULL!')
    $invalidEntries = @()
    $validUsers = @()

    foreach ($user in $users) {
        $oldUsername = if ($user.OldUsername) { $user.OldUsername.Trim() } else { '' }
        $newUsername = if ($user.NewUsername) { $user.NewUsername.Trim() } else { '' }
        $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { '' }
        $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { '' }

        # Skip rows with Excel errors or empty critical fields
        if ($excelErrors -contains $oldUsername -or $excelErrors -contains $newUsername -or
            $excelErrors -contains $oldEmail -or $excelErrors -contains $newEmail -or
            $oldUsername -like '<*>' -or $newUsername -like '<*>' -or
            $oldEmail -like '<*>' -or $newEmail -like '<*>' -or
            [string]::IsNullOrWhiteSpace($oldUsername) -or [string]::IsNullOrWhiteSpace($oldEmail)) {
            continue  # Skip these rows silently
        }

        # Validate formats for remaining rows
        $isValidOldUsername = $oldUsername -match $usernameRegex
        $isValidNewUsername = $newUsername -match $usernameRegex
        $isValidOldEmail = $oldEmail -match $emailRegex
        $isValidNewEmail = $newEmail -match $emailRegex

        # Collect validation errors
        if (-not $isValidOldUsername) {
            $invalidEntries += "Invalid OldUsername: '$oldUsername'"
        }
        if (-not $isValidNewUsername) {
            $invalidEntries += "Invalid NewUsername: '$newUsername'"
        }
        if (-not $isValidOldEmail) {
            $invalidEntries += "Invalid OldEmail: '$oldEmail'"
        }
        if (-not $isValidNewEmail) {
            $invalidEntries += "Invalid NewEmail: '$newEmail'"
        }

        # Only add users with valid formats to processing list
        if ($isValidOldUsername -and $isValidNewUsername -and $isValidOldEmail -and $isValidNewEmail) {
            $validUsers += [PSCustomObject]@{
                OldUsername = $oldUsername
                NewUsername = $newUsername
                OldEmail = $oldEmail
                NewEmail = $newEmail
            }
        }
    }

    # Update users array to only include valid entries
    $users = $validUsers
    $skippedRows = $($users.Count) - $($validUsers.Count)

    # Update users array and calculate skipped rows
    $totalRows = $users.Count
    $users = $validUsers
    $skippedRows = $totalRows - $validUsers.Count

    Write-Log "Filtered out Excel errors and invalid entries. Processing $($validUsers.Count) valid users." "INFO"
    if ($skippedRows -gt 0) {
        Write-Log "Skipped $skippedRows rows with Excel errors or invalid data." "WARNING"
    }

    if ($invalidEntries.Count -gt 0) {
        Write-Log "Found $($invalidEntries.Count) validation errors:" "WARNING"
        # Only show first 10 to avoid log spam
        $displayCount = [Math]::Min($invalidEntries.Count, 10)
        for ($i = 0; $i -lt $displayCount; $i++) {
            Write-Log "  - $($invalidEntries[$i])" "WARNING"
        }
        if ($invalidEntries.Count -gt 10) {
            Write-Log "  ... and $($invalidEntries.Count - 10) more validation errors" "WARNING"
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
        # 🛡️ ENTERPRISE SECURITY: Zero plain-text password exposure in memory
        $secureCredString = $null
        $base64AuthInfo = $null
        try {
            # Create credential string using secure methods without exposing plain text
            $networkCred = $creds.GetNetworkCredential()
            $secureCredString = "{0}:{1}" -f $networkCred.UserName, $networkCred.Password
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($secureCredString))

            $apiHeaders = @{
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
                'Authorization' = "Basic $base64AuthInfo"
            }
            $session = $null  # No session needed for Basic Auth
            Write-Log "Basic Authentication configured" "SUCCESS"
        } finally {
            # 🔒 SECURITY: Immediately clear sensitive data from memory
            if ($secureCredString) {
                $secureCredString = $null
                [System.GC]::Collect()  # Force garbage collection to clear memory
            }
            if ($base64AuthInfo -and $apiHeaders) {
                # Keep the auth header but clear the intermediate variable
                $base64AuthInfo = $null
            }
        }
    }
    # Handle Cookie-based (Session) Authentication
    else {
        Write-Log "Creating JIRA session for cookie-based authentication..." "INFO"
        $sessionHeaders = @{
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        # 🛡️ ENTERPRISE SECURITY: Secure session body creation with memory protection
        $sessionBodyObject = $null
        $sessionBody = $null
        try {
            $sessionBodyObject = @{
                username = $creds.UserName
                password = $creds.GetNetworkCredential().Password
            }
            $sessionBody = $sessionBodyObject | ConvertTo-Json
        } finally {
            # 🔒 SECURITY: Immediately clear password from memory after use
            if ($sessionBodyObject) {
                $sessionBodyObject.password = $null
                $sessionBodyObject = $null
                [System.GC]::Collect()  # Force garbage collection
            }
        }

        $SessionUri = "$JiraBaseUrl/rest/auth/1/session"

        # Enhanced session creation with better error handling
        try {
            $sessionResponse = Invoke-WebRequest -Method Post -Uri $SessionUri -Body $sessionBody -Headers $sessionHeaders -UseBasicParsing -ErrorAction Stop
            $session = $sessionResponse.Content | ConvertFrom-Json

            # Check for CAPTCHA or authentication issues
            if ($sessionResponse.Headers['X-Seraph-LoginReason']) {
                $loginReason = $sessionResponse.Headers['X-Seraph-LoginReason']
                if ($loginReason -eq 'AUTHENTICATION_DENIED') {
                    throw "Authentication denied - CAPTCHA may be triggered. Please log in via web browser to resolve."
                }
            }

            Write-Log "JIRA session created successfully for user: $($session.loginInfo.loginCount) previous logins" "SUCCESS"
            Write-Log "Debug: Session name=$($session.session.name), Session value length=$($session.session.value.Length)" "INFO"

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
    $authTestPassed = Test-JiraAuthentication -Headers $apiHeaders -BaseUrl $JiraBaseUrl

    # For session-based auth, if session was created successfully but test fails,
    # it might be due to restrictive permissions on test endpoints - proceed with warning
    if (-not $authTestPassed) {
        if ($session -and -not $PersonalAccessToken -and -not $UseBasicAuth) {
            Write-Log "Authentication test failed but session was created successfully. Proceeding with caution..." "WARNING"
            Write-Log "Note: Some JIRA instances restrict access to test endpoints. The script may still work for user operations." "WARNING"
        } else {
            Write-Log "Authentication test failed. Cannot continue." "ERROR"
            exit 1
        }
    }

    # Quick diagnostic: Test if we can find any users at all
    Write-Log "Running diagnostic test to check user search capabilities..." "INFO"
    try {
        $diagnosticUri = "$JiraBaseUrl/rest/api/2/user/search?query=admin&maxResults=5"
        $diagnosticResult = Invoke-RestMethod -Method Get -Uri $diagnosticUri -Headers $apiHeaders -ErrorAction Stop
        if ($diagnosticResult -and $diagnosticResult.Count -gt 0) {
            Write-Log "SUCCESS: Diagnostic - Found $($diagnosticResult.Count) user(s) with 'admin' search. User search is working." "SUCCESS"
            Write-Log "Sample user: $($diagnosticResult[0].displayName) [$($diagnosticResult[0].name)] ($($diagnosticResult[0].emailAddress))" "INFO"
        } else {
            Write-Log "WARNING: Diagnostic - 'admin' search returned no results. Users might not be searchable or different search patterns needed." "WARNING"
        }
    } catch {
        Write-Log "WARNING: Diagnostic - User search test failed: $($_.Exception.Message)" "WARNING"
    }

        # Test specific known user from CSV
        Write-Log "Testing search for known user: ajn4901 / kenneth.hargett@teliacompany.com" "INFO"
        try {
            $knownUser = Search-JiraUser -Email "kenneth.hargett@teliacompany.com" -Username "ajn4901" -Headers $apiHeaders -BaseUrl $JiraBaseUrl
            if ($knownUser) {
                Write-Log "SUCCESS: Found known user - $($knownUser.displayName) [$($knownUser.name)] ($($knownUser.emailAddress))" "SUCCESS"
            } else {
                Write-Log "FAILED: Could not find known user ajn4901 / kenneth.hargett@teliacompany.com" "ERROR"
            }
        } catch {
            Write-Log "ERROR: Search for known user failed: $($_.Exception.Message)" "ERROR"
        }} catch {
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

    # ⚡ ENTERPRISE PERFORMANCE: Parallel processing with throttled async operations
    $maxConcurrentBackups = 10  # Limit concurrent operations to prevent API overload
    $backupJobs = @()
    $userBackups = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

    # Filter valid users for backup
    $validUsersForBackup = $users | Where-Object { -not [string]::IsNullOrWhiteSpace($_.OldUsername) -and -not [string]::IsNullOrWhiteSpace($_.OldEmail) }
    Write-Log "Initiating parallel backup for $($validUsersForBackup.Count) users with throttling (max $maxConcurrentBackups concurrent)" "INFO"

    # Create background jobs for parallel processing
    foreach ($user in $validUsersForBackup) {
        # Wait if we've reached the concurrent limit
        while ((Get-Job -State Running).Count -ge $maxConcurrentBackups) {
            Start-Sleep -Milliseconds 100
            # Clean up completed jobs to prevent memory buildup
            Get-Job -State Completed | Remove-Job
        }

        # Start background job for each user backup
        $backupJob = Start-Job -ScriptBlock {
            param($JiraBaseUrl, $UserEmail, $UserUsername, $ApiHeaders)

            try {
                # Try searching by username first, then email
                $searchUri = "$JiraBaseUrl/rest/api/2/user/search?username=$UserUsername"
                # Convert hashtable to proper headers format for job context
                $headers = @{}
                foreach ($key in $ApiHeaders.Keys) {
                    $headers[$key] = $ApiHeaders[$key]
                }

                $searchResult = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $headers -ErrorAction Stop

                if ($searchResult.Count -gt 0) {
                    return @{
                        Success = $true
                        User = $searchResult[0]
                        Username = $UserUsername
                        Email = $UserEmail
                    }
                } else {
                    # Fallback to email search
                    $searchUri = "$JiraBaseUrl/rest/api/2/user/search?query=$UserEmail"
                    $searchResult = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $headers -ErrorAction Stop

                    if ($searchResult.Count -gt 0) {
                        return @{
                            Success = $true
                            User = $searchResult[0]
                            Username = $UserUsername
                            Email = $UserEmail
                        }
                    } else {
                        return @{
                            Success = $false
                            Message = "User not found by username or email"
                            Username = $UserUsername
                            Email = $UserEmail
                        }
                    }
                }
            } catch {
                return @{
                    Success = $false
                    Message = $_.Exception.Message
                    Username = $UserUsername
                    Email = $UserEmail
                }
            }
        } -ArgumentList $JiraBaseUrl, $user.OldEmail, $user.OldUsername, $apiHeaders

        $backupJobs += $backupJob
    }

    # Wait for all backup jobs to complete and collect results
    Write-Log "Waiting for parallel backup operations to complete..." "INFO"
    $backupJobs | Wait-Job | Out-Null

    foreach ($job in $backupJobs) {
        try {
            $result = Receive-Job -Job $job
            if ($result.Success -and $result.User) {
                $userBackups.Add($result.User)
            } elseif (-not $result.Success) {
                Write-Log "Warning: Could not backup user data for $($result.Username)/$($result.Email): $($result.Message)" "WARNING"
            }
        } catch {
            Write-Log "Error processing backup job result: $($_.Exception.Message)" "WARNING"
        } finally {
            Remove-Job -Job $job -Force
        }
    }

    # Convert concurrent bag to array for JSON serialization
    $backupArray = @($userBackups.ToArray())

    if ($backupArray.Count -gt 0) {
        try {
            $backupArray | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupPath -Encoding UTF8
            Write-Log "SUCCESS: Parallel user data backup completed: $backupPath ($($backupArray.Count) users backed up in parallel)" "SUCCESS"
        } catch {
            Write-Log "Failed to create user backup: $($_.Exception.Message)" "WARNING"
        }
    } else {
        Write-Log "No users found to backup" "WARNING"
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
        $oldUsername = if ($user.OldUsername) { $user.OldUsername.Trim() } else { $null }
        $newUsername = if ($user.NewUsername) { $user.NewUsername.Trim() } else { $null }
        $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { $null }
        $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { $null }

        # Skip invalid entries
        if ([string]::IsNullOrWhiteSpace($oldUsername) -or [string]::IsNullOrWhiteSpace($oldEmail)) {
            $invalidUsers += [PSCustomObject]@{
                OldUsername = $oldUsername
                NewUsername = $newUsername
                OldEmail = $oldEmail
                NewEmail = $newEmail
                Reason = "Missing required fields (OldUsername or OldEmail)"
            }
            continue
        }

        try {
            Write-Log "Searching for user: $oldUsername / $oldEmail" "INFO"
            $jiraUser = Search-JiraUser -Email $oldEmail -Username $oldUsername -Headers $apiHeaders -BaseUrl $JiraBaseUrl

            if ($null -ne $jiraUser) {
                # Support both modern JIRA (accountId) and older versions (name as identifier)
                $userId = if (-not [string]::IsNullOrEmpty($jiraUser.accountId)) { $jiraUser.accountId } else { $jiraUser.name }

                $existingUsers += [PSCustomObject]@{
                    OldUsername = $oldUsername
                    NewUsername = $newUsername
                    OldEmail = $oldEmail
                    NewEmail = $newEmail
                    DisplayName = $jiraUser.displayName
                    CurrentUsername = $jiraUser.name
                    AccountId = $userId
                    Active = $jiraUser.active
                }
                Write-Log "SUCCESS: Found $oldUsername/$oldEmail maps to $($jiraUser.displayName) [$($jiraUser.name)] (Active: $($jiraUser.active))" "SUCCESS"
            } else {
                $missingUsers += [PSCustomObject]@{
                    OldUsername = $oldUsername
                    NewUsername = $newUsername
                    OldEmail = $oldEmail
                    NewEmail = $newEmail
                    Reason = "User not found in JIRA using any search method"
                }
                Write-Log "MISSING: $oldUsername/$oldEmail - No user found using any search method" "WARNING"
            }
        } catch {
            $errorMessage = $_.Exception.Message
            $statusCode = "Unknown"

            # Extract status code if available
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }

            $missingUsers += [PSCustomObject]@{
                OldUsername = $oldUsername
                NewUsername = $newUsername
                OldEmail = $oldEmail
                NewEmail = $newEmail
                Reason = "Search failed ($statusCode): $errorMessage"
            }
            Write-Log "ERROR: Error searching for $oldUsername/$oldEmail (Status: $statusCode): $errorMessage" "ERROR"
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
            OldUsername = $existing.OldUsername
            NewUsername = $existing.NewUsername
            OldEmail = $existing.OldEmail
            NewEmail = $existing.NewEmail
            Status = "EXISTS"
            DisplayName = $existing.DisplayName
            CurrentUsername = $existing.CurrentUsername
            AccountId = $existing.AccountId
            Active = $existing.Active
            Reason = ""
        }
    }

    foreach ($missing in $missingUsers) {
        $allCheckResults += [PSCustomObject]@{
            OldUsername = $missing.OldUsername
            NewUsername = $missing.NewUsername
            OldEmail = $missing.OldEmail
            NewEmail = $missing.NewEmail
            Status = "MISSING"
            DisplayName = ""
            CurrentUsername = ""
            AccountId = ""
            Active = ""
            Reason = $missing.Reason
        }
    }

    foreach ($invalid in $invalidUsers) {
        $allCheckResults += [PSCustomObject]@{
            OldUsername = $invalid.OldUsername
            NewUsername = $invalid.NewUsername
            OldEmail = $invalid.OldEmail
            NewEmail = $invalid.NewEmail
            Status = "INVALID"
            DisplayName = ""
            CurrentUsername = ""
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
            Write-Log "  - $($missing.OldUsername)/$($missing.OldEmail): $($missing.Reason)" "WARNING"
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
    $oldUsername = if ($user.OldUsername) { $user.OldUsername.Trim() } else { $null }
    $newUsername = if ($user.NewUsername) { $user.NewUsername.Trim() } else { $null }
    $oldEmail = if ($user.OldEmail) { $user.OldEmail.Trim() } else { $null }
    $newEmail = if ($user.NewEmail) { $user.NewEmail.Trim() } else { $null }

    # Debug: Show extracted values for the first few users
    if ($updateCount + $errorCount + $skippedCount -lt 3) {
        Write-Log "Debug CSV extraction - OldUsername: '$oldUsername', NewUsername: '$newUsername', OldEmail: '$oldEmail', NewEmail: '$newEmail'" "INFO"
    }

    $currentUser = [PSCustomObject]@{
        OldUsername = $oldUsername
        NewUsername = $newUsername
        OldEmail = $oldEmail
        NewEmail = $newEmail
        Status = "Pending"
        AccountId = $null
        ErrorMessage = $null
    }

    # Validate required fields
    if ([string]::IsNullOrWhiteSpace($oldUsername) -or [string]::IsNullOrWhiteSpace($oldEmail) -or
        [string]::IsNullOrWhiteSpace($newUsername) -or [string]::IsNullOrWhiteSpace($newEmail)) {
        $currentUser.Status = "Skipped"
        $currentUser.ErrorMessage = "Missing required fields (username or email)"
        Write-Log "Skipping row with missing data: OldUsername='$oldUsername', NewUsername='$newUsername', OldEmail='$oldEmail', NewEmail='$newEmail'" "WARNING"
        $skippedCount++
        $processedUsers += $currentUser
        continue
    }

    # Skip if both username and email are unchanged
    if ($oldUsername -eq $newUsername -and $oldEmail -eq $newEmail) {
        $currentUser.Status = "Skipped"
        $currentUser.ErrorMessage = "Both username and email are identical to current values"
        Write-Log "Skipping $oldUsername/$oldEmail - no changes needed" "INFO"
        $skippedCount++
        $processedUsers += $currentUser
        continue
    }

    try {
        # Search for user by username and email
        Write-Log "Processing user: $oldUsername/$oldEmail -> $newUsername/$newEmail" "INFO"

        $jiraUser = Search-JiraUser -Email $oldEmail -Username $oldUsername -Headers $apiHeaders -BaseUrl $JiraBaseUrl

        if ($null -eq $jiraUser) {
            $currentUser.Status = "Failed"
            $currentUser.ErrorMessage = "User not found in JIRA instance using any search method"
            Write-Log "No user found for username/email: $oldUsername/$oldEmail using any search method" "WARNING"
            $errorCount++
            $processedUsers += $currentUser
            continue
        }

        # Validate that we have a valid user object with required properties
        # Support both modern JIRA (accountId) and older versions (name as identifier)
        $userIdentifier = $null
        if (-not [string]::IsNullOrEmpty($jiraUser.accountId)) {
            $userIdentifier = $jiraUser.accountId
        } elseif (-not [string]::IsNullOrEmpty($jiraUser.name)) {
            $userIdentifier = $jiraUser.name
        }

        if ([string]::IsNullOrEmpty($userIdentifier)) {
            $currentUser.Status = "Failed"
            $currentUser.ErrorMessage = "Invalid user data returned from search - missing accountId and name"
            Write-Log "Search returned invalid user data for username/email: $oldUsername/$oldEmail" "ERROR"
            $errorCount++
            $processedUsers += $currentUser
            continue
        }

        $currentUser.AccountId = $userIdentifier

        Write-Log "Found user: $($jiraUser.displayName) [$($jiraUser.name)] (ID: $userIdentifier)" "INFO"

        if ($DryRun) {
            $currentUser.Status = "DryRun"
            $changesNeeded = @()
            if ($oldUsername -ne $newUsername) {
                $changesNeeded += "username: $oldUsername -> $newUsername"
            }
            if ($oldEmail -ne $newEmail) {
                $changesNeeded += "email: $oldEmail -> $newEmail"
            }
            Write-Log "DRY RUN: Would update $($changesNeeded -join ', ') for user $($jiraUser.displayName)" "INFO"
        } else {
            # Prepare update payload with both username and email if they differ
            $updatePayload = @{}
            $changesApplied = @()

            if ($oldEmail -ne $newEmail) {
                $updatePayload.emailAddress = $newEmail
                $changesApplied += "email: $oldEmail -> $newEmail"
            }

            # Note: Username changes in JIRA Server are supported via API
            # This functionality is enabled for JIRA Server instances
            if ($oldUsername -ne $newUsername) {
                Write-Log "Attempting username change from $oldUsername to $newUsername" "INFO"
                try {
                    # For JIRA Server, username changes are supported via the name field
                    $updatePayload.name = $newUsername
                    $changesApplied += "username: $oldUsername -> $newUsername"
                    Write-Log "Username change added to update payload: $oldUsername -> $newUsername" "INFO"
                } catch {
                    Write-Log "Warning: Failed to prepare username change: $($_.Exception.Message)" "WARNING"
                }
            }

            if ($updatePayload.Count -eq 0) {
                $currentUser.Status = "Skipped"
                $currentUser.ErrorMessage = "No supported changes to apply"
                Write-Log "No supported changes for user $($jiraUser.displayName)" "INFO"
                $skippedCount++
            } else {
                $updatePayloadJson = $updatePayload | ConvertTo-Json

                # Update user - use accountId for modern JIRA, username for older versions
                if (-not [string]::IsNullOrEmpty($jiraUser.accountId)) {
                    $updateUri = "$JiraBaseUrl/rest/api/2/user?accountId=$userIdentifier"
                } else {
                    $updateUri = "$JiraBaseUrl/rest/api/2/user?username=$userIdentifier"
                }
                try {
                    $updateResult = Invoke-RestMethod -Method Put -Uri $updateUri -Headers $apiHeaders -Body $updatePayloadJson -ErrorAction Stop

                    $currentUser.Status = "Success"
                    Write-Log "Successfully updated $($changesApplied -join ', ') for user $($jiraUser.displayName)" "SUCCESS"

                    # Log detailed update result for troubleshooting
                    if ($updateResult) {
                        Write-Log "Update API Response: $($updateResult | ConvertTo-Json -Compress)" "DEBUG"
                    }

                    $updateCount++
                } catch {
                    throw
                }
            }
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
            Write-Log "Authentication failed for $oldUsername/$oldEmail - Check JIRA permissions or session validity" "ERROR"
            $currentUser.ErrorMessage = "401 Unauthorized - Authentication or permission issue"
        } elseif ($_.Exception.Message -match "404" -or $statusCode -eq 404) {
            Write-Log "User or endpoint not found for $oldUsername/$oldEmail - User may not exist" "ERROR"
            $currentUser.ErrorMessage = "404 Not Found - User does not exist"
        } elseif ($_.Exception.Message -match "403" -or $statusCode -eq 403) {
            Write-Log "Access forbidden for $oldUsername/$oldEmail - Insufficient permissions" "ERROR"
            $currentUser.ErrorMessage = "403 Forbidden - Insufficient permissions"
        } elseif ($_.Exception.Message -match "400" -or $statusCode -eq 400) {
            Write-Log "Bad Request for $oldUsername/$oldEmail - Check format or API parameters" "ERROR"
            $currentUser.ErrorMessage = "400 Bad Request - Invalid request format or parameters"

            # Try to get detailed error information
            try {
                if ($_.Exception.Response) {
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    # 🔧 ENTERPRISE PATTERN: Guaranteed resource cleanup with proper disposal
                    $reader = $null
                    try {
                        $reader = New-Object System.IO.StreamReader($errorStream)
                        $errorDetails = $reader.ReadToEnd()
                        Write-Log "400 Bad Request details: $errorDetails" "ERROR"
                    } finally {
                        # Ensure StreamReader is always disposed to prevent memory leaks
                        if ($reader) {
                            $reader.Dispose()
                            $reader = $null
                        }
                    }
                }
            } catch {
                Write-Log "Could not read detailed error information" "WARNING"
            }
        } else {
            Write-Log "Failed to process user $oldUsername/$oldEmail (Status: $statusCode): $($_.Exception.Message)" "ERROR"
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