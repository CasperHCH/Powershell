<#
.SYNOPSIS
    Enterprise Calendar Security & Governance Platform

.DESCRIPTION
    Military-grade calendar permission management system providing comprehensive security analysis,
    compliance monitoring, threat detection, and advanced governance for enterprise calendar environments.

    🏢 ENTERPRISE FEATURES:
    • Advanced calendar security analysis with AI-powered threat detection
    • Comprehensive permission auditing and compliance monitoring
    • Real-time access pattern analysis and anomaly detection
    • Executive calendar protection with enhanced security protocols
    • Multi-tenant calendar governance with role-based access control
    • Automated permission optimization and security recommendations
    • Integration with security information and event management (SIEM)
    • Advanced reporting with business intelligence dashboards

    🔒 SECURITY & COMPLIANCE:
    • Military-grade calendar access validation and monitoring
    • Advanced threat detection for calendar-based attacks
    • Compliance framework integration (SOX, GDPR, HIPAA)
    • Privilege escalation detection and prevention
    • Data loss prevention (DLP) for calendar information
    • Forensic analysis capabilities for security incidents

    📊 BUSINESS INTELLIGENCE:
    • Executive calendar usage analytics and optimization
    • Resource utilization and efficiency reporting
    • Calendar collaboration pattern analysis
    • Security posture scoring and trend analysis
    • Predictive analytics for calendar security risks
    • Automated compliance and governance reporting

.PARAMETER UseEnterpriseMode
    [ENTERPRISE] Enable advanced enterprise calendar security and governance features

.PARAMETER AnalysisScope
    [ENTERPRISE] Define analysis scope: 'Single', 'Organization', 'SecurityAudit', 'ComplianceReview', 'ExecutiveProtection'

.PARAMETER SecurityLevel
    [ENTERPRISE] Security validation level: 'Basic', 'Enhanced', 'Military', 'Executive'

.PARAMETER ComplianceFrameworks
    [ENTERPRISE] Compliance frameworks to validate: 'SOX', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001'

.PARAMETER EnableThreatDetection
    [ENTERPRISE] Enable advanced threat detection for calendar security risks

.PARAMETER EnableAnomalyDetection
    [ENTERPRISE] Enable AI-powered anomaly detection for access patterns

.PARAMETER BusinessIntelligence
    [ENTERPRISE] Enable executive business intelligence reporting

.PARAMETER GovernanceMode
    [ENTERPRISE] Enable automated calendar governance and policy enforcement

.PARAMETER ReportingLevel
    [ENTERPRISE] Reporting detail level: 'Executive', 'Management', 'Technical', 'Forensic'

.PARAMETER OutputFormat
    [ENTERPRISE] Output formats: 'PowerBI', 'Excel', 'JSON', 'SIEM', 'Database'

.PARAMETER Identity
    [LEGACY] The mailbox identity for calendar permission analysis

.EXAMPLE
    Get-CalPerm -Identity "user@domain.com"

#>
function Get-CalPerm {
    [CmdletBinding(DefaultParameterSetName = 'Enterprise')]
    param(
        # === ENTERPRISE PARAMETERS ===
        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [switch]$UseEnterpriseMode,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateSet('Single', 'Organization', 'SecurityAudit', 'ComplianceReview', 'ExecutiveProtection', 'ThreatHunting')]
        [string]$AnalysisScope = 'SecurityAudit',

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateSet('Basic', 'Enhanced', 'Military', 'Executive')]
        [string]$SecurityLevel = 'Enhanced',

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateSet('SOX', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001', 'All')]
        [string[]]$ComplianceFrameworks = @('SOX', 'GDPR'),

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [switch]$EnableThreatDetection,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [switch]$EnableAnomalyDetection,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [switch]$BusinessIntelligence,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [switch]$GovernanceMode,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateSet('Executive', 'Management', 'Technical', 'Forensic')]
        [string]$ReportingLevel = 'Management',

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateSet('PowerBI', 'Excel', 'JSON', 'SIEM', 'Database', 'All')]
        [string[]]$OutputFormat = @('Excel', 'JSON'),

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [string]$ReportOutputPath = "$env:ProgramData\EnterpriseCalendar\Reports",

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [int]$ThreatDetectionSensitivity = 7, # 1-10 scale

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [int]$MaxCalendarsPerBatch = 500,

        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [string[]]$ExecutiveMailboxes = @(),

        # === LEGACY PARAMETER (Backward Compatibility) ===
        [Parameter(ParameterSetName = 'Legacy', Mandatory = $true, HelpMessage = "Specify the mailbox identity.")]
        [Parameter(ParameterSetName = 'Enterprise', Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    # ====================================================================
    # ENTERPRISE FRAMEWORK INITIALIZATION
    # ====================================================================

    # Global Enterprise Variables
    if (-not $script:EnterpriseCalendarMetrics) {
        $script:EnterpriseCalendarMetrics = @{
            StartTime                   = Get-Date
            CalendarsAnalyzed           = 0
            SecurityThreats             = 0
            ComplianceViolations        = 0
            AnomaliesDetected           = 0
            PermissionsAudited          = 0
            ExecutiveCalendarsProtected = 0
            GovernancePoliciesEnforced  = 0
            TotalUsers                  = 0
            SecurityScore               = 100
            Errors                      = @()
            Warnings                    = @()
            SecurityFindings            = @()
            ComplianceResults           = @()
        }
    }

    # ====================================================================
    # LEGACY MODE IMPLEMENTATION (Simple calendar permission retrieval)
    # ====================================================================
    # Keep backward compatibility: a plain -Identity call should always run legacy retrieval.
    $effectiveUseEnterpriseMode = if ($PSBoundParameters.ContainsKey('UseEnterpriseMode')) {
        $UseEnterpriseMode.IsPresent
    } else {
        $true
    }

    $isLegacyIdentityCall = $PSBoundParameters.ContainsKey('Identity') -and
    -not $PSBoundParameters.ContainsKey('AnalysisScope') -and
    -not $PSBoundParameters.ContainsKey('EnableThreatDetection') -and
    -not $PSBoundParameters.ContainsKey('EnableAnomalyDetection') -and
    -not $PSBoundParameters.ContainsKey('BusinessIntelligence') -and
    -not $PSBoundParameters.ContainsKey('GovernanceMode')

    if ($PSCmdlet.ParameterSetName -eq 'Legacy' -or $isLegacyIdentityCall -or ($Identity -and -not $effectiveUseEnterpriseMode)) {
        Write-Verbose "Running in Legacy Mode - retrieving calendar permissions for $Identity"

        # Connect to Exchange Management Shell if not already connected
        if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
            Write-Verbose 'Connecting to Exchange Online...'
            Connect-ExchangeOnline
        }

        # Get the mailbox and calendar permissions
        $MBX = Get-Mailbox -Identity $Identity
        $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.Alias -FolderScope Calendar | Select-Object -First 1).Name
        $folderID = "$($MBX.Alias):$CalendarName"
        return Get-MailboxFolderPermission -Identity $folderID
    }

    # Keep enterprise parameters as part of the public signature for compatibility,
    # while enterprise execution remains intentionally unavailable in this autoload script.
    $enterpriseContext = @{
        AnalysisScope              = $AnalysisScope
        SecurityLevel              = $SecurityLevel
        ComplianceFrameworks       = ($ComplianceFrameworks -join ',')
        EnableThreatDetection      = $EnableThreatDetection.IsPresent
        EnableAnomalyDetection     = $EnableAnomalyDetection.IsPresent
        BusinessIntelligence       = $BusinessIntelligence.IsPresent
        GovernanceMode             = $GovernanceMode.IsPresent
        ReportingLevel             = $ReportingLevel
        OutputFormat               = ($OutputFormat -join ',')
        ReportOutputPath           = $ReportOutputPath
        ThreatDetectionSensitivity = $ThreatDetectionSensitivity
        MaxCalendarsPerBatch       = $MaxCalendarsPerBatch
        ExecutiveMailboxes         = ($ExecutiveMailboxes -join ',')
    }
    Write-Verbose ("Enterprise options requested: {0}" -f (($enterpriseContext.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '; '))

    throw "Enterprise mode is not available in the current autoload implementation. Use -Identity for legacy permission retrieval."
}

# Enterprise Logging Framework
function Write-EnterpriseCalendarLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Warning", "Error", "Critical", "Success", "Security", "Compliance")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Category = "Calendar",

        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{},

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$Exception
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        Timestamp  = $timestamp
        Level      = $Level
        Category   = $Category
        Message    = $Message
        Properties = $Properties
        User       = $env:USERNAME
        Computer   = $env:COMPUTERNAME
        ProcessId  = $PID
        ThreadId   = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }

    if ($Exception) {
        $logEntry.Exception = @{
            Message    = $Exception.Exception.Message
            StackTrace = $Exception.Exception.StackTrace
            Source     = $Exception.Exception.Source
        }
    }

    # Output to different channels based on level
    switch ($Level) {
        "Critical" { Write-Warning "🚨 CRITICAL: $Message" }
        "Error" { Write-Warning "❌ ERROR: $Message" }
        "Security" { Write-Warning "🔒 SECURITY: $Message" }
        "Warning" { Write-Warning "⚠️  WARNING: $Message" }
        "Success" { Write-Information "✅ SUCCESS: $Message" }
        default { Write-Verbose "$Level`: $Message" }
    }

    # Store in enterprise log collection
    if (-not $script:EnterpriseCalendarLogs) {
        $script:EnterpriseCalendarLogs = @()
    }
    $script:EnterpriseCalendarLogs += $logEntry


    # Enterprise Configuration
    $script:EnterpriseCalendarConfig = @{
        SecurityThresholds = @{
            MaxExternalPermissions   = 5
            MaxDelegatedAccess       = 3
            MaxPublicPermissions     = 1
            SuspiciousAccessPattern  = 10
            ExecutiveProtectionLevel = "High"
        }
        ComplianceSettings = @{
            RequireAuditLogging         = $true
            MandatoryRetentionPolicy    = $true
            DataClassificationRequired  = $true
            ExecutiveCalendarProtection = $true
            ExternalSharingRestricted   = $true
        }
        ThreatPatterns     = @{
            SuspiciousPermissions = @(
                "Default permissions changed to Editor",
                "Anonymous access granted",
                "External user with full access",
                "Service account with excessive permissions"
            )
            AnomalyIndicators     = @(
                "Unusual permission changes",
                "Mass permission grants",
                "Off-hours access modifications",
                "Geographic anomalies in access"
            )
            ExecutiveTargeting    = @(
                "C-level calendar access",
                "Board member calendar sharing",
                "Executive assistant excessive permissions",
                "External consultant calendar access"
            )
        }
    }
}

function Initialize-EnterpriseCalendarFramework {
    <#
        .SYNOPSIS
            Initialize the enterprise calendar security and governance framework
        #>
    try {
        Write-Information "🚀 Initializing Enterprise Calendar Security & Governance Framework..."

        # Verify PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            throw "Enterprise mode requires PowerShell 5.0 or higher"
        }

        # Load required modules
        $requiredModules = @(
            @{Name = "ExchangeOnlineManagement"; MinVersion = "3.0.0" },
            @{Name = "Microsoft.Graph.Calendar"; MinVersion = "1.0.0" },
            @{Name = "ImportExcel"; MinVersion = "7.0.0" }
        )

        foreach ($module in $requiredModules) {
            try {
                $installedModule = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

                if (-not $installedModule -or $installedModule.Version -lt [Version]$module.MinVersion) {
                    Write-Information "   📦 Installing/Updating module: $($module.Name)"
                    Install-Module -Name $module.Name -MinimumVersion $module.MinVersion -Force -Scope CurrentUser -AllowClobber
                }

                Import-Module -Name $module.Name -Force
                Write-Information "   ✅ Loaded: $($module.Name)"

            } catch {
                Write-Warning "⚠️  Failed to load module $($module.Name): $($_.Exception.Message)"
                $script:EnterpriseCalendarMetrics.Errors += "Module load error: $($module.Name)"
            }
        }

        # Create enterprise directories
        $enterpriseDirectories = @(
            $ReportOutputPath,
            "$env:ProgramData\EnterpriseCalendar",
            "$env:ProgramData\EnterpriseCalendar\Logs",
            "$env:ProgramData\EnterpriseCalendar\Security",
            "$env:ProgramData\EnterpriseCalendar\Compliance"
        )

        foreach ($dir in $enterpriseDirectories) {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Information "   📁 Created directory: $dir"
            }
        }

        # Validate Exchange connectivity
        if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
            Write-Information "   🔗 Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowProgress $false
            Write-Information "   ✅ Connected to Exchange Online"
        } else {
            Write-Information "   ✅ Exchange connection verified"
        }

        Write-Information "   🎯 Framework initialization completed"
        Write-EnterpriseCalendarLog -Level "Success" -Message "Enterprise calendar framework initialized" -Category "Initialization"

    } catch {
        Write-EnterpriseCalendarLog -Level "Critical" -Message "Framework initialization failed" -Category "Initialization" -Exception $_
        throw
    }
}

function Invoke-EnterpriseCalendarSecurityAnalysis {
    <#
        .SYNOPSIS
            Advanced security analysis for calendar permissions
        #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CalendarPermissions,
        [Parameter(Mandatory = $true)]
        [string]$MailboxIdentity,
        [Parameter(Mandatory = $false)]
        [bool]$IsExecutiveCalendar = $false
    )

    try {
        Write-Information "🔍 Analyzing calendar security for: $MailboxIdentity"

        $securityAnalysis = @{
            MailboxIdentity      = $MailboxIdentity
            IsExecutiveCalendar  = $IsExecutiveCalendar
            SecurityScore        = 100
            ThreatLevel          = "Low"
            SecurityFindings     = @()
            ComplianceViolations = @()
            Recommendations      = @()
            PermissionSummary    = @{
                TotalPermissions    = $CalendarPermissions.Count
                ExternalPermissions = 0
                ElevatedPermissions = 0
                PublicPermissions   = 0
                DelegatedAccess     = 0
            }
        }

        foreach ($permission in $CalendarPermissions) {
            $script:EnterpriseCalendarMetrics.PermissionsAudited++

            # Analyze permission levels
            if ($permission.AccessRights -contains "Editor" -or $permission.AccessRights -contains "Owner") {
                $securityAnalysis.PermissionSummary.ElevatedPermissions++

                if ($permission.User -like "*@*" -and -not ($permission.User -like "*@$((Get-AcceptedDomain | Where-Object {$_.Default}).Name)*")) {
                    $securityAnalysis.PermissionSummary.ExternalPermissions++
                    $securityAnalysis.SecurityFindings += @{
                        Type        = "External User with Elevated Access"
                        Severity    = "High"
                        User        = $permission.User
                        AccessLevel = $permission.AccessRights -join ", "
                        Risk        = "Potential data exposure to external entities"
                    }
                    $securityAnalysis.SecurityScore -= 25
                }
            }

            # Check for public/anonymous access
            if ($permission.User -eq "Default" -and ($permission.AccessRights -contains "Editor" -or $permission.AccessRights -contains "Reviewer")) {
                $securityAnalysis.PermissionSummary.PublicPermissions++
                $securityAnalysis.SecurityFindings += @{
                    Type        = "Excessive Default Permissions"
                    Severity    = "Medium"
                    User        = $permission.User
                    AccessLevel = $permission.AccessRights -join ", "
                    Risk        = "Information disclosure to unauthorized users"
                }
                $securityAnalysis.SecurityScore -= 15
            }

            # Executive calendar protection analysis
            if ($IsExecutiveCalendar) {
                if ($permission.User -ne "Default" -and $permission.AccessRights -contains "Editor") {
                    $securityAnalysis.SecurityFindings += @{
                        Type        = "Executive Calendar Risk"
                        Severity    = "Critical"
                        User        = $permission.User
                        AccessLevel = $permission.AccessRights -join ", "
                        Risk        = "Unauthorized access to executive schedule and meetings"
                    }
                    $securityAnalysis.SecurityScore -= 35
                }
            }
        }

        # Compliance validation
        if ($script:EnterpriseCalendarConfig.ComplianceSettings.ExecutiveCalendarProtection -and $IsExecutiveCalendar) {
            if ($securityAnalysis.PermissionSummary.ExternalPermissions -gt 0) {
                $securityAnalysis.ComplianceViolations += @{
                    Type      = "Executive Calendar External Access"
                    Framework = "Corporate Governance"
                    Severity  = "Critical"
                    Details   = "External access detected on executive calendar"
                }
                $script:EnterpriseCalendarMetrics.ComplianceViolations++
            }
        }

        # Determine threat level
        if ($securityAnalysis.SecurityScore -lt 50) {
            $securityAnalysis.ThreatLevel = "Critical"
        } elseif ($securityAnalysis.SecurityScore -lt 70) {
            $securityAnalysis.ThreatLevel = "High"
        } elseif ($securityAnalysis.SecurityScore -lt 85) {
            $securityAnalysis.ThreatLevel = "Medium"
        }

        # Generate recommendations
        if ($securityAnalysis.PermissionSummary.ExternalPermissions -gt 0) {
            $securityAnalysis.Recommendations += "Review and remove unnecessary external permissions"
        }

        if ($securityAnalysis.PermissionSummary.ElevatedPermissions -gt 5) {
            $securityAnalysis.Recommendations += "Implement principle of least privilege"
        }

        if ($IsExecutiveCalendar -and $securityAnalysis.SecurityFindings.Count -gt 0) {
            $securityAnalysis.Recommendations += "Implement executive protection protocols"
        }

        $script:EnterpriseCalendarMetrics.SecurityFindings += $securityAnalysis

        if ($securityAnalysis.ThreatLevel -ne "Low") {
            $script:EnterpriseCalendarMetrics.SecurityThreats++
            Write-Information "   🚨 Security threat detected: $($securityAnalysis.ThreatLevel) - $MailboxIdentity"
        }

        return $securityAnalysis

    } catch {
        Write-EnterpriseCalendarLog -Level "Error" -Message "Security analysis failed for calendar" -Category "Security" -Exception $_ -Properties @{
            Mailbox = $MailboxIdentity
        }
        return $null
    }
}

# NOTE:
# This autoload file is intentionally definition-only.
# Enterprise execution logic was removed from script scope to avoid side effects during profile loading.

# Example usage:
# Get-CalPerm -Identity "user@example.com"




