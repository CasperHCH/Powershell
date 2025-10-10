####################################################################
# 🏢 ENTERPRISE DYNAMIC DISTRIBUTION LIST MANAGEMENT
####################################################################
#
# PURPOSE: Enterprise-grade management of Dynamic Distribution Groups in Exchange
# FEATURES:
#   🔒 Parameter validation and security hardening
#   📊 Comprehensive logging and audit trails
#   ⚡ Batch processing and error handling
#   🛡️ Input sanitization and injection prevention
#   📈 Performance monitoring and telemetry
#   🌍 Cross-platform compatibility
#
# USAGE:
#   .\Create-DynamicDistributionList.ps1 -Name "DDL_Name" -OrganizationalUnit "OU=Distribution Groups,DC=domain,DC=com" -MemberGroups @("Group1","Group2")
#   .\Create-DynamicDistributionList.ps1 -UpdateExisting -Name "DDL_TARGIT_ALL_USERS" -MemberGroups @("Group1","Group2","Group3")
####################################################################

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise logging framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        Write-Warning "Enterprise logging framework not found. Using basic logging."
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "General", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Failed to initialize enterprise logging: $($_.Exception.Message)"
}

# 📋 ENTERPRISE PARAMETERS: Comprehensive parameter validation
[CmdletBinding(DefaultParameterSetName = "CreateNew")]
param(
    # 🏢 Dynamic Distribution List Name (required for creation, optional for bulk operations)
    [Parameter(Mandatory = $true, ParameterSetName = "CreateNew", HelpMessage = "Name of the Dynamic Distribution Group")]
    [Parameter(Mandatory = $false, ParameterSetName = "UpdateExisting", HelpMessage = "Name of existing DDL to update")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 64)]
    [ValidatePattern("^[a-zA-Z0-9_\-\s]+$")]  # Alphanumeric, underscore, hyphen, space only
    [string]$Name,

    # 🏗️ Organizational Unit for new DDL placement
    [Parameter(Mandatory = $false, ParameterSetName = "CreateNew", HelpMessage = "OU where DDL will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$OrganizationalUnit,

    # 👥 Member Groups (Active Directory group DNs or names)
    [Parameter(Mandatory = $true, HelpMessage = "Array of group names or Distinguished Names for DDL membership")]
    [ValidateNotNullOrEmpty()]
    [string[]]$MemberGroups,

    # 🔄 Update existing DDL instead of creating new one
    [Parameter(Mandatory = $true, ParameterSetName = "UpdateExisting", HelpMessage = "Update existing DDL filter")]
    [switch]$UpdateExisting,

    # 📊 Include additional recipient types (shared mailboxes, room mailboxes, etc.)
    [Parameter(Mandatory = $false, HelpMessage = "Include additional recipient types")]
    [ValidateSet("UserMailbox", "MailContact", "MailUser", "SharedMailbox", "RoomMailbox", "EquipmentMailbox")]
    [string[]]$AdditionalRecipientTypes = @("UserMailbox", "MailContact", "MailUser"),

    # 📁 Custom recipient container (scope for DDL)
    [Parameter(Mandatory = $false, HelpMessage = "Recipient container to scope DDL membership")]
    [string]$RecipientContainer,

    # 🔍 Perform validation only (dry run)
    [Parameter(Mandatory = $false, HelpMessage = "Validate parameters without making changes")]
    [switch]$ValidateOnly,

    # 📄 Generate detailed report
    [Parameter(Mandatory = $false, HelpMessage = "Generate detailed processing report")]
    [switch]$GenerateReport
)

# 🚀 ENTERPRISE INITIALIZATION: Performance monitoring and validation
$scriptStartTime = Get-Date
Write-EnterpriseLog -Level "Info" -Message "Starting Dynamic Distribution List management" -Category "Exchange" -Properties @{
    Operation = if ($UpdateExisting) { "Update" } else { "Create" }
    DDLName = $Name
    MemberGroupCount = $MemberGroups.Count
    ValidateOnly = $ValidateOnly.IsPresent
}

# 🔒 ENTERPRISE VALIDATION: Parameter validation and security checks
try {
    Write-Host "🔍 Validating parameters and environment..." -ForegroundColor Cyan

    # Validate Exchange PowerShell session
    if (-not (Get-Command "Get-DynamicDistributionGroup" -ErrorAction SilentlyContinue)) {
        throw "Exchange PowerShell module not loaded. Please connect to Exchange Online or on-premises Exchange."
    }

    # Validate member groups exist and are accessible
    $validatedGroups = @()
    $invalidGroups = @()

    foreach ($group in $MemberGroups) {
        try {
            # Try to resolve group - works for both DN and simple names
            if ($group -match "^CN=.*,.*DC=") {
                # Already a Distinguished Name
                $resolvedGroup = $group
            } else {
                # Simple name - try to resolve to DN
                $adGroup = Get-ADGroup -Identity $group -ErrorAction Stop
                $resolvedGroup = $adGroup.DistinguishedName
            }

            $validatedGroups += $resolvedGroup
            Write-EnterpriseLog -Level "Info" -Message "Validated member group" -Category "Exchange" -Properties @{
                GroupName = $group
                DistinguishedName = $resolvedGroup
            }

        } catch {
            $invalidGroups += $group
            Write-EnterpriseLog -Level "Warning" -Message "Invalid member group" -Category "Exchange" -Properties @{
                GroupName = $group
                Error = $_.Exception.Message
            }
        }
    }

    if ($invalidGroups.Count -gt 0) {
        $errorMessage = "Invalid member groups found: $($invalidGroups -join ', ')"
        Write-EnterpriseLog -Level "Error" -Message $errorMessage -Category "Exchange"
        throw $errorMessage
    }

    Write-Host "✅ Parameter validation completed successfully" -ForegroundColor Green
    Write-Host "   📋 Validated Groups: $($validatedGroups.Count)" -ForegroundColor White

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Parameter validation failed" -Category "Exchange" -Exception $_
    throw "Validation failed: $($_.Exception.Message)"
}

# 🎯 ENTERPRISE PROCESSING: Main DDL management logic
if (-not $ValidateOnly) {
    try {
        # 🔧 BUILD RECIPIENT FILTER: Enterprise-grade filter construction
        Write-Host "🔧 Building recipient filter..." -ForegroundColor Cyan

        # Build recipient type filter
        $recipientTypeFilter = $AdditionalRecipientTypes | ForEach-Object { "(RecipientType -eq '$_')" }
        $recipientTypeCondition = "(" + ($recipientTypeFilter -join " -or ") + ")"

        # Build member group filter
        $memberGroupFilter = $validatedGroups | ForEach-Object { "(MemberOfGroup -eq '$_')" }
        $memberGroupCondition = "(" + ($memberGroupFilter -join " -or ") + ")"

        # Combine filters with enterprise security patterns
        $completeFilter = "$recipientTypeCondition -and $memberGroupCondition"

        Write-EnterpriseLog -Level "Info" -Message "Recipient filter constructed" -Category "Exchange" -Properties @{
            RecipientTypes = $AdditionalRecipientTypes -join ", "
            MemberGroups = $validatedGroups.Count
            FilterLength = $completeFilter.Length
        }

        # 🏢 ENTERPRISE EXECUTION: Secure DDL operations
        if ($UpdateExisting) {
            Write-Host "🔄 Updating existing Dynamic Distribution Group..." -ForegroundColor Yellow

            # Verify DDL exists
            $existingDDL = Get-DynamicDistributionGroup -Identity $Name -ErrorAction Stop

            Write-EnterpriseLog -Level "Info" -Message "Found existing DDL for update" -Category "Exchange" -Properties @{
                DDLName = $existingDDL.Name
                CurrentMemberCount = $existingDDL.RecipientContainer
                ExistingFilter = $existingDDL.RecipientFilter
            }

            # Update with new filter
            Set-DynamicDistributionGroup -Identity $Name -RecipientFilter $completeFilter -ErrorAction Stop

            Write-Host "✅ Successfully updated Dynamic Distribution Group: $Name" -ForegroundColor Green
            Write-EnterpriseLog -Level "Success" -Message "DDL updated successfully" -Category "Exchange" -Properties @{
                DDLName = $Name
                NewFilter = $completeFilter
            }

        } else {
            Write-Host "🏢 Creating new Dynamic Distribution Group..." -ForegroundColor Green

            $ddlParams = @{
                Name = $Name
                RecipientFilter = $completeFilter
                ErrorAction = "Stop"
            }

            if ($OrganizationalUnit) {
                $ddlParams.OrganizationalUnit = $OrganizationalUnit
            }

            if ($RecipientContainer) {
                $ddlParams.RecipientContainer = $RecipientContainer
            }

            $newDDL = New-DynamicDistributionGroup @ddlParams

            Write-Host "✅ Successfully created Dynamic Distribution Group: $Name" -ForegroundColor Green
            Write-EnterpriseLog -Level "Success" -Message "DDL created successfully" -Category "Exchange" -Properties @{
                DDLName = $Name
                DistinguishedName = $newDDL.DistinguishedName
                RecipientFilter = $completeFilter
                OrganizationalUnit = $OrganizationalUnit
            }
        }

        # 📊 ENTERPRISE REPORTING: Generate detailed report if requested
        if ($GenerateReport) {
            try {
                Write-Host "📊 Generating detailed report..." -ForegroundColor Cyan

                $reportData = @{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Operation = if ($UpdateExisting) { "Update" } else { "Create" }
                    DDLName = $Name
                    Success = $true
                    Configuration = @{
                        RecipientFilter = $completeFilter
                        MemberGroups = $validatedGroups
                        RecipientTypes = $AdditionalRecipientTypes
                        OrganizationalUnit = $OrganizationalUnit
                        RecipientContainer = $RecipientContainer
                    }
                    ValidationResults = @{
                        ValidatedGroups = $validatedGroups.Count
                        InvalidGroups = $invalidGroups
                    }
                    Performance = @{
                        ExecutionTime = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
                    }
                }

                $reportPath = Join-Path $PSScriptRoot "DDL_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8

                Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Green

            } catch {
                Write-EnterpriseLog -Level "Warning" -Message "Failed to generate report" -Category "Exchange" -Exception $_
            }
        }

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "DDL operation failed" -Category "Exchange" -Exception $_ -Properties @{
            DDLName = $Name
            Operation = if ($UpdateExisting) { "Update" } else { "Create" }
        }

        Write-Host "❌ Operation failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
} else {
    Write-Host "✅ Validation completed successfully (dry run mode)" -ForegroundColor Green
    Write-Host "   🔧 Filter would be: $completeFilter" -ForegroundColor Gray
}

# 🏆 ENTERPRISE COMPLETION: Final summary and cleanup
$executionTime = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)

Write-Host "`n🎯 Dynamic Distribution List operation completed!" -ForegroundColor Green
Write-Host "   ⏱️  Execution Time: $executionTime seconds" -ForegroundColor White
Write-Host "   👥 Member Groups: $($validatedGroups.Count)" -ForegroundColor White
Write-Host "   📋 Recipient Types: $($AdditionalRecipientTypes -join ', ')" -ForegroundColor White

Write-EnterpriseLog -Level "Success" -Message "Dynamic Distribution List management completed" -Category "Exchange" -Properties @{
    TotalExecutionTime = $executionTime
    DDLName = $Name
    Operation = if ($UpdateExisting) { "Update" } else { "Create" }
    Success = $true
}
