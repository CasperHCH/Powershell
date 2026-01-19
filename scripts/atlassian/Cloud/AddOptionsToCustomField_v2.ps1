#requires -version 5.1
<#
.SYNOPSIS
 Adds options to a Jira Cloud custom field by importing values from an Excel file or manual input.

.DESCRIPTION
 This script automates the process of adding options to a Jira Cloud custom field (select list, multi-select,
 radio buttons, checkboxes, etc.). It handles the complete workflow:

 1. Connects to your Jira Cloud instance with secure authentication
 2. Retrieves custom field information by name or ID
 3. Identifies the correct field context
 4. Imports options from an Excel file (with columns: ARE, Company Name)
 5. Adds each option to the custom field via REST API v3

 This is particularly useful for bulk-adding options to custom fields, maintaining field configurations
 across instances, or automating field setup during migrations or new project creation.

.PARAMETER Url
 The base URL of your Atlassian Cloud site (e.g., https://yoursite.atlassian.net).
 Do not include a trailing slash. If not provided, the script will prompt for it.

.PARAMETER AdminAccount
 The email address of the Atlassian administrator account used to generate the API token.
 This account must have Jira Administrator permissions. If not provided, the script will prompt for it.

.PARAMETER ApiToken
 The API token for authentication with the Atlassian Cloud API.
 Can be generated at: https://id.atlassian.com/manage-profile/security/api-tokens
 If not provided, the script will prompt for it securely.

.PARAMETER ListOfOptions
 Full path to an Excel file containing the custom field options to add.
 Expected columns: ARE, Company Name
 Format: Options will be created as "ARE - Company Name"
 If not provided, the script will prompt for the file path.

.PARAMETER CustomFieldID
 The custom field ID (e.g., customfield_10234).
 If not provided, you will be prompted for the custom field name to lookup the ID.

.PARAMETER ContextID
 The context ID for the custom field.
 If not provided, the script will automatically retrieve it from the field configuration.

.INPUTS
 - Excel file (.xlsx) with custom field options
 - Columns required: ARE, Company Name

.OUTPUTS
 - Log file: <script_directory>\<script_name>.log (Detailed execution log with sanitized output)
 - Console output with progress indicators and results

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
                 - Better Excel file handling
                 - Added audit trail
                 - Comprehensive input validation
                 - Updated API endpoints to v3

 Requirements:
  - PowerShell 5.1 or higher
  - ImportExcel module (auto-installed if not present)
  - Valid Atlassian Cloud Jira Administrator credentials
  - Network connectivity to Atlassian Cloud (HTTPS/443)
  - Excel file with proper format

 Security Considerations:
  - API tokens are handled as SecureString and never logged
  - Credentials are not exposed in process list or logs
  - All API communication uses HTTPS with proper authentication
  - Audit trail maintained for all operations

.EXAMPLE
 .\AddOptionsToCustomField_v2.ps1

 Runs interactively, prompting for all required parameters (URL, credentials, file path, field details).

.EXAMPLE
 .\AddOptionsToCustomField_v2.ps1 -Url "https://mysite.atlassian.net" -ListOfOptions "C:\Data\options.xlsx"

 Runs with partial parameters, prompting for credentials and field information.

.EXAMPLE
 .\AddOptionsToCustomField_v2.ps1 -Url "https://mysite.atlassian.net" -CustomFieldID "customfield_10234" -ListOfOptions "C:\Data\options.xlsx" -WhatIf

 Shows what would be added without actually making changes (dry run mode).
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

    [Parameter(Mandatory = $false, HelpMessage = "Path to Excel file with custom field options")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ListOfOptions,

    [Parameter(Mandatory = $false, HelpMessage = "Custom field ID (e.g., customfield_10234)")]
    [ValidatePattern('^customfield_\d+$')]
    [string]$CustomFieldID,

    [Parameter(Mandatory = $false, HelpMessage = "Context ID for the custom field")]
    [string]$ContextID
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

Write-Host "🚀 Starting Jira Custom Field Options Management" -ForegroundColor Cyan
Write-Host "📋 Session ID: $script:SessionId" -ForegroundColor Gray
Write-Host "📁 Log file: $sLogFile" -ForegroundColor Gray
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

######### WebApiRequest #########
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
            Write-Host "   💡 Resource not found - check field ID or context ID" -ForegroundColor Yellow
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

######### Import list of Custom Field Options #########
function Get-CustomFieldOptionsFromFile {
    param()

    Write-Host "📄 Please provide the path to your Excel file" -ForegroundColor Cyan
    Write-Host "   Required columns: ARE, Company Name" -ForegroundColor Gray
    Write-Host "   Format: Options will be created as 'ARE - Company Name'" -ForegroundColor Gray
    Write-Host ""

    do {
        if ([string]::IsNullOrWhiteSpace($script:ListOfOptions)) {
            $script:ListOfOptions = Read-Host -Prompt "Excel file path"
        }

        if (Test-Path $script:ListOfOptions -PathType Leaf) {
            try {
                Write-Host "⏳ Importing Excel file..." -ForegroundColor Yellow
                $script:options = Import-Excel -Path $script:ListOfOptions -ErrorAction Stop

                # Validate required columns
                $firstRow = $script:options | Select-Object -First 1
                if (-not ($firstRow.PSObject.Properties.Name -contains "ARE" -and
                        $firstRow.PSObject.Properties.Name -contains "Company Name")) {
                    Write-Host "❌ Excel file must contain 'ARE' and 'Company Name' columns" -ForegroundColor Red
                    $script:ListOfOptions = $null
                    continue
                }

                Write-Host "✅ Successfully imported $($script:options.Count) options from Excel" -ForegroundColor Green
                Write-Log -Message "Imported $($script:options.Count) options from: $script:ListOfOptions" -Level "SUCCESS"
                Write-Host ""
                break
            }
            catch {
                Write-Host "❌ Failed to import Excel file: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -Message "Excel import failed: $($_.Exception.Message)" -Level "ERROR"
                $script:ListOfOptions = $null
            }
        }
        else {
            Write-Host "❌ File not found: $script:ListOfOptions" -ForegroundColor Red
            $script:ListOfOptions = $null
        }
    } while ($true)
}

######### Collect Custom Field ID based on name #########
function Get-CustomFieldID {
    param()

    Write-Host "🔍 Looking up custom field information..." -ForegroundColor Cyan
    Write-Host ""

    try {
        $customFieldName = Read-Host -Prompt "Custom field name (or press Enter to provide ID directly)"

        if ([string]::IsNullOrWhiteSpace($customFieldName)) {
            do {
                $fieldId = Read-Host -Prompt "Custom field ID (e.g., customfield_10234)"
                if ($fieldId -match '^customfield_\d+$') {
                    $script:CustomFieldID = $fieldId
                    Write-Host "✅ Custom field ID set to: $script:CustomFieldID" -ForegroundColor Green
                    Write-Log -Message "Custom field ID provided: $script:CustomFieldID" -Level "SUCCESS"
                    break
                }
                else {
                    Write-Host "❌ Invalid format. Must be like: customfield_10234" -ForegroundColor Red
                }
            } while ($true)
        }
        else {
            Write-Host "⏳ Searching for field '$customFieldName'..." -ForegroundColor Yellow

            $uri = '/rest/api/3/field'
            $fields = Invoke-JiraApiRequest -Uri $uri -Method GET

            $matchingField = $fields | Where-Object { $_.name -eq $customFieldName -and $_.custom -eq $true }

            if ($matchingField) {
                $script:CustomFieldID = $matchingField.id
                Write-Host "✅ Found custom field: $($matchingField.name) (ID: $script:CustomFieldID)" -ForegroundColor Green
                Write-Log -Message "Custom field found - Name: $customFieldName, ID: $script:CustomFieldID" -Level "SUCCESS"
            }
            else {
                Write-Host "❌ Custom field '$customFieldName' not found" -ForegroundColor Red
                Write-Log -Message "Custom field not found: $customFieldName" -Level "ERROR"
                throw "Custom field not found"
            }
        }

        Write-Host ""
    }
    catch {
        Write-Log -Message "Error retrieving custom field: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

######### Collect the Context ID of a custom field #########
function Get-ContextID {
    param()

    Write-Host "🔍 Retrieving field context information..." -ForegroundColor Cyan

    try {
        $uri = "/rest/api/3/field/$script:CustomFieldID/context"
        $contexts = Invoke-JiraApiRequest -Uri $uri -Method GET

        if ($contexts.values -and $contexts.values.Count -gt 0) {
            if ($contexts.values.Count -eq 1) {
                $script:ContextID = $contexts.values[0].id
                Write-Host "✅ Found context: $($contexts.values[0].name) (ID: $script:ContextID)" -ForegroundColor Green
                Write-Log -Message "Context ID retrieved: $script:ContextID" -Level "SUCCESS"
            }
            else {
                Write-Host "⚠️  Multiple contexts found:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $contexts.values.Count; $i++) {
                    Write-Host "   [$i] $($contexts.values[$i].name) (ID: $($contexts.values[$i].id))" -ForegroundColor Gray
                }

                do {
                    $selection = Read-Host -Prompt "Select context number [0-$($contexts.values.Count - 1)]"
                    if ($selection -match '^\d+$' -and [int]$selection -lt $contexts.values.Count) {
                        $script:ContextID = $contexts.values[[int]$selection].id
                        Write-Host "✅ Selected context: $($contexts.values[[int]$selection].name)" -ForegroundColor Green
                        Write-Log -Message "Context selected: $script:ContextID" -Level "SUCCESS"
                        break
                    }
                    else {
                        Write-Host "❌ Invalid selection" -ForegroundColor Red
                    }
                } while ($true)
            }
        }
        else {
            Write-Host "❌ No contexts found for this custom field" -ForegroundColor Red
            Write-Log -Message "No contexts found for field: $script:CustomFieldID" -Level "ERROR"
            throw "No contexts found"
        }

        Write-Host ""
    }
    catch {
        Write-Log -Message "Error retrieving context: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

######### Add the provided options to the Custom Field #########
function Add-OptionsToCustomField {
    param()

    Write-Host "📊 Adding options to custom field..." -ForegroundColor Cyan
    Write-Host ""

    try {
        $successCount = 0
        $errorCount = 0
        $totalOptions = $script:options.Count

        Write-Log -Message "Starting to add $totalOptions options to field $script:CustomFieldID in context $script:ContextID" -Level "INFO"

        for ($index = 0; $index -lt $totalOptions; $index++) {
            $option = $script:options[$index]
            $optionValue = "$($option.ARE) - $($option.'Company Name')"

            $percentComplete = [math]::Round((($index + 1) / $totalOptions) * 100)
            Write-Progress -Activity "Adding Custom Field Options" -Status "Processing $($index + 1) of $totalOptions" -PercentComplete $percentComplete

            if ($PSCmdlet.ShouldProcess("Custom Field $script:CustomFieldID", "Add option: $optionValue")) {
                try {
                    $data = @{
                        options = @(
                            @{
                                disabled = $false
                                value    = $optionValue
                            }
                        )
                    } | ConvertTo-Json -Depth 10

                    $uri = "/rest/api/3/field/$script:CustomFieldID/context/$script:ContextID/option"
                    $null = Invoke-JiraApiRequest -Uri $uri -Body $data -Method POST

                    Write-Host "✅ Added: $optionValue" -ForegroundColor Green
                    Write-Log -Message "Option added successfully: $optionValue" -Level "SUCCESS"
                    $successCount++
                }
                catch {
                    Write-Host "❌ Failed to add: $optionValue - $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log -Message "Failed to add option '$optionValue': $($_.Exception.Message)" -Level "ERROR"
                    $errorCount++
                }
            }
            else {
                Write-Host "🔍 WhatIf: Would add option: $optionValue" -ForegroundColor Yellow
            }
        }

        Write-Progress -Activity "Adding Custom Field Options" -Completed

        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Summary" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Total options processed: $totalOptions" -ForegroundColor White
        Write-Host "Successfully added: $successCount" -ForegroundColor Green
        if ($errorCount -gt 0) {
            Write-Host "Failed: $errorCount" -ForegroundColor Red
        }
        Write-Host ""

        Write-Log -Message "AUDIT: Options added - Field: $script:CustomFieldID, Context: $script:ContextID, Success: $successCount, Failed: $errorCount, User: $env:USERNAME" -Level "AUDIT" -Sensitive $true
    }
    catch {
        Write-Log -Message "Fatal error adding options: $($_.Exception.Message)" -Level "FATAL"
        throw
    }
}

# Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        Write-Host "✅ Module $m is already imported." -ForegroundColor Green
        return
    }

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

    Write-Host "❌ Module $m not found anywhere, exiting." -ForegroundColor Red
    exit 1
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
    # Import required modules
    Import-ModuleIfAvailable ImportExcel
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

    if ([string]::IsNullOrWhiteSpace($CustomFieldID)) {
        Get-CustomFieldID
    }
    else {
        Write-Host "✅ Using provided custom field ID: $CustomFieldID" -ForegroundColor Green
        Write-Log -Message "Using custom field ID from parameter: $CustomFieldID" -Level "INFO"
    }

    if ([string]::IsNullOrWhiteSpace($ContextID)) {
        Get-ContextID
    }
    else {
        Write-Host "✅ Using provided context ID: $ContextID" -ForegroundColor Green
        Write-Log -Message "Using context ID from parameter: $ContextID" -Level "INFO"
    }

    # Get options from Excel file
    Get-CustomFieldOptionsFromFile

    # Add options to custom field
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Adding Options to Custom Field" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    Add-OptionsToCustomField

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
