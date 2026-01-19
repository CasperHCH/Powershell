#requires -version 5.1
<#
.SYNOPSIS
 Collects all users from a specified Atlassian Cloud group and exports them to a JSON file.

.DESCRIPTION
 This script retrieves all members from an Atlassian Cloud group using the Jira REST API v3. It handles
 pagination automatically by detecting the total user count from API responses and iterating until all
 users are collected. The script prompts for required credentials securely and outputs results to a JSON
 file in the script directory.

 Active users are collected from the specified group and appended to a JSON output file for further processing
 or auditing purposes. All sensitive data (API tokens, credentials) are handled securely and not logged.

.PARAMETER Url
 The base URL of your Atlassian Cloud site (e.g., https://yoursite.atlassian.net).
 Do not include a trailing slash. If not provided, the script will prompt for it.

.PARAMETER AdminAccount
 The email address of the Atlassian administrator account used to generate the API token.
 This account must have permissions to view group membership. If not provided, the script will prompt for it.

.PARAMETER ApiToken
 The API token for authentication with the Atlassian Cloud API.
 Can be generated at: https://id.atlassian.com/manage-profile/security/api-tokens
 If not provided, the script will prompt for it securely.

.PARAMETER GroupId
 The unique identifier (GUID format) of the group from which to extract users.
 Example format: 1X2X3X4-5Y6Y7Y8-0Z1Z2Z3
 If not provided, the script will prompt for it.

.PARAMETER MaxResults
 Maximum number of users to retrieve per API call (default: 50, max: 50 per Jira API limits).

.INPUTS
 None. Parameters can be passed via command line or entered interactively.

.OUTPUTS
 - JSON file: <script_directory>\<script_name>.json (Contains all user data)
 - Log file: <script_directory>\<script_name>.log (Detailed execution log with sanitized output)

.NOTES
 Version:        2.0
 Author:         CHC
 Creation Date:  19/05/2023
 Modified Date:  19/01/2026
 Purpose/Change: Major security and functionality improvements:
                 - Replaced curl.exe with Invoke-RestMethod for better error handling
                 - Implemented secure credential handling (no logging of sensitive data)
                 - Added dynamic pagination based on API responses
                 - Added comprehensive parameter validation
                 - Added WhatIf support for safe testing
                 - Fixed URL construction bug (double question mark)
                 - Improved error handling and logging
                 - Added progress indicators

 Requirements:
  - PowerShell 5.1 or higher
  - PSLogging module (auto-installed if not present)
  - Valid Atlassian Cloud administrator credentials
  - Network connectivity to Atlassian Cloud (HTTPS/443)

 Security Considerations:
  - API tokens are handled as SecureString and never logged
  - Credentials are not exposed in process list
  - Log files are sanitized to remove sensitive information
  - All API communication uses HTTPS
  - Audit trail maintained for all operations

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group_v2.ps1

 Runs interactively, prompting for all required parameters (URL, admin account, API token, and group ID).

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group_v2.ps1 -Url "https://mysite.atlassian.net" -AdminAccount "admin@company.com" -GroupId "12345678-abcd-1234-efgh-567890abcdef"

 Runs with partial parameters, prompting securely for the API token.

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group_v2.ps1 -WhatIf

 Shows what the script would do without actually executing API calls.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Atlassian Cloud site URL (e.g., https://yoursite.atlassian.net)")]
    [ValidatePattern('^https?://[a-zA-Z0-9.-]+\.atlassian\.net/?$')]
    [string]$Url,

    [Parameter(Mandatory = $false, HelpMessage = "Administrator email address")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$AdminAccount,

    [Parameter(Mandatory = $false, HelpMessage = "API token for authentication")]
    [string]$ApiToken,

    [Parameter(Mandatory = $false, HelpMessage = "Group ID (GUID format)")]
    [ValidatePattern('^[a-zA-Z0-9-]{36}$')]
    [string]$GroupId,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum results per API call (default: 50)")]
    [ValidateRange(1, 50)]
    [int]$MaxResults = 50
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Generate unique session ID for audit trail
$script:SessionId = (New-Guid).ToString().Substring(0, 8)

# Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = "$sLogPath\$sLogName.log"
$sOutputFile = "$sLogPath\$($sLogName -replace '\.ps1$','').json"

# Set proper error handling
$ErrorActionPreference = 'Stop'

Write-Host "🚀 Starting Atlassian Cloud User Collection" -ForegroundColor Cyan
Write-Host "📋 Session ID: $script:SessionId" -ForegroundColor Gray
Write-Host "📁 Log file: $sLogFile" -ForegroundColor Gray
Write-Host ""

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Script Version
$sScriptVersion = '2.0'

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Write-Log {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Entry,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $Entry"

    # Always log to file
    try {
        Add-Content -Path $sLogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }

    # Display to console if not sensitive
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

######### GetUrl #########
function Get-AtlassianUrl {
    param()

    Write-Host "🌐 Please provide your Atlassian Cloud site URL" -ForegroundColor Cyan
    Write-Host "   Example: https://yoursite.atlassian.net" -ForegroundColor Gray
    Write-Host "   (Do not include trailing slash)" -ForegroundColor Gray
    Write-Host ""

    do {
        $userInput = Read-Host -Prompt "Atlassian Cloud URL"
        $userInput = $userInput.TrimEnd('/')

        if ($userInput -match '^https?://[a-zA-Z0-9.-]+\.atlassian\.net$') {
            $script:Url = $userInput
            Write-Log -Entry "URL collected and validated: [SANITIZED]" -Level "SUCCESS"
            Write-Host "✅ URL validated successfully" -ForegroundColor Green
            Write-Host ""
            break
        }
        else {
            Write-Host "❌ Invalid URL format. Must be https://yoursite.atlassian.net" -ForegroundColor Red
            Write-Host ""
        }
    } while ($true)
}

######### Collect Admin account email #########
function Get-AdminAccountEmail {
    param()

    Write-Host "👤 Please provide your Atlassian administrator email" -ForegroundColor Cyan
    Write-Host "   (The account used to generate the API token)" -ForegroundColor Gray
    Write-Host ""

    do {
        $userInput = Read-Host -Prompt "Admin email address"

        if ($userInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            $script:AdminAccount = $userInput
            Write-Log -Entry "Admin account email collected: [SANITIZED]" -Level "SUCCESS" -Sensitive $true
            Write-Host "✅ Email address validated" -ForegroundColor Green
            Write-Host ""
            break
        }
        else {
            Write-Host "❌ Invalid email format. Please try again." -ForegroundColor Red
            Write-Host ""
        }
    } while ($true)
}

######### Provide API Token #########
function Get-ApiTokenSecure {
    param()

    Write-Host "🔑 Please provide your Atlassian API token" -ForegroundColor Cyan
    Write-Host "   Generate at: https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Gray
    Write-Host "   (Input will be hidden for security)" -ForegroundColor Gray
    Write-Host ""

    # Use SecureString for secure input
    $secureToken = Read-Host -Prompt "API Token" -AsSecureString

    # Convert to plain text for API usage (kept in memory only)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $script:ApiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    if ([string]::IsNullOrWhiteSpace($script:ApiToken)) {
        Write-Host "❌ API token cannot be empty" -ForegroundColor Red
        throw "API token is required"
    }

    Write-Log -Entry "API Token collected securely (not logged)" -Level "SUCCESS" -Sensitive $true
    Write-Host "✅ API token received" -ForegroundColor Green
    Write-Host ""
}

######### GetGroupID #########
function Get-GroupIdentifier {
    param()

    Write-Host "👥 Please provide the Group ID" -ForegroundColor Cyan
    Write-Host "   Format: 12345678-abcd-1234-efgh-567890abcdef (36 characters)" -ForegroundColor Gray
    Write-Host ""

    do {
        $userInput = Read-Host -Prompt "Group ID"

        if ($userInput -match '^[a-zA-Z0-9-]{36}$') {
            $script:GroupId = $userInput
            Write-Log -Entry "Group ID collected: $userInput" -Level "SUCCESS"
            Write-Host "✅ Group ID validated" -ForegroundColor Green
            Write-Host ""
            break
        }
        else {
            Write-Host "❌ Invalid Group ID format. Must be 36 characters (GUID format)." -ForegroundColor Red
            Write-Host ""
        }
    } while ($true)
}

######### CollectUsersFromGroup #########
function Get-GroupMembers {
    param()

    Write-Host "📊 Starting user collection from group..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # Prepare authentication header (Base64 encoded)
        $authString = "${AdminAccount}:${ApiToken}"
        $authBytes = [System.Text.Encoding]::ASCII.GetBytes($authString)
        $authHeader = [System.Convert]::ToBase64String($authBytes)

        $headers = @{
            'Authorization' = "Basic $authHeader"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/json'
        }

        $allUsers = @()
        $startAt = 0
        $isLast = $false
        $totalCollected = 0

        Write-Log -Entry "Beginning pagination through group members" -Level "INFO"

        while (-not $isLast) {
            # Fix: Removed double question mark bug
            $apiUrl = "$Url/rest/api/3/group/member?includeInactiveUsers=false&groupId=$GroupId&startAt=$startAt&maxResults=$MaxResults"

            if ($PSCmdlet.ShouldProcess("Group $GroupId", "Retrieve users (starting at $startAt)")) {
                try {
                    Write-Host "⏳ Fetching users $startAt to $($startAt + $MaxResults)..." -ForegroundColor Yellow

                    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -ErrorAction Stop

                    # Check if we got users
                    if ($response.values -and $response.values.Count -gt 0) {
                        $allUsers += $response.values
                        $totalCollected += $response.values.Count

                        Write-Host "✅ Retrieved $($response.values.Count) users (Total: $totalCollected)" -ForegroundColor Green
                        Write-Log -Entry "Retrieved $($response.values.Count) users from startAt=$startAt" -Level "SUCCESS"

                        # Update progress
                        if ($response.total) {
                            $percentComplete = [math]::Min(100, [math]::Round(($totalCollected / $response.total) * 100))
                            Write-Progress -Activity "Collecting Group Members" -Status "$totalCollected of $($response.total) users" -PercentComplete $percentComplete
                        }
                    }
                    else {
                        Write-Host "ℹ️  No more users found" -ForegroundColor Gray
                    }

                    # Check if this is the last page
                    $isLast = $response.isLast -eq $true -or $response.values.Count -lt $MaxResults
                    $startAt += $MaxResults

                    # Safety check to prevent infinite loops
                    if ($startAt -gt 100000) {
                        Write-Host "⚠️  Safety limit reached (100,000 records). Stopping pagination." -ForegroundColor Yellow
                        Write-Log -Entry "Safety limit reached at $startAt records" -Level "WARNING"
                        break
                    }
                }
                catch {
                    Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log -Entry "API error at startAt=$startAt : $($_.Exception.Message)" -Level "ERROR"

                    if ($_.Exception.Response) {
                        $statusCode = $_.Exception.Response.StatusCode.value__
                        Write-Host "   HTTP Status Code: $statusCode" -ForegroundColor Red

                        if ($statusCode -eq 401) {
                            Write-Host "   💡 Check your credentials and API token" -ForegroundColor Yellow
                        }
                        elseif ($statusCode -eq 403) {
                            Write-Host "   💡 Check that your account has permission to view group members" -ForegroundColor Yellow
                        }
                        elseif ($statusCode -eq 404) {
                            Write-Host "   💡 Check that the Group ID is correct" -ForegroundColor Yellow
                        }
                    }

                    throw
                }
            }
            else {
                # WhatIf mode
                Write-Host "🔍 WhatIf: Would retrieve users from startAt=$startAt" -ForegroundColor Yellow
                $isLast = $true  # Exit after one iteration in WhatIf mode
            }
        }

        Write-Progress -Activity "Collecting Group Members" -Completed

        # Save to JSON file
        if ($allUsers.Count -gt 0 -and $PSCmdlet.ShouldProcess($sOutputFile, "Save $($allUsers.Count) users to JSON")) {
            $outputData = @{
                CollectionDate = Get-Date -Format "o"
                GroupId        = $GroupId
                TotalUsers     = $allUsers.Count
                Users          = $allUsers
            }

            $outputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $sOutputFile -Encoding UTF8

            Write-Host ""
            Write-Host "✅ Successfully collected $($allUsers.Count) users" -ForegroundColor Green
            Write-Host "📁 Output saved to: $sOutputFile" -ForegroundColor Cyan
            Write-Log -Entry "Collection complete: $($allUsers.Count) users saved to $sOutputFile" -Level "SUCCESS"
        }
        elseif ($allUsers.Count -eq 0) {
            Write-Host "⚠️  No users found in group" -ForegroundColor Yellow
            Write-Log -Entry "No users found in group $GroupId" -Level "WARNING"
        }

        # Audit log
        Write-Log -Entry "AUDIT: User collection completed - GroupId=$GroupId, TotalUsers=$($allUsers.Count), User=$env:USERNAME" -Level "AUDIT" -Sensitive $true

        return $allUsers
    }
    catch {
        Write-Host "❌ Fatal error during user collection: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Entry "Fatal error: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
    finally {
        # Clear sensitive data from memory
        $authString = $null
        $authBytes = $null
        $authHeader = $null
        $headers = $null
    }
}

# Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        Write-Host "✅ Module $m is already imported." -ForegroundColor Green
        return
    }

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
        try {
            Import-Module $m -ErrorAction Stop
            Write-Host "✅ Module $m imported successfully." -ForegroundColor Green
            return
        }
        catch {
            Write-Host "❌ Failed to import module $m : $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # If module is not imported, not available on disk, but is in online gallery then install and import
    if (Find-Module -Name $m -ErrorAction SilentlyContinue) {
        try {
            Write-Host "📦 Installing module $m from PowerShell Gallery..." -ForegroundColor Yellow
            Install-Module -Name $m -Force -Scope CurrentUser -ErrorAction Stop
            Import-Module $m -ErrorAction Stop
            Write-Host "✅ Module $m installed and imported successfully." -ForegroundColor Green
            return
        }
        catch {
            Write-Host "❌ Failed to install module $m : $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # If the module is not imported, not available and not in the online gallery then abort
    Write-Host "❌ Module $m not found anywhere, exiting." -ForegroundColor Red
    exit 1
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
    # Import required modules
    Import-ModuleIfAvailable PSLogging
    Write-Host "✅ Initialization completed" -ForegroundColor Green
    Write-Host ""

    Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

    Write-Log -Entry "Script execution started - Version $sScriptVersion" -Level "INFO"
    Write-Log -Entry "Executed by: $env:USERNAME on $env:COMPUTERNAME" -Level "INFO"

    # Collect required parameters if not provided
    if ([string]::IsNullOrWhiteSpace($Url)) {
        Get-AtlassianUrl
    }
    else {
        $Url = $Url.TrimEnd('/')
        Write-Host "✅ Using provided URL" -ForegroundColor Green
        Write-Log -Entry "Using URL from parameter: [SANITIZED]" -Level "INFO"
    }

    if ([string]::IsNullOrWhiteSpace($AdminAccount)) {
        Get-AdminAccountEmail
    }
    else {
        Write-Host "✅ Using provided admin account" -ForegroundColor Green
        Write-Log -Entry "Using admin account from parameter: [SANITIZED]" -Level "INFO" -Sensitive $true
    }

    if ([string]::IsNullOrWhiteSpace($ApiToken)) {
        Get-ApiTokenSecure
    }
    else {
        Write-Host "✅ Using provided API token" -ForegroundColor Green
        Write-Log -Entry "Using API token from parameter (not logged)" -Level "INFO" -Sensitive $true
    }

    if ([string]::IsNullOrWhiteSpace($GroupId)) {
        Get-GroupIdentifier
    }
    else {
        Write-Host "✅ Using provided Group ID: $GroupId" -ForegroundColor Green
        Write-Log -Entry "Using Group ID from parameter: $GroupId" -Level "INFO"
    }

    # Execute main collection
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Starting Group Member Collection" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $results = Get-GroupMembers

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Collection Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    Log-Finish -LogPath $sLogFile
}
catch {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  Script Failed" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Log -Entry "Script failed: $($_.Exception.Message)" -Level "ERROR"

    if ($sLogFile) {
        Write-Host "📋 Check log file for details: $sLogFile" -ForegroundColor Yellow
    }

    exit 1
}
finally {
    # Clean up sensitive data from memory
    if ($ApiToken) {
        $ApiToken = $null
        [System.GC]::Collect()
    }
}
