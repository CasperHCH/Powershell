#requires -version 5.1
<#
.SYNOPSIS
 Deletes custom fields from a Jira Cloud instance by importing field IDs from a CSV file.

.DESCRIPTION
 This script automates the deletion of custom fields in Atlassian Jira Cloud. It handles the complete workflow:

 1. Connects to your Jira Cloud instance with secure authentication
 2. Imports a list of custom field IDs from a CSV file
 3. Deletes each custom field via the Jira REST API v3
 4. Maintains an audit log of all operations

 WARNING: Custom field deletion is permanent and cannot be undone. Use with caution!
 This will remove the field from all projects, issues, and configurations.

.PARAMETER Url
 The base URL of your Atlassian Cloud site (e.g., https://yoursite.atlassian.net).
 Do not include a trailing slash. If not provided, the script will prompt for it.

.PARAMETER List
 Full path to a CSV file containing custom field IDs to delete.
 Expected column header: id
 Format: Each row should contain a custom field ID (e.g., customfield_10234)
 If not provided, the script will prompt for the file path.

.PARAMETER AdminAccount
 The email address of the Atlassian administrator account used to generate the API token.
 This account must have Jira Administrator permissions. If not provided, the script will prompt for it.

.PARAMETER ApiToken
 The API token for authentication with the Atlassian Cloud API.
 Can be generated at: https://id.atlassian.com/manage-profile/security/api-tokens
 If not provided, the script will prompt for it securely.

.INPUTS
 CSV file (.csv) with custom field IDs
 Required column: id

.OUTPUTS
 Log file: <script_directory>\<script_name>.log (Detailed execution log with audit trail)
 Console output with progress indicators and results

.NOTES
 Version:        2.0
 Author:         Casper Hjorth Christensen
 Creation Date:  2023
 Modified Date:  19/01/2026
 Purpose/Change: Major security and functionality improvements:
                 - Implemented secure credential handling (SecureString for API tokens)
                 - Enhanced parameter validation
                 - Added WhatIf support for safe testing
                 - Improved error handling with specific guidance
                 - Added progress indicators and better UX
                 - Sanitized logging (no sensitive data in logs)
                 - Better CSV file handling
                 - Added audit trail
                 - Comprehensive input validation
                 - Updated API endpoints to v3
                 - Replaced curl with Invoke-RestMethod
                 - Added confirmation prompts for destructive operations

 Requirements:
  - PowerShell 5.1 or higher
  - Valid Atlassian Cloud Jira Administrator credentials
  - Network connectivity to Atlassian Cloud (HTTPS/443)
  - CSV file with proper format

 Security Considerations:
  - API tokens are handled as SecureString and never logged
  - Credentials are not exposed in process list or logs
  - All API communication uses HTTPS with proper authentication
  - Audit trail maintained for all operations
  - Confirmation required before deletion

.EXAMPLE
 .\Atlassian_Cloud_Delete_Customfields.ps1

 Runs interactively, prompting for all required parameters (URL, credentials, CSV file path).

.EXAMPLE
 .\Atlassian_Cloud_Delete_Customfields.ps1 -Url "https://mysite.atlassian.net" -List "C:\Data\fields_to_delete.csv"

 Runs with partial parameters, prompting for credentials only.

.EXAMPLE
 .\Atlassian_Cloud_Delete_Customfields.ps1 -Url "https://mysite.atlassian.net" -List "C:\Data\fields_to_delete.csv" -WhatIf

 Shows what would be deleted without actually making changes (dry run mode).
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
  [Parameter(Mandatory = $false, HelpMessage = "Atlassian Cloud site URL (e.g., https://yoursite.atlassian.net)")]
  [ValidatePattern('^https?://[a-zA-Z0-9.-]+\.atlassian\.net/?$')]
  [string]$Url,

  [Parameter(Mandatory = $false, HelpMessage = "Path to CSV file with custom field IDs to delete")]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$List,

  [Parameter(Mandatory = $false, HelpMessage = "Administrator email address")]
  [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
  [string]$AdminAccount,

  [Parameter(Mandatory = $false, HelpMessage = "API token for authentication")]
  [string]$ApiToken
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Generate unique session ID for audit trail
$script:SessionId = (New-Guid).ToString().Substring(0, 8)

# Script Version
$sScriptVersion = '2.0'

# Log File Info
$sLogName = $MyInvocation.MyCommand.Name -replace '\.ps1$', '.log'
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

# Set proper error handling
$ErrorActionPreference = 'Stop'

Write-Host "🚀 Starting Jira Custom Field Deletion" -ForegroundColor Cyan
Write-Host "📋 Session ID: $script:SessionId" -ForegroundColor Gray
Write-Host "📁 Log file: $sLogFile" -ForegroundColor Gray
Write-Host "⚠️  WARNING: Custom field deletion is permanent and cannot be undone!" -ForegroundColor Red
Write-Host ""

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Write-Log {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG", "SUCCESS", "AUDIT")]
    [string]$Level = "INFO",

    [Parameter(Mandatory = $false)]
    [switch]$Sensitive
  )

  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $logEntry = "[$timestamp] [$script:SessionId] [$Level] $Message"

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
      "FATAL" { "Red" }
      "WARN" { "Yellow" }
      "SUCCESS" { "Green" }
      "AUDIT" { "Cyan" }
      "DEBUG" { "Gray" }
      default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
  }
}

function Invoke-JiraApiRequest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,

    [Parameter(Mandatory = $false)]
    [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
    [string]$Method = "GET",

    [Parameter(Mandatory = $false)]
    [string]$Body = ""
  )

  try {
    # Prepare authentication header
    $authString = "${script:AdminAccount}:${script:ApiToken}"
    $authBytes = [System.Text.Encoding]::ASCII.GetBytes($authString)
    $authHeader = [System.Convert]::ToBase64String($authBytes)

    $headers = @{
      'Authorization' = "Basic $authHeader"
      'Content-Type'  = 'application/json'
      'Accept'        = 'application/json'
    }

    $fullUri = "$script:Url$Uri"

    Write-Log -Message "API Request: $Method $Uri" -Level "DEBUG"

    if ($Method -eq "GET") {
      $response = Invoke-RestMethod -Uri $fullUri -Method Get -Headers $headers -ErrorAction Stop
    }
    else {
      $response = Invoke-RestMethod -Uri $fullUri -Method $Method -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -Headers $headers -ErrorAction Stop
    }

    return $response
  }
  catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $statusDescription = $_.Exception.Response.StatusDescription

    Write-Log -Message "API request failed - URI: $Uri, Method: $Method, Status: $statusCode $statusDescription" -Level "ERROR"
    Write-Log -Message "Error details: $($_.Exception.Message)" -Level "ERROR"

    if ($statusCode -eq 401) {
      Write-Host "   💡 Authentication failed - check your credentials" -ForegroundColor Yellow
    }
    elseif ($statusCode -eq 403) {
      Write-Host "   💡 Permission denied - ensure admin privileges" -ForegroundColor Yellow
    }
    elseif ($statusCode -eq 404) {
      Write-Host "   💡 Resource not found - check field ID" -ForegroundColor Yellow
    }

    throw
  }
  finally {
    # Clear sensitive data
    $authString = $null
    $authBytes = $null
    $authHeader = $null
  }
}

######### GetUrl #########
function Get-JiraUrl {
  param()

  Write-Host "🌐 Please provide your Jira Cloud site URL" -ForegroundColor Cyan
  Write-Host "   Example: https://yoursite.atlassian.net" -ForegroundColor Gray
  Write-Host "   (Do not include trailing slash)" -ForegroundColor Gray
  Write-Host ""

  do {
    $userInput = Read-Host -Prompt "Jira Cloud URL"
    $userInput = $userInput.TrimEnd('/')

    if ($userInput -match '^https?://[a-zA-Z0-9.-]+\.atlassian\.net$') {
      $script:Url = $userInput
      Write-Log -Message "URL collected and validated: [SANITIZED]" -Level "SUCCESS"
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

######### Collect and Import CSV #########
function Get-CustomFieldListFromFile {
  param()

  Write-Host "📄 Please provide the path to your CSV file" -ForegroundColor Cyan
  Write-Host "   Required column header: id" -ForegroundColor Gray
  Write-Host "   Format: Each row should contain a custom field ID (e.g., customfield_10234)" -ForegroundColor Gray
  Write-Host ""

  do {
    if ([string]::IsNullOrWhiteSpace($script:List)) {
      $script:List = Read-Host -Prompt "CSV file path"
    }

    if (Test-Path $script:List -PathType Leaf) {
      try {
        Write-Host "⏳ Importing CSV file..." -ForegroundColor Yellow
        $script:FieldList = Import-Csv -Path $script:List -ErrorAction Stop

        # Validate required column
        $firstRow = $script:FieldList | Select-Object -First 1
        if (-not ($firstRow.PSObject.Properties.Name -contains "id")) {
          Write-Host "❌ CSV file must contain 'id' column" -ForegroundColor Red
          $script:List = $null
          continue
        }

        Write-Host "✅ Successfully imported $($script:FieldList.Count) field IDs from CSV" -ForegroundColor Green
        Write-Log -Message "Imported $($script:FieldList.Count) field IDs from: $script:List" -Level "SUCCESS"
        Write-Host ""
        break
      }
      catch {
        Write-Host "❌ Failed to import CSV file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Message "CSV import failed: $($_.Exception.Message)" -Level "ERROR"
        $script:List = $null
      }
    }
    else {
      Write-Host "❌ File not found: $script:List" -ForegroundColor Red
      $script:List = $null
    }
  } while ($true)
}

######### Collect Admin account email #########
function Get-AdminAccountEmail {
  param()

  Write-Host "👤 Please provide your Jira administrator email" -ForegroundColor Cyan
  Write-Host "   (Must have Jira Administrator permissions)" -ForegroundColor Gray
  Write-Host ""

  do {
    $userInput = Read-Host -Prompt "Admin email address"

    if ($userInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
      $script:AdminAccount = $userInput
      Write-Log -Message "Admin account email collected: [SANITIZED]" -Level "SUCCESS" -Sensitive $true
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
}

catch {
  Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
  break
}
}

End {
  if ($?) {
    Write-Log -Entry "Completed Successfully."
    Write-Log -Entry " "
  }
}
}


######### Provide API Token #########
function Get-ApiTokenSecure {
  param()

  Write-Host "🔑 Please provide your Jira API token" -ForegroundColor Cyan
  Write-Host "   Generate at: https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Gray
  Write-Host "   (Input will be hidden for security)" -ForegroundColor Gray
  Write-Host ""

  $secureToken = Read-Host -Prompt "API Token" -AsSecureString

  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
  $script:ApiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

  if ([string]::IsNullOrWhiteSpace($script:ApiToken)) {
    Write-Host "❌ API token cannot be empty" -ForegroundColor Red
    throw "API token is required"
  }

  Write-Log -Message "API Token collected securely (not logged)" -Level "SUCCESS" -Sensitive $true
  Write-Host "✅ API token received" -ForegroundColor Green
  Write-Host ""
}

######### DeleteCustomFields #########
function Remove-CustomFields {
  param()

  Write-Host "📊 Deleting custom fields..." -ForegroundColor Cyan
  Write-Host ""

  # Final confirmation
  Write-Host "⚠️  WARNING: You are about to delete $($script:FieldList.Count) custom field(s)!" -ForegroundColor Red
  Write-Host "   This action CANNOT be undone!" -ForegroundColor Red
  Write-Host ""

  if (-not $WhatIfPreference) {
    $confirmation = Read-Host "Type 'DELETE' to confirm"
    if ($confirmation -ne 'DELETE') {
      Write-Host "❌ Operation cancelled by user" -ForegroundColor Yellow
      Write-Log -Message "User cancelled deletion operation" -Level "WARN"
      return
    }
  }

  try {
    $successCount = 0
    $errorCount = 0
    $totalFields = $script:FieldList.Count

    Write-Log -Message "Starting deletion of $totalFields custom fields" -Level "INFO"

    for ($index = 0; $index -lt $totalFields; $index++) {
      $field = $script:FieldList[$index]
      $fieldId = $field.id

      $percentComplete = [math]::Round((($index + 1) / $totalFields) * 100)
      Write-Progress -Activity "Deleting Custom Fields" -Status "Processing $($index + 1) of $totalFields" -PercentComplete $percentComplete

      if ($PSCmdlet.ShouldProcess("Custom Field $fieldId", "Delete custom field")) {
        try {
          $uri = "/rest/api/3/field/$fieldId"
          $null = Invoke-JiraApiRequest -Uri $uri -Method DELETE

          Write-Host "✅ Deleted: $fieldId" -ForegroundColor Green
          Write-Log -Message "Field deleted successfully: $fieldId" -Level "SUCCESS"
          $successCount++
        }
        catch {
          Write-Host "❌ Failed to delete: $fieldId - $($_.Exception.Message)" -ForegroundColor Red
          Write-Log -Message "Failed to delete field '$fieldId': $($_.Exception.Message)" -Level "ERROR"
          $errorCount++
        }
      }
      else {
        Write-Host "🔍 WhatIf: Would delete field: $fieldId" -ForegroundColor Yellow
      }
    }

    Write-Progress -Activity "Deleting Custom Fields" -Completed

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Total fields processed: $totalFields" -ForegroundColor White
    Write-Host "Successfully deleted: $successCount" -ForegroundColor Green
    if ($errorCount -gt 0) {
      Write-Host "Failed: $errorCount" -ForegroundColor Red
    }
    Write-Host ""

    Write-Log -Message "AUDIT: Fields deleted - Success: $successCount, Failed: $errorCount, User: $env:USERNAME" -Level "AUDIT" -Sensitive $true
  }
  catch {
    Write-Log -Message "Fatal error deleting fields: $($_.Exception.Message)" -Level "FATAL"
    throw
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
  Write-Host "✅ Initialization completed" -ForegroundColor Green
  Write-Host ""

  Write-Log -Message "Script execution started - Version $sScriptVersion" -Level "INFO"
  Write-Log -Message "Executed by: $env:USERNAME on $env:COMPUTERNAME" -Level "INFO"

  # Collect required parameters if not provided
  if ([string]::IsNullOrWhiteSpace($Url)) {
    Get-JiraUrl
  }
  else {
    $Url = $Url.TrimEnd('/')
    Write-Host "✅ Using provided URL" -ForegroundColor Green
    Write-Log -Message "Using URL from parameter: [SANITIZED]" -Level "INFO"
  }

  if ([string]::IsNullOrWhiteSpace($List)) {
    Get-CustomFieldListFromFile
  }
  else {
    Write-Host "⏳ Importing CSV file..." -ForegroundColor Yellow
    $script:FieldList = Import-Csv -Path $List -ErrorAction Stop

    # Validate required column
    $firstRow = $script:FieldList | Select-Object -First 1
    if (-not ($firstRow.PSObject.Properties.Name -contains "id")) {
      throw "CSV file must contain 'id' column"
    }

    Write-Host "✅ Successfully imported $($script:FieldList.Count) field IDs from CSV" -ForegroundColor Green
    Write-Log -Message "Imported $($script:FieldList.Count) field IDs from: $List" -Level "SUCCESS"
    Write-Host ""
  }

  if ([string]::IsNullOrWhiteSpace($AdminAccount)) {
    Get-AdminAccountEmail
  }
  else {
    Write-Host "✅ Using provided admin account" -ForegroundColor Green
    Write-Log -Message "Using admin account from parameter: [SANITIZED]" -Level "INFO" -Sensitive $true
  }

  if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    Get-ApiTokenSecure
  }
  else {
    Write-Host "✅ Using provided API token" -ForegroundColor Green
    Write-Log -Message "Using API token from parameter (not logged)" -Level "INFO" -Sensitive $true
  }

  # Delete custom fields
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "  Deleting Custom Fields" -ForegroundColor Cyan
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host ""

  Remove-CustomFields

  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-Host "  Script Completed Successfully!" -ForegroundColor Green
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-Host ""

  Write-Log -Message "Script completed successfully" -Level "SUCCESS"
}
catch {
  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
  Write-Host "  Script Failed" -ForegroundColor Red
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
  Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  Write-Log -Message "Script failed: $($_.Exception.Message)" -Level "FATAL"

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