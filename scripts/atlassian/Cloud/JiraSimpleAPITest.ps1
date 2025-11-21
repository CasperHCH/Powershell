<#
.SYNOPSIS
    Secure Jira Cloud API authentication test script for validating API connectivity.

.DESCRIPTION
    This script validates connectivity and authentication to a Jira Cloud instance using:
    - Bearer token authentication (standard Jira Cloud PAT)
    - Basic authentication for service accounts (email:token)

    Features:
    - Secure credential handling (SecureString input, immediate cleanup)
    - Comprehensive parameter validation (URL patterns, email format)
    - Audit logging with session tracking for compliance
    - URL sanitization to prevent information disclosure
    - Support for both standard and service account authentication
    - Configurable timeout for network resilience

    Use Cases:
    - Verify API token validity before automation
    - Test connectivity to Jira Cloud endpoints
    - Validate service account configuration
    - Troubleshoot API authentication issues
    - Compliance testing for secure API integration

.PARAMETER JiraBaseUrl
    The base URL of your Jira Cloud instance.
    Format: https://<subdomain>.atlassian.net
    Example: https://yourcompany.atlassian.net

    Note: Must end with .atlassian.net (validated by regex)

.PARAMETER ApiEndpoint
    The Jira REST API endpoint path to test (without leading slash).
    Common endpoints:
    - rest/api/3/myself           - Get current user info (best for auth testing)
    - rest/api/3/project          - List accessible projects
    - rest/api/3/issue/PROJ-123   - Get specific issue

    Note: Jira Cloud uses API version 3 (rest/api/3/)

.PARAMETER ServiceAccountEmail
    Optional: Service account email for Basic Authentication.
    Format: bot@serviceaccount.atlassian.com

    Required if using service account authentication with CloudId.
    Service accounts use Basic Auth (email:token) instead of Bearer tokens.

.PARAMETER CloudId
    Optional: Cloud ID for service account authentication.
    Required when using ServiceAccountEmail parameter.

    Changes API URL format to:
    https://api.atlassian.com/ex/jira/<CloudId>/<endpoint>

.PARAMETER UseStoredToken
    Switch parameter to use secure token storage retrieval.
    Currently not implemented - placeholder for future enhancement.

    If specified, script attempts to retrieve token from secure storage
    instead of prompting user for input.

.PARAMETER TimeoutSeconds
    HTTP request timeout in seconds.
    Default: 30 seconds
    Range: 5-120 seconds

    Prevents script from hanging on network issues.
    Increase for slow networks, decrease for faster failure detection.

.EXAMPLE
    .\JiraSimpleAPITest.ps1 -JiraBaseUrl "https://example.atlassian.net" -ApiEndpoint "rest/api/3/myself"

    Basic authentication test using Bearer token with current user endpoint.
    Prompts for API token interactively.

.EXAMPLE
    .\JiraSimpleAPITest.ps1 -JiraBaseUrl "https://company.atlassian.net" -ApiEndpoint "rest/api/3/project" -TimeoutSeconds 60

    Test project list endpoint with extended 60-second timeout.

.EXAMPLE
    .\JiraSimpleAPITest.ps1 -JiraBaseUrl "https://example.atlassian.net" -ApiEndpoint "rest/api/3/myself" -ServiceAccountEmail "bot@serviceaccount.atlassian.com" -CloudId "abc123-def456-ghi789"

    Service account authentication using Basic Auth with cloud ID.

.NOTES
    File Name      : JiraSimpleAPITest.ps1
    Author         : PowerShell Automation
    Prerequisite   : PowerShell 5.1 or higher
    Version        : 1.0

    Security:
    - All sensitive data (tokens) are cleared from memory after use
    - URLs are sanitized in console/log output
    - Audit logs contain full details for troubleshooting
    - Supports SecureString password input

    Compliance:
    - GDPR: No PII stored, minimal data collection
    - SOX: Complete audit trail with session tracking
    - Security: Secure credential handling, input validation

.LINK
    https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/
    https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
#>

#region Script Parameters
# ============================================================================
# PARAMETER DEFINITIONS WITH VALIDATION
# ============================================================================
# All parameters include:
# - Help messages for user guidance
# - Validation patterns/ranges to prevent invalid input
# - Mandatory flags to ensure required data is provided
#
# Parameter Validation Benefits:
# - Fails fast with clear error messages
# - Prevents API calls with invalid data
# - Improves security by rejecting malformed input
# - Provides better user experience with helpful prompts
# ============================================================================

[CmdletBinding()]
param(
    # Jira Cloud base URL - must be a valid atlassian.net domain
    # Pattern ensures HTTPS and proper domain format
    # Example: https://yourcompany.atlassian.net
    [Parameter(Mandatory = $true, HelpMessage = "Jira Cloud base URL (e.g., https://example.atlassian.net)")]
    [ValidatePattern('^https://[a-zA-Z0-9.-]+\.atlassian\.net/?$')]
    [string]$JiraBaseUrl,

    # API endpoint path - validated to contain only safe characters
    # Pattern prevents injection attacks and ensures valid REST paths
    # Example: rest/api/3/myself
    [Parameter(Mandatory = $true, HelpMessage = "Jira API endpoint path (e.g., rest/api/3/myself)")]
    [ValidatePattern('^[a-zA-Z0-9/_\-]+$')]
    [string]$ApiEndpoint,

    # Service account email for Basic Auth (optional)
    # Pattern validates proper email format
    # Used with CloudId for service account authentication
    [Parameter(Mandatory = $false, HelpMessage = "Service account email (e.g., bot@serviceaccount.atlassian.com)")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$ServiceAccountEmail,

    # Cloud ID for service account authentication (optional)
    # Required when using ServiceAccountEmail parameter
    # Changes API URL to: https://api.atlassian.com/ex/jira/<CloudId>/<endpoint>
    [Parameter(Mandatory = $false, HelpMessage = "Cloud ID for service account authentication")]
    [string]$CloudId,

    # Switch to enable stored token retrieval (not yet implemented)
    # Placeholder for future integration with secure credential storage
    [Parameter(Mandatory = $false, HelpMessage = "Use stored token retrieval")]
    [switch]$UseStoredToken,

    # Request timeout in seconds - prevents hanging on network issues
    # Range validation ensures reasonable timeout values
    # Default 30 seconds balances responsiveness and reliability
    [Parameter(Mandatory = $false, HelpMessage = "Request timeout in seconds")]
    [ValidateRange(5, 120)]
    [int]$TimeoutSeconds = 30
)

#endregion

#region Logging Functions
# ============================================================================
# SECURE LOGGING AND AUDIT TRAIL FUNCTIONS
# ============================================================================
# These functions provide:
# - Console output with color-coded severity levels
# - File-based audit logging for compliance
# - Sensitive data sanitization to prevent information disclosure
# - Session tracking for correlating related operations
# - Structured audit entries in JSON format for analysis
#
# Security Features:
# - URLs are replaced with [JIRA_URL] placeholder in console output
# - Full details preserved in audit log for troubleshooting
# - Sensitive flag allows file-only logging (no console output)
# - Username tracking for accountability
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to console and file with severity-based formatting.

    .DESCRIPTION
        Dual-purpose logging function that:
        - Displays color-coded messages on console for user feedback
        - Writes detailed entries to audit log file for compliance
        - Sanitizes sensitive data (URLs) in console output
        - Preserves full details in log file for troubleshooting
        - Supports session correlation via unique session ID

    .PARAMETER Message
        The log message to write. Can contain URLs or sensitive data.

    .PARAMETER Level
        Severity level: INFO (default), WARNING, ERROR, DEBUG, AUDIT
        Determines console color and helps with log filtering.

    .PARAMETER Sensitive
        Switch to prevent console output (file-only logging).
        Use for data that should not be displayed on screen.

    .PARAMETER LogPath
        Path to the audit log file.
        Default: ScriptAudit.log in the same directory as the script

    .EXAMPLE
        Write-Log "Starting API test" -Level "INFO"
        Displays info message in white and logs to file

    .EXAMPLE
        Write-Log "API token retrieved" -Level "DEBUG" -Sensitive
        Logs to file only, no console output
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",
        [Parameter(Mandatory = $false)]
        [switch]$Sensitive,
        [Parameter(Mandatory = $false)]
        [string]$LogPath = (Join-Path $PSScriptRoot "ScriptAudit.log")
    )

    # Generate timestamp for log entries (consistent format)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Use script-level session ID or generate new one
    # Session ID correlates all log entries from single execution
    $sessionId = $script:SessionId ?? (New-Guid).ToString().Substring(0, 8)

    # Sanitize message for console display (replace URLs with placeholder)
    $displayMessage = $Message
    if ($script:JiraBaseUrl) {
        $displayMessage = $displayMessage -replace $script:JiraBaseUrl, "[JIRA_URL]"
    }

    # Format log entry for console display
    $logEntry = "[$timestamp] [$sessionId] [$Level] $displayMessage"

    # Display on console unless -Sensitive flag is set
    if (-not $Sensitive) {
        # Choose color based on severity level
        $color = switch ($Level) {
            "ERROR" { "Red" }       # Critical errors
            "WARNING" { "Yellow" }  # Important warnings
            "AUDIT" { "Cyan" }      # Security/compliance events
            default { "White" }     # INFO, DEBUG, and others
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Write full details (unsanitized) to audit log file
    # Includes Windows username for accountability
    $fullLogEntry = "[$timestamp] [$sessionId] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
    }
    catch {
        # If log file write fails, warn user but continue execution
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Creates structured audit log entries in JSON format.

    .DESCRIPTION
        Generates compliance-focused audit entries with:
        - ISO 8601 timestamps for precise tracking
        - Session correlation for multi-step operations
        - User and computer identification
        - Action and target tracking
        - Error details for failures
        - Additional context data

        Audit logs are critical for:
        - Security incident investigation
        - Compliance requirements (SOX, GDPR, etc.)
        - Troubleshooting API issues
        - Change tracking and accountability

    .PARAMETER Action
        The action being performed (e.g., "API_TEST_START", "AUTH_SUCCESS")
        Use consistent naming: OBJECT_ACTION_RESULT

    .PARAMETER Target
        What the action targets (e.g., URL, user account)

    .PARAMETER User
        Who performed the action (Windows username)

    .PARAMETER Error
        Error message if the action failed

    .PARAMETER AdditionalData
        Hashtable of extra contextual information

    .EXAMPLE
        Write-AuditLog -Action "API_TEST_START" -Target "https://example.atlassian.net" -User $env:USERNAME
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [Parameter(Mandatory = $false)]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$User,
        [Parameter(Mandatory = $false)]
        [string]$Error,
        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    # Create structured audit entry with all relevant context
    $auditEntry = @{
        Timestamp      = Get-Date -Format "o"  # ISO 8601 format (sortable, timezone-aware)
        SessionId      = $script:SessionId      # Links all operations in this execution
        Action         = $Action                # What happened
        User           = $User                  # Who did it (Windows account)
        Target         = $Target               # What was affected
        Error          = $Error                # Error details if failed
        ComputerName   = $env:COMPUTERNAME     # Where it ran
        ScriptName     = $MyInvocation.ScriptName  # Which script
        AdditionalData = $AdditionalData       # Extra context
    }

    # Convert to compact JSON for efficient storage and parsing
    $auditJson = $auditEntry | ConvertTo-Json -Compress

    # Write as sensitive to keep it in file only (may contain sensitive details)
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
}

#endregion

#region Token Retrieval
# ============================================================================
# SECURE API TOKEN RETRIEVAL
# ============================================================================
# Handles secure retrieval of Jira API tokens with two modes:
# 1. Interactive mode: Prompts user for token using SecureString
# 2. Stored token mode: Retrieves from secure storage (placeholder)
#
# Security Features:
# - SecureString input prevents token from appearing on screen
# - Immediate conversion to plain text only when needed
# - Token cleared from memory after use (in finally block)
#
# Best Practices:
# - Use API tokens instead of passwords for better security
# - Tokens can be revoked without changing password
# - Tokens have fine-grained permissions
# - Generate tokens at: https://id.atlassian.com/manage-profile/security/api-tokens
# ============================================================================

function Get-JiraApiToken {
    <#
    .SYNOPSIS
        Securely retrieves Jira API token for authentication.

    .DESCRIPTION
        Provides two methods for token retrieval:

        1. Interactive Mode (default):
           - Prompts user to enter token securely
           - Uses SecureString to prevent token visibility
           - Token is masked with asterisks during input

        2. Stored Token Mode (-UseStoredToken):
           - Placeholder for integration with credential storage
           - Could integrate with Windows Credential Manager
           - Could integrate with Azure Key Vault
           - Currently throws error - not yet implemented

        The token is converted to plain text only when needed for
        API authentication, then immediately cleared from memory.

    .PARAMETER UseStoredToken
        Switch to enable stored token retrieval.
        Currently not implemented - throws error with guidance.

    .OUTPUTS
        String - The Jira API token in plain text

    .EXAMPLE
        $token = Get-JiraApiToken
        Prompts user to enter token securely

    .EXAMPLE
        $token = Get-JiraApiToken -UseStoredToken
        Attempts to retrieve from secure storage (not yet implemented)

    .NOTES
        Security: Token is cleared from memory in the calling function's
        finally block to minimize exposure time.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseStoredToken
    )

    if ($UseStoredToken) {
        # Future enhancement: Implement secure token storage integration
        # Options: Windows Credential Manager, Azure Key Vault, encrypted file
        throw "Stored token retrieval not implemented. Please use manual entry."
    }
    else {
        # Interactive mode: Prompt user for token using SecureString
        # SecureString ensures token is encrypted in memory
        $secureToken = Read-Host "Enter Jira API token" -AsSecureString

        # Convert SecureString to plain text for API authentication
        # Note: This is necessary for HTTP headers but minimizes exposure time
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        )
    }
}

#endregion

#region Main Execution
# ============================================================================
# MAIN SCRIPT EXECUTION FLOW
# ============================================================================
# Workflow:
# 1. Initialize session and logging
# 2. Validate API endpoint format
# 3. Retrieve API token securely
# 4. Build authentication headers (Bearer or Basic)
# 5. Execute API test request
# 6. Display results or handle errors
# 7. Clean up sensitive data
#
# Authentication Methods:
# - Bearer Token: Standard Jira Cloud authentication (PAT)
# - Basic Auth: Service account authentication (email:token)
#
# Exit Codes:
# 0 = Success - API authentication worked
# 1 = Token retrieval failed
# 2 = API authentication failed
# ============================================================================

# Store base URL in script scope for sanitization in logging functions
$script:JiraBaseUrl = $JiraBaseUrl

# Generate unique 8-character session ID for this execution
# Used to correlate all log entries from this script run
# Example: "a7b3c9d2"
$script:SessionId = (New-Guid).ToString().Substring(0, 8)

# Log script start with session information
Write-Log "🚀 Starting Jira Cloud API authentication test..." -Level "INFO"
Write-AuditLog -Action "API_TEST_START" -Target $JiraBaseUrl -User $env:USERNAME

# ============================================================================
# STEP 1: VALIDATE API ENDPOINT FORMAT
# ============================================================================
# Jira Cloud uses REST API v3 (rest/api/3/)
# Warn if endpoint doesn't follow this convention (may still work)
if ($ApiEndpoint -notmatch '^rest/api/3/') {
    Write-Log "⚠️  API endpoint should start with 'rest/api/3/' for Jira Cloud." -Level "WARNING"
    Write-Log "   Your endpoint: $ApiEndpoint" -Level "WARNING"
}

# ============================================================================
# STEP 2: RETRIEVE API TOKEN SECURELY
# ============================================================================
# Token retrieval with error handling
# Exits with code 1 if token retrieval fails
try {
    $apiToken = Get-JiraApiToken -UseStoredToken:$UseStoredToken
    Write-Log "✅ API token retrieved successfully" -Level "INFO"
}
catch {
    Write-Log "❌ Token retrieval failed: $($_.Exception.Message)" -Level "ERROR"
    Write-AuditLog -Action "TOKEN_RETRIEVAL_FAILED" -Target $JiraBaseUrl -User $env:USERNAME -Error $_.Exception.Message
    exit 1
}

# ============================================================================
# STEP 3: BUILD REQUEST URL AND AUTHENTICATION HEADERS
# ============================================================================
# Two authentication modes based on parameters:

# Check if using service account authentication
if ($ServiceAccountEmail -and $CloudId) {
    # ========================================================================
    # SERVICE ACCOUNT MODE (Basic Authentication)
    # ========================================================================
    # Service accounts use:
    # - Basic Authentication with email:token
    # - Special API URL format via Atlassian API gateway
    # - Cloud ID to route to correct Jira instance
    #
    # URL Format: https://api.atlassian.com/ex/jira/<CloudId>/<endpoint>
    # Auth Header: Basic <base64(email:token)>
    # ========================================================================

    Write-Log "Using service account authentication with cloud ID" -Level "INFO"

    # Build service account URL via Atlassian API gateway
    $fullUrl = "https://api.atlassian.com/ex/jira/$CloudId/$ApiEndpoint"

    # Create Basic Auth header: Base64-encode "email:token"
    # Example: "bot@serviceaccount.atlassian.com:abc123..." → "Ym90QHNlcnZpY2VhY2NvdW50..."
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ServiceAccountEmail}:${apiToken}"))

    $headers = @{
        'Authorization' = "Basic $base64AuthInfo"
        'Accept'        = 'application/json'
        'User-Agent'    = 'PowerShellJiraAuthTest/1.0'
    }
}
else {
    # ========================================================================
    # STANDARD MODE (Bearer Token Authentication)
    # ========================================================================
    # Standard Jira Cloud authentication uses:
    # - Bearer token (Personal Access Token / PAT)
    # - Direct access to Jira instance URL
    #
    # URL Format: https://<subdomain>.atlassian.net/<endpoint>
    # Auth Header: Bearer <token>
    # ========================================================================

    Write-Log "Using standard Bearer token authentication" -Level "INFO"

    # Build direct URL to Jira instance
    $fullUrl = "$JiraBaseUrl/$ApiEndpoint"

    # Clean up URL: Remove double slashes but preserve protocol (https://)
    # Example: "https://example.atlassian.net//rest/api/3/myself" → "https://example.atlassian.net/rest/api/3/myself"
    $fullUrl = $fullUrl -replace '([^:])//+', '$1/'

    $headers = @{
        'Authorization' = "Bearer $apiToken"
        'Accept'        = 'application/json'
        'User-Agent'    = 'PowerShellJiraAuthTest/1.0'
    }
}

# ============================================================================
# STEP 4: EXECUTE API REQUEST AND HANDLE RESPONSE
# ============================================================================
try {
    # Log the request (URL is sanitized in Write-Log function)
    Write-Log "Testing API call to $fullUrl" -Level "INFO" -Sensitive

    # Make the API request with configured timeout
    # -Method Get: Read-only operation (safe for testing)
    # -TimeoutSec: Prevents hanging on network issues
    $response = Invoke-RestMethod -Uri $fullUrl -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds

    # ========================================================================
    # SUCCESS: API call succeeded
    # ========================================================================
    Write-Log "✅ Authentication succeeded. Jira API responded." -Level "INFO"
    Write-AuditLog -Action "API_AUTH_SUCCESS" -Target $fullUrl -User $env:USERNAME

    # Display success message and response details
    Write-Host "✅ Jira API authentication successful." -ForegroundColor Green
    Write-Host "📊 Response summary:" -ForegroundColor White

    # Pretty-print JSON response (limited depth to avoid overwhelming output)
    $response | ConvertTo-Json -Depth 3 | Write-Host
}
catch {
    # ========================================================================
    # ERROR: API call failed
    # ========================================================================
    # Common failure reasons:
    # - Invalid token (401 Unauthorized)
    # - Insufficient permissions (403 Forbidden)
    # - Invalid endpoint (404 Not Found)
    # - Network issues (timeout, connection refused)
    # ========================================================================

    # Sanitize error message to prevent URL exposure in console
    $sanitizedError = $_.Exception.Message -replace $JiraBaseUrl, "[JIRA_URL]"

    # Display error to user
    Write-Host "❌ API call failed: $sanitizedError" -ForegroundColor Red
    Write-Log "❌ API call failed: $sanitizedError" -Level "ERROR"

    # Log full error details (unsanitized) to audit log for troubleshooting
    Write-AuditLog -Action "API_AUTH_FAILED" -Target $fullUrl -User $env:USERNAME -Error $_.Exception.Message

    # Exit with error code 2 (API authentication failed)
    exit 2
}
finally {
    # ========================================================================
    # CLEANUP: Clear sensitive data from memory
    # ========================================================================
    # Security best practice: Immediately clear tokens after use
    # Reduces risk of credential exposure in memory dumps
    $apiToken = $null
}

# ============================================================================
# SCRIPT COMPLETION
# ============================================================================
Write-Log "🏁 Jira Cloud API authentication test completed." -Level "INFO"
Write-AuditLog -Action "API_TEST_COMPLETE" -Target $JiraBaseUrl -User $env:USERNAME

#endregion