<#
.SYNOPSIS
    Find Jira Cloud Custom Field ID og Context ID helper script.

.DESCRIPTION
    Dette hjælpe-script hjælper med at finde Custom Field ID og Context ID
    i Jira Cloud, hvilket er nødvendigt for Update-JiraCustomFieldOptions.ps1 scriptet.

.PARAMETER JiraCloudUrl
    Jira Cloud base URL (e.g., https://your-domain.atlassian.net)

.PARAMETER AdminEmail
    Admin email for authentication

.PARAMETER ApiToken
    Jira Cloud API token

.PARAMETER SearchFieldName
    Optional: Søg efter et specifikt field navn (supports wildcards)

.EXAMPLE
    .\Get-JiraCustomFieldInfo.ps1 -JiraCloudUrl "https://mycompany.atlassian.net"

    Viser alle custom fields og deres contexts.

.EXAMPLE
    .\Get-JiraCustomFieldInfo.ps1 -JiraCloudUrl "https://mycompany.atlassian.net" -SearchFieldName "*Department*"

    Søger efter custom fields der indeholder "Department" i navnet.

.NOTES
    Version:        1.0
    Author:         GitHub Copilot
    Creation Date:  2026-01-15
    Purpose:        Helper script til at finde Custom Field og Context IDs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Jira Cloud base URL (e.g., https://your-domain.atlassian.net)")]
    [ValidateScript({ $_ -match '^https://.*\.atlassian\.net$' })]
    [string]$JiraCloudUrl,

    [Parameter(Mandatory = $false, HelpMessage = "Admin email for authentication")]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$AdminEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Jira Cloud API token")]
    [string]$ApiToken,

    [Parameter(Mandatory = $false, HelpMessage = "Search for specific field name (supports wildcards)")]
    [string]$SearchFieldName,

    [Parameter(Mandatory = $false, HelpMessage = "Request timeout in seconds")]
    [ValidateRange(5, 300)]
    [int]$TimeoutSeconds = 30
)

# Initialize session ID for audit logging
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "ScriptAudit.log"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-JiraAuthHeaders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Email,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${Email}:${Token}"))

    return @{
        'Authorization' = "Basic $base64AuthInfo"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
        'User-Agent'    = 'PowerShellScript/1.0'
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔍 Jira Custom Field & Context Finder" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

try {
    # Get credentials if not provided
    if (-not $AdminEmail) {
        $AdminEmail = Read-Host "Enter Jira Cloud admin email"
    }

    if (-not $ApiToken) {
        $secureToken = Read-Host "Enter Jira Cloud API token" -AsSecureString
        $ApiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
    }

    # Create authentication headers
    Write-Log -Level INFO -Message "🔐 Creating authentication headers..."
    $headers = Get-JiraAuthHeaders -Email $AdminEmail -Token $ApiToken

    # Get all fields
    Write-Log -Level INFO -Message "📥 Fetching all Jira fields..."
    $uri = "$JiraCloudUrl/rest/api/3/field"
    $allFields = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop

    # Filter to only custom fields
    $customFields = $allFields | Where-Object { $_.custom -eq $true }

    # Apply search filter if provided
    if ($SearchFieldName) {
        Write-Log -Level INFO -Message "🔎 Filtering fields matching: $SearchFieldName"
        $customFields = $customFields | Where-Object { $_.name -like $SearchFieldName }
    }

    if (-not $customFields) {
        Write-Log -Level WARNING -Message "⚠️  No custom fields found matching criteria"
        exit 0
    }

    Write-Log -Level INFO -Message "✅ Found $($customFields.Count) custom field(s)"
    Write-Host ""

    # Process each custom field
    foreach ($field in $customFields) {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "📋 Field Name: " -NoNewline -ForegroundColor Cyan
        Write-Host $field.name -ForegroundColor White
        Write-Host "🆔 Field ID: " -NoNewline -ForegroundColor Cyan
        Write-Host $field.id -ForegroundColor Green
        Write-Host "📝 Field Type: " -NoNewline -ForegroundColor Cyan
        Write-Host $field.schema.type -ForegroundColor White

        if ($field.schema.custom) {
            Write-Host "🔧 Custom Type: " -NoNewline -ForegroundColor Cyan
            Write-Host $field.schema.custom -ForegroundColor Gray
        }

        # Get contexts for this field
        try {
            $contextsUri = "$JiraCloudUrl/rest/api/3/field/$($field.id)/context"
            $contextsResponse = Invoke-RestMethod -Uri $contextsUri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop

            if ($contextsResponse.values -and $contextsResponse.values.Count -gt 0) {
                Write-Host ""
                Write-Host "  📂 Contexts:" -ForegroundColor Magenta

                foreach ($context in $contextsResponse.values) {
                    Write-Host "    ├─ Name: " -NoNewline -ForegroundColor Gray
                    Write-Host $context.name -ForegroundColor White
                    Write-Host "    ├─ Context ID: " -NoNewline -ForegroundColor Gray
                    Write-Host $context.id -ForegroundColor Green
                    Write-Host "    ├─ Description: " -NoNewline -ForegroundColor Gray
                    Write-Host $(if ($context.description) { $context.description } else { "(none)" }) -ForegroundColor Gray
                    Write-Host "    └─ Is Global Context: " -NoNewline -ForegroundColor Gray
                    Write-Host $(if ($context.isGlobalContext) { "Yes ✓" } else { "No" }) -ForegroundColor White

                    # Try to get options for this context
                    try {
                        $optionsUri = "$JiraCloudUrl/rest/api/3/field/$($field.id)/context/$($context.id)/option"
                        $optionsResponse = Invoke-RestMethod -Uri $optionsUri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction SilentlyContinue

                        if ($optionsResponse.values -and $optionsResponse.values.Count -gt 0) {
                            Write-Host ""
                            Write-Host "      🎯 Options ($($optionsResponse.values.Count)):" -ForegroundColor Yellow

                            $optionsList = $optionsResponse.values | ForEach-Object {
                                $status = if ($_.disabled) { "❌ disabled" } else { "✅ enabled" }
                                "        • $($_.value) (ID: $($_.id)) - $status"
                            }

                            # Show first 10 options
                            $optionsList | Select-Object -First 10 | ForEach-Object {
                                Write-Host $_ -ForegroundColor Gray
                            }

                            if ($optionsResponse.values.Count -gt 10) {
                                Write-Host "        ... and $($optionsResponse.values.Count - 10) more" -ForegroundColor DarkGray
                            }
                        }
                    }
                    catch {
                        # Options may not be available for all field types
                    }

                    Write-Host ""
                }
            }
            else {
                Write-Host "  ⚠️  No contexts found for this field" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ❌ Error retrieving contexts: $($_.Exception.Message)" -ForegroundColor Red
        }

        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
    }

    # Summary with example usage
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  💡 Example Usage with Update-JiraCustomFieldOptions.ps1" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    if ($customFields.Count -gt 0) {
        $exampleField = $customFields[0]

        # Try to get first context
        try {
            $contextsUri = "$JiraCloudUrl/rest/api/3/field/$($exampleField.id)/context"
            $contextsResponse = Invoke-RestMethod -Uri $contextsUri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop

            if ($contextsResponse.values -and $contextsResponse.values.Count -gt 0) {
                $exampleContext = $contextsResponse.values[0]

                Write-Host ".\Update-JiraCustomFieldOptions.ps1 ``" -ForegroundColor Green
                Write-Host "  -JiraCloudUrl `"$JiraCloudUrl`" ``" -ForegroundColor Green
                Write-Host "  -CustomFieldId `"$($exampleField.id)`" ``" -ForegroundColor Green
                Write-Host "  -ContextId `"$($exampleContext.id)`" ``" -ForegroundColor Green
                Write-Host "  -DesiredOptions @(`"option1`", `"option2`", `"option3`")" -ForegroundColor Green
            }
        }
        catch {
            Write-Log -Level WARNING -Message "Could not generate example usage"
        }
    }

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Log -Level INFO -Message "✅ Script completed successfully!"
}
catch {
    Write-Log -Level ERROR -Message "❌ Script failed: $($_.Exception.Message)"
    throw
}
finally {
    # Clear sensitive variables
    $ApiToken = $null
    $secureToken = $null
    $headers = $null
}
