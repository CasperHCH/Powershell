# Jira Bulk User Deletion Script with Enhanced Error Handling and Logging
# This script safely deletes users from a Jira On-Prem instance based on CSV input.
# Features: Input validation, logging, progress tracking, dry-run mode, and comprehensive error handling.
# Requires PowerShell 5.1 or later and Jira REST API access with admin privileges.

<#
.SYNOPSIS
  Enterprise-grade bulk user deletion for Jira On-Prem instances.

.DESCRIPTION
  This script safely processes CSV files to delete users from Jira using the REST API.
  Features include:
  - Input validation and safety checks
  - Comprehensive logging with timestamps
  - Progress tracking and statistics
  - Dry-run mode for testing
  - Detailed error reporting
  - Backup recommendations and confirmation prompts

.PARAMETER JiraBaseUrl
  The base URL of the Jira On-Prem instance (e.g., https://your-jira-instance.com).

.PARAMETER CsvPath
  Path to the CSV file containing usernames. Must have a "Username" column.

.PARAMETER Username
  Jira admin username for API authentication.

.PARAMETER ApiToken
  API token or password for the specified username.

.PARAMETER DryRun
  If specified, performs validation checks without actually deleting users.

.PARAMETER LogPath
  Optional path for detailed log file. Defaults to script directory.

.PARAMETER BatchSize
  Number of users to process in each batch (default: 10).

.PARAMETER DelayBetweenRequests
  Delay in milliseconds between API calls to avoid rate limiting (default: 500).

.EXAMPLE
  .\BulkDeleteUsers.ps1 -JiraBaseUrl "https://jira.company.com" -CsvPath "users.csv" -Username "admin" -ApiToken "your-token" -DryRun
  Performs a dry run to validate the CSV and check connectivity.

.EXAMPLE
  .\BulkDeleteUsers.ps1 -JiraBaseUrl "https://jira.company.com" -CsvPath "users.csv" -Username "admin" -ApiToken "your-token"
  Executes the actual user deletion process.

.NOTES
    Version:        2.0
    Author:         Casper Hjorth Christensen
    Creation Date:  2025-10-09
    Last Modified:  2025-10-09
    Purpose/Change: Enhanced enterprise version with safety features and comprehensive logging

.LINK
    https://developer.atlassian.com/server/jira/platform/rest-apis/
#>


[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiToken,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [string]$LogPath = (Join-Path $PSScriptRoot "JiraBulkDelete_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"),

    [Parameter()]
    [ValidateRange(1, 50)]
    [int]$BatchSize = 10,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$DelayBetweenRequests = 500
)

# Initialize logging and error tracking
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$VerbosePreference = 'Continue'

# Statistics tracking
$Stats = @{
    TotalUsers = 0
    SuccessCount = 0
    FailureCount = 0
    SkippedCount = 0
    StartTime = Get-Date
}

# Enhanced logging function
function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console with appropriate colors
    switch ($Level) {
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        default   { Write-Host $logEntry -ForegroundColor White }
    }

    # Write to log file
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

# Validate Jira connectivity
function Test-JiraConnection {
    param([hashtable]$Headers)

    try {
        Write-LogMessage "Testing Jira connectivity to $JiraBaseUrl..."
        $testUri = "$JiraBaseUrl/rest/api/2/myself"
        $response = Invoke-RestMethod -Uri $testUri -Method Get -Headers $Headers -TimeoutSec 30
        Write-LogMessage "✅ Successfully connected to Jira as: $($response.displayName)" -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-LogMessage "❌ Failed to connect to Jira: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Validate CSV structure
function Test-CsvStructure {
    param([string]$Path)

    try {
        Write-LogMessage "Validating CSV structure: $Path"
        $sample = Import-Csv -Path $Path | Select-Object -First 1

        if (-not $sample.PSObject.Properties.Name -contains 'Username') {
            throw "CSV file must contain a 'Username' column"
        }

        $totalUsers = (Import-Csv -Path $Path | Measure-Object).Count
        Write-LogMessage "✅ CSV validation successful. Found $totalUsers users to process." -Level 'SUCCESS'
        return $totalUsers
    }
    catch {
        Write-LogMessage "❌ CSV validation failed: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

# Delete single user with enhanced error handling
function Remove-JiraUser {
    param(
        [string]$Username,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    $uri = "$BaseUrl/rest/api/2/user?username=$([System.Web.HttpUtility]::UrlEncode($Username))"

    try {
        if ($DryRun) {
            # Dry run - just check if user exists
            $checkUri = "$BaseUrl/rest/api/2/user?username=$([System.Web.HttpUtility]::UrlEncode($Username))"
            $userInfo = Invoke-RestMethod -Uri $checkUri -Method Get -Headers $Headers -ErrorAction Stop
            Write-LogMessage "✅ [DRY RUN] User '$Username' exists and would be deleted (Display: $($userInfo.displayName))" -Level 'INFO'
            return @{ Success = $true; Action = 'DryRun' }
        }
        else {
            $response = Invoke-RestMethod -Uri $uri -Method Delete -Headers $Headers -ErrorAction Stop
            Write-LogMessage "✅ User '$Username' successfully deleted." -Level 'SUCCESS'
            return @{ Success = $true; Action = 'Deleted' }
        }
    }
    catch {
        $errorDetails = @{
            Success = $false
            Action = 'Failed'
            StatusCode = $null
            Message = $_.Exception.Message
        }

        if ($_.Exception.Response) {
            $errorDetails.StatusCode = $_.Exception.Response.StatusCode.value__

            switch ($_.Exception.Response.StatusCode.value__) {
                400 {
                    Write-LogMessage "⚠️ Bad request for user '$Username' - Invalid username format or parameters" -Level 'WARNING'
                    $errorDetails.Message = "Bad request - Invalid username format"
                }
                401 {
                    Write-LogMessage "🔒 Authentication failed for user '$Username' - Check credentials" -Level 'ERROR'
                    $errorDetails.Message = "Authentication failed"
                }
                403 {
                    Write-LogMessage "🚫 Insufficient permissions to delete user '$Username'" -Level 'ERROR'
                    $errorDetails.Message = "Insufficient permissions"
                }
                404 {
                    Write-LogMessage "❌ User '$Username' not found - May have been already deleted" -Level 'WARNING'
                    $errorDetails.Message = "User not found"
                    $errorDetails.Action = 'NotFound'
                }
                default {
                    Write-LogMessage "❗ HTTP $($_.Exception.Response.StatusCode.value__) error for user '$Username': $($_.Exception.Message)" -Level 'ERROR'
                }
            }
        }
        else {
            Write-LogMessage "❗ Network or connection error for user '$Username': $($_.Exception.Message)" -Level 'ERROR'
        }

        return $errorDetails
    }
}

# Main execution starts here
try {
    Write-LogMessage "=== Jira Bulk User Deletion Script Started ===" -Level 'INFO'
    Write-LogMessage "Script Version: 2.0" -Level 'INFO'
    Write-LogMessage "Execution Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE DELETION' })" -Level 'INFO'
    Write-LogMessage "Log File: $LogPath" -Level 'INFO'

    # Normalize Jira URL
    $JiraBaseUrl = $JiraBaseUrl.TrimEnd('/')

    # Create authentication header
    $authString = "$Username`:$ApiToken"
    $authBytes = [System.Text.Encoding]::UTF8.GetBytes($authString)
    $authHeader = @{
        'Authorization' = "Basic $([Convert]::ToBase64String($authBytes))"
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
    }

    # Validate connectivity
    if (-not (Test-JiraConnection -Headers $authHeader)) {
        throw "Unable to establish connection to Jira instance"
    }

    # Validate CSV and get user count
    $Stats.TotalUsers = Test-CsvStructure -Path $CsvPath

    # Safety confirmation for live runs
    if (-not $DryRun) {
        Write-LogMessage "" -Level 'WARNING'
        Write-LogMessage "⚠️  WARNING: This will PERMANENTLY DELETE $($Stats.TotalUsers) users from Jira!" -Level 'WARNING'
        Write-LogMessage "⚠️  Ensure you have a complete backup before proceeding!" -Level 'WARNING'
        Write-LogMessage "" -Level 'WARNING'

        $confirmation = Read-Host "Type 'DELETE' in uppercase to confirm this destructive operation"
        if ($confirmation -ne 'DELETE') {
            Write-LogMessage "Operation cancelled by user." -Level 'INFO'
            exit 0
        }
    }

    # Load and process users
    Write-LogMessage "Loading users from CSV: $CsvPath" -Level 'INFO'
    $users = Import-Csv -Path $CsvPath

    Write-LogMessage "Starting processing of $($Stats.TotalUsers) users in batches of $BatchSize..." -Level 'INFO'

    $processedCount = 0
    $batchCount = 1

    for ($i = 0; $i -lt $users.Count; $i += $BatchSize) {
        $batch = $users[$i..([Math]::Min($i + $BatchSize - 1, $users.Count - 1))]

        Write-LogMessage "Processing batch $batchCount (Users $($i + 1) - $([Math]::Min($i + $BatchSize, $users.Count)))" -Level 'INFO'

        foreach ($user in $batch) {
            $username = $user.Username.Trim()

            if ([string]::IsNullOrWhiteSpace($username)) {
                Write-LogMessage "⚠️ Skipping empty username in row $($processedCount + 1)" -Level 'WARNING'
                $Stats.SkippedCount++
                continue
            }

            try {
                $result = Remove-JiraUser -Username $username -Headers $authHeader -BaseUrl $JiraBaseUrl

                if ($result.Success) {
                    $Stats.SuccessCount++
                }
                else {
                    if ($result.Action -eq 'NotFound') {
                        $Stats.SkippedCount++
                    }
                    else {
                        $Stats.FailureCount++
                    }
                }

                $processedCount++

                # Progress indicator
                if ($processedCount % 5 -eq 0) {
                    $percentComplete = [Math]::Round(($processedCount / $Stats.TotalUsers) * 100, 2)
                    Write-LogMessage "Progress: $processedCount/$($Stats.TotalUsers) users processed ($percentComplete%)" -Level 'INFO'
                }

                # Rate limiting delay
                if ($DelayBetweenRequests -gt 0) {
                    Start-Sleep -Milliseconds $DelayBetweenRequests
                }
            }
            catch {
                Write-LogMessage "❌ Unexpected error processing user '$username': $($_.Exception.Message)" -Level 'ERROR'
                $Stats.FailureCount++
            }
        }

        $batchCount++

        # Small delay between batches
        if ($i + $BatchSize -lt $users.Count) {
            Start-Sleep -Milliseconds 1000
        }
    }

    # Generate final report
    $Stats.EndTime = Get-Date
    $Stats.Duration = $Stats.EndTime - $Stats.StartTime

    Write-LogMessage "" -Level 'INFO'
    Write-LogMessage "=== FINAL REPORT ===" -Level 'INFO'
    Write-LogMessage "Total Users: $($Stats.TotalUsers)" -Level 'INFO'
    Write-LogMessage "Successfully Processed: $($Stats.SuccessCount)" -Level 'SUCCESS'
    Write-LogMessage "Failed: $($Stats.FailureCount)" -Level $(if ($Stats.FailureCount -gt 0) { 'ERROR' } else { 'INFO' })
    Write-LogMessage "Skipped/Not Found: $($Stats.SkippedCount)" -Level 'WARNING'
    Write-LogMessage "Execution Time: $($Stats.Duration.ToString('hh\:mm\:ss'))" -Level 'INFO'
    Write-LogMessage "Mode: $(if ($DryRun) { 'DRY RUN - No users were actually deleted' } else { 'LIVE EXECUTION - Users were permanently deleted' })" -Level 'INFO'
    Write-LogMessage "Log File: $LogPath" -Level 'INFO'
    Write-LogMessage "=== Script Completed ===" -Level 'SUCCESS'

}
catch {
    Write-LogMessage "❌ Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-LogMessage "❌ Stack Trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit 1
}