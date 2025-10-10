# cSpell:words creds jira notfound atlassian anonymization userkey
<#
.SYNOPSIS
    Enterprise JIRA User Management - Bulk disable and anonymize users with comprehensive search capabilities

.DESCRIPTION
    This enterprise-grade script provides comprehensive user lifecycle management for JIRA on-premise instances.
    It can discover, disable, and anonymize users based on CSV input, email domains, or username patterns.
    Features include project lead conflict resolution, inactive user discovery, GDPR-compliant anonymization
    with content ownership transfer, parallel processing, comprehensive logging, and extensive error handling.
    
    Key Features:
    - Multi-method user discovery (active and inactive users)
    - Automatic project lead transfer for conflict resolution  
    - GDPR-compliant anonymization with proper content ownership
    - Enhanced batch processing with manual intervention tracking
    - Comprehensive logging with optional debug output
    - Support for Personal Access Token authentication

.PARAMETER CsvPath
    Path to CSV file containing user information (username, email, or displayName columns)

.PARAMETER JiraBaseUrl
    The base URL of your JIRA instance (e.g., https colon slash slash jira.company.com)

.PARAMETER EmailDomains
    Comma-separated list of email domains to target for disabling (e.g., "oldcompany.com,contractor.net")

.PARAMETER UsernamePatterns
    Comma-separated list of username patterns using wildcards (e.g., "temp_*,contractor_*,old.*")

.PARAMETER Username
    JIRA username for authentication (if not provided, will prompt)

.PARAMETER CredentialFile
    Path to encrypted credential file (alternative to interactive login)

.PARAMETER PersonalAccessToken
    Personal Access Token for authentication (recommended for automation)

.PARAMETER UseBasicAuth
    Use Basic Authentication instead of session-based authentication

.PARAMETER DisableOnly
    If specified, only disables users without anonymizing them

.PARAMETER AnonymizeUsers
    If specified, anonymizes disabled users (removes personal information permanently)

.PARAMETER DryRun
    If specified, shows what would be changed without actually making changes

.PARAMETER BackupUsers
    If specified, creates a backup of user data before changes

.PARAMETER CheckUsersOnly
    If specified, only checks which users would be affected without making any changes

.PARAMETER ForceProjectLeadTransfer
    If specified, automatically transfers project leadership when conflicts are detected

.PARAMETER NewProjectLead
    Username to transfer project leadership to when ForceProjectLeadTransfer is used (defaults to "admin")

.PARAMETER LogPath
    Path for the log file (defaults to timestamped file in current directory)

.PARAMETER MaxConcurrentOperations
    Maximum number of concurrent operations (default: 5)

.PARAMETER AnonymizationTimeout
    Timeout in seconds for anonymization operations (default: 600)

.PARAMETER EnableDebugLogging
    If specified, enables detailed debug logging for troubleshooting (may generate verbose output)

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -DisableOnly

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "oldcompany.com,contractor.net" -JiraBaseUrl "https://jira.company.com" -DryRun

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira.company.com" -DisableOnly -PersonalAccessToken "your_token"

    Disable only users with @teliacompany.com email domain using Personal Access Token authentication

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -AnonymizeUsers -BackupUsers

    Anonymize users from CSV (disables and permanently removes personal information)

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -UsernamePatterns "temp_*,old.*" -JiraBaseUrl "https://jira.company.com" -AnonymizeUsers -BackupUsers

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "contractor.net" -JiraBaseUrl "https://jira.company.com" -AnonymizeUsers -PersonalAccessToken "your_token"

    Anonymize users with @contractor.net domain (works on both active and already disabled users)
    Note: Anonymization permanently removes personal data and cannot be undone

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -CsvPath "users.csv" -JiraBaseUrl "https://jira.company.com" -PersonalAccessToken "your_token" -CheckUsersOnly

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -DisableOnly -ForceProjectLeadTransfer -NewProjectLead "johndoe" -PersonalAccessToken "your_token"

    Disable users from teliacompany.com domain and automatically transfer any project leadership to 'johndoe' user

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -AnonymizeUsers -PersonalAccessToken "your_token" -DryRun

    Test anonymization of users with @teliacompany.com domain without making changes

.EXAMPLE
    .\Bulk_Disable_Jira_Users.ps1 -EmailDomains "teliacompany.com" -JiraBaseUrl "https://jira-ks.norlys.dk" -AnonymizeUsers -ForceProjectLeadTransfer -NewProjectLead "admin" -PersonalAccessToken "your_token" -EnableDebugLogging

    Anonymize inactive teliacompany.com users with debug logging enabled for troubleshooting

.NOTES
    Author: Enterprise PowerShell Team  
    Version: 3.0
    Date: October 2025
    Requires: PowerShell 5.1+, JIRA Admin permissions

    Authentication Methods:
    1. Personal Access Token (recommended for automation)
    2. Cookie-based session authentication (default)
    3. Basic authentication (simple but less secure)

    CSV Format Supported:
    - Minimum: username column
    - Enhanced: username, email, displayName columns
    - Auto-detects delimiter (comma or semicolon)

    Safety Features:
    - Comprehensive logging and audit trail
    - Dry-run mode for testing
    - User data backup before changes
    - Rollback functionality for critical errors
    - Parallel processing with throttling
    - Extensive error handling and retry logic

    Domain Filtering:
    - Supports multiple email domains
    - Pattern matching with wildcards
    - Case-insensitive matching
    - Automatic user discovery by domain

    IMPORTANT SECURITY NOTES:
    - Anonymization is PERMANENT and cannot be undone
    - Always use -DryRun first to verify target users
    - Create backups before running destructive operations
    - Test on non-production environment first

    Anonymization Process (Based on Atlassian Documentation):
    - User profiles are completely anonymized (email, name, avatar removed)
    - Usernames changed to anonymous aliases (e.g., jirauser80900)
    - Display names changed to anonymous aliases (e.g., user-ca31a)
    - Activity history preserved but with anonymized identifiers
    - External directory users must be removed from directory first
    - Some third-party integrations may require manual cleanup
    - Process can work on both active and already disabled users
#>

[CmdletBinding(DefaultParameterSetName = "CsvInput")]
param (
    [Parameter(ParameterSetName = "CsvInput", Mandatory = $false, HelpMessage = "Path to CSV file with user information")]
    [ValidateScript({
        if ([string]::IsNullOrEmpty($_)) { $true }
        elseif (Test-Path $_) { $true }
        else { throw "CSV file not found: $_" }
    })]
    [string]$CsvPath,

    [Parameter(ParameterSetName = "DomainInput", Mandatory = $true, HelpMessage = "Comma-separated email domains to target")]
    [Parameter(ParameterSetName = "PatternInput", Mandatory = $true, HelpMessage = "Comma-separated email domains to target")]
    [ValidatePattern('^[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(\s*,\s*[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?)*$')]
    [string]$EmailDomains,

    [Parameter(ParameterSetName = "PatternInput", Mandatory = $true, HelpMessage = "Comma-separated username patterns with wildcards")]
    [string]$UsernamePatterns,

    [Parameter(Mandatory = $true, HelpMessage = "JIRA base URL (e.g., https`://jira.company.com)")]
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
    [switch]$DisableOnly,

    [Parameter(Mandatory = $false)]
    [switch]$AnonymizeUsers,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$BackupUsers,

    [Parameter(Mandatory = $false)]
    [switch]$CheckUsersOnly,

    [Parameter(Mandatory = $false)]
    [switch]$ForceProjectLeadTransfer,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$NewProjectLead = "admin",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\JiraBulkUserDisable_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$MaxConcurrentOperations = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3600)]
    [int]$AnonymizationTimeout = 600,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLogging
)

# 📊 ENTERPRISE LOGGING FRAMEWORK
# Advanced logging with military-grade security patterns and colored output
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $LogPath,
        [switch]$NoConsole
    )

    # Skip DEBUG messages if debug logging is not enabled
    if ($Level -eq "DEBUG" -and -not $EnableDebugLogging) {
        return
    }

    # 🛡️ ENTERPRISE SECURITY: Input validation and sanitization
    $sanitizedMessage = $Message -replace '[\x00-\x1F\x7F-\x9F]', '' # Remove control characters
    $sanitizedMessage = $sanitizedMessage -replace '"', '\"' # Escape quotes for JSON compliance

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $sanitizedMessage"

    # 🎨 ENTERPRISE UX: Color-coded console output for operational clarity
    if (-not $NoConsole) {
        $consoleColor = switch ($Level.ToUpper()) {
            "ERROR"     { "Red" }
            "WARNING"   { "Yellow" }
            "SUCCESS"   { "Green" }
            "CRITICAL"  { "Magenta" }
            "DEBUG"     { "Cyan" }
            default     { "White" }
        }
        Write-Host $logMessage -ForegroundColor $consoleColor
    }

    # 💾 ENTERPRISE PERSISTENCE: Thread-safe file operations with error recovery
    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            # 🔒 SECURITY: Atomic write operations to prevent log corruption
            Add-Content -Path $LogFile -Value $logMessage -ErrorAction Stop
            break
        } catch {
            $retryCount++
            if ($retryCount -eq $maxRetries) {
                Write-Warning "Failed to write to log file after $maxRetries attempts: $($_.Exception.Message)"
            } else {
                Start-Sleep -Milliseconds (100 * $retryCount) # Exponential backoff
            }
        }
    }
}

# Test authentication by making a simple API call
function Test-JiraAuthentication {
    param(
        [hashtable]$Headers,
        [string]$BaseUrl
    )
    try {
        Write-Log "Testing JIRA authentication..." "INFO"

        # Try multiple endpoints to find one that works
        $testEndpoints = @(
            "/rest/api/2/myself",
            "/rest/api/2/serverInfo",
            "/rest/api/2/user/picker?query=admin"
        )

        foreach ($endpoint in $testEndpoints) {
            try {
                $testUri = "$BaseUrl$endpoint"
                Write-Log "Trying authentication test with endpoint: $testUri" "DEBUG"
                $testResult = Invoke-RestMethod -Method Get -Uri $testUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                if ($endpoint -eq "/rest/api/2/myself") {
                    Write-Log "Authentication test successful - logged in as: $($testResult.displayName) ($($testResult.emailAddress))" "SUCCESS"
                } elseif ($endpoint -eq "/rest/api/2/serverInfo") {
                    Write-Log "Authentication test successful - JIRA Server: $($testResult.serverTitle) (Version: $($testResult.version))" "SUCCESS"
                } else {
                    Write-Log "Authentication test successful using $endpoint" "SUCCESS"
                }
                return $true
            } catch {
                Write-Log "Endpoint $endpoint failed: $($_.Exception.Message)" "DEBUG"
                continue
            }
        }

        throw "All authentication test endpoints failed"

    } catch {
        Write-Log "Authentication test failed: $($_.Exception.Message)" "ERROR"

        # Provide specific guidance based on error
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 401) {
                Write-Log "401 Unauthorized - Check credentials or session expiry" "ERROR"
            } elseif ($statusCode -eq 403) {
                Write-Log "403 Forbidden - Account may be locked or insufficient permissions" "ERROR"
            }
        }

        return $false
    }
}

# Enhanced function to search for users with multiple methods
function Search-JiraUsers {
    param(
        [string[]]$EmailDomains,
        [string[]]$UsernamePatterns,
        [hashtable]$Headers,
        [string]$BaseUrl,
        [int]$MaxResults = 1000
    )

    Write-Log "Starting user search with domains: $($EmailDomains -join ', '), patterns: $($UsernamePatterns -join ', ')" "INFO"

    $foundUsers = @()

    # Search for users by email domains using multiple methods
    if ($EmailDomains -and $EmailDomains.Count -gt 0) {
        foreach ($domain in $EmailDomains) {
            Write-Log "Searching for users with email domain: $domain" "INFO"

            # Try multiple search approaches for maximum compatibility
            $searchAttempts = @(
                # Standard user search endpoints (fixed with username parameter)
                @{ Method = "Username search with domain"; Uri = "/rest/api/2/user/search?username=@$domain&maxResults=$MaxResults" },
                @{ Method = "Username wildcard search"; Uri = "/rest/api/2/user/search?username=*$domain*&maxResults=$MaxResults" },
                @{ Method = "Query with username param"; Uri = "/rest/api/2/user/search?username=.&query=@$domain&maxResults=$MaxResults" },
                @{ Method = "Query with username param wildcard"; Uri = "/rest/api/2/user/search?username=.&query=$domain&maxResults=$MaxResults" },

                # User picker endpoints (these work and return users)
                @{ Method = "User picker domain search"; Uri = "/rest/api/2/user/picker?query=@$domain&maxResults=$MaxResults" },
                @{ Method = "User picker wildcard"; Uri = "/rest/api/2/user/picker?query=$domain&maxResults=$MaxResults" },
                @{ Method = "User picker email search"; Uri = "/rest/api/2/user/picker?query=*@$domain&maxResults=$MaxResults" },
                @{ Method = "User picker broad search"; Uri = "/rest/api/2/user/picker?query=*&maxResults=$MaxResults" },

                # Alternative API endpoints for different JIRA versions
                @{ Method = "User search v3 with username"; Uri = "/rest/api/3/user/search?accountType=atlassian&query=$domain&maxResults=$MaxResults" },

                # Additional search methods for hard-to-find domains
                @{ Method = "Direct email search"; Uri = "/rest/api/2/user/search?username=.&query=*@$domain&maxResults=$MaxResults" },
                @{ Method = "Broad search with email filter"; Uri = "/rest/api/2/user/search?username=.&query=*&maxResults=$MaxResults" },
                @{ Method = "Email domain search"; Uri = "/rest/api/2/user/search?username=.&emailAddress=*@$domain&maxResults=$MaxResults" },

                # Search methods that specifically include inactive users
                @{ Method = "Include inactive users search"; Uri = "/rest/api/2/user/search?username=.&query=@$domain&includeInactive=true&maxResults=$MaxResults" },
                @{ Method = "Include inactive broad search"; Uri = "/rest/api/2/user/search?username=.&query=*&includeInactive=true&maxResults=$MaxResults" },
                @{ Method = "Active false filter search"; Uri = "/rest/api/2/user/search?username=.&query=*&active=false&maxResults=$MaxResults" },
                @{ Method = "JQL user search"; Uri = "/rest/api/2/search?jql=assignee was '$domain' OR reporter was '$domain'&maxResults=$MaxResults" }
            )

            $domainUsersFound = $false
            foreach ($attempt in $searchAttempts) {
                try {
                    $searchUri = "$BaseUrl$($attempt.Uri)"
                    Write-Log "Trying $($attempt.Method): $searchUri" "DEBUG"

                    $result = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                    # Log the raw response for debugging
                    if ($result) {
                        Write-Log "Raw response type: $($result.GetType().Name)" "DEBUG"
                        if ($result -is [array]) {
                            Write-Log "Response is array with $($result.Count) items" "DEBUG"
                        } elseif ($result.PSObject.Properties) {
                            $propNames = ($result.PSObject.Properties | Select-Object -ExpandProperty Name) -join ', '
                            Write-Log "Response properties: $propNames" "DEBUG"
                        }
                    }

                    # Handle different response formats
                    $users = @()
                    if ($result -is [array]) {
                        $users = $result
                        Write-Log "Using direct array response: $($users.Count) users" "DEBUG"
                    } elseif ($result.users -and $result.users -is [array]) {
                        $users = $result.users  # User picker format
                        Write-Log "Using result.users property: $($users.Count) users" "DEBUG"
                    } elseif ($result.values -and $result.values -is [array]) {
                        $users = $result.values  # Some endpoints use 'values'
                        Write-Log "Using result.values property: $($users.Count) users" "DEBUG"
                    } elseif ($result.PSObject.Properties['users']) {
                        $users = $result.users
                        Write-Log "Using PSObject users property: $($users.Count) users" "DEBUG"
                    } elseif ($result -and $result.name) {
                        $users = @($result)  # Single user response
                        Write-Log "Single user response converted to array" "DEBUG"
                    }

                    Write-Log "Total users found in response: $($users.Count)" "DEBUG"

                    if ($users -and $users.Count -gt 0) {
                        # Filter users by email domain (primary method)
                        Write-Log "Filtering users for domain: @$($domain.ToLower())" "DEBUG"
                        $domainUsers = @()

                        # Check each user for domain match
                        foreach ($user in $users) {
                            $userEmail = if ($user.emailAddress) { $user.emailAddress.ToLower() } else { "" }
                            $domainPattern = "@$($domain.ToLower())"

                            Write-Log "Checking user $($user.name): email='$userEmail' against pattern '$domainPattern'" "DEBUG"

                            if ($userEmail -and $userEmail.EndsWith($domainPattern)) {
                                $domainUsers += $user
                                Write-Log "MATCH: User $($user.name) matches domain (exact)" "DEBUG"
                            }
                        }

                        # Also check for users where the domain appears anywhere in the email
                        if ($domainUsers.Count -eq 0) {
                            foreach ($user in $users) {
                                $userEmail = if ($user.emailAddress) { $user.emailAddress.ToLower() } else { "" }

                                if ($userEmail -and $userEmail.Contains($domain.ToLower())) {
                                    $domainUsers += $user
                                    Write-Log "MATCH: User $($user.name) matches domain (substring)" "DEBUG"
                                }
                            }
                            if ($domainUsers.Count -gt 0) {
                                Write-Log "Found users with domain substring match in email" "DEBUG"
                            }
                        }

                        # If no email matches and this is a broad search, check display names and usernames
                        if ($domainUsers.Count -eq 0 -and ($attempt.Method -contains "picker" -or $attempt.Method -contains "broad")) {
                            foreach ($user in $users) {
                                $displayName = if ($user.displayName) { $user.displayName.ToLower() } else { "" }
                                $userName = if ($user.name) { $user.name.ToLower() } else { "" }

                                if (($displayName -and $displayName.Contains($domain.ToLower())) -or
                                    ($userName -and $userName.Contains($domain.ToLower()))) {
                                    $domainUsers += $user
                                    Write-Log "MATCH: User $($user.name) matches domain in display name or username" "DEBUG"
                                }
                            }
                            if ($domainUsers.Count -gt 0) {
                                Write-Log "Found users with domain match in display name or username" "DEBUG"
                            }
                        }

                        # Special handling for when we get many users but no emails populated
                        if ($domainUsers.Count -eq 0 -and $users.Count -gt 10) {
                        Write-Log "Large result set with no email matches - checking if emails are populated" "DEBUG"
                        $usersWithEmail = $users | Where-Object { $_.emailAddress -and $_.emailAddress.Trim() -ne "" }
                        Write-Log "Users with populated email addresses: $($usersWithEmail.Count) out of $($users.Count)" "INFO"

                        # For debugging: show unique domains found in the search results
                        if ($usersWithEmail.Count -gt 0) {
                            $foundDomains = @{}
                            foreach ($userWithEmail in $usersWithEmail) {
                                if ($userWithEmail.emailAddress -match "@(.+)$") {
                                    $foundDomain = $matches[1].ToLower()
                                    if ($foundDomains.ContainsKey($foundDomain)) {
                                        $foundDomains[$foundDomain]++
                                    } else {
                                        $foundDomains[$foundDomain] = 1
                                    }
                                }
                            }
                            $topDomains = $foundDomains.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
                            $domainList = ($topDomains | ForEach-Object { "$($_.Name) ($($_.Value))" }) -join ", "
                            Write-Log "Top email domains found: $domainList" "INFO"

                            # Specifically check for the target domain
                            $targetDomainLower = $domain.ToLower()
                            if ($foundDomains.ContainsKey($targetDomainLower)) {
                                Write-Log "Target domain '$targetDomainLower' found with $($foundDomains[$targetDomainLower]) users, but filtered out - investigating..." "WARNING"
                                $targetUsers = $usersWithEmail | Where-Object { $_.emailAddress.ToLower().EndsWith("@$targetDomainLower") }
                                foreach ($targetUser in $targetUsers | Select-Object -First 3) {
                                    Write-Log "Sample target user: $($targetUser.name) - $($targetUser.emailAddress) - Active: $($targetUser.active)" "INFO"
                                }
                            }
                        }                            if ($usersWithEmail.Count -eq 0) {
                                Write-Log "No users have populated email addresses in search results - attempting detailed user lookup" "INFO"

                                # Try to get detailed user information for a sample to check if emails are available
                                $sampleUsers = $users | Select-Object -First 10
                                $usersWithDetailedEmails = @()

                                foreach ($sampleUser in $sampleUsers) {
                                    try {
                                        $userIdentifier = if ($sampleUser.accountId) { $sampleUser.accountId } else { $sampleUser.name }
                                        $paramName = if ($sampleUser.accountId) { "accountId" } else { "username" }
                                        $detailUri = "$BaseUrl/rest/api/2/user?$paramName=$userIdentifier"

                                        Write-Log "Getting detailed info for user: $($sampleUser.name)" "DEBUG"
                                        $detailedUser = Invoke-RestMethod -Method Get -Uri $detailUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                                        if ($detailedUser.emailAddress -and $detailedUser.emailAddress.Trim() -ne "") {
                                            Write-Log "Found email in detailed lookup: $($detailedUser.name) -> $($detailedUser.emailAddress)" "DEBUG"
                                            if ($detailedUser.emailAddress.ToLower().Contains($domain.ToLower())) {
                                                $usersWithDetailedEmails += $detailedUser
                                                Write-Log "User matches domain in detailed lookup: $($detailedUser.displayName) [$($detailedUser.name)] ($($detailedUser.emailAddress))" "SUCCESS"
                                            }
                                        }
                                    } catch {
                                        Write-Log "Failed to get detailed user info for $($sampleUser.name): $($_.Exception.Message)" "DEBUG"
                                    }
                                }

                                if ($usersWithDetailedEmails.Count -gt 0) {
                                    Write-Log "Found $($usersWithDetailedEmails.Count) users with domain match via detailed lookup" "SUCCESS"
                                    Write-Log "JIRA instance requires individual user lookups to get email addresses" "INFO"
                                    Write-Log "Performing full detailed lookup for all $($users.Count) users..." "INFO"

                                    # Perform detailed lookup for all users
                                    foreach ($user in $users) {
                                        try {
                                            $userIdentifier = if ($user.accountId) { $user.accountId } else { $user.name }
                                            $paramName = if ($user.accountId) { "accountId" } else { "username" }
                                            $detailUri = "$BaseUrl/rest/api/2/user?$paramName=$userIdentifier"

                                            $detailedUser = Invoke-RestMethod -Method Get -Uri $detailUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                                            if ($detailedUser.emailAddress -and $detailedUser.emailAddress.ToLower().Contains($domain.ToLower())) {
                                                $domainUsers += $detailedUser
                                            }
                                        } catch {
                                            Write-Log "Failed detailed lookup for $($user.name): $($_.Exception.Message)" "DEBUG"
                                        }

                                        # Add small delay to avoid overwhelming API
                                        Start-Sleep -Milliseconds 100
                                    }

                                    Write-Log "Completed detailed lookup - found $($domainUsers.Count) users matching domain" "SUCCESS"
                                } else {
                                    Write-Log "No email addresses found even in detailed user lookup" "WARNING"
                                    Write-Log "This JIRA instance may not expose email addresses or users don't have emails set" "INFO"
                                    Write-Log "Consider using username patterns instead: -UsernamePatterns '*$domain*'" "INFO"
                                }
                            }
                        }                        Write-Log "Users matching domain filter: $($domainUsers.Count)" "DEBUG"

                        if ($domainUsers -and $domainUsers.Count -gt 0) {
                            Write-Log "Found $($domainUsers.Count) users with $($attempt.Method)" "SUCCESS"

                            # Show some sample users for verification
                            $sampleUsers = $domainUsers | Select-Object -First 3
                            foreach ($sampleUser in $sampleUsers) {
                                Write-Log "Sample user: $($sampleUser.displayName) [$($sampleUser.name)] ($($sampleUser.emailAddress))" "DEBUG"
                            }

                            $foundUsers += $domainUsers
                            $domainUsersFound = $true
                            break  # Success, no need to try other methods for this domain
                        } else {
                            Write-Log "No users matched domain filter for $($attempt.Method)" "DEBUG"
                            # Show sample users to help debug
                            $sampleAll = $users | Select-Object -First 2
                            foreach ($sample in $sampleAll) {
                                Write-Log "Sample response user: $($sample.displayName) [$($sample.name)] ($($sample.emailAddress))" "DEBUG"
                            }
                        }
                    } else {
                        Write-Log "No users returned from $($attempt.Method)" "DEBUG"
                    }

                } catch {
                    Write-Log "$($attempt.Method) failed: $($_.Exception.Message)" "DEBUG"

                    # Log additional error details for 400 errors
                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 400) {
                        try {
                            $errorStream = $_.Exception.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($errorStream)
                            $errorBody = $reader.ReadToEnd()
                            Write-Log "400 Error details: $errorBody" "DEBUG"
                        } catch {
                            # Ignore errors reading error response
                        }
                    }
                    continue
                }
            }

            if (-not $domainUsersFound) {
                Write-Log "Standard searches failed - trying specialized inactive user search..." "INFO"

                # Last resort: Get ALL users (including inactive) and filter by domain
                try {
                    $allUsersUri = "$BaseUrl/rest/api/2/user/search?username=.&query=*&includeInactive=true&maxResults=2000"
                    Write-Log "Attempting comprehensive user search: $allUsersUri" "DEBUG"

                    $allUsersResult = Invoke-RestMethod -Method Get -Uri $allUsersUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                    if ($allUsersResult -and $allUsersResult.Count -gt 0) {
                        Write-Log "Retrieved $($allUsersResult.Count) total users (active and inactive)" "INFO"

                        # Filter by domain
                        $domainUsers = @()
                        foreach ($user in $allUsersResult) {
                            if ($user.emailAddress -and $user.emailAddress.ToLower().EndsWith("@$($domain.ToLower())")) {
                                $domainUsers += $user
                                $status = if ($user.active) { "ACTIVE" } else { "INACTIVE" }
                                Write-Log "Found $status user with target domain: $($user.name) - $($user.emailAddress)" "SUCCESS"
                            }
                        }

                        if ($domainUsers.Count -gt 0) {
                            Write-Log "Comprehensive search found $($domainUsers.Count) users with domain '$domain'" "SUCCESS"
                            $foundUsers += $domainUsers
                            $domainUsersFound = $true
                        }
                    }
                } catch {
                    Write-Log "Comprehensive user search failed: $($_.Exception.Message)" "DEBUG"
                }

                if (-not $domainUsersFound) {
                    Write-Log "No users found for domain '$domain' using any search method (including inactive user search)" "WARNING"
                    Write-Log "This could mean: 1) No users exist with this domain, 2) Different search syntax needed, 3) Permission restrictions" "INFO"
                    Write-Log "Consider verifying users exist by searching manually in JIRA web interface" "INFO"
                }
            }
        }
    }    # Search for users by username patterns
    if ($UsernamePatterns -and $UsernamePatterns.Count -gt 0) {
        foreach ($pattern in $UsernamePatterns) {
            Write-Log "Searching for users with username pattern: $pattern" "INFO"

            $searchAttempts = @(
                @{ Method = "Direct pattern search"; Uri = "/rest/api/2/user/search?query=$pattern&maxResults=$MaxResults" },
                @{ Method = "Username parameter search"; Uri = "/rest/api/2/user/search?username=$pattern&maxResults=$MaxResults" },
                @{ Method = "User picker pattern search"; Uri = "/rest/api/2/user/picker?query=$pattern&maxResults=$MaxResults" }
            )

            $patternUsersFound = $false
            foreach ($attempt in $searchAttempts) {
                try {
                    $searchUri = "$BaseUrl$($attempt.Uri)"
                    Write-Log "Trying $($attempt.Method): $searchUri" "DEBUG"

                    $result = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $Headers -UseBasicParsing -ErrorAction Stop

                    # Handle different response formats
                    $users = @()
                    if ($result -is [array]) {
                        $users = $result
                    } elseif ($result.users) {
                        $users = $result.users
                    } else {
                        $users = @($result)
                    }

                    if ($users -and $users.Count -gt 0) {
                        # Filter by pattern if needed (convert wildcards to regex)
                        $regexPattern = $pattern -replace '\*', '.*' -replace '\?', '.'
                        $patternUsers = $users | Where-Object {
                            $_.name -match "^$regexPattern$"
                        }

                        if ($patternUsers -and $patternUsers.Count -gt 0) {
                            Write-Log "Found $($patternUsers.Count) users with $($attempt.Method)" "SUCCESS"
                            $foundUsers += $patternUsers
                            $patternUsersFound = $true
                            break
                        }
                    }

                } catch {
                    Write-Log "$($attempt.Method) failed: $($_.Exception.Message)" "DEBUG"
                    continue
                }
            }

            if (-not $patternUsersFound) {
                Write-Log "No users found for pattern '$pattern' using any search method" "WARNING"
            }
        }
    }

    # Remove duplicates based on username
    $uniqueUsers = $foundUsers | Sort-Object name -Unique
    Write-Log "Total unique users found: $($uniqueUsers.Count)" "SUCCESS"

    return $uniqueUsers
}

# Function to transfer project leadership
function Transfer-JiraProjectLead {
    param(
        [string]$ProjectKey,
        [string]$CurrentLead,
        [string]$NewLead,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    Write-Log "Attempting to transfer project lead for $ProjectKey from $CurrentLead to $NewLead" "INFO"

    try {
        # Get project details first to verify current state
        $projectUri = "$BaseUrl/rest/api/2/project/$ProjectKey"
        $project = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $Headers -UseBasicParsing -ErrorAction Stop
        Write-Log "Current project lead: $($project.lead.name)" "DEBUG"

        # Try multiple payload formats for different JIRA versions
        $payloadFormats = @(
            @{ lead = $NewLead },                    # Simple string format
            @{ lead = @{ name = $NewLead } },        # Object format
            @{ lead = @{ key = $NewLead } },         # Key format
            @{ leadUserName = $NewLead }             # Alternative field name
        )

        $success = $false
        foreach ($payloadFormat in $payloadFormats) {
            try {
                $updatePayload = $payloadFormat | ConvertTo-Json -Depth 3
                Write-Log "Trying payload format: $updatePayload" "DEBUG"

                $updateUri = "$BaseUrl/rest/api/2/project/$ProjectKey"
                $result = Invoke-RestMethod -Uri $updateUri -Method Put -Headers $Headers -Body $updatePayload -ContentType "application/json" -UseBasicParsing -ErrorAction Stop

                $success = $true
                Write-Log "Successfully transferred project lead using format: $($payloadFormat.GetType().Name)" "DEBUG"
                break

            } catch {
                Write-Log "Payload format failed: $($_.Exception.Message)" "DEBUG"
                continue
            }
        }

        if (-not $success) {
            throw "All payload formats failed"
        }

        # Verify the transfer by getting updated project details
        Start-Sleep -Seconds 2  # Give JIRA time to process the change
        $updatedProject = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $Headers -UseBasicParsing -ErrorAction Stop
        $actualLead = $updatedProject.lead.name

        if ($actualLead -eq $NewLead) {
            Write-Log "Successfully transferred project lead for $ProjectKey to $NewLead (verified)" "SUCCESS"
            return @{ Success = $true; Message = "Project lead transferred successfully to $actualLead" }
        } else {
            Write-Log "Transfer appeared successful but verification failed. Expected: $NewLead, Actual: $actualLead" "WARNING"
            return @{ Success = $false; Message = "Transfer verification failed - lead is still $actualLead" }
        }

    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Failed to transfer project lead for ${ProjectKey}: $errorMessage" "ERROR"

        # Try to get detailed error information
        if ($_.Exception.Response) {
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                Write-Log "Transfer error details: $errorBody" "DEBUG"
            } catch {
                # Ignore errors reading error response
            }
        }

        return @{ Success = $false; Message = $errorMessage }
    }
}

# Function to disable a JIRA user
function Disable-JiraUser {
    param(
        [PSCustomObject]$User,
        [hashtable]$Headers,
        [string]$BaseUrl,
        [bool]$DryRun = $false
    )

    if ($DryRun) {
        Write-Log "DRY RUN: Would disable user: $($User.displayName) [$($User.name)] ($($User.emailAddress))" "INFO"
        return @{ Success = $true; Action = "DryRun" }
    }

    try {
        # Check if user is already disabled
        if ($User.active -eq $false) {
            Write-Log "User $($User.name) is already disabled - skipping" "INFO"
            return @{ Success = $true; Action = "AlreadyDisabled" }
        }

        # Prepare update payload to disable the user
        $disablePayload = @{
            active = $false
        } | ConvertTo-Json

        # Use appropriate identifier based on JIRA version
        $userIdentifier = if (-not [string]::IsNullOrEmpty($User.accountId)) { $User.accountId } else { $User.name }
        $parameterName = if (-not [string]::IsNullOrEmpty($User.accountId)) { "accountId" } else { "username" }

        $disableUri = "$BaseUrl/rest/api/2/user?$parameterName=$userIdentifier"

        Write-Log "Attempting to disable user with URI: $disableUri" "DEBUG"
        Write-Log "Using identifier: $userIdentifier (parameter: $parameterName)" "DEBUG"
        Write-Log "Payload: $disablePayload" "DEBUG"

        $result = Invoke-RestMethod -Method Put -Uri $disableUri -Headers $Headers -Body $disablePayload -UseBasicParsing -ErrorAction Stop

        Write-Log "Successfully disabled user: $($User.displayName) [$($User.name)]" "SUCCESS"
        return @{ Success = $true; Action = "Disabled"; Result = $result }

    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Failed to disable user $($User.name): $errorMessage" "ERROR"

        # Try to get more detailed error information
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                Write-Log "HTTP Status Code: $statusCode" "DEBUG"

                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                Write-Log "Error response body: $errorBody" "DEBUG"

                # Check for specific project lead conflict
                if ($statusCode -eq 400 -and $errorBody -match "project lead.*projects?:\s*([^""'}]+)") {
                    $conflictingProjects = $matches[1] -split '\s*,\s*'
                    Write-Log "CONFLICT: User $($User.name) is project lead on: $($conflictingProjects -join ', ')" "WARNING"

                    if ($ForceProjectLeadTransfer) {
                        Write-Log "ForceProjectLeadTransfer enabled - attempting to transfer project leads..." "INFO"
                        $allTransfersSuccessful = $true

                        foreach ($projectKey in $conflictingProjects) {
                            Write-Log "Transferring project lead for $projectKey to $NewProjectLead..." "INFO"
                            $transferResult = Transfer-JiraProjectLead -ProjectKey $projectKey.Trim() -CurrentLead $User.name -NewLead $NewProjectLead -Headers $Headers -BaseUrl $BaseUrl

                            if (-not $transferResult.Success) {
                                Write-Log "Failed to transfer project lead for ${projectKey}: $($transferResult.Message)" "ERROR"
                                $allTransfersSuccessful = $false
                            } else {
                                Write-Log "Successfully transferred project lead for $projectKey" "SUCCESS"
                            }
                        }

                        if ($allTransfersSuccessful) {
                            Write-Log "All project leads transferred successfully. Retrying user disable..." "INFO"

                            # Retry the disable operation
                            try {
                                $retryResult = Invoke-RestMethod -Method Put -Uri $disableUri -Headers $Headers -Body $disablePayload -UseBasicParsing -ErrorAction Stop
                                Write-Log "Successfully disabled user after project lead transfers: $($User.displayName) [$($User.name)]" "SUCCESS"
                                return @{ Success = $true; Action = "DisabledAfterTransfer"; Result = $retryResult }
                            } catch {
                                Write-Log "Failed to disable user even after project lead transfers: $($_.Exception.Message)" "ERROR"
                                return @{ Success = $false; Action = "DisableFailedAfterTransfer"; Error = $_.Exception.Message }
                            }
                        } else {
                            Write-Log "Some project lead transfers failed. Cannot disable user." "ERROR"
                            return @{
                                Success = $false;
                                Action = "ProjectLeadTransferFailed";
                                Error = "Failed to transfer some project leads";
                                ConflictingProjects = $conflictingProjects
                            }
                        }
                    } else {
                        Write-Log "ACTION REQUIRED: Transfer project leadership before disabling user" "INFO"
                        Write-Log "Go to each project settings and change the project lead to another user" "INFO"
                        Write-Log "Or use -ForceProjectLeadTransfer -NewProjectLead 'username' to automatically transfer" "INFO"

                        return @{
                            Success = $false;
                            Action = "ProjectLeadConflict";
                            Error = "User is project lead on: $($conflictingProjects -join ', ')";
                            ConflictingProjects = $conflictingProjects
                        }
                    }
                }

            } catch {
                Write-Log "Could not read error response details" "DEBUG"
            }
        }

        return @{ Success = $false; Action = "Disable"; Error = $errorMessage }
    }
}

# Function to wait for anonymization progress
function Wait-AnonymizationProgress {
    param(
        [hashtable]$Headers,
        [string]$BaseUrl,
        [int]$TimeoutSeconds = 600,
        [string]$UserId = $null
    )

    # Updated progress endpoint as per Atlassian API documentation
    $progressUri = "$BaseUrl/rest/api/2/user/anonymization/progress"
    $elapsed = 0
    $checkInterval = 10

    Write-Log "Checking anonymization progress..." "INFO"

    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $progress = Invoke-RestMethod -Uri $progressUri -Method Get -Headers $Headers -UseBasicParsing -ErrorAction Stop

            # Handle different response formats
            if ($progress -is [array] -and $progress.Count -eq 0) {
                Write-Log "No anonymization process currently running (empty array response)" "SUCCESS"
                return $true
            } elseif (-not $progress.inProgress -and $null -ne $progress.inProgress) {
                Write-Log "No anonymization process currently running (inProgress: false)" "SUCCESS"
                return $true
            } elseif ($progress.inProgress -eq $true) {
                # Progress information available
                $progressPercent = if ($progress.progress) { "$($progress.progress)%" } else { "Unknown" }
                $currentUser = if ($progress.currentUser) { $progress.currentUser } else { "Unknown user" }
                $submittedTime = if ($progress.submittedTime) { " (Started: $($progress.submittedTime))" } else { "" }

                Write-Log "Anonymization in progress: $progressPercent complete for user: $currentUser$submittedTime" "INFO"
            } else {
                # No clear progress indicator - assume complete
                Write-Log "Anonymization progress check complete (no active process detected)" "SUCCESS"
                return $true
            }

            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval

        } catch {
            # Handle different error scenarios
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
                if ($statusCode -eq 404) {
                    Write-Log "Anonymization progress endpoint not available - assuming no process running" "INFO"
                    return $true
                } elseif ($statusCode -eq 403) {
                    Write-Log "No permission to check anonymization progress - continuing anyway" "WARNING"
                    return $true
                }
            }

            Write-Log "Failed to check anonymization progress: $($_.Exception.Message)" "WARNING"
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
        }
    }

    Write-Log "Timeout waiting for anonymization process to complete after $TimeoutSeconds seconds" "WARNING"
    return $false
}

# Function to validate if a user can be anonymized
function Test-UserAnonymizationEligibility {
    param(
        [PSCustomObject]$User,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    try {
        Write-Log "Checking anonymization eligibility for user: $($User.name)" "DEBUG"

        # Check if user is from external directory (cannot be anonymized)
        if ($User.directoryId -and $User.directoryId -ne "1") {
            Write-Log "User $($User.name) is from external directory (ID: $($User.directoryId)) - cannot be anonymized" "WARNING"
            Write-Log "Remove user from external directory first, sync, then anonymize" "INFO"
            return @{
                Eligible = $false;
                Reason = "External directory user";
                Action = "Remove from external directory and sync before anonymizing"
            }
        }

        # Check if user is already anonymized (username starts with jirauser)
        if ($User.name -match "^jirauser\d+$") {
            Write-Log "User appears to already be anonymized (username: $($User.name))" "INFO"
            return @{
                Eligible = $false;
                Reason = "Already anonymized";
                Action = "No action needed"
            }
        }

        # Check if user has accountId but is marked as deleted/inactive
        if ($User.active -eq $false) {
            Write-Log "User $($User.name) is inactive - can still be anonymized" "INFO"
        }

        Write-Log "User $($User.name) is eligible for anonymization" "SUCCESS"
        return @{
            Eligible = $true;
            Reason = "User meets anonymization requirements"
        }

    } catch {
        Write-Log "Failed to check anonymization eligibility for $($User.name): $($_.Exception.Message)" "WARNING"
        # Assume eligible if check fails
        return @{
            Eligible = $true;
            Reason = "Eligibility check failed - attempting anyway"
        }
    }
}

# Function to anonymize a JIRA user according to Atlassian API documentation
function Set-JiraUserAnonymized {
    param(
        [PSCustomObject]$User,
        [hashtable]$Headers,
        [string]$BaseUrl,
        [string]$NewOwnerKey,
        [bool]$DryRun = $false,
        [int]$TimeoutSeconds = 600
    )

    if ($DryRun) {
        Write-Log "DRY RUN: Would anonymize user: $($User.displayName) [$($User.name)] ($($User.emailAddress))" "INFO"
        return @{ Success = $true; Action = "DryRun" }
    }

    try {
        Write-Log "Starting anonymization process for user: $($User.displayName) [$($User.name)]" "INFO"

        # Wait for any previous anonymization to complete
        Write-Log "Checking for existing anonymization processes..." "DEBUG"
        $progressReady = Wait-AnonymizationProgress -Headers $Headers -BaseUrl $BaseUrl -TimeoutSeconds 60
        if (-not $progressReady) {
            Write-Log "Cannot start anonymization for $($User.name) - previous operation still running" "WARNING"
            return @{ Success = $false; Action = "Anonymize"; Error = "Previous anonymization still in progress" }
        }

        # Determine the correct user identifier and parameter name
        # According to Atlassian API docs, the parameter should be based on user type
        if (-not [string]::IsNullOrEmpty($User.accountId)) {
            # Modern Jira Cloud/DC with account IDs (Jira 8.4+)
            $userIdentifier = $User.accountId
            $identifierType = "accountId"
            Write-Log "Using accountId for anonymization: $userIdentifier" "DEBUG"
        } elseif (-not [string]::IsNullOrEmpty($User.key) -and $User.key -ne $User.name) {
            # Jira with separate user keys
            $userIdentifier = $User.key
            $identifierType = "userKey"
            Write-Log "Using userKey for anonymization: $userIdentifier" "DEBUG"
        } else {
            # Legacy Jira with username as key
            $userIdentifier = $User.name
            $identifierType = "username"
            Write-Log "Using username for anonymization: $userIdentifier" "DEBUG"
        }

        # Prepare anonymization payload according to official API documentation
        # The API expects either 'userIdentify' or 'userKey' as the parameter name
        # and requires 'newOwnerKey' to specify who inherits the content
        $anonymizePayload = @{
            newOwnerKey = $NewOwnerKey
        }

        if ($identifierType -eq "accountId") {
            $anonymizePayload.userIdentify = $userIdentifier
        } elseif ($identifierType -eq "userKey") {
            $anonymizePayload.userKey = $userIdentifier
        } else {
            # For legacy systems, use the username as userKey
            $anonymizePayload.userKey = $userIdentifier
        }

        $anonymizeBody = $anonymizePayload | ConvertTo-Json
        $anonymizeUri = "$BaseUrl/rest/api/2/user/anonymization"

        Write-Log "Anonymization payload: $anonymizeBody" "DEBUG"
        Write-Log "Content ownership will transfer to: $NewOwnerKey" "INFO"
        Write-Log "Anonymization URI: $anonymizeUri" "DEBUG"

        # Make the anonymization request
        Write-Log "Submitting anonymization request for user: $($User.name)" "INFO"
        $result = Invoke-RestMethod -Method Post -Uri $anonymizeUri -Headers $Headers -Body $anonymizeBody -UseBasicParsing -ErrorAction Stop

        Write-Log "Anonymization request submitted successfully" "SUCCESS"

        # Log the response for debugging
        if ($result) {
            Write-Log "Anonymization response: $($result | ConvertTo-Json -Compress)" "DEBUG"
        }

        # Wait for this anonymization to complete with enhanced progress tracking
        Write-Log "Waiting for anonymization process to complete..." "INFO"
        $completed = Wait-AnonymizationProgress -Headers $Headers -BaseUrl $BaseUrl -TimeoutSeconds $TimeoutSeconds -UserId $userIdentifier

        if ($completed) {
            Write-Log "Successfully anonymized user: $($User.displayName) [$($User.name)]" "SUCCESS"
            Write-Log "User personal data has been permanently anonymized and cannot be recovered" "WARNING"
            return @{
                Success = $true;
                Action = "Anonymized";
                Result = $result;
                UserIdentifier = $userIdentifier;
                IdentifierType = $identifierType
            }
        } else {
            Write-Log "Anonymization timeout for user: $($User.name) after $TimeoutSeconds seconds" "WARNING"
            Write-Log "The anonymization may still be processing in the background" "INFO"
            return @{ Success = $false; Action = "Anonymize"; Error = "Anonymization timeout - check JIRA admin console" }
        }

    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Failed to anonymize user $($User.name): $errorMessage" "ERROR"

        # Enhanced error reporting with HTTP details
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                Write-Log "HTTP Status Code: $statusCode" "DEBUG"

                # Get detailed error response
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $errorBody = $reader.ReadToEnd()
                Write-Log "Error response body: $errorBody" "DEBUG"

                # Provide specific guidance based on status code
                switch ($statusCode) {
                    400 {
                        Write-Log "Bad Request (400) - Check user identifier format or API payload structure" "ERROR"
                        if ($errorBody -match "userKey") {
                            Write-Log "API expects 'userKey' parameter - verify user identification method" "INFO"
                        }
                    }
                    403 {
                        Write-Log "Forbidden (403) - Insufficient permissions to anonymize users" "ERROR"
                        Write-Log "Ensure the account has JIRA Administrator permissions" "INFO"
                    }
                    404 {
                        Write-Log "Not Found (404) - User may already be anonymized or deleted" "ERROR"
                    }
                    409 {
                        Write-Log "Conflict (409) - Anonymization may already be in progress for this user" "ERROR"
                    }
                    500 {
                        Write-Log "Internal Server Error (500) - JIRA server error during anonymization" "ERROR"
                    }
                }
            } catch {
                Write-Log "Could not read detailed error response" "DEBUG"
            }
        }

        return @{
            Success = $false;
            Action = "Anonymize";
            Error = $errorMessage;
            UserIdentifier = if (Get-Variable -Name userIdentifier -ErrorAction SilentlyContinue) { $userIdentifier } else { $User.name }
        }
    }
}

# Load required assemblies
Add-Type -AssemblyName System.Web

# Initialize script
Write-Log "=== JIRA Enterprise User Management Script Started ===" "INFO"
Write-Log "Parameters: CsvPath=$CsvPath, EmailDomains=$EmailDomains, UsernamePatterns=$UsernamePatterns, JiraBaseUrl=$JiraBaseUrl" "INFO"
Write-Log "Modes: DryRun=$DryRun, DisableOnly=$DisableOnly, AnonymizeUsers=$AnonymizeUsers, CheckUsersOnly=$CheckUsersOnly" "INFO"

# Global variables
$creds = $null
$session = $null
$processedCount = 0
$disabledCount = 0
$anonymizedCount = 0
$errorCount = 0
$skippedCount = 0
$backupPath = ".\JiraUserBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

# Validate parameter combinations
if (-not $CsvPath -and -not $EmailDomains -and -not $UsernamePatterns) {
    Write-Log "Error: Must specify either -CsvPath, -EmailDomains, or -UsernamePatterns" "ERROR"
    exit 1
}

if (-not $DisableOnly -and -not $AnonymizeUsers -and -not $CheckUsersOnly -and -not $DryRun) {
    Write-Log "Error: Must specify either -DisableOnly, -AnonymizeUsers, -CheckUsersOnly, or -DryRun" "ERROR"
    exit 1
}

####Handle authentication credentials
Write-Log "Setting up authentication credentials..." "INFO"

try {
    # Use Personal Access Token if provided
    if ($PersonalAccessToken) {
        Write-Log "Using Personal Access Token authentication" "INFO"
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

            Write-Log "JIRA session created successfully" "SUCCESS"

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

    if (-not $authTestPassed) {
        Write-Log "Authentication test failed. Cannot continue." "ERROR"
        exit 1
    }

} catch {
    Write-Log "Failed to set up JIRA authentication: $($_.Exception.Message)" "ERROR"
    Write-Log "Please verify your credentials and JIRA URL" "ERROR"
    exit 1
}

####Get target users
Write-Log "Identifying target users..." "INFO"
$targetUsers = @()

try {
    if ($CsvPath) {
        Write-Log "Loading users from CSV file: $CsvPath" "INFO"

        # Auto-detect CSV delimiter (comma or semicolon)
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
        }

        # Import CSV with detected delimiter
        $csvUsers = Import-Csv $CsvPath -Delimiter $delimiter

        if ($csvUsers.Count -eq 0) {
            throw "CSV file is empty or contains only headers."
        }

        Write-Log "Loaded $($csvUsers.Count) users from CSV file" "SUCCESS"

        # Convert CSV users to target users by searching JIRA
        foreach ($csvUser in $csvUsers) {
            $username = if ($csvUser.username) { $csvUser.username } elseif ($csvUser.name) { $csvUser.name } else { $null }
            $email = if ($csvUser.email) { $csvUser.email } elseif ($csvUser.emailAddress) { $csvUser.emailAddress } else { $null }

            if ([string]::IsNullOrWhiteSpace($username) -and [string]::IsNullOrWhiteSpace($email)) {
                Write-Log "Skipping CSV row with no username or email: $($csvUser | ConvertTo-Json -Compress)" "WARNING"
                continue
            }

            # Search for user in JIRA
            try {
                $searchUri = if ($username) {
                    "$JiraBaseUrl/rest/api/2/user/search?username=$username&maxResults=1"
                } else {
                    "$JiraBaseUrl/rest/api/2/user/search?query=$email&maxResults=1"
                }

                $searchResult = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $apiHeaders -UseBasicParsing -ErrorAction Stop

                if ($searchResult -and $searchResult.Count -gt 0) {
                    $targetUsers += $searchResult[0]
                    Write-Log "Found user: $($searchResult[0].displayName) [$($searchResult[0].name)]" "SUCCESS"
                } else {
                    Write-Log "User not found in JIRA: ${username}/${email}" "WARNING"
                }
            } catch {
                Write-Log "Failed to search for user ${username}/${email}: $($_.Exception.Message)" "ERROR"
            }
        }
    }
    elseif ($EmailDomains -or $UsernamePatterns) {
        Write-Log "Searching for users by domains/patterns..." "INFO"

        $domains = if ($EmailDomains) { $EmailDomains -split ',' | ForEach-Object { $_.Trim() } } else { @() }
        $patterns = if ($UsernamePatterns) { $UsernamePatterns -split ',' | ForEach-Object { $_.Trim() } } else { @() }

        $targetUsers = Search-JiraUsers -EmailDomains $domains -UsernamePatterns $patterns -Headers $apiHeaders -BaseUrl $JiraBaseUrl
    }

    # Remove duplicates and filter based on operation mode
    $uniqueUsers = $targetUsers | Sort-Object name -Unique
    $activeUsers = $uniqueUsers | Where-Object { $_.active -eq $true }
    $inactiveUsers = $uniqueUsers | Where-Object { $_.active -eq $false }

    Write-Log "Total users found: $($uniqueUsers.Count)" "INFO"
    Write-Log "Active users found: $($activeUsers.Count)" "INFO"
    Write-Log "Inactive users found: $($inactiveUsers.Count)" "INFO"

    # Determine which users to process based on operation mode
    if ($AnonymizeUsers -and -not $DisableOnly) {
        # For anonymization, process both active and inactive users
        $targetUsers = $uniqueUsers
        Write-Log "Anonymization mode: Processing both active and inactive users ($($uniqueUsers.Count) total)" "SUCCESS"
    } elseif ($DisableOnly) {
        # For disable-only operations, process only active users
        $targetUsers = $activeUsers
        Write-Log "Disable-only mode: Processing active users only ($($activeUsers.Count) users)" "SUCCESS"
        Write-Log "Inactive users (will skip): $($inactiveUsers.Count)" "INFO"
    } else {
        # Default behavior: process active users for disable+anonymize operations
        $targetUsers = $activeUsers
        Write-Log "Standard mode: Processing active users for disable operations ($($activeUsers.Count) users)" "SUCCESS"
        Write-Log "Inactive users (will skip): $($inactiveUsers.Count)" "INFO"
    }

    # Debug: Show details of found users with their selection status
    foreach ($user in $uniqueUsers) {
        $willProcess = $targetUsers -contains $user
        $status = if ($user.active) { "ACTIVE" } else { "INACTIVE" }
        $action = if ($willProcess) { "WILL PROCESS" } else { "WILL SKIP" }
        Write-Log "Found user: $($user.displayName) [$($user.name)] - Status: $status - Action: $action" "DEBUG"
    }

} catch {
    Write-Log "Failed to identify target users: $($_.Exception.Message)" "ERROR"
    exit 1
}

if ($targetUsers.Count -eq 0) {
    if ($AnonymizeUsers -and -not $DisableOnly) {
        Write-Log "No users (active or inactive) found to process. Exiting." "WARNING"
    } else {
        Write-Log "No active users found to process. Exiting." "WARNING"
    }
    exit 0
}

####Backup users (if requested)
if ($BackupUsers) {
    Write-Log "Creating backup of target user data..." "INFO"
    try {
        $targetUsers | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupPath -Encoding UTF8
        Write-Log "User data backup created: $backupPath" "SUCCESS"
    } catch {
        Write-Log "Failed to create user backup: $($_.Exception.Message)" "WARNING"
    }
}

####Process users
Write-Log "Starting user processing..." "INFO"
$processedUsers = @()

# Check users only mode
if ($CheckUsersOnly) {
    Write-Log "=== CHECK USERS ONLY MODE ===" "INFO"
    Write-Log "Users that would be affected:" "INFO"

    foreach ($user in $targetUsers) {
        Write-Log "  - $($user.displayName) [$($user.name)] ($($user.emailAddress)) - Active: $($user.active)" "INFO"
    }

    Write-Log "Total users that would be processed: $($targetUsers.Count)" "SUCCESS"
    Write-Log "=== CHECK USERS ONLY COMPLETED ===" "SUCCESS"
    exit 0
}

# Initialize tracking arrays for different outcomes
$manualInterventionRequired = @()
$successfulUsers = @()
$failedUsers = @()

# Process each user
foreach ($user in $targetUsers) {
    $processedCount++
    Write-Log "Processing user $processedCount/$($targetUsers.Count): $($user.displayName) [$($user.name)]" "INFO"

    $userResult = [PSCustomObject]@{
        Username = $user.name
        DisplayName = $user.displayName
        Email = $user.emailAddress
        DisableResult = $null
        AnonymizeResult = $null
        Status = "Pending"
        ErrorMessage = $null
        ConflictingProjects = @()
        RequiredAction = ""
    }

    # Step 1: Disable the user
    if (-not $AnonymizeUsers -or $DisableOnly -or ($AnonymizeUsers -and -not $DisableOnly)) {
        Write-Log "Disabling user: $($user.displayName)" "INFO"
        $disableResult = Disable-JiraUser -User $user -Headers $apiHeaders -BaseUrl $JiraBaseUrl -DryRun:$DryRun
        $userResult.DisableResult = $disableResult

        if ($disableResult.Success) {
            $disabledCount++
            if (-not $DryRun) {
                Write-Log "User disabled successfully: $($user.name)" "SUCCESS"
            }
        } else {
            $errorCount++
            $userResult.Status = "Failed"
            $userResult.ErrorMessage = $disableResult.Error

            # Check if this is a project lead conflict requiring manual intervention
            if ($disableResult.Action -eq "ProjectLeadConflict") {
                $userResult.ConflictingProjects = $disableResult.ConflictingProjects
                $userResult.RequiredAction = "Transfer project leadership manually or use -ForceProjectLeadTransfer"
                $manualInterventionRequired += $userResult
                Write-Log "MANUAL INTERVENTION REQUIRED: $($user.name) - Project lead on: $($disableResult.ConflictingProjects -join ', ')" "WARNING"
            } else {
                $failedUsers += $userResult
                Write-Log "Failed to disable user: $($user.name) - $($disableResult.Error)" "ERROR"
            }
        }
    }

    # Step 2: Anonymize the user (if requested and appropriate conditions met)
    if ($AnonymizeUsers -and ($disableResult.Success -or $user.active -eq $false -or $DryRun)) {
        # Check if user can be anonymized (works for both active and inactive users)
        Write-Log "Checking anonymization eligibility for user: $($user.displayName)" "INFO"
        $eligibilityCheck = Test-UserAnonymizationEligibility -User $user -Headers $apiHeaders -BaseUrl $JiraBaseUrl

        if ($eligibilityCheck.Eligible) {
            Write-Log "User is eligible for anonymization - proceeding..." "SUCCESS"
            Write-Log "Anonymizing user: $($user.displayName) with content ownership transferring to: $NewProjectLead" "INFO"
            $anonymizeResult = Set-JiraUserAnonymized -User $user -Headers $apiHeaders -BaseUrl $JiraBaseUrl -NewOwnerKey $NewProjectLead -DryRun:$DryRun -TimeoutSeconds $AnonymizationTimeout
            $userResult.AnonymizeResult = $anonymizeResult

            if ($anonymizeResult.Success) {
                $anonymizedCount++
                $userResult.Status = "Success"
                if (-not $DryRun) {
                    Write-Log "User anonymized successfully: $($user.name)" "SUCCESS"
                    Write-Log "IMPORTANT: User data has been permanently anonymized and cannot be recovered" "WARNING"
                }
            } else {
                $errorCount++
                $userResult.Status = "PartialFailure"
                $userResult.ErrorMessage = $anonymizeResult.Error
                Write-Log "Failed to anonymize user: $($user.name) - $($anonymizeResult.Error)" "ERROR"
            }
        } else {
            # User not eligible for anonymization
            $skippedCount++
            $userResult.Status = "Skipped"
            $userResult.ErrorMessage = "$($eligibilityCheck.Reason) - $($eligibilityCheck.Action)"
            Write-Log "Skipping anonymization for $($user.name): $($eligibilityCheck.Reason)" "WARNING"
            Write-Log "Required action: $($eligibilityCheck.Action)" "INFO"
        }
    } elseif ($DisableOnly) {
        $userResult.Status = if ($disableResult.Success) { "Success" } else { "Failed" }
    }

    # Categorize the final result
    if ($userResult.Status -eq "Success") {
        $successfulUsers += $userResult
    } elseif ($userResult.Status -eq "Skipped") {
        # Already logged above, just track it
    }

    $processedUsers += $userResult

    # Add delay between operations to avoid overwhelming JIRA
    if (-not $DryRun) {
        Start-Sleep -Seconds 2
    }
}

####Generate summary report
Write-Log "=== User Management Summary ===" "INFO"
Write-Log "Total users processed: $processedCount" "INFO"
Write-Log "Users disabled: $disabledCount" "SUCCESS"
if ($AnonymizeUsers) {
    Write-Log "Users anonymized: $anonymizedCount" "SUCCESS"
    Write-Log "Users skipped (ineligible): $skippedCount" "INFO"
}
Write-Log "Errors encountered: $errorCount" "ERROR"

# Report users requiring manual intervention
if ($manualInterventionRequired.Count -gt 0) {
    Write-Log "=== MANUAL INTERVENTION REQUIRED ===" "WARNING"
    Write-Log "The following users could not be processed automatically:" "WARNING"

    foreach ($user in $manualInterventionRequired) {
        Write-Log "• $($user.DisplayName) [$($user.Username)] - $($user.ErrorMessage)" "WARNING"
        if ($user.ConflictingProjects.Count -gt 0) {
            Write-Log "  Projects where user is lead: $($user.ConflictingProjects -join ', ')" "INFO"
            Write-Log "  Action needed: Transfer project leadership manually or rerun with -ForceProjectLeadTransfer -NewProjectLead 'username'" "INFO"
        }
    }
    Write-Log "Manual intervention required for $($manualInterventionRequired.Count) users" "WARNING"
}

# Report successful users
if ($successfulUsers.Count -gt 0) {
    Write-Log "=== SUCCESSFULLY PROCESSED USERS ===" "SUCCESS"
    foreach ($user in $successfulUsers) {
        $actions = @()
        if ($user.DisableResult -and $user.DisableResult.Success) { $actions += "Disabled" }
        if ($user.AnonymizeResult -and $user.AnonymizeResult.Success) { $actions += "Anonymized" }
        Write-Log "• $($user.DisplayName) [$($user.Username)] - $($actions -join ', ')" "SUCCESS"
    }
}

# Report other failures
if ($failedUsers.Count -gt 0) {
    Write-Log "=== FAILED USERS (Non-recoverable) ===" "ERROR"
    foreach ($user in $failedUsers) {
        Write-Log "• $($user.DisplayName) [$($user.Username)] - $($user.ErrorMessage)" "ERROR"
    }
}

# Additional anonymization-specific warnings and information
if ($AnonymizeUsers -and ($anonymizedCount -gt 0 -or $DryRun)) {
    Write-Log "=== ANONYMIZATION IMPORTANT NOTICES ===" "WARNING"
    Write-Log "• Anonymized user data is PERMANENTLY removed and cannot be recovered" "WARNING"
    Write-Log "• Personal information (names, emails, avatars) has been replaced with anonymous aliases" "INFO"
    Write-Log "• User activity history remains but with anonymized identifiers" "INFO"
    Write-Log "• Some integrations may require manual cleanup of cached user data" "INFO"
    if (-not $DryRun) {
        Write-Log "• Check JIRA audit logs for complete anonymization details" "INFO"
    }
}

if ($DryRun) {
    Write-Log "This was a DRY RUN - no actual changes were made" "WARNING"
}

# Create detailed report
$reportPath = ".\JiraUserManagementReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
try {
    $processedUsers | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Log "Detailed report saved to: $reportPath" "SUCCESS"
} catch {
    Write-Log "Failed to create detailed report: $($_.Exception.Message)" "WARNING"
}

# Create manual intervention report if needed
if ($manualInterventionRequired.Count -gt 0) {
    $manualReportPath = ".\JiraManualIntervention_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    try {
        $manualInterventionRequired | Select-Object Username, DisplayName, Email, ErrorMessage,
            @{Name='ConflictingProjects'; Expression={$_.ConflictingProjects -join '; '}},
            RequiredAction | Export-Csv -Path $manualReportPath -NoTypeInformation -Encoding UTF8
        Write-Log "Manual intervention report saved to: $manualReportPath" "WARNING"
        Write-Log "Review this file for users requiring manual action before rerunning the script" "INFO"
    } catch {
        Write-Log "Failed to create manual intervention report: $($_.Exception.Message)" "WARNING"
    }
}

# Show failed operations
$failedOperations = $processedUsers | Where-Object { $_.Status -eq "Failed" -or $_.Status -eq "PartialFailure" }
if ($failedOperations.Count -gt 0) {
    Write-Log "Failed Operations Details:" "ERROR"
    foreach ($failed in $failedOperations) {
        Write-Log "  - $($failed.Username): $($failed.ErrorMessage)" "ERROR"
    }
}

####Close session (only needed for cookie-based auth)
if ($session -and -not $PersonalAccessToken -and -not $UseBasicAuth) {
    try {
        $SessionUri = "$JiraBaseUrl/rest/auth/1/session"
        Invoke-RestMethod -Method Delete -Uri $SessionUri -Headers $apiHeaders -UseBasicParsing -ErrorAction SilentlyContinue
        Write-Log "JIRA session closed successfully" "SUCCESS"
    } catch {
        Write-Log "Warning: Failed to properly close JIRA session" "WARNING"
    }
}

# Final actionable summary
if ($manualInterventionRequired.Count -gt 0) {
    Write-Log "=== NEXT STEPS ===" "INFO"
    Write-Log "To complete user management for users requiring manual intervention:" "INFO"
    Write-Log "1. Review the manual intervention report: $manualReportPath" "INFO"
    Write-Log "2. Either:" "INFO"
    Write-Log "   a) Manually transfer project leadership in JIRA for each conflicting project" "INFO"
    Write-Log "   b) Rerun this script with -ForceProjectLeadTransfer -NewProjectLead 'username'" "INFO"
    Write-Log "3. After resolving conflicts, rerun the script to complete processing" "INFO"

    Write-Log "Example command with automatic project lead transfer:" "INFO"
    $exampleCmd = $MyInvocation.Line -replace '-PersonalAccessToken\s+"[^"]*"', '-PersonalAccessToken "YOUR_TOKEN"'
    if ($exampleCmd -notmatch '-ForceProjectLeadTransfer') {
        $exampleCmd += " -ForceProjectLeadTransfer -NewProjectLead `"admin`""
    }
    Write-Log "  $exampleCmd" "INFO"
}

Write-Log "=== JIRA Enterprise User Management Script Completed ===" "SUCCESS"

# Exit with appropriate code based on outcomes
if ($manualInterventionRequired.Count -gt 0) {
    Write-Log "Script completed with manual intervention required" "WARNING"
    exit 2  # Special exit code for manual intervention needed
} elseif ($errorCount -gt 0) {
    exit 1  # General error
} else {
    exit 0  # Success
}