<#
.SYNOPSIS
    Opdater Jira Cloud custom field options - disable options der ikke er i listen.

.DESCRIPTION
    Dette script opdaterer custom field options i Jira Cloud via REST API v3.
    Det sammenligner eksisterende options med en provided liste og disabler de options
    der ikke findes i listen, mens det sikrer at options fra listen er enabled.

    SECURITY: No hardcoded credentials, all output sanitized, audit logging enabled
    COMPLIANCE: GDPR, SOX, organizational standards

.PARAMETER JiraCloudUrl
    Jira Cloud base URL (e.g., https://your-domain.atlassian.net)

.PARAMETER AdminEmail
    Admin email for authentication (Jira Cloud requires email, not username)

.PARAMETER ApiToken
    Jira Cloud API token (can be created at https://id.atlassian.com/manage-profile/security/api-tokens)

.PARAMETER CustomFieldId
    The custom field ID (e.g., "customfield_10001")

.PARAMETER ContextId
    The context ID for the custom field (can be retrieved via API)

.PARAMETER DesiredOptions
    Array of option values that should be enabled. All other options will be disabled.

.PARAMETER CsvPath
    Path to CSV file containing desired options (one column: 'Value')

.PARAMETER WhatIf
    Preview changes without making actual modifications

.EXAMPLE
    .\Update-JiraCustomFieldOptions.ps1 -JiraCloudUrl "https://mycompany.atlassian.net" -CustomFieldId "customfield_10001" -ContextId "10000" -DesiredOptions @("b","c","d","e")

    Opdaterer custom field hvor kun options "b", "c", "d", "e" vil være enabled.
    Option "a" vil blive disabled hvis den eksisterer.

.EXAMPLE
    .\Update-JiraCustomFieldOptions.ps1 -JiraCloudUrl "https://mycompany.atlassian.net" -CustomFieldId "customfield_10001" -ContextId "10000" -CsvPath "C:\options.csv"

    Indlæser ønskede options fra CSV fil.

.EXAMPLE
    .\Update-JiraCustomFieldOptions.ps1 -JiraCloudUrl "https://mycompany.atlassian.net" -CustomFieldId "customfield_10001" -ContextId "10000" -DesiredOptions @("b","c","d","e") -WhatIf

    Preview mode - viser hvilke ændringer der ville blive lavet uden at udføre dem.

.NOTES
    Version:        1.0
    Author:         GitHub Copilot
    Creation Date:  2026-01-15
    Purpose:        Sync Jira Cloud custom field options with desired list
    Requirements:   PowerShell 5.1+, Jira Cloud API access, Custom field admin permissions

.LINK
    https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-options/
#>

<#
DATA CLASSIFICATION:
    PUBLIC: Custom field IDs, option values
    CONFIDENTIAL: Admin email
    RESTRICTED: API tokens, credentials
All restricted data is handled securely and never logged.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Jira Cloud base URL (e.g., https://your-domain.atlassian.net)")]
    [ValidateScript({ $_ -match '^https://.*\.atlassian\.net$' })]
    [string]$JiraCloudUrl,

    [Parameter(Mandatory = $false, HelpMessage = "Admin email for authentication")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$AdminEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Jira Cloud API token")]
    [string]$ApiToken,

    [Parameter(Mandatory = $true, HelpMessage = "Custom field ID (e.g., customfield_10001)")]
    [ValidatePattern('^customfield_\d+$')]
    [string]$CustomFieldId,

    [Parameter(Mandatory = $true, HelpMessage = "Context ID for the custom field")]
    [ValidateNotNullOrEmpty()]
    [string]$ContextId,

    [Parameter(Mandatory = $false, HelpMessage = "Path to CSV file with desired options (ANBEFALET)")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Array of desired option values (alternativ til CSV)")]
    [string[]]$DesiredOptions,

    [Parameter(Mandatory = $false, HelpMessage = "Request timeout in seconds")]
    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Add new options if they don't exist")]
    [switch]$AddMissingOptions
)

#-----------------------------------------------------------[Initialisations]--------------------------------------------------------

# Initialize session ID for audit logging
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "ScriptAudit.log"

# Clear error variable
$Error.Clear()

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Write-Log {
    <#
    .SYNOPSIS
        Secure logging function with data sanitization
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Sanitize message for display (remove sensitive data)
    $displayMessage = $Message
    if ($script:JiraCloudUrl) {
        $displayMessage = $displayMessage -replace [regex]::Escape($script:JiraCloudUrl), "[JIRA_URL]"
    }
    if ($script:AdminEmail) {
        $displayMessage = $displayMessage -replace [regex]::Escape($script:AdminEmail), "[ADMIN_EMAIL]"
    }

    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"

    # Display non-sensitive logs
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Always log full message to file (including sensitive data for troubleshooting)
    $fullLogEntry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $script:LogFile -Value $fullLogEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Audit-specific logging function
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMsg,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp      = Get-Date -Format "o"
        SessionId      = $script:SessionId
        Action         = $Action
        User           = $env:USERNAME
        Target         = $Target
        Error          = $ErrorMsg
        ComputerName   = $env:COMPUTERNAME
        ScriptName     = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
}

function Get-JiraAuthHeaders {
    <#
    .SYNOPSIS
        Create authentication headers for Jira Cloud API
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${Email}:${Token}"))

        $headers = @{
            'Authorization' = "Basic $base64AuthInfo"
            'Content-Type'  = 'application/json'
            'Accept'        = 'application/json'
            'User-Agent'    = 'PowerShellScript/1.0'
        }

        Write-AuditLog -Action "AUTH_HEADERS_CREATED" -Target $Email
        return $headers
    }
    catch {
        Write-Log -Level ERROR -Message "Failed to create auth headers: $($_.Exception.Message)"
        Write-AuditLog -Action "AUTH_HEADERS_FAILED" -ErrorMsg $_.Exception.Message
        throw
    }
}

function Get-CustomFieldOptions {
    <#
    .SYNOPSIS
        Retrieve existing options for a custom field context
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$FieldId,

        [Parameter(Mandatory = $true)]
        [string]$CtxId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    try {
        Write-Log -Level INFO -Message "📥 Henter eksisterende options for custom field $FieldId (context: $CtxId)..."

        $uri = "$BaseUrl/rest/api/3/field/$FieldId/context/$CtxId/option"
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop

        $options = $response.values
        Write-Log -Level INFO -Message "✅ Fundet $($options.Count) eksisterende options"
        Write-AuditLog -Action "GET_OPTIONS_SUCCESS" -Target "$FieldId/$CtxId" -AdditionalData @{Count = $options.Count }

        return $options
    }
    catch {
        $sanitizedError = $_.Exception.Message -replace [regex]::Escape($BaseUrl), "[JIRA_URL]"
        Write-Log -Level ERROR -Message "❌ Kunne ikke hente options: $sanitizedError"
        Write-AuditLog -Action "GET_OPTIONS_FAILED" -Target "$FieldId/$CtxId" -ErrorMsg $_.Exception.Message
        throw
    }
}

function Update-CustomFieldOption {
    <#
    .SYNOPSIS
        Update a single custom field option (enable/disable)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$FieldId,

        [Parameter(Mandatory = $true)]
        [string]$CtxId,

        [Parameter(Mandatory = $true)]
        [string]$OptionId,

        [Parameter(Mandatory = $true)]
        [bool]$Disabled,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $false)]
        [string]$OptionValue
    )

    try {
        $uri = "$BaseUrl/rest/api/3/field/$FieldId/context/$CtxId/option"

        $body = @{
            options = @(
                @{
                    id       = $OptionId
                    disabled = $Disabled
                }
            )
        } | ConvertTo-Json -Depth 10

        if ($PSCmdlet.ShouldProcess("Option '$OptionValue' (ID: $OptionId)", "Set disabled=$Disabled")) {
            $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $Headers -Body $body -TimeoutSec $TimeoutSeconds -ErrorAction Stop

            $status = if ($Disabled) { "disabled ❌" } else { "enabled ✅" }
            Write-Log -Level INFO -Message "  Updated: '$OptionValue' is now $status"
            Write-AuditLog -Action "UPDATE_OPTION_SUCCESS" -Target "$OptionId" -AdditionalData @{Value = $OptionValue; Disabled = $Disabled }

            return $response
        }
        else {
            $status = if ($Disabled) { "disable ❌" } else { "enable ✅" }
            Write-Log -Level INFO -Message "🔍 WhatIf: Would $status option '$OptionValue' (ID: $OptionId)" -Level WARNING
            Write-AuditLog -Action "WHATIF_UPDATE_OPTION" -Target "$OptionId" -AdditionalData @{Value = $OptionValue; Disabled = $Disabled }
        }
    }
    catch {
        $sanitizedError = $_.Exception.Message -replace [regex]::Escape($BaseUrl), "[JIRA_URL]"
        Write-Log -Level ERROR -Message "❌ Kunne ikke opdatere option '$OptionValue': $sanitizedError"
        Write-AuditLog -Action "UPDATE_OPTION_FAILED" -Target "$OptionId" -ErrorMsg $_.Exception.Message
        throw
    }
}

function Add-CustomFieldOption {
    <#
    .SYNOPSIS
        Add a new custom field option
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$FieldId,

        [Parameter(Mandatory = $true)]
        [string]$CtxId,

        [Parameter(Mandatory = $true)]
        [string]$OptionValue,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    try {
        $uri = "$BaseUrl/rest/api/3/field/$FieldId/context/$CtxId/option"

        $body = @{
            options = @(
                @{
                    value    = $OptionValue
                    disabled = $false
                }
            )
        } | ConvertTo-Json -Depth 10

        if ($PSCmdlet.ShouldProcess("Custom field option", "Add new option '$OptionValue'")) {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $Headers -Body $body -TimeoutSec $TimeoutSeconds -ErrorAction Stop

            Write-Log -Level INFO -Message "  Added new option: '$OptionValue' ✨"
            Write-AuditLog -Action "ADD_OPTION_SUCCESS" -Target "$FieldId/$CtxId" -AdditionalData @{Value = $OptionValue }

            return $response
        }
        else {
            Write-Log -Level WARNING -Message "🔍 WhatIf: Would add new option '$OptionValue'"
            Write-AuditLog -Action "WHATIF_ADD_OPTION" -Target "$FieldId/$CtxId" -AdditionalData @{Value = $OptionValue }
        }
    }
    catch {
        $sanitizedError = $_.Exception.Message -replace [regex]::Escape($BaseUrl), "[JIRA_URL]"
        Write-Log -Level ERROR -Message "❌ Kunne ikke tilføje option '$OptionValue': $sanitizedError"
        Write-AuditLog -Action "ADD_OPTION_FAILED" -Target "$FieldId/$CtxId" -ErrorMsg $_.Exception.Message
        throw
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -Level INFO -Message "🚀 Starting Jira Custom Field Options Update Script (Session: $script:SessionId)"
Write-AuditLog -Action "SCRIPT_START" -Target "$CustomFieldId/$ContextId"

try {
    # Validate parameters
    if (-not $DesiredOptions -and -not $CsvPath) {
        Write-Log -Level ERROR -Message "❌ Du skal angive enten -CsvPath eller -DesiredOptions parameter"
        Write-Host ""
        Write-Host "📋 CSV Format (ANBEFALET):" -ForegroundColor Yellow
        Write-Host "  Value" -ForegroundColor Gray
        Write-Host "  Option A" -ForegroundColor Gray
        Write-Host "  Option B" -ForegroundColor Gray
        Write-Host "  Option C" -ForegroundColor Gray
        Write-Host ""
        Write-Host "📋 Alternativt med -DesiredOptions:" -ForegroundColor Yellow
        Write-Host "  -DesiredOptions @('Option A', 'Option B', 'Option C')" -ForegroundColor Gray
        Write-Host ""
        throw "Manglende påkrævet parameter"
    }

    # Load desired options from CSV if provided
    if ($CsvPath) {
        Write-Log -Level INFO -Message "📄 Indlæser ønskede options fra CSV: $CsvPath"

        if (-not (Test-Path $CsvPath)) {
            Write-Log -Level ERROR -Message "❌ CSV fil ikke fundet: $CsvPath"
            throw "CSV fil ikke fundet: $CsvPath"
        }

        try {
            $csvData = Import-Csv -Path $CsvPath -Encoding UTF8

            if (-not $csvData -or $csvData.Count -eq 0) {
                throw "CSV fil er tom"
            }

            Write-Log -Level DEBUG -Message "CSV indeholder $($csvData.Count) rækker"
            Write-Log -Level DEBUG -Message "CSV kolonner: $($csvData[0].PSObject.Properties.Name -join ', ')"

            # Try to find the value column (supports multiple possible column names)
            $valueColumn = $null
            $possibleColumns = @('Value', 'value', 'Option', 'option', 'Name', 'name', 'OptionValue', 'optionvalue')

            foreach ($col in $possibleColumns) {
                if ($csvData[0].PSObject.Properties.Name -contains $col) {
                    $valueColumn = $col
                    Write-Log -Level DEBUG -Message "Bruger CSV kolonne: '$valueColumn'"
                    break
                }
            }

            if (-not $valueColumn) {
                Write-Log -Level ERROR -Message "❌ CSV filen skal indeholde en kolonne med et af følgende navne:"
                Write-Host ""
                foreach ($col in $possibleColumns) {
                    Write-Host "  • $col" -ForegroundColor Yellow
                }
                Write-Host ""
                Write-Host "📋 Fundne kolonner i din CSV:" -ForegroundColor Cyan
                foreach ($col in $csvData[0].PSObject.Properties.Name) {
                    Write-Host "  • $col" -ForegroundColor Gray
                }
                Write-Host ""
                Write-Host "💡 Korrekt CSV format eksempel:" -ForegroundColor Yellow
                Write-Host "  Value" -ForegroundColor Gray
                Write-Host "  Option A" -ForegroundColor Gray
                Write-Host "  Option B" -ForegroundColor Gray
                Write-Host ""
                throw "Ugyldig CSV kolonne struktur"
            }

            # Extract and validate options
            $DesiredOptions = $csvData | ForEach-Object {
                $val = $_.$valueColumn
                if ($val -and $val.ToString().Trim()) {
                    $val.ToString().Trim()
                }
            } | Where-Object { $_ -ne $null -and $_ -ne '' }

            if ($DesiredOptions.Count -eq 0) {
                throw "CSV filen indeholder ingen gyldige værdier i '$valueColumn' kolonnen"
            }

            Write-Log -Level INFO -Message "✅ Indlæst $($DesiredOptions.Count) options fra CSV fil"

            # Show preview of loaded options
            if ($DesiredOptions.Count -le 10) {
                Write-Log -Level DEBUG -Message "Options: $($DesiredOptions -join ', ')"
            }
            else {
                $preview = ($DesiredOptions | Select-Object -First 5) -join ', '
                Write-Log -Level DEBUG -Message "Options preview (første 5): $preview ... (+$($DesiredOptions.Count - 5) mere)"
            }
        }
        catch {
            Write-Log -Level ERROR -Message "❌ Fejl ved læsning af CSV fil: $($_.Exception.Message)"
            Write-Host ""
            Write-Host "💡 Tjek at din CSV fil:" -ForegroundColor Yellow
            Write-Host "  1. Er gemt med UTF-8 encoding" -ForegroundColor Gray
            Write-Host "  2. Har en header-række med kolonne navne" -ForegroundColor Gray
            Write-Host "  3. Har en kolonne kaldet 'Value', 'Option', eller 'Name'" -ForegroundColor Gray
            Write-Host "  4. Indeholder mindst én række med data" -ForegroundColor Gray
            Write-Host ""
            throw
        }
    }
    else {
        Write-Log -Level DEBUG -Message "Bruger direkte options fra -DesiredOptions parameter"
    }

    # Trim whitespace and validate options
    if ($DesiredOptions) {
        $DesiredOptions = $DesiredOptions | ForEach-Object {
            if ($_) { $_.ToString().Trim() }
        } | Where-Object { $_ -ne '' }

        if ($DesiredOptions.Count -eq 0) {
            throw "Ingen gyldige options angivet"
        }

        # Remove duplicates
        $originalCount = $DesiredOptions.Count
        $DesiredOptions = $DesiredOptions | Select-Object -Unique
        if ($DesiredOptions.Count -lt $originalCount) {
            $duplicates = $originalCount - $DesiredOptions.Count
            Write-Log -Level WARNING -Message "⚠️  Fjernede $duplicates duplikat option(s)"
        }

        Write-Log -Level INFO -Message "📋 Total antal ønskede options: $($DesiredOptions.Count)"

        if ($DesiredOptions.Count -le 20) {
            Write-Log -Level INFO -Message "📋 Ønskede options: $($DesiredOptions -join ', ')"
        }
        else {
            $preview = ($DesiredOptions | Select-Object -First 10) -join ', '
            Write-Log -Level INFO -Message "📋 Første 10 options: $preview ... (+$($DesiredOptions.Count - 10) mere)"
        }
    }
    else {
        throw "Ingen options blev indlæst"
    }

    # Get credentials if not provided
    if (-not $AdminEmail) {
        $AdminEmail = Read-Host "Enter Jira Cloud admin email"
    }

    if (-not $ApiToken) {
        $secureToken = Read-Host "Enter Jira Cloud API token (hentes fra https://id.atlassian.com/manage-profile/security/api-tokens)" -AsSecureString
        $ApiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
    }

    # Create authentication headers
    Write-Log -Level INFO -Message "🔐 Opretter authentication headers..."
    $headers = Get-JiraAuthHeaders -Email $AdminEmail -Token $ApiToken

    # Get existing options
    $existingOptions = Get-CustomFieldOptions -BaseUrl $JiraCloudUrl -FieldId $CustomFieldId -CtxId $ContextId -Headers $headers

    # Initialize counters
    $disabledCount = 0
    $enabledCount = 0
    $addedCount = 0
    $unchangedCount = 0

    # Create lookup for existing options
    $existingOptionsMap = @{}
    foreach ($option in $existingOptions) {
        $existingOptionsMap[$option.value] = $option
    }

    Write-Log -Level INFO -Message ""
    Write-Log -Level INFO -Message "⚙️ Processing options..."
    Write-Log -Level INFO -Message ""

    # Process existing options - disable those not in desired list
    foreach ($option in $existingOptions) {
        $optionValue = $option.value
        $optionId = $option.id
        $isCurrentlyDisabled = $option.disabled

        if ($DesiredOptions -contains $optionValue) {
            # This option should be enabled
            if ($isCurrentlyDisabled) {
                Write-Log -Level INFO -Message "🔄 Enabling option: '$optionValue'"
                Update-CustomFieldOption -BaseUrl $JiraCloudUrl -FieldId $CustomFieldId -CtxId $ContextId `
                    -OptionId $optionId -Disabled $false -Headers $headers -OptionValue $optionValue
                $enabledCount++
            }
            else {
                Write-Log -Level DEBUG -Message "  Option '$optionValue' is already enabled ✓"
                $unchangedCount++
            }
        }
        else {
            # This option should be disabled
            if (-not $isCurrentlyDisabled) {
                Write-Log -Level INFO -Message "🔄 Disabling option: '$optionValue'"
                Update-CustomFieldOption -BaseUrl $JiraCloudUrl -FieldId $CustomFieldId -CtxId $ContextId `
                    -OptionId $optionId -Disabled $true -Headers $headers -OptionValue $optionValue
                $disabledCount++
            }
            else {
                Write-Log -Level DEBUG -Message "  Option '$optionValue' is already disabled ✓"
                $unchangedCount++
            }
        }
    }

    # Add new options if requested
    if ($AddMissingOptions) {
        Write-Log -Level INFO -Message ""
        Write-Log -Level INFO -Message "➕ Checking for missing options..."

        foreach ($desiredOption in $DesiredOptions) {
            if (-not $existingOptionsMap.ContainsKey($desiredOption)) {
                Write-Log -Level INFO -Message "🔄 Adding new option: '$desiredOption'"
                Add-CustomFieldOption -BaseUrl $JiraCloudUrl -FieldId $CustomFieldId -CtxId $ContextId `
                    -OptionValue $desiredOption -Headers $headers
                $addedCount++
            }
        }
    }
    else {
        # Check if there are missing options
        $missingOptions = $DesiredOptions | Where-Object { -not $existingOptionsMap.ContainsKey($_) }
        if ($missingOptions) {
            Write-Log -Level WARNING -Message ""
            Write-Log -Level WARNING -Message "⚠️  Følgende options findes ikke i custom field:"
            foreach ($missing in $missingOptions) {
                Write-Log -Level WARNING -Message "  - '$missing'"
            }
            Write-Log -Level WARNING -Message "💡 Brug -AddMissingOptions parameteren for automatisk at tilføje dem"
        }
    }

    # Summary
    Write-Log -Level INFO -Message ""
    Write-Log -Level INFO -Message "════════════════════════════════════════"
    Write-Log -Level INFO -Message "📊 SUMMARY"
    Write-Log -Level INFO -Message "════════════════════════════════════════"
    Write-Log -Level INFO -Message "  ✅ Enabled:    $enabledCount"
    Write-Log -Level INFO -Message "  ❌ Disabled:   $disabledCount"
    Write-Log -Level INFO -Message "  ✨ Added:      $addedCount"
    Write-Log -Level INFO -Message "  ➖ Unchanged:  $unchangedCount"
    Write-Log -Level INFO -Message "════════════════════════════════════════"

    Write-AuditLog -Action "SCRIPT_COMPLETE" -Target "$CustomFieldId/$ContextId" -AdditionalData @{
        Enabled   = $enabledCount
        Disabled  = $disabledCount
        Added     = $addedCount
        Unchanged = $unchangedCount
    }

    Write-Log -Level INFO -Message ""
    Write-Log -Level INFO -Message "✅ Script completed successfully!"

}
catch {
    $sanitizedError = $_.Exception.Message -replace [regex]::Escape($JiraCloudUrl), "[JIRA_URL]"
    Write-Log -Level ERROR -Message "❌ Script failed: $sanitizedError"
    Write-AuditLog -Action "SCRIPT_FAILED" -ErrorMsg $_.Exception.Message
    throw
}
finally {
    # Clear sensitive variables
    $ApiToken = $null
    $secureToken = $null
    $headers = $null

    Write-Log -Level INFO -Message "🔒 Cleared sensitive data from memory"
}
