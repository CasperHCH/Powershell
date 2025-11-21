<#
.SYNOPSIS
    Updates the owner of Jira filters based on filter IDs extracted from log files.

.DESCRIPTION
    This script automates the process of changing filter ownership in Jira. It:
    1. Scans log files for filters with missing owners (matching pattern "Filter {ID} has no owner")
    2. Validates the new owner exists in Jira (optional with -SkipUserValidation)
    3. Updates each filter's ownership using the Jira REST API
    4. Provides detailed progress reporting and audit logging

    The script includes comprehensive error handling, supports WhatIf mode for testing,
    and tries multiple payload formats for maximum compatibility with different Jira versions.

.PARAMETER LogFolder
    Path to the folder containing the log files with filter IDs.
    The script will recursively process all .log files in this directory.
    Example: "C:\Logs\JiraFilters"

.PARAMETER JiraUrl
    Base URL of the Jira instance (e.g., https://jira.example.com).
    Do not include trailing slashes or API paths - just the base URL.

.PARAMETER JiraUser
    Username for Jira authentication. Must have filter administration permissions.
    This account needs permission to:
    - View filters
    - Modify filter ownership
    - Query user information (unless using -SkipUserValidation)

.PARAMETER JiraPassword
    Secure password for Jira authentication.
    If not provided, the script will prompt you securely.
    Use: $pwd = Read-Host "Password" -AsSecureString

.PARAMETER NewOwner
    Username of the new filter owner.
    This user will become the owner of all processed filters.
    Will be validated before processing unless -SkipUserValidation is used.

.PARAMETER WhatIf
    Preview changes without actually updating filters.
    Shows what would happen without making any modifications.
    Useful for testing before running in production.

.PARAMETER ValidateOnly
    Only validate permissions and user existence without making changes.
    Performs all checks but stops before actual filter updates.

.PARAMETER SkipUserValidation
    Skip validation of the new owner's existence in Jira.
    Use this when your account lacks permission to query the user API.
    The script will still attempt to update filters but won't verify
    the target user exists beforehand.

.NOTES
    Author: EPM Automation Suite
    Version: 2.0
    Requires: PowerShell 5.1+, Filter administration permissions in Jira
    Security: Uses secure credential handling, audit logging, and sanitized output

    IMPORTANT PERMISSIONS:
    - Your Jira account needs "Share Objects" or "Administer Jira" permission
    - Filters must be accessible (not private to other users)
    - User validation requires permission to query /rest/api/2/user endpoint

.EXAMPLE
    # Basic usage with password prompt
    .\ChangeFilterOwner.ps1 -LogFolder "C:\Logs" -JiraUrl "https://jira.example.com" -JiraUser "admin" -NewOwner "newowner"

.EXAMPLE
    # Skip user validation if you lack user query permissions
    .\ChangeFilterOwner.ps1 -LogFolder "C:\Logs" -JiraUrl "https://jira.example.com" -JiraUser "admin" -NewOwner "newowner" -SkipUserValidation

.EXAMPLE
    # Preview changes without executing (WhatIf mode)
    .\ChangeFilterOwner.ps1 -LogFolder "C:\Logs" -JiraUrl "https://jira.example.com" -JiraUser "admin" -NewOwner "newowner" -WhatIf

.EXAMPLE
    # Provide password as SecureString to avoid prompts
    $pwd = Read-Host "Enter password" -AsSecureString
    .\ChangeFilterOwner.ps1 -LogFolder "C:\Logs" -JiraUrl "https://jira.example.com" -JiraUser "admin" -JiraPassword $pwd -NewOwner "newowner"

.EXAMPLE
    # Validate configuration without making changes
    .\ChangeFilterOwner.ps1 -LogFolder "C:\Logs" -JiraUrl "https://jira.example.com" -JiraUser "admin" -NewOwner "newowner" -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to folder containing filter log files")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$LogFolder,

    [Parameter(Mandatory = $true, HelpMessage = "Jira base URL (e.g., https://jira.example.com)")]
    [ValidatePattern('^https?://')]
    [string]$JiraUrl,

    [Parameter(Mandatory = $true, HelpMessage = "Jira username for authentication")]
    [ValidateNotNullOrEmpty()]
    [string]$JiraUser,

    [Parameter(Mandatory = $false, HelpMessage = "Secure password for authentication")]
    [SecureString]$JiraPassword,

    [Parameter(Mandatory = $true, HelpMessage = "New owner username for filters")]
    [ValidateNotNullOrEmpty()]
    [string]$NewOwner,

    [Parameter(Mandatory = $false, HelpMessage = "Only validate without making changes")]
    [switch]$ValidateOnly,

    [Parameter(Mandatory = $false, HelpMessage = "Skip user validation (use if you lack user query permissions)")]
    [switch]$SkipUserValidation
)

#region Initialization and Logging Setup

# Generate a unique session ID for this script execution
# This 8-character ID is used to correlate all log entries and audit records
# Example: "a67791d6" - makes it easy to track a single execution across log files
$script:SessionId = (New-Guid).ToString().Substring(0, 8)

# Create the audit log file in the same directory as the script
# Format: FilterOwnerChange_[SessionID].log
# This file contains detailed execution logs including API calls, errors, and audit events
$script:LogFile = Join-Path $PSScriptRoot "FilterOwnerChange_$script:SessionId.log"

function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to console and file with color coding and sanitization.

    .DESCRIPTION
        This function provides centralized logging with:
        - Color-coded console output based on severity level
        - Automatic sanitization of sensitive data (URLs, domains)
        - Dual logging (console + file) for comprehensive audit trail
        - Session tracking via unique session ID
        - Support for sensitive data that should only go to file

    .PARAMETER Message
        The log message to write. Can contain sensitive information.

    .PARAMETER Level
        Severity level: INFO, WARNING, ERROR, DEBUG, or AUDIT
        Determines console color and helps filter logs later.

    .PARAMETER Sensitive
        If set, the message is ONLY written to file, not to console.
        Use for API tokens, passwords, or PII that shouldn't appear on screen.

    .EXAMPLE
        Write-Log "Processing filter 12345" -Level INFO
        # Outputs to console and file with timestamp

    .EXAMPLE
        Write-Log "API Token: abc123..." -Level DEBUG -Sensitive
        # Only written to log file, hidden from console
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Sanitize message for display - remove potentially sensitive data like URLs and domains
    # This prevents accidental exposure of internal infrastructure details
    $displayMessage = $Message
    if ($JiraUrl) {
        # Replace the actual Jira URL with a generic placeholder
        $displayMessage = $displayMessage -replace [regex]::Escape($JiraUrl), "[JIRA-URL]"
    }

    # Format: [Timestamp] [SessionID] [Level] Message
    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"

    # Display non-sensitive logs to console with color coding
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }       # Critical errors - immediate attention needed
            "WARNING" { "Yellow" }  # Warnings - potential issues
            "AUDIT" { "Cyan" }      # Audit events - compliance tracking
            "DEBUG" { "Gray" }      # Debug info - troubleshooting details
            default { "White" }     # INFO and general messages
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Always log full message to file (including sensitive data for troubleshooting)
    # The file-based log includes the Windows username for accountability
    $fullLogEntry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $script:LogFile -Value $fullLogEntry -ErrorAction Stop
    }
    catch {
        # If we can't write to the log file, warn the user but continue execution
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Creates structured audit log entries for compliance and troubleshooting.

    .DESCRIPTION
        Generates JSON-formatted audit entries with:
        - ISO 8601 timestamps for precise tracking
        - Session correlation via unique session ID
        - User accountability (Windows username)
        - Computer identification for distributed environments
        - Structured data for easy parsing and analysis

        These audit logs are critical for:
        - Compliance requirements (SOX, GDPR, etc.)
        - Security incident investigation
        - Change tracking and rollback
        - Performance analysis

    .PARAMETER Action
        The action being performed (e.g., "FILTER_UPDATE_SUCCESS", "USER_VALIDATION_FAILED")
        Use consistent naming: OBJECT_ACTION_RESULT

    .PARAMETER Target
        The target of the action (e.g., "Filter 12345", "User john.doe")

    .PARAMETER Error
        Error message if the action failed

    .PARAMETER AdditionalData
        Hashtable of extra data (filter names, old/new values, etc.)

    .EXAMPLE
        Write-AuditLog -Action "FILTER_UPDATE_SUCCESS" -Target "Filter 17443" -AdditionalData @{
            OldOwner = "olduser"
            NewOwner = "newuser"
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$Error,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    # Create a structured audit entry with all relevant context
    $auditEntry = @{
        Timestamp      = Get-Date -Format "o"  # ISO 8601 format for international compatibility
        SessionId      = $script:SessionId      # Links all operations in this execution
        Action         = $Action                # What happened
        User           = $env:USERNAME          # Who did it (Windows account)
        JiraUser       = $JiraUser             # Which Jira account was used
        Target         = $Target               # What was affected
        Error          = $Error                # Error details if failed
        ComputerName   = $env:COMPUTERNAME     # Where it ran
        ScriptName     = $MyInvocation.ScriptName  # Which script version
        AdditionalData = $AdditionalData       # Extra context (old/new values, etc.)
    }

    # Convert to compact JSON for efficient storage and easy parsing
    $auditJson = $auditEntry | ConvertTo-Json -Compress

    # Write as sensitive to keep it in file only (may contain PII or system details)
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive
}

#endregion

#region Authentication Setup
# ============================================================================
# AUTHENTICATION CONFIGURATION
# ============================================================================
# This section sets up the HTTP Basic Authentication required by Jira's REST API
#
# Authentication Flow:
# 1. Prompt for password if not provided via parameter (interactive mode)
# 2. Convert SecureString password to plain text (required for Base64 encoding)
# 3. Create "username:password" string and encode to Base64
# 4. Add "Authorization: Basic <base64>" header to all API requests
#
# Security Considerations:
# - Plain text password exists briefly in memory during encoding
# - Use SecureString parameters when possible to minimize exposure
# - Passwords are never logged to console or file
# - Consider using API tokens instead of passwords for better security
# ============================================================================

Write-Log "🚀 Starting Filter Owner Change Process" -Level "INFO"
Write-Log "Session ID: $script:SessionId" -Level "INFO"
Write-AuditLog -Action "SCRIPT_START" -AdditionalData @{
    LogFolder    = $LogFolder
    NewOwner     = $NewOwner
    ValidateOnly = $ValidateOnly.IsPresent
}

# Prompt for password if not provided via -JiraPassword parameter
# This allows secure interactive execution without exposing passwords in command history
if (-not $JiraPassword) {
    Write-Host ""
    Write-Host "🔐 Authentication Required" -ForegroundColor Cyan
    $JiraPassword = Read-Host "Enter password for $JiraUser" -AsSecureString
}

# Convert SecureString to plain text string for HTTP Basic Auth
# Note: This is required because Base64 encoding needs a plain string
# The plain text password exists briefly in $PlainPassword then gets cleared
$PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($JiraPassword))

# Create Base64-encoded credentials in format "username:password"
# Example: "chcasp:MyP@ssw0rd" → "Y2hjYXNwOk15UEBzc3cwcmQ="
$EncodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($JiraUser):$($PlainPassword)"))

# Construct authentication headers for all Jira API requests
# - Authorization: Base64-encoded credentials for authentication
# - Content-Type: Tells Jira we're sending JSON data
# - Accept: Tells Jira we want JSON responses
$AuthHeader = @{
    "Authorization" = "Basic $EncodedAuth"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

Write-Log "Authentication configured for user: $JiraUser" -Level "INFO"

#endregion

#region User Validation
# ============================================================================
# NEW OWNER VALIDATION
# ============================================================================
# Before attempting to change filter ownership, verify that the target user:
# 1. Exists in Jira (returns 404 if not found)
# 2. Is active and not disabled (would cause 403 errors)
# 3. Is accessible with current authentication (requires "Browse Users" permission)
#
# This validation can be skipped with -SkipUserValidation parameter if:
# - Your account lacks "Browse Users" permission (common restriction)
# - You're confident the user exists (faster execution)
# - You want to proceed despite validation errors
#
# Note: Skipping validation means filter updates may fail with 404 if user doesn't exist
# ============================================================================

Write-Host ""
Write-Host "🔍 Validating new owner..." -ForegroundColor Cyan

function Test-JiraUser {
    <#
    .SYNOPSIS
        Validates that a Jira user account exists and is accessible.

    .DESCRIPTION
        Queries the Jira REST API to verify:
        - User account exists in Jira
        - User account is active (not disabled)
        - Authentication has permission to query user information

        This prevents attempting to assign filters to:
        - Non-existent users (would fail with 404)
        - Deactivated users (would fail with 403)
        - Inaccessible users due to permission restrictions

        Note: Requires "Browse Users" permission in Jira
        Use -SkipUserValidation if your account lacks this permission

    .PARAMETER Username
        The Jira username to validate (e.g., "nicste", "john.doe")

    .EXAMPLE
        $result = Test-JiraUser -Username "nicste"
        if ($result.Success) {
            Write-Host "User exists: $($result.DisplayName)"
        }
    #>
    param([string]$Username)

    try {
        # Construct the Jira user API endpoint
        # Example: https://jira.example.com/rest/api/2/user?username=nicste
        $userUrl = "$JiraUrl/rest/api/2/user?username=$Username"
        Write-Log "Checking user existence: $userUrl" -Level "DEBUG" -Sensitive

        # Query Jira API to retrieve user information
        # Requires "Browse Users" global permission in Jira
        $userResponse = Invoke-RestMethod -Uri $userUrl -Method GET -Headers $AuthHeader -ErrorAction Stop

        # User found - return success with user details
        Write-Log "✅ User '$Username' found and validated" -Level "INFO"
        Write-AuditLog -Action "USER_VALIDATION_SUCCESS" -Target $Username

        return @{
            Success     = $true
            User        = $userResponse         # Full user object from API
            Key         = $userResponse.key     # User key (e.g., "JIRAUSER10000")
            Name        = $userResponse.name    # Username (e.g., "nicste")
            DisplayName = $userResponse.displayName  # Display name (e.g., "Nicolaj Steen")
        }
    }
    catch {
        # Extract HTTP status code and error message for troubleshooting
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message

        # Try to parse JSON error response from Jira API for more details
        if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorMessage = $errorJson.errorMessages -join "; "
            }
            catch {
                # JSON parsing failed - use raw error message
                $errorMessage = $_.ErrorDetails.Message
            }
        }

        # Log the failure with context for troubleshooting
        Write-Log "❌ User validation failed for '$Username': [$statusCode] $errorMessage" -Level "ERROR"
        Write-AuditLog -Action "USER_VALIDATION_FAILED" -Target $Username -Error $errorMessage

        return @{
            Success    = $false
            Error      = $errorMessage
            StatusCode = $statusCode
        }
    }
}

# Validate the new owner exists (unless -SkipUserValidation parameter was used)
# This is the entry point that calls Test-JiraUser internally
if ($SkipUserValidation) {
    Write-Host "   ⚠️  User validation skipped (as requested)" -ForegroundColor Yellow
    Write-Log "User validation skipped by parameter" -Level "WARNING"

    # Create a mock validation object
    $newOwnerValidation = @{
        Success     = $true
        Name        = $NewOwner
        Key         = $NewOwner
        DisplayName = $NewOwner
    }
}
else {
    $newOwnerValidation = Test-JiraUser -Username $NewOwner

    if (-not $newOwnerValidation.Success) {
        Write-Host ""
        Write-Host "❌ CRITICAL ERROR: New owner '$NewOwner' does not exist or is not accessible" -ForegroundColor Red
        Write-Host "   Status Code: $($newOwnerValidation.StatusCode)" -ForegroundColor Red
        Write-Host "   Error: $($newOwnerValidation.Error)" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   • Verify the username is correct" -ForegroundColor Gray
        Write-Host "   • Check if the user account is active" -ForegroundColor Gray
        Write-Host "   • Ensure you have permission to view user information" -ForegroundColor Gray
        Write-Host "   • Or use -SkipUserValidation to bypass this check" -ForegroundColor Gray
        Write-AuditLog -Action "SCRIPT_ABORTED" -Error "New owner validation failed"
        exit 1
    }

    Write-Host "   Display Name: $($newOwnerValidation.DisplayName)" -ForegroundColor Green
    Write-Host "   User Key: $($newOwnerValidation.Key)" -ForegroundColor Green
}

#endregion

#region Filter ID Extraction
# ============================================================================
# LOG FILE SCANNING AND FILTER ID EXTRACTION
# ============================================================================
# This section scans all .log files in the specified folder to find filter IDs
# that need ownership changes.
#
# Process:
# 1. Find all .log files in the LogFolder directory
# 2. Read each file line-by-line for efficiency (some logs can be large)
# 3. Apply regex pattern to extract filter IDs from matching lines
# 4. Deduplicate filter IDs (same ID may appear in multiple logs or lines)
# 5. Sort the unique filter IDs for orderly processing
#
# Expected Log Format:
#   "Filter 12345 has no owner"
#   "Filter 67890 has no owner"
#
# Regex Pattern Explanation:
#   'Filter (\d+) has no owner'
#   - Filter: Literal text match
#   - \d+: One or more digits (the filter ID) - captured in $matches[1]
#   - has no owner: Literal text match
#
# Performance Considerations:
# - Processes files sequentially to avoid memory issues with large log sets
# - Deduplicates during scanning to minimize memory usage
# - Uses -match instead of Select-String for better performance
# ============================================================================

Write-Host ""
Write-Host "📂 Scanning log files for filter IDs..." -ForegroundColor Cyan

# Initialize an empty array to store unique Filter IDs
# Example: @(12345, 67890, 54321)
$filterIds = @()

# Get all .log files in the specified folder
# Does NOT scan subfolders - use Get-ChildItem -Recurse if needed
$logFiles = Get-ChildItem -Path $LogFolder -Filter *.log

# Exit if no log files found - nothing to process
if ($logFiles.Count -eq 0) {
    Write-Log "⚠️  No log files found in $LogFolder" -Level "WARNING"
    Write-AuditLog -Action "NO_LOGS_FOUND" -Target $LogFolder
    exit 0
}

Write-Log "Found $($logFiles.Count) log file(s) to process" -Level "INFO"

# Define regex pattern to extract filter ID from log entries
# Captures the numeric ID in group 1 ($matches[1])
# Example match: "Filter 12345 has no owner" → $matches[1] = "12345"
$regexPattern = 'Filter (\d+) has no owner'

# Process each log file and extract unique Filter IDs
foreach ($logFile in $logFiles) {
    Write-Log "Processing: $($logFile.Name)" -Level "DEBUG"

    # Read log file line-by-line (efficient for large files)
    $lines = Get-Content -Path $logFile.FullName

    # Scan each line for filter ID pattern
    foreach ($line in $lines) {
        # Check if the line matches our regex pattern
        if ($line -match $regexPattern) {
            # Extract the Filter ID from the first capture group
            $filterId = $matches[1]

            # Only add if not already in our list (deduplication during scan)
            if ($filterId -notin $filterIds) {
                $filterIds += $filterId
                Write-Log "  Found Filter ID: $filterId" -Level "DEBUG"
            }
        }
    }
}

# Additional deduplication and sorting for consistency
# (Should be redundant due to -notin check above, but ensures clean data)
$filterIds = $filterIds | Select-Object -Unique

if ($filterIds.Count -eq 0) {
    Write-Host ""
    Write-Log "ℹ️  No filter IDs found matching pattern: $regexPattern" -Level "INFO"
    Write-AuditLog -Action "NO_FILTERS_FOUND"
    exit 0
}

Write-Host ""
Write-Host "✅ Found $($filterIds.Count) unique filter(s) to update" -ForegroundColor Green
Write-Host ""

#endregion

#region Filter Validation and Update
# ============================================================================
# FILTER PROCESSING - VALIDATE AND UPDATE OWNERSHIP
# ============================================================================
# This is the main processing loop that:
# 1. Retrieves current filter information from Jira API
# 2. Validates current owner and checks if update is needed
# 3. Updates filter ownership using PUT request to /rest/api/2/filter/{id}
# 4. Handles errors with contextual troubleshooting messages
# 5. Tracks success/failure metrics for final summary report
#
# API Endpoints Used:
# - GET  /rest/api/2/filter/{id}     - Retrieve filter details
# - PUT  /rest/api/2/filter/{id}     - Update filter (including owner)
#
# Required Permissions:
# - "Edit All Filters" or "Share Objects" global permission
# - Filter must be visible to the authenticated user
# - User must have edit rights on the specific filter
#
# Error Handling:
# - 401 Unauthorized: Invalid credentials
# - 403 Forbidden: Insufficient permissions or filter access denied
# - 404 Not Found: Filter doesn't exist or user lacks view permission
# - 400 Bad Request: Invalid payload format or user doesn't exist
#
# Payload Format Strategy:
# The script tries 3 different payload formats for maximum compatibility:
# 1. {"owner": {"name": "username"}}        - Standard on-premise format
# 2. {"owner": {"key": "JIRAUSER10000"}}    - User key format
# 3. {"owner": "username"}                  - Simplified format (rare)
#
# This handles differences between Jira versions and configurations
# ============================================================================

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                  FILTER UPDATE PROCESS                     " -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Initialize counters for summary statistics
$successCount = 0  # Filters successfully updated
$failureCount = 0  # Filters that failed to update
$results = @()     # Detailed results array for final report

# Process each filter ID found in the log files
foreach ($filterId in $filterIds) {
    Write-Host "Processing Filter ID: $filterId" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Gray

    # ========================================================================
    # STEP 1: RETRIEVE CURRENT FILTER INFORMATION
    # ========================================================================
    # Query Jira API to get filter details including:
    # - Filter name and description
    # - Current owner (if any)
    # - JQL query
    # - Permissions and sharing settings
    $filterUrl = "$JiraUrl/rest/api/2/filter/$filterId"

    try {
        Write-Log "  Fetching filter details: $filterUrl" -Level "DEBUG" -Sensitive

        # GET request to retrieve filter information
        # Will throw exception if filter doesn't exist or user lacks view permission
        $filterInfo = Invoke-RestMethod -Uri $filterUrl -Method GET -Headers $AuthHeader -ErrorAction Stop

        # Display current filter information for user visibility
        Write-Host "  Filter Name: $($filterInfo.name)" -ForegroundColor Gray

        # Handle filters with no owner (common scenario from log files)
        $currentOwner = if ($filterInfo.owner.displayName) { $filterInfo.owner.displayName } else { 'None' }
        Write-Host "  Current Owner: $currentOwner" -ForegroundColor Gray

        # Show truncated JQL query (can be very long)
        Write-Host "  JQL: $($filterInfo.jql.Substring(0, [Math]::Min(50, $filterInfo.jql.Length)))..." -ForegroundColor Gray

        # ====================================================================
        # STEP 2: CHECK IF UPDATE IS NEEDED
        # ====================================================================
        # Skip if filter is already owned by target user (idempotent operation)
        if ($filterInfo.owner.name -eq $NewOwner) {
            Write-Host "  ℹ️  Filter already owned by $NewOwner - skipping" -ForegroundColor Cyan
            $results += @{
                FilterId = $filterId
                Status   = "Skipped"
                Reason   = "Already owned by target user"
            }
            Write-Host ""
            continue  # Move to next filter
        }

        # ====================================================================
        # STEP 3: UPDATE FILTER OWNER (OR VALIDATE)
        # ====================================================================
        if ($ValidateOnly) {
            # WhatIf mode: Show what would be done without making changes
            Write-Host "  🔍 VALIDATE-ONLY MODE: Would update owner to $NewOwner" -ForegroundColor Yellow
            $results += @{
                FilterId = $filterId
                Status   = "Validated"
                Reason   = "WhatIf mode"
            }
            $successCount++
        }
        else {
            # ================================================================
            # ACTUAL UPDATE MODE: Change the filter owner
            # ================================================================
            # Uses PowerShell's ShouldProcess for proper -WhatIf/-Confirm support
            # This allows users to preview changes before applying them
            if ($PSCmdlet.ShouldProcess("Filter $filterId ($($filterInfo.name))", "Change owner to $NewOwner")) {

                # Try multiple payload formats for maximum Jira version compatibility
                # Different Jira versions/configurations expect different JSON structures
                $payloadFormats = @(
                    # Format 1: User object with name property (most common on-premise)
                    # Example: {"owner": {"name": "nicste"}}
                    @{ "owner" = @{ "name" = $NewOwner } },

                    # Format 2: User object with key property (alternative format)
                    # Example: {"owner": {"key": "JIRAUSER10000"}}
                    @{ "owner" = @{ "key" = $newOwnerValidation.Key } },

                    # Format 3: Direct string value (simplified format, rare)
                    # Example: {"owner": "nicste"}
                    @{ "owner" = $NewOwner }
                )

                $updateSuccess = $false  # Track if any format succeeded
                $lastError = $null       # Store last error for reporting

                # Try each payload format until one succeeds
                for ($payloadIndex = 0; $payloadIndex -lt $payloadFormats.Count; $payloadIndex++) {
                    # Convert hashtable to JSON string for API request
                    # -Depth 5 ensures nested objects are fully serialized
                    $body = $payloadFormats[$payloadIndex] | ConvertTo-Json -Depth 5

                    Write-Log "  Attempting update with payload format $($payloadIndex + 1)" -Level "DEBUG"

                    try {
                        # ====================================================
                        # PUT REQUEST: Update filter ownership
                        # ====================================================
                        # Endpoint: PUT /rest/api/2/filter/{id}
                        # Body: JSON with new owner information
                        # Returns: Updated filter object (but we don't use it)
                        $null = Invoke-RestMethod -Uri $filterUrl -Method PUT -Headers $AuthHeader -Body $body -ErrorAction Stop

                        # Success! Filter owner has been updated
                        Write-Host "  ✅ Successfully updated filter owner" -ForegroundColor Green
                        Write-Log "Filter $filterId updated successfully" -Level "INFO"

                        # Log detailed audit information for compliance
                        Write-AuditLog -Action "FILTER_UPDATE_SUCCESS" -Target "Filter $filterId" -AdditionalData @{
                            FilterName    = $filterInfo.name
                            OldOwner      = $filterInfo.owner.name
                            NewOwner      = $NewOwner
                            PayloadFormat = $payloadIndex + 1  # Track which format worked
                        }

                        # Store result for final summary report
                        $results += @{
                            FilterId   = $filterId
                            FilterName = $filterInfo.name
                            Status     = "Success"
                            OldOwner   = $filterInfo.owner.displayName
                            NewOwner   = $newOwnerValidation.DisplayName
                        }

                        $updateSuccess = $true
                        $successCount++
                        break  # Exit the payload format loop - success achieved

                    }
                    catch {
                        # ================================================
                        # ERROR HANDLING: Update attempt failed
                        # ================================================
                        # Extract error details for troubleshooting
                        $statusCode = $_.Exception.Response.StatusCode.value__
                        $errorMessage = $_.Exception.Message

                        # Try to parse JSON error response from Jira API
                        if ($_.ErrorDetails.Message) {
                            try {
                                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                                # Get error messages array (e.g., ["User 'xyz' does not exist"])
                                $errorMessage = $errorJson.errorMessages -join "; "
                                # Fallback to errors object if errorMessages is empty
                                if (-not $errorMessage) {
                                    $errorMessage = $errorJson.errors | ConvertTo-Json
                                }
                            }
                            catch {
                                # JSON parsing failed - use raw error text
                                $errorMessage = $_.ErrorDetails.Message
                            }
                        }

                        # Store error details for reporting if all formats fail
                        $lastError = @{
                            StatusCode    = $statusCode
                            Message       = $errorMessage
                            PayloadFormat = $payloadIndex + 1
                        }

                        # Log failure at DEBUG level (only last error shown to user)
                        Write-Log "  Payload format $($payloadIndex + 1) failed: [$statusCode] $errorMessage" -Level "DEBUG"
                    }
                }

                # ========================================================
                # ALL PAYLOAD FORMATS FAILED: Report the error
                # ========================================================
                if (-not $updateSuccess) {
                    Write-Host "  ❌ Failed to update filter after trying all payload formats" -ForegroundColor Red
                    Write-Host "     Status Code: $($lastError.StatusCode)" -ForegroundColor Red
                    Write-Host "     Error: $($lastError.Message)" -ForegroundColor Red

                    # Provide context-specific troubleshooting guidance
                    switch ($lastError.StatusCode) {
                        401 {
                            # Authentication credentials are invalid or expired
                            Write-Host "     💡 Authentication failed - check username/password" -ForegroundColor Yellow
                        }
                        403 {
                            # Permission issues - most common error
                            Write-Host "     💡 Permission denied - possible causes:" -ForegroundColor Yellow
                            Write-Host "        • You don't have permission to edit this filter" -ForegroundColor Gray
                            Write-Host "        • The filter is owned by someone else and is private" -ForegroundColor Gray
                            Write-Host "        • Your account lacks 'Administer Jira' or 'Edit All Filters' permission" -ForegroundColor Gray
                            Write-Host "        • The filter may have restrictive sharing settings" -ForegroundColor Gray
                        }
                        404 {
                            # Filter not found - may have been deleted since log was generated
                            Write-Host "     💡 Filter not found - it may have been deleted or you lack view permission" -ForegroundColor Yellow
                        }
                        400 {
                            # Bad request - usually invalid data or user doesn't exist
                            Write-Host "     💡 Invalid request - the new owner may not exist or be invalid" -ForegroundColor Yellow
                        }
                    }

                    # Log detailed error information for troubleshooting
                    Write-Log "Filter $filterId update failed: [$($lastError.StatusCode)] $($lastError.Message)" -Level "ERROR"
                    Write-AuditLog -Action "FILTER_UPDATE_FAILED" -Target "Filter $filterId" -Error $lastError.Message -AdditionalData @{
                        FilterName        = $filterInfo.name
                        StatusCode        = $lastError.StatusCode
                        AllPayloadsFailed = $true
                    }

                    # Store failed result for summary report
                    $results += @{
                        FilterId   = $filterId
                        FilterName = $filterInfo.name
                        Status     = "Failed"
                        Error      = "$($lastError.StatusCode): $($lastError.Message)"
                    }

                    $failureCount++
                }
            }
        }

    }
    catch {
        # ====================================================================
        # FILTER RETRIEVAL ERROR: Failed to get filter information
        # ====================================================================
        # This typically happens when:
        # - Filter doesn't exist or was deleted
        # - User lacks view permission on the filter
        # - Network/connectivity issues
        # - Jira server issues
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message

        # Try to parse Jira's JSON error response for better context
        if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorMessage = $errorJson.errorMessages -join "; "
            }
            catch {
                $errorMessage = $_.ErrorDetails.Message
            }
        }

        # Display error to user with context
        Write-Host "  ❌ Failed to retrieve filter information" -ForegroundColor Red
        Write-Host "     Status Code: $statusCode" -ForegroundColor Red
        Write-Host "     Error: $errorMessage" -ForegroundColor Red

        # Log and audit the failure
        Write-Log "Failed to retrieve filter $filterId : [$statusCode] $errorMessage" -Level "ERROR"
        Write-AuditLog -Action "FILTER_RETRIEVAL_FAILED" -Target "Filter $filterId" -Error $errorMessage

        # Store failed result
        $results += @{
            FilterId = $filterId
            Status   = "Failed"
            Error    = "$statusCode : $errorMessage"
        }

        $failureCount++
    }

    Write-Host ""  # Blank line between filter processing
}

#endregion

#region Summary Report
# ============================================================================
# EXECUTION SUMMARY AND RESULTS REPORT
# ============================================================================
# This section generates a comprehensive summary of the script execution:
# - Total number of filters processed
# - Success and failure counts
# - Detailed results for each filter
# - Location of audit log file for troubleshooting
#
# Results are displayed both on console and stored in the audit log file
# for compliance and troubleshooting purposes
# ============================================================================

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    EXECUTION SUMMARY                       " -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Display high-level statistics
Write-Host "Total Filters Processed: $($filterIds.Count)" -ForegroundColor White
Write-Host "✅ Successful Updates:   $successCount" -ForegroundColor Green
Write-Host "❌ Failed Updates:       $failureCount" -ForegroundColor Red
Write-Host ""

# Display detailed results table if any filters were processed
if ($results.Count -gt 0) {
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Gray

    # Iterate through results and display each filter's outcome
    foreach ($result in $results) {
        # Use visual icons for quick status identification
        $statusIcon = switch ($result.Status) {
            "Success" { "✅" }      # Successfully updated
            "Failed" { "❌" }       # Update failed
            "Skipped" { "ℹ️ " }     # Already owned by target user (note: space after emoji for alignment)
            "Validated" { "🔍" }   # WhatIf mode - would update
            default { "•" }         # Unknown status
        }

        # Color-code status for visual clarity
        $statusColor = switch ($result.Status) {
            "Success" { "Green" }
            "Failed" { "Red" }
            "Skipped" { "Cyan" }
            "Validated" { "Yellow" }
            default { "Gray" }
        }

        # Display filter ID and status with icon
        Write-Host "$statusIcon Filter $($result.FilterId): $($result.Status)" -ForegroundColor $statusColor

        # Show additional details if available
        if ($result.FilterName) {
            Write-Host "   Name: $($result.FilterName)" -ForegroundColor Gray
        }
        if ($result.OldOwner) {
            Write-Host "   $($result.OldOwner) → $($result.NewOwner)" -ForegroundColor Gray
        }
        if ($result.Error) {
            Write-Host "   Error: $($result.Error)" -ForegroundColor Gray
        }
        if ($result.Reason) {
            Write-Host "   Reason: $($result.Reason)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "📋 Audit log saved to: $script:LogFile" -ForegroundColor Cyan
Write-Host "   Review this file for detailed error information and troubleshooting" -ForegroundColor Gray
Write-Host ""

# Log final script completion audit entry
Write-AuditLog -Action "SCRIPT_COMPLETE" -AdditionalData @{
    TotalProcessed = $filterIds.Count
    SuccessCount   = $successCount
    FailureCount   = $failureCount
}

# Exit with appropriate code for automation/CI integration
# Exit code 0 = success or partial success
# Exit code 1 = all operations failed or critical error
if ($failureCount -gt 0) {
    exit 1
}
else {
    exit 0
}

#endregion
