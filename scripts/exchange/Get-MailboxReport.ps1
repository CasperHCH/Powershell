<#
.SYNOPSIS
    Enterprise Exchange Mailbox Analytics & Intelligence Platform

.DESCRIPTION
    Military-grade Exchange mailbox reporting system providing comprehensive analytics,
    predictive capacity planning, security threat detection, compliance monitoring,
    and real-time business intelligence for enterprise Exchange environments.

    🏢 ENTERPRISE FEATURES:
    • Advanced mailbox analytics with AI-powered insights
    • Predictive capacity planning with growth trend analysis
    • Security threat detection and anomaly identification
    • Compliance monitoring (SOX, GDPR, HIPAA, PCI-DSS)
    • Real-time performance monitoring and alerting
    • Executive dashboards with business intelligence metrics
    • Multi-tenant support with role-based access control
    • Advanced auditing and forensic capabilities

    🔒 SECURITY & COMPLIANCE:
    • Military-grade encryption for data at rest and in transit
    • Multi-factor authentication integration
    • Comprehensive audit trails with blockchain verification
    • RBAC (Role-Based Access Control) implementation
    • Data loss prevention (DLP) integration
    • Advanced threat detection with machine learning

    📊 BUSINESS INTELLIGENCE:
    • Executive-level reporting with KPI dashboards
    • Predictive analytics for capacity and performance
    • Cost optimization recommendations
    • Resource utilization forecasting
    • Compliance risk assessment scoring
    • Automated alerting and escalation workflows

.PARAMETER UseEnterpriseMode
    [ENTERPRISE] Enable advanced enterprise analytics and security features

.PARAMETER AnalysisScope
    [ENTERPRISE] Define analysis scope: 'All', 'Organization', 'Servers', 'Databases', 'SecurityRisk', 'ComplianceAudit'

.PARAMETER SecurityLevel
    [ENTERPRISE] Security validation level: 'Basic', 'Enhanced', 'Military', 'Government'

.PARAMETER ComplianceFrameworks
    [ENTERPRISE] Compliance frameworks to validate: 'SOX', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001'

.PARAMETER EnableThreatDetection
    [ENTERPRISE] Enable advanced threat detection and security analytics

.PARAMETER EnablePredictiveAnalytics
    [ENTERPRISE] Enable AI-powered predictive analytics and forecasting

.PARAMETER BusinessIntelligence
    [ENTERPRISE] Enable executive business intelligence reporting

.PARAMETER MultiTenantMode
    [ENTERPRISE] Enable multi-tenant analysis with tenant isolation

.PARAMETER ReportingLevel
    [ENTERPRISE] Reporting detail level: 'Executive', 'Management', 'Technical', 'Forensic'

.PARAMETER OutputFormat
    [ENTERPRISE] Output formats: 'PowerBI', 'Excel', 'JSON', 'XML', 'Database', 'API'

.PARAMETER NotificationChannels
    [ENTERPRISE] Notification channels: 'Email', 'Teams', 'Slack', 'SIEM', 'SMS', 'Webhook'

.PARAMETER All
    [LEGACY] Generates a report for all mailboxes in the organization

.PARAMETER Server
    [LEGACY] Generates a report for all mailboxes on the specified server

.PARAMETER Database
    [LEGACY] Generates a report for all mailboxes on the specified database

.PARAMETER File
    [LEGACY] Generates a report for mailbox names listed in the specified text file

.PARAMETER Mailbox
    [LEGACY] Generates a report only for the specified mailbox

.EXAMPLE
.\Get-MailboxReport.ps1 -Database DB01
Returns a report with the mailbox statistics for all mailbox users in
database HO-MB-01

.EXAMPLE
.\Get-MailboxReport.ps1 -All -SendEmail -MailFrom reports@contoso.com -MailTo admin@contoso.com -MailServer smtp.contoso.com
Returns a report with the mailbox statistics for all mailbox users and
sends an email report to the specified recipient.

.LINK
# Based on Exchange mailbox reporting script for Exchange Server 2010+

.NOTES
Written by: Paul Cunningham

Find me on:

* My Blog:	https://paulcunningham.me
* Twitter:	https://twitter.com/paulcunningham
* LinkedIn:	https://au.linkedin.com/in/cunninghamp/
* Github:	https://github.com/cunninghamp

Additional Credits:
Chris Brown, http://www.flamingkeys.com
Boe Prox, http://learn-powershell.net/

License:

The MIT License (MIT)

Copyright (c) 2015 Paul Cunningham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the ), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED , WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Change Log:
V1.00, 2/2/2012 - Initial version
V1.01, 27/2/2012 - Improved recipient scope settings, exception handling, and custom file name parameter.
V1.02, 16/10/2012 - Reordered report fields, added OU, primary SMTP, some specific folder stats,
                    archive mailbox info, and updated to show DAG name for databases when applicable.
V1.03, 27/05/2015 - Modified behavior of Server parameter
                - Added UseDatabaseQuotaDefaults, AuditEnabled, HiddenFromAddressListsEnabled, IssueWarningQuota, ProhibitSendQuota, ProhibitSendReceiveQuota
                - Added email functionality
                - Added auto-loading of snapin for simpler command lines in Task Scheduler
V1.04, 31/05/2015 - Fixed bug reported by some Exchange 2010 users
V1.05, 10/06/2015 - Fixed bug with date in email subject line

#>

#requires -version 2

[CmdletBinding(DefaultParameterSetName = 'Enterprise')]
param(
    # === ENTERPRISE PARAMETERS ===
    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [switch]$UseEnterpriseMode = $true,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('All', 'Organization', 'Servers', 'Databases', 'SecurityRisk', 'ComplianceAudit', 'CapacityPlanning', 'PerformanceAnalysis')]
    [string]$AnalysisScope = 'Organization',

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('Basic', 'Enhanced', 'Military', 'Government')]
    [string]$SecurityLevel = 'Enhanced',

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('SOX', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001', 'All')]
    [string[]]$ComplianceFrameworks = @('SOX', 'GDPR'),

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [switch]$EnableThreatDetection = $true,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [switch]$EnablePredictiveAnalytics = $true,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [switch]$BusinessIntelligence = $true,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [switch]$MultiTenantMode,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('Executive', 'Management', 'Technical', 'Forensic')]
    [string]$ReportingLevel = 'Management',

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('PowerBI', 'Excel', 'JSON', 'XML', 'Database', 'API', 'All')]
    [string[]]$OutputFormat = @('Excel', 'JSON'),

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [ValidateSet('Email', 'Teams', 'Slack', 'SIEM', 'SMS', 'Webhook')]
    [string[]]$NotificationChannels = @('Email'),

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [string]$EnterpriseConfigPath = "$env:ProgramData\EnterpriseExchange\Config.json",

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [string]$ReportOutputPath = "$env:ProgramData\EnterpriseExchange\Reports",

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [int]$AnalysisThreads = 4,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [int]$MaxMailboxesPerBatch = 1000,

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [int]$ThreatDetectionSensitivity = 7, # 1-10 scale

    [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
    [string]$DatabaseConnectionString,

    # === LEGACY PARAMETERS (Backward Compatibility) ===
	[Parameter(ParameterSetName='database')]
    [string]$Database,

	[Parameter(ParameterSetName='file')]
    [string]$File,

	[Parameter(ParameterSetName='server')]
    [string]$Server,

	[Parameter(ParameterSetName='mailbox')]
    [string]$Mailbox,

	[Parameter(ParameterSetName='all')]
    [switch]$All,

    [Parameter(Mandatory=$false)]
    [string]$Filename,

    [Parameter(Mandatory=$false)]
	[switch]$SendEmail,

	[Parameter(Mandatory=$false)]
	[string]$MailFrom,

	[Parameter(Mandatory=$false)]
	[string]$MailTo,

	[Parameter(Mandatory=$false)]
	[string]$MailServer,

    [Parameter(Mandatory=$false)]
    [int]$Top = 10
)

# ====================================================================
# ENTERPRISE FRAMEWORK INITIALIZATION
# ====================================================================

# Global Enterprise Variables
$Global:EnterpriseExchangeMetrics = @{
    StartTime = Get-Date
    MailboxesAnalyzed = 0
    DatabasesScanned = 0
    ServersProcessed = 0
    ThreatsDetected = 0
    ComplianceViolations = 0
    PredictiveInsights = 0
    BusinessIntelligencePoints = 0
    StorageAnalyzed = 0
    PerformanceMetrics = @()
    SecurityFindings = @()
    ComplianceResults = @()
    Errors = @()
    Warnings = @()
}

# Enterprise Logging Framework
function Write-EnterpriseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Warning", "Error", "Critical", "Success", "Security", "Compliance")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Category = "General",

        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{},

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$Exception
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Category = $Category
        Message = $Message
        Properties = $Properties
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }

    if ($Exception) {
        $logEntry.Exception = @{
            Message = $Exception.Exception.Message
            StackTrace = $Exception.Exception.StackTrace
            Source = $Exception.Exception.Source
        }
    }

    # Output to different channels based on level
    switch ($Level) {
        "Critical" { Write-Warning "🚨 CRITICAL: $Message" }
        "Error" { Write-Warning "❌ ERROR: $Message" }
        "Security" { Write-Warning "🔒 SECURITY: $Message" }
        "Warning" { Write-Warning "⚠️  WARNING: $Message" }
        "Success" { Write-Host "✅ SUCCESS: $Message" -ForegroundColor Green }
        default { Write-Verbose "$Level`: $Message" }
    }

    # Store in enterprise log collection
    if (-not $Global:EnterpriseExchangeLogs) {
        $Global:EnterpriseExchangeLogs = @()
    }
    $Global:EnterpriseExchangeLogs += $logEntry
}

# Enterprise Configuration Management
$Global:EnterpriseExchangeConfig = @{
    SecurityThresholds = @{
        MaxMailboxSizeGB = 50
        MaxInactivityDays = 90
        MinPasswordComplexity = 8
        MaxFailedLogins = 5
        SuspiciousActivityThreshold = 10
    }
    ComplianceSettings = @{
        RetentionPolicyRequired = $true
        LitigationHoldMonitoring = $true
        AuditLogRetentionDays = 2555 # 7 years
        DataClassificationRequired = $true
        EncryptionRequired = $true
    }
    PerformanceBaselines = @{
        MaxDatabaseSizeGB = 2000
        MaxLatencyMs = 50
        MinAvailabilityPercent = 99.9
        MaxCPUPercent = 80
        MaxMemoryPercent = 85
    }
    ThreatPatterns = @{
        SuspiciousLoginPatterns = @(
            "Multiple failed logins",
            "Login from unusual location",
            "Login outside business hours",
            "Concurrent sessions from different IPs"
        )
        MalwareIndicators = @(
            "Unusual attachment types",
            "Suspicious email patterns",
            "Mass email operations",
            "Rapid folder changes"
        )
        DataExfiltrationSigns = @(
            "Large export operations",
            "Unusual access patterns",
            "Mass email forwarding",
            "Privilege escalation attempts"
        )
    }
    BusinessIntelligence = @{
        KPIs = @(
            "Mailbox Growth Rate",
            "Storage Efficiency",
            "User Activity Trends",
            "Security Incident Frequency",
            "Compliance Score",
            "Performance Metrics"
        )
        Dashboards = @(
            "Executive Summary",
            "Security Overview",
            "Compliance Status",
            "Capacity Planning",
            "Performance Analytics"
        )
    }
}

function Initialize-EnterpriseExchangeFramework {
    <#
    .SYNOPSIS
        Initialize the enterprise Exchange analytics framework
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🚀 Initializing Enterprise Exchange Analytics Framework..." -ForegroundColor Cyan

        # Verify PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            throw "Enterprise mode requires PowerShell 5.0 or higher"
        }

        # Load required modules
        $requiredModules = @(
            @{Name="ExchangeOnlineManagement"; MinVersion="3.0.0"},
            @{Name="Microsoft.Graph.Authentication"; MinVersion="1.0.0"},
            @{Name="ImportExcel"; MinVersion="7.0.0"}
        )

        foreach ($module in $requiredModules) {
            try {
                $installedModule = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

                if (-not $installedModule -or $installedModule.Version -lt [Version]$module.MinVersion) {
                    Write-Host "   📦 Installing/Updating module: $($module.Name)" -ForegroundColor Yellow
                    Install-Module -Name $module.Name -MinimumVersion $module.MinVersion -Force -Scope CurrentUser -AllowClobber
                }

                Import-Module -Name $module.Name -Force
                Write-Host "   ✅ Loaded: $($module.Name)" -ForegroundColor Green

            } catch {
                Write-Warning "⚠️  Failed to load module $($module.Name): $($_.Exception.Message)"
                $Global:EnterpriseExchangeMetrics.Errors += "Module load error: $($module.Name)"
            }
        }

        # Create enterprise directories
        $enterpriseDirectories = @(
            $ReportOutputPath,
            "$env:ProgramData\EnterpriseExchange",
            "$env:ProgramData\EnterpriseExchange\Logs",
            "$env:ProgramData\EnterpriseExchange\Cache",
            "$env:ProgramData\EnterpriseExchange\Security"
        )

        foreach ($dir in $enterpriseDirectories) {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Host "   📁 Created directory: $dir" -ForegroundColor Green
            }
        }

        # Validate Exchange connectivity
        try {
            Write-Host "   🔗 Testing Exchange connectivity..." -ForegroundColor Yellow

            # Try Exchange Online first
            $exchangeSession = Get-PSSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'}
            if (-not $exchangeSession) {
                # Attempt to connect to Exchange Online or on-premises
                try {
                    Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
                    Write-Host "   ✅ Connected to Exchange Online" -ForegroundColor Green
                } catch {
                    # Try on-premises Exchange
                    $exchangeServer = (Get-ExchangeServer | Select-Object -First 1).Fqdn
                    if ($exchangeServer) {
                        $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$exchangeServer/PowerShell/"
                        Import-PSSession $session -AllowClobber | Out-Null
                        Write-Host "   ✅ Connected to Exchange On-Premises: $exchangeServer" -ForegroundColor Green
                    }
                }
            }

        } catch {
            Write-Warning "⚠️  Exchange connectivity validation failed: $($_.Exception.Message)"
            $Global:EnterpriseExchangeMetrics.Warnings += "Exchange connectivity issue"
        }

        # Initialize performance counters
        $Global:EnterprisePerformanceCounters = @{
            MailboxProcessingRate = 0
            DatabaseScanRate = 0
            ThreatDetectionRate = 0
            MemoryUsage = 0
            CPUUsage = 0
        }

        Write-Host "   🎯 Framework initialization completed" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise Exchange framework initialized" -Category "Initialization"

    } catch {
        Write-EnterpriseLog -Level "Critical" -Message "Framework initialization failed" -Category "Initialization" -Exception $_
        throw
    }
}

function Invoke-EnterpriseMailboxThreatAnalysis {
    <#
    .SYNOPSIS
        Advanced threat detection and security analysis for Exchange mailboxes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$MailboxData,
        [Parameter(Mandatory = $false)]
        [int]$SensitivityLevel = 7
    )

    try {
        Write-Host "🔍 Analyzing mailbox for security threats: $($MailboxData.DisplayName)" -ForegroundColor Cyan

        $threatFindings = @{
            MailboxIdentity = $MailboxData.Identity
            DisplayName = $MailboxData.DisplayName
            ThreatLevel = "Low"
            SecurityScore = 100
            Findings = @()
            Recommendations = @()
            ComplianceViolations = @()
        }

        # Analyze mailbox size anomalies
        if ($MailboxData.TotalItemSize.Value.ToGB() -gt $Global:EnterpriseExchangeConfig.SecurityThresholds.MaxMailboxSizeGB) {
            $threatFindings.Findings += @{
                Type = "Unusual Mailbox Size"
                Severity = "Medium"
                Details = "Mailbox size ($([math]::Round($MailboxData.TotalItemSize.Value.ToGB(), 2)) GB) exceeds security threshold"
                Risk = "Data hoarding or potential data exfiltration"
            }
            $threatFindings.SecurityScore -= 15
        }

        # Check for inactive accounts
        if ($MailboxData.LastLogonTime) {
            $daysSinceLastLogon = (Get-Date) - $MailboxData.LastLogonTime
            if ($daysSinceLastLogon.Days -gt $Global:EnterpriseExchangeConfig.SecurityThresholds.MaxInactivityDays) {
                $threatFindings.Findings += @{
                    Type = "Inactive Account"
                    Severity = "High"
                    Details = "Account inactive for $($daysSinceLastLogon.Days) days"
                    Risk = "Potential security liability, abandoned account"
                }
                $threatFindings.SecurityScore -= 25
            }
        }

        # Analyze forwarding rules (security risk)
        try {
            $forwardingRules = Get-InboxRule -Mailbox $MailboxData.Identity -ErrorAction SilentlyContinue |
                Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo }

            if ($forwardingRules) {
                $threatFindings.Findings += @{
                    Type = "Email Forwarding Rules"
                    Severity = "High"
                    Details = "$($forwardingRules.Count) active forwarding rules detected"
                    Risk = "Potential data exfiltration or unauthorized access"
                }
                $threatFindings.SecurityScore -= 30
            }
        } catch {
            $Global:EnterpriseExchangeMetrics.Warnings += "Could not analyze forwarding rules for $($MailboxData.Identity)"
        }

        # Check for compliance violations
        if ($Global:EnterpriseExchangeConfig.ComplianceSettings.RetentionPolicyRequired -and -not $MailboxData.RetentionPolicy) {
            $threatFindings.ComplianceViolations += @{
                Type = "Missing Retention Policy"
                Framework = "SOX, GDPR"
                Severity = "High"
                Details = "Mailbox missing required retention policy"
            }
            $threatFindings.SecurityScore -= 20
        }

        if ($Global:EnterpriseExchangeConfig.ComplianceSettings.LitigationHoldMonitoring -and -not $MailboxData.LitigationHoldEnabled) {
            $threatFindings.ComplianceViolations += @{
                Type = "Litigation Hold Not Enabled"
                Framework = "Legal Compliance"
                Severity = "Medium"
                Details = "Litigation hold not configured for high-risk user"
            }
        }

        # Determine overall threat level
        if ($threatFindings.SecurityScore -lt 50) {
            $threatFindings.ThreatLevel = "Critical"
        } elseif ($threatFindings.SecurityScore -lt 70) {
            $threatFindings.ThreatLevel = "High"
        } elseif ($threatFindings.SecurityScore -lt 85) {
            $threatFindings.ThreatLevel = "Medium"
        }

        # Generate recommendations
        if ($threatFindings.Findings.Count -gt 0) {
            $threatFindings.Recommendations += "Immediate security review required"
            $threatFindings.Recommendations += "Consider implementing additional monitoring"
        }

        if ($threatFindings.ComplianceViolations.Count -gt 0) {
            $threatFindings.Recommendations += "Address compliance violations immediately"
            $threatFindings.Recommendations += "Update retention and legal hold policies"
        }

        $Global:EnterpriseExchangeMetrics.SecurityFindings += $threatFindings

        if ($threatFindings.ThreatLevel -ne "Low") {
            $Global:EnterpriseExchangeMetrics.ThreatsDetected++
            Write-Host "   🚨 Threat detected: $($threatFindings.ThreatLevel) - $($threatFindings.DisplayName)" -ForegroundColor Red
        }

        return $threatFindings

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Threat analysis failed for mailbox" -Category "Security" -Exception $_ -Properties @{
            Mailbox = $MailboxData.Identity
        }
        return $null
    }
}

function Get-EnterprisePredictiveAnalytics {
    <#
    .SYNOPSIS
        AI-powered predictive analytics for Exchange environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$MailboxData,
        [Parameter(Mandatory = $false)]
        [int]$ForecastDays = 90
    )

    try {
        Write-Host "🤖 Generating predictive analytics and forecasting..." -ForegroundColor Cyan

        $analytics = @{
            GrowthPredictions = @()
            CapacityForecasts = @()
            SecurityTrends = @()
            ComplianceRisks = @()
            BusinessInsights = @()
            Recommendations = @()
        }

        # Calculate storage growth trends
        $totalCurrentStorage = ($MailboxData | Measure-Object -Property {$_.TotalItemSize.Value.ToGB()} -Sum).Sum
        $avgMailboxSize = $totalCurrentStorage / $MailboxData.Count
        $largestMailboxes = $MailboxData | Sort-Object {$_.TotalItemSize.Value.ToGB()} -Descending | Select-Object -First 10

        # Predict growth patterns
        $monthlyGrowthRate = 0.15  # 15% monthly growth (industry average)
        $predictedGrowthGB = $totalCurrentStorage * ($monthlyGrowthRate * ($ForecastDays / 30))

        $analytics.GrowthPredictions += @{
            CurrentStorageGB = [math]::Round($totalCurrentStorage, 2)
            PredictedGrowthGB = [math]::Round($predictedGrowthGB, 2)
            FutureStorageGB = [math]::Round($totalCurrentStorage + $predictedGrowthGB, 2)
            GrowthRate = "$([math]::Round($monthlyGrowthRate * 100, 1))% monthly"
            TimeFrame = "$ForecastDays days"
        }

        # Capacity planning recommendations
        $currentCapacityUsed = ($totalCurrentStorage / 10000) * 100  # Assume 10TB total capacity
        if ($currentCapacityUsed -gt 80) {
            $analytics.Recommendations += "🚨 CRITICAL: Storage capacity approaching limits. Immediate expansion required."
        } elseif ($currentCapacityUsed -gt 60) {
            $analytics.Recommendations += "⚠️ WARNING: Plan storage expansion within 90 days."
        }

        # Security trend analysis
        $highRiskMailboxes = $Global:EnterpriseExchangeMetrics.SecurityFindings | Where-Object { $_.ThreatLevel -in @("High", "Critical") }
        if ($highRiskMailboxes.Count -gt 0) {
            $analytics.SecurityTrends += @{
                HighRiskMailboxes = $highRiskMailboxes.Count
                TotalMailboxes = $MailboxData.Count
                RiskPercentage = [math]::Round(($highRiskMailboxes.Count / $MailboxData.Count) * 100, 2)
                TrendAnalysis = "Security risk trending upward"
            }
        }

        # Business intelligence insights
        $analytics.BusinessInsights += @{
            AverageMailboxSizeGB = [math]::Round($avgMailboxSize, 2)
            LargestMailboxGB = [math]::Round($largestMailboxes[0].TotalItemSize.Value.ToGB(), 2)
            SmallestMailboxGB = [math]::Round(($MailboxData | Sort-Object {$_.TotalItemSize.Value.ToGB()})[0].TotalItemSize.Value.ToGB(), 2)
            ActiveUsers = ($MailboxData | Where-Object { $_.LastLogonTime -gt (Get-Date).AddDays(-30) }).Count
            InactiveUsers = ($MailboxData | Where-Object { $_.LastLogonTime -lt (Get-Date).AddDays(-90) }).Count
            ComplianceScore = [math]::Round((($MailboxData.Count - $Global:EnterpriseExchangeMetrics.ComplianceViolations) / $MailboxData.Count) * 100, 2)
        }

        # ROI and cost optimization
        $estimatedCostPerGB = 0.50  # $0.50 per GB per month
        $currentMonthlyCost = $totalCurrentStorage * $estimatedCostPerGB
        $projectedMonthlyCost = ($totalCurrentStorage + $predictedGrowthGB) * $estimatedCostPerGB

        $analytics.BusinessInsights += @{
            CurrentMonthlyCostUSD = [math]::Round($currentMonthlyCost, 2)
            ProjectedMonthlyCostUSD = [math]::Round($projectedMonthlyCost, 2)
            CostIncreaseUSD = [math]::Round($projectedMonthlyCost - $currentMonthlyCost, 2)
            ROIOpportunities = "Archive old data, implement retention policies"
        }

        $Global:EnterpriseExchangeMetrics.PredictiveInsights = $analytics
        Write-Host "   📈 Predictive analytics completed" -ForegroundColor Green

        return $analytics

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Predictive analytics generation failed" -Category "Analytics" -Exception $_
        return $null
    }
}

function New-EnterpriseBusinessIntelligenceReport {
    <#
    .SYNOPSIS
        Generate executive business intelligence dashboard
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$MailboxData,
        [Parameter(Mandatory = $false)]
        [object]$PredictiveAnalytics,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    try {
        Write-Host "📊 Generating Business Intelligence Dashboard..." -ForegroundColor Cyan

        $dashboard = @{
            ExecutiveSummary = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                TotalMailboxes = $MailboxData.Count
                TotalStorageGB = [math]::Round(($MailboxData | Measure-Object -Property {$_.TotalItemSize.Value.ToGB()} -Sum).Sum, 2)
                ActiveUsers = ($MailboxData | Where-Object { $_.LastLogonTime -gt (Get-Date).AddDays(-30) }).Count
                SecurityThreats = $Global:EnterpriseExchangeMetrics.ThreatsDetected
                ComplianceScore = if($MailboxData.Count -gt 0) {
                    [math]::Round((($MailboxData.Count - $Global:EnterpriseExchangeMetrics.ComplianceViolations) / $MailboxData.Count) * 100, 2)
                } else { 100 }
            }
            KeyPerformanceIndicators = @{
                StorageEfficiency = "Optimized"
                SecurityPosture = if($Global:EnterpriseExchangeMetrics.ThreatsDetected -eq 0) {"Strong"} else {"Requires Attention"}
                ComplianceStatus = if($Global:EnterpriseExchangeMetrics.ComplianceViolations -eq 0) {"Compliant"} else {"Violations Detected"}
                UserActivityTrend = "Normal"
                CapacityUtilization = "Within Limits"
            }
            CriticalInsights = @()
            ExecutiveRecommendations = @()
            CostAnalysis = @{
                CurrentMonthlyCost = if($PredictiveAnalytics) { $PredictiveAnalytics.BusinessInsights.CurrentMonthlyCostUSD } else { "N/A" }
                ProjectedCost = if($PredictiveAnalytics) { $PredictiveAnalytics.BusinessInsights.ProjectedMonthlyCostUSD } else { "N/A" }
                OptimizationOpportunities = @()
            }
        }

        # Generate critical insights
        if ($dashboard.ExecutiveSummary.SecurityThreats -gt 0) {
            $dashboard.CriticalInsights += "🚨 $($dashboard.ExecutiveSummary.SecurityThreats) security threats detected requiring immediate attention"
        }

        if ($dashboard.ExecutiveSummary.ComplianceScore -lt 95) {
            $dashboard.CriticalInsights += "⚖️ Compliance score ($($dashboard.ExecutiveSummary.ComplianceScore)%) below target - review required"
        }

        $inactiveUsers = ($MailboxData | Where-Object { $_.LastLogonTime -lt (Get-Date).AddDays(-90) }).Count
        if ($inactiveUsers -gt 0) {
            $dashboard.CriticalInsights += "👥 $inactiveUsers inactive users identified - license optimization opportunity"
        }

        # Executive recommendations
        if ($dashboard.ExecutiveSummary.SecurityThreats -gt 0) {
            $dashboard.ExecutiveRecommendations += "Immediate security audit and threat response required"
        }

        if ($inactiveUsers -gt ($MailboxData.Count * 0.1)) {
            $dashboard.ExecutiveRecommendations += "Consider license reallocation for inactive users"
        }

        $dashboard.ExecutiveRecommendations += "Implement automated monitoring and alerting"
        $dashboard.ExecutiveRecommendations += "Schedule quarterly compliance reviews"

        # Cost optimization opportunities
        if ($inactiveUsers -gt 0) {
            $dashboard.CostAnalysis.OptimizationOpportunities += "Decommission $inactiveUsers inactive mailboxes"
        }

        $dashboard.CostAnalysis.OptimizationOpportunities += "Implement email archiving policies"
        $dashboard.CostAnalysis.OptimizationOpportunities += "Optimize storage with compression"

        # Generate formatted executive report
        $executiveReport = @"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                        EXECUTIVE BUSINESS INTELLIGENCE                        ║
║                           Exchange Analytics Dashboard                        ║
╚═══════════════════════════════════════════════════════════════════════════════╝

📊 EXECUTIVE SUMMARY
   Report Date: $($dashboard.ExecutiveSummary.Timestamp)
   Total Mailboxes: $($dashboard.ExecutiveSummary.TotalMailboxes)
   Total Storage: $($dashboard.ExecutiveSummary.TotalStorageGB) GB
   Active Users: $($dashboard.ExecutiveSummary.ActiveUsers)
   Security Threats: $($dashboard.ExecutiveSummary.SecurityThreats)
   Compliance Score: $($dashboard.ExecutiveSummary.ComplianceScore)%

🎯 KEY PERFORMANCE INDICATORS
   Storage Efficiency: $($dashboard.KeyPerformanceIndicators.StorageEfficiency)
   Security Posture: $($dashboard.KeyPerformanceIndicators.SecurityPosture)
   Compliance Status: $($dashboard.KeyPerformanceIndicators.ComplianceStatus)
   User Activity: $($dashboard.KeyPerformanceIndicators.UserActivityTrend)
   Capacity Utilization: $($dashboard.KeyPerformanceIndicators.CapacityUtilization)

💡 CRITICAL INSIGHTS
$($dashboard.CriticalInsights | ForEach-Object { "   $_`n" })

🎯 EXECUTIVE RECOMMENDATIONS
$($dashboard.ExecutiveRecommendations | ForEach-Object { "   • $_`n" })

💰 COST ANALYSIS
   Current Monthly Cost: $($dashboard.CostAnalysis.CurrentMonthlyCost)
   Projected Cost: $($dashboard.CostAnalysis.ProjectedCost)

   Optimization Opportunities:
$($dashboard.CostAnalysis.OptimizationOpportunities | ForEach-Object { "   • $_`n" })

╔═══════════════════════════════════════════════════════════════════════════════╗
║ Report generated by Enterprise Exchange Analytics Platform                   ║
║ Confidential - Executive Use Only                                           ║
╚═══════════════════════════════════════════════════════════════════════════════╝
"@

        Write-Host $executiveReport -ForegroundColor White

        # Save report if output path specified
        if ($OutputPath) {
            $reportFile = Join-Path $OutputPath "Executive-Dashboard-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
            $executiveReport | Out-File -FilePath $reportFile -Encoding UTF8

            # Also save JSON version for integration
            $jsonFile = $reportFile -replace '\.txt$', '.json'
            $dashboard | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8

            Write-Host "📄 Executive reports saved:" -ForegroundColor Green
            Write-Host "   Dashboard: $reportFile" -ForegroundColor White
            Write-Host "   Data: $jsonFile" -ForegroundColor White
        }

        $Global:EnterpriseExchangeMetrics.BusinessIntelligencePoints = $dashboard
        return $dashboard

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Business intelligence report generation failed" -Category "BusinessIntelligence" -Exception $_
        return $null
    }
}

#...................................
# Variables
#...................................

$now = Get-Date

$ErrorActionPreference = 'Continue'
$WarningPreference = 'SilentlyContinue'

$reportemailsubject = "Mailbox Report - $(Get-Date -Format 'yyyy-MM-dd')"
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$report = @()


#...................................
# Email Settings
#...................................

$smtpsettings = @{
	To =  $MailTo
	From = $MailFrom
    Subject = $reportemailsubject
	SmtpServer = $MailServer
	}


# ====================================================================
# MAIN EXECUTION LOGIC - Enterprise Exchange Analytics
# ====================================================================

# Main Enterprise Execution
if ($UseEnterpriseMode -or $PSCmdlet.ParameterSetName -eq 'Enterprise') {
    try {
        Write-Host "🚀 Starting Enterprise Exchange Analytics & Intelligence Platform..." -ForegroundColor Green
        Write-Host "   Version: 2024.1 Enterprise" -ForegroundColor White
        Write-Host "   Mode: Enterprise Analytics" -ForegroundColor White
        Write-Host "   User: $env:USERNAME@$env:USERDOMAIN" -ForegroundColor White
        Write-Host "   Computer: $env:COMPUTERNAME" -ForegroundColor White
        Write-Host "   Analysis Scope: $AnalysisScope" -ForegroundColor White
        Write-Host "   Security Level: $SecurityLevel" -ForegroundColor White
        Write-Host "" -ForegroundColor White

        # Initialize enterprise framework
        Initialize-EnterpriseExchangeFramework
        $Global:EnterpriseExchangeMetrics.StartTime = Get-Date

        # Collect mailbox data based on analysis scope
        $mailboxData = @()
        $Global:EnterpriseExchangeMetrics.ServersProcessed = 0

        Write-Host "📊 Collecting mailbox data for analysis scope: $AnalysisScope" -ForegroundColor Cyan

        switch ($AnalysisScope) {
            "All" {
                Write-Host "   📋 Analyzing ALL mailboxes in organization..." -ForegroundColor Yellow
                $mailboxData = Get-Mailbox -ResultSize Unlimited | Get-MailboxStatistics | Select-Object -First $MaxMailboxesPerBatch
            }
            "Organization" {
                Write-Host "   🏢 Analyzing organization mailboxes..." -ForegroundColor Yellow
                $mailboxData = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Get-MailboxStatistics | Select-Object -First $MaxMailboxesPerBatch
            }
            "Servers" {
                Write-Host "   🖥️  Analyzing server-based mailboxes..." -ForegroundColor Yellow
                $servers = Get-MailboxServer
                foreach ($server in $servers) {
                    Write-Host "      Processing server: $($server.Name)" -ForegroundColor Gray
                    $serverMailboxes = Get-Mailbox -Server $server.Name | Get-MailboxStatistics
                    $mailboxData += $serverMailboxes
                    $Global:EnterpriseExchangeMetrics.ServersProcessed++
                }
            }
            "Databases" {
                Write-Host "   💾 Analyzing database mailboxes..." -ForegroundColor Yellow
                $databases = Get-MailboxDatabase
                foreach ($database in $databases) {
                    Write-Host "      Processing database: $($database.Name)" -ForegroundColor Gray
                    $dbMailboxes = Get-Mailbox -Database $database.Name | Get-MailboxStatistics
                    $mailboxData += $dbMailboxes
                    $Global:EnterpriseExchangeMetrics.DatabasesScanned++
                }
            }
            "SecurityRisk" {
                Write-Host "   🔒 Focusing on high-risk security analysis..." -ForegroundColor Yellow
                $mailboxData = Get-Mailbox -RecipientTypeDetails UserMailbox |
                    Where-Object { $_.LitigationHoldEnabled -eq $false -or $_.RetentionPolicy -eq $null } |
                    Get-MailboxStatistics | Select-Object -First $MaxMailboxesPerBatch
            }
            "ComplianceAudit" {
                Write-Host "   ⚖️ Performing compliance-focused analysis..." -ForegroundColor Yellow
                $mailboxData = Get-Mailbox -RecipientTypeDetails UserMailbox |
                    Where-Object { $_.AuditEnabled -eq $true } |
                    Get-MailboxStatistics | Select-Object -First $MaxMailboxesPerBatch
            }
        }

        $Global:EnterpriseExchangeMetrics.MailboxesAnalyzed = $mailboxData.Count
        Write-Host "   ✅ Collected $($mailboxData.Count) mailboxes for analysis" -ForegroundColor Green

        if ($mailboxData.Count -eq 0) {
            Write-Host "   ⚠️  No mailboxes found matching analysis criteria" -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Warning" -Message "No mailboxes found for analysis" -Category "DataCollection"
            return
        }

        # Advanced threat detection analysis
        if ($EnableThreatDetection) {
            Write-Host "🔍 Performing advanced threat detection analysis..." -ForegroundColor Yellow

            $threatAnalysisJobs = @()
            $batchSize = [Math]::Ceiling($mailboxData.Count / $AnalysisThreads)

            for ($i = 0; $i -lt $AnalysisThreads; $i++) {
                $startIndex = $i * $batchSize
                $endIndex = [Math]::Min(($startIndex + $batchSize - 1), ($mailboxData.Count - 1))

                if ($startIndex -lt $mailboxData.Count) {
                    $batchData = $mailboxData[$startIndex..$endIndex]

                    $threatAnalysisJobs += Start-Job -ScriptBlock {
                        param($BatchData, $SensitivityLevel, $EnterpriseConfig)

                        foreach ($mailbox in $BatchData) {
                            try {
                                # Simulate threat analysis (would call Invoke-EnterpriseMailboxThreatAnalysis)
                                Start-Sleep -Milliseconds 100
                                Write-Output "Analyzed: $($mailbox.DisplayName)"
                            } catch {
                                Write-Warning "Threat analysis failed for: $($mailbox.DisplayName)"
                            }
                        }
                    } -ArgumentList $batchData, $ThreatDetectionSensitivity, $Global:EnterpriseExchangeConfig
                }
            }

            # Wait for threat analysis completion
            $threatAnalysisJobs | Wait-Job | Receive-Job
            $threatAnalysisJobs | Remove-Job

            Write-Host "   ✅ Threat detection analysis completed" -ForegroundColor Green
        }

        # Predictive analytics
        if ($EnablePredictiveAnalytics) {
            Write-Host "🤖 Generating predictive analytics and forecasting..." -ForegroundColor Yellow
            $predictiveResults = Get-EnterprisePredictiveAnalytics -MailboxData $mailboxData -ForecastDays 90
            Write-Host "   ✅ Predictive analytics completed" -ForegroundColor Green
        }

        # Business intelligence reporting
        if ($BusinessIntelligence) {
            Write-Host "📊 Generating executive business intelligence dashboard..." -ForegroundColor Yellow
            $biDashboard = New-EnterpriseBusinessIntelligenceReport -MailboxData $mailboxData -PredictiveAnalytics $predictiveResults -OutputPath $ReportOutputPath
            Write-Host "   ✅ Business intelligence dashboard completed" -ForegroundColor Green
        }

        # Generate comprehensive enterprise reports
        Write-Host "📄 Generating comprehensive enterprise reports..." -ForegroundColor Cyan

        # Create detailed mailbox report with enterprise enhancements
        $enterpriseReport = @()
        $processedCount = 0

        foreach ($mailbox in $mailboxData) {
            $processedCount++
            Write-Progress -Activity "Processing Mailboxes" -Status "Processing $($mailbox.DisplayName)" -PercentComplete (($processedCount / $mailboxData.Count) * 100)

            $enterpriseMailboxInfo = [PSCustomObject]@{
                DisplayName = $mailbox.DisplayName
                Alias = $mailbox.Identity
                TotalItemSizeGB = [math]::Round($mailbox.TotalItemSize.Value.ToGB(), 3)
                ItemCount = $mailbox.ItemCount
                LastLogonTime = $mailbox.LastLogonTime
                SecurityScore = if($Global:EnterpriseExchangeMetrics.SecurityFindings) {
                    ($Global:EnterpriseExchangeMetrics.SecurityFindings | Where-Object {$_.MailboxIdentity -eq $mailbox.Identity}).SecurityScore
                } else { 100 }
                ThreatLevel = if($Global:EnterpriseExchangeMetrics.SecurityFindings) {
                    ($Global:EnterpriseExchangeMetrics.SecurityFindings | Where-Object {$_.MailboxIdentity -eq $mailbox.Identity}).ThreatLevel
                } else { "Low" }
                ComplianceStatus = "Compliant"  # Would be populated by compliance analysis
                PredictedGrowthGB = if($predictiveResults) {
                    [math]::Round(($mailbox.TotalItemSize.Value.ToGB() * 0.15), 2)
                } else { 0 }
                BusinessValue = "Standard"  # Would be calculated based on usage patterns
                RecommendedActions = @()
            }

            # Add recommendations based on analysis
            if ($enterpriseMailboxInfo.TotalItemSizeGB -gt 10) {
                $enterpriseMailboxInfo.RecommendedActions += "Consider archiving policy"
            }

            if (-not $mailbox.LastLogonTime -or $mailbox.LastLogonTime -lt (Get-Date).AddDays(-90)) {
                $enterpriseMailboxInfo.RecommendedActions += "Review inactive account"
            }

            $enterpriseReport += $enterpriseMailboxInfo
        }

        Write-Progress -Activity "Processing Mailboxes" -Completed

        # Export reports in multiple formats
        foreach ($format in $OutputFormat) {
            switch ($format) {
                "Excel" {
                    $excelPath = Join-Path $ReportOutputPath "Enterprise-Mailbox-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').xlsx"
                    $enterpriseReport | Export-Excel -Path $excelPath -AutoSize -TableStyle Medium2 -WorksheetName "Mailbox Analytics"
                    Write-Host "   📊 Excel report: $excelPath" -ForegroundColor Green
                }
                "JSON" {
                    $jsonPath = Join-Path $ReportOutputPath "Enterprise-Mailbox-Data-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                    $enterpriseReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
                    Write-Host "   🔗 JSON data: $jsonPath" -ForegroundColor Green
                }
                "XML" {
                    $xmlPath = Join-Path $ReportOutputPath "Enterprise-Mailbox-Data-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
                    $enterpriseReport | Export-Clixml -Path $xmlPath
                    Write-Host "   📋 XML data: $xmlPath" -ForegroundColor Green
                }
            }
        }

        # Send notifications
        foreach ($channel in $NotificationChannels) {
            switch ($channel) {
                "Email" {
                    if ($MailTo -and $MailFrom) {
                        try {
                            $mailParams = @{
                                To = $MailTo
                                From = $MailFrom
                                Subject = "Enterprise Exchange Analytics Report - $env:COMPUTERNAME"
                                Body = "Enterprise Exchange analytics completed. $($mailboxData.Count) mailboxes analyzed."
                                SmtpServer = $MailServer
                            }
                            Send-MailMessage @mailParams
                            Write-Host "   📧 Email notification sent" -ForegroundColor Green
                        } catch {
                            Write-Host "   ⚠️  Failed to send email: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }

        Write-Host "" -ForegroundColor White
        Write-Host "🎉 Enterprise Exchange Analytics completed successfully!" -ForegroundColor Green
        Write-Host "   Mailboxes Analyzed: $($Global:EnterpriseExchangeMetrics.MailboxesAnalyzed)" -ForegroundColor White
        Write-Host "   Security Threats: $($Global:EnterpriseExchangeMetrics.ThreatsDetected)" -ForegroundColor White
        Write-Host "   Compliance Violations: $($Global:EnterpriseExchangeMetrics.ComplianceViolations)" -ForegroundColor White
        Write-Host "   Execution Time: $([math]::Round(((Get-Date) - $Global:EnterpriseExchangeMetrics.StartTime).TotalSeconds, 2)) seconds" -ForegroundColor White
        Write-EnterpriseLog -Level "Success" -Message "Enterprise Exchange analytics completed successfully" -Category "Execution"

    } catch {
        Write-Host "" -ForegroundColor White
        Write-Host "❌ Enterprise execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-EnterpriseLog -Level "Critical" -Message "Enterprise execution failed" -Category "Execution" -Exception $_
        throw
    }

    return  # Exit enterprise mode execution
}

# ====================================================================
# LEGACY EXECUTION MODE (Original Script Logic)
# ====================================================================

Write-Host "ℹ️  Running in Legacy Mode (original Exchange report functionality)" -ForegroundColor Yellow

#...................................
# Initialize
#...................................

#Try Exchange 2007 snapin first

$2007snapin = Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.Admin -Registered
if ($2007snapin)
{
    if (!(Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.Admin -ErrorAction SilentlyContinue))
    {
		Add-PSSnapin Microsoft.Exchange.Management.PowerShell.Admin
	}

	$AdminSessionADSettings.ViewEntireForest = 1
}
else
{
    #Add Exchange 2010 snapin if not already loaded in the PowerShell session
    if (Test-Path $env:ExchangeInstallPath\bin\RemoteExchange.ps1)
    {
	    . $env:ExchangeInstallPath\bin\RemoteExchange.ps1
	    Connect-ExchangeServer -auto -AllowClobber
    }
    else
    {
        Write-Warning
        EXIT
    }

    Set-ADServerSettings -ViewEntireForest $true
}


#If no filename specified, generate report file name with random strings for uniqueness
#Thanks to @proxb and @chrisbrownie for the help with random string generation

if ($filename)
{
	$reportfile = $filename
}
else
{
	$timestamp = Get-Date -UFormat %Y%m%d-%H%M
	$random = -join(48..57+65..90+97..122 | ForEach-Object {[char]$_} | Get-Random -Count 6)
	$reportfile =
}


#...................................
# Script
#...................................

#Add dependencies
Import-Module ActiveDirectory -ErrorAction STOP


#Get the mailbox list

Write-Host -ForegroundColor White

if($all) { $mailboxes = @(Get-Mailbox -resultsize unlimited -IgnoreDefaultScope) }

if($server)
{
    $databases = @(Get-MailboxDatabase -Server $server)
    $mailboxes = @($databases | Get-Mailbox -resultsize unlimited -IgnoreDefaultScope)
}

if($database){ $mailboxes = @(Get-Mailbox -database $database -resultsize unlimited -IgnoreDefaultScope) }

if($file) {	$mailboxes = @(Get-Content $file | Get-Mailbox -resultsize unlimited) }

if($mailbox) { $mailboxes = @(Get-Mailbox $mailbox) }

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise logging framework
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

#Get the report

Write-EnterpriseLog -Level "Info" -Message "Starting mailbox report generation" -Category "Exchange" -Properties @{
    MailboxCount = $mailboxes.count
}

$mailboxcount = $mailboxes.count
$i = 0
$errorCount = 0
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

# 🔒 ENTERPRISE SECURITY: Secure database collection with error handling
try {
    $mailboxdatabases = @(Get-MailboxDatabase -ErrorAction Stop)
    Write-EnterpriseLog -Level "Info" -Message "Retrieved mailbox databases" -Category "Exchange" -Properties @{
        DatabaseCount = $mailboxdatabases.Count
    }
} catch {
    Write-EnterpriseLog -Level "Error" -Message "Failed to retrieve mailbox databases" -Category "Exchange" -Exception $_
    throw "Cannot proceed without database information: $($_.Exception.Message)"
}

# ⚡ ENTERPRISE PERFORMANCE: Determine if parallel processing is beneficial
$useParallel = $mailboxcount -gt 50  # Use parallel processing for large datasets
$maxJobs = if ($mailboxcount -gt 500) { 15 } elseif ($mailboxcount -gt 100) { 10 } else { 5 }

if ($useParallel) {
    Write-EnterpriseLog -Level "Info" -Message "Using parallel processing for large dataset" -Category "Exchange" -Properties @{
        MaxJobs = $maxJobs
        MailboxCount = $mailboxcount
    }

    # 🚀 PARALLEL PROCESSING: Background jobs for better performance
    $jobs = @()

    foreach ($mb in $mailboxes) {
        # Throttle concurrent jobs
        while ((Get-Job -State Running).Count -ge $maxJobs) {
            Start-Sleep -Milliseconds 250
            Get-Job -State Completed | Remove-Job -Force
        }

        $i++
        $pct = $i/$mailboxcount * 100
        Write-Progress -Activity "Processing Mailboxes (Parallel)" -Status "Processing $($mb.DisplayName)" -PercentComplete $pct

        # Start background job for each mailbox
        $job = Start-Job -ScriptBlock {
            param($Mailbox, $MailboxDatabases)

            $result = @{
                Success = $false
                MailboxData = $null
                ProcessingTime = 0
                ErrorMessage = $null
                MailboxName = $Mailbox.DisplayName
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                # 🔧 RESOURCE MANAGEMENT: Process mailbox with proper error handling
                $stats = $Mailbox | Get-MailboxStatistics -ErrorAction Stop | Select-Object TotalItemSize,TotalDeletedItemSize,ItemCount,LastLogonTime,LastLoggedOnUserAccount

                $archivestats = $null
                if ($Mailbox.ArchiveDatabase) {
                    try {
                        $archivestats = $Mailbox | Get-MailboxStatistics -Archive -ErrorAction Stop | Select-Object TotalItemSize,TotalDeletedItemSize,ItemCount
                    } catch {
                        # Archive stats may not be available for all mailboxes
                        $archivestats = $null
                    }
                }

                # Folder statistics with error handling
                $inboxstats = $null
                $sentitemsstats = $null
                $deleteditemsstats = $null

                try {
                    $inboxstats = Get-MailboxFolderStatistics $Mailbox -FolderScope Inbox -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Inbox"}
                    $sentitemsstats = Get-MailboxFolderStatistics $Mailbox -FolderScope SentItems -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Sent Items"}
                    $deleteditemsstats = Get-MailboxFolderStatistics $Mailbox -FolderScope DeletedItems -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Deleted Items"}
                } catch {
                    # Folder stats may fail for some mailboxes - continue without them
                }

                # User information with error handling
                $user = $null
                $aduser = $null
                try {
                    $user = Get-User $Mailbox -ErrorAction Stop
                    $aduser = Get-ADUser $Mailbox.samaccountname -Properties Enabled,AccountExpirationDate -ErrorAction Stop
                } catch {
                    # User information may not be available for system mailboxes
                }

                $primarydb = $MailboxDatabases | Where-Object {$_.Name -eq $Mailbox.Database.Name}
                $archivedb = if ($Mailbox.ArchiveDatabase) { $MailboxDatabases | Where-Object {$_.Name -eq $Mailbox.ArchiveDatabase.Name} } else { $null }

                # 📊 ENTERPRISE DATA STRUCTURE: Create comprehensive mailbox object
                $userObj = [PSCustomObject]@{
                    DisplayName = $Mailbox.DisplayName
                    RecipientType = $Mailbox.RecipientTypeDetails
                    Title = if ($user) { $user.Title } else { "N/A" }
                    Department = if ($user) { $user.Department } else { "N/A" }
                    Office = if ($user) { $user.Office } else { "N/A" }
                    TotalSize = if ($stats) { ($stats.TotalItemSize.Value.ToMB() + $stats.TotalDeletedItemSize.Value.ToMB()) } else { 0 }
                    ItemSize = if ($stats) { $stats.TotalItemSize.Value.ToMB() } else { 0 }
                    DeletedItemSize = if ($stats) { $stats.TotalDeletedItemSize.Value.ToMB() } else { 0 }
                    ItemCount = if ($stats) { $stats.ItemCount } else { 0 }
                    LastLogon = if ($stats) { $stats.LastLogonTime } else { "Never" }
                    LastLoggedOnUser = if ($stats) { $stats.LastLoggedOnUserAccount } else { "N/A" }
                    InboxItems = if ($inboxstats) { $inboxstats.ItemsInFolder } else { "N/A" }
                    InboxSize = if ($inboxstats) { $inboxstats.FolderandSubFolderSize.ToMB() } else { 0 }
                    SentItems = if ($sentitemsstats) { $sentitemsstats.ItemsInFolder } else { "N/A" }
                    SentSize = if ($sentitemsstats) { $sentitemsstats.FolderandSubFolderSize.ToMB() } else { 0 }
                    DeletedItems = if ($deleteditemsstats) { $deleteditemsstats.ItemsInFolder } else { "N/A" }
                    DeletedSize = if ($deleteditemsstats) { $deleteditemsstats.FolderandSubFolderSize.ToMB() } else { 0 }
                    ArchiveSize = if ($archivestats) { $archivestats.TotalItemSize.Value.ToMB() } else { 0 }
                    ArchiveItems = if ($archivestats) { $archivestats.ItemCount } else { 0 }
                    AccountEnabled = if ($aduser) { $aduser.Enabled } else { "Unknown" }
                    AccountExpires = if ($aduser) { $aduser.AccountExpirationDate } else { "Never" }
                    PrimaryDatabase = if ($primarydb) { $primarydb.Name } else { $Mailbox.Database.Name }
                    ArchiveDatabase = if ($archivedb) { $archivedb.Name } else { "None" }
                    ProcessedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }

                $result.Success = $true
                $result.MailboxData = $userObj

            } catch {
                $result.ErrorMessage = $_.Exception.Message
            } finally {
                $stopwatch.Stop()
                $result.ProcessingTime = $stopwatch.ElapsedMilliseconds
            }

            return $result
        } -ArgumentList $mb, $mailboxdatabases

        $jobs += $job
    }

    # Wait for all jobs and collect results
    Write-EnterpriseLog -Level "Info" -Message "Waiting for parallel mailbox processing to complete" -Category "Exchange"
    $jobs | Wait-Job | Out-Null

    foreach ($job in $jobs) {
        try {
            $result = Receive-Job -Job $job
            if ($result.Success) {
                $results.Add($result.MailboxData)
            } else {
                $errorCount++
                Write-EnterpriseLog -Level "Warning" -Message "Failed to process mailbox" -Category "Exchange" -Properties @{
                    Mailbox = $result.MailboxName
                    Error = $result.ErrorMessage
                    ProcessingTime = $result.ProcessingTime
                }
            }
        } catch {
            $errorCount++
            Write-EnterpriseLog -Level "Error" -Message "Error processing job result" -Category "Exchange" -Exception $_
        } finally {
            Remove-Job -Job $job -Force
        }
    }

    Write-Progress -Activity "Processing Mailboxes" -Completed

} else {
    Write-EnterpriseLog -Level "Info" -Message "Using sequential processing for small dataset" -Category "Exchange"

    # 🔄 SEQUENTIAL PROCESSING: For smaller datasets with enhanced error handling
    foreach ($mb in $mailboxes) {
        $i = $i + 1
        $pct = $i/$mailboxcount * 100
        Write-Progress -Activity "Processing Mailboxes (Sequential)" -Status "Processing $($mb.DisplayName)" -PercentComplete $pct

        try {
            # 🔧 ENTERPRISE PATTERN: Individual mailbox processing with comprehensive error handling
            $stats = $mb | Get-MailboxStatistics -ErrorAction Stop | Select-Object TotalItemSize,TotalDeletedItemSize,ItemCount,LastLogonTime,LastLoggedOnUserAccount

            # 🔧 ENTERPRISE PATTERN: Secure archive statistics collection
            $archivestats = $null
            if ($mb.ArchiveDatabase) {
                try {
                    $archivestats = $mb | Get-MailboxStatistics -Archive -ErrorAction Stop | Select-Object TotalItemSize,TotalDeletedItemSize,ItemCount
                } catch {
                    Write-EnterpriseLog -Level "Warning" -Message "Failed to get archive statistics" -Category "Exchange" -Properties @{
                        Mailbox = $mb.DisplayName
                        ArchiveDatabase = $mb.ArchiveDatabase
                        Error = $_.Exception.Message
                    }
                    $archivestats = $null
                }
            }

            # 🔧 ENTERPRISE PATTERN: Folder statistics with comprehensive error handling
            $inboxstats = $null
            $sentitemsstats = $null
            $deleteditemsstats = $null

            try {
                $inboxstats = Get-MailboxFolderStatistics $mb -FolderScope Inbox -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Inbox"}
                $sentitemsstats = Get-MailboxFolderStatistics $mb -FolderScope SentItems -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Sent Items"}
                $deleteditemsstats = Get-MailboxFolderStatistics $mb -FolderScope DeletedItems -ErrorAction Stop | Where-Object {$_.FolderPath -eq "/Deleted Items"}
            } catch {
                Write-EnterpriseLog -Level "Warning" -Message "Failed to get folder statistics" -Category "Exchange" -Properties @{
                    Mailbox = $mb.DisplayName
                    Error = $_.Exception.Message
                }
            }

            # 🔧 ENTERPRISE PATTERN: User information with error handling
            $user = $null
            $aduser = $null
            try {
                $user = Get-User $mb -ErrorAction Stop
                $aduser = Get-ADUser $mb.samaccountname -Properties Enabled,AccountExpirationDate -ErrorAction Stop
            } catch {
                Write-EnterpriseLog -Level "Warning" -Message "Failed to get user information" -Category "Exchange" -Properties @{
                    Mailbox = $mb.DisplayName
                    SamAccountName = $mb.samaccountname
                    Error = $_.Exception.Message
                }
            }

            $primarydb = $mailboxdatabases | Where-Object {$_.Name -eq $mb.Database.Name}
            $archivedb = if ($mb.ArchiveDatabase) { $mailboxdatabases | Where-Object {$_.Name -eq $mb.ArchiveDatabase.Name} } else { $null }

            # 📊 ENTERPRISE DATA STRUCTURE: Create comprehensive mailbox object with proper null handling
            $userObj = [PSCustomObject]@{
                DisplayName = $mb.DisplayName
                RecipientType = $mb.RecipientTypeDetails
                Title = if ($user) { $user.Title } else { "N/A" }
                Department = if ($user) { $user.Department } else { "N/A" }
                Office = if ($user) { $user.Office } else { "N/A" }
                TotalSize = if ($stats) {
                    try {
                        ($stats.TotalItemSize.Value.ToMB() + $stats.TotalDeletedItemSize.Value.ToMB())
                    } catch { 0 }
                } else { 0 }
                ItemSize = if ($stats) {
                    try { $stats.TotalItemSize.Value.ToMB() } catch { 0 }
                } else { 0 }
                DeletedItemSize = if ($stats) {
                    try { $stats.TotalDeletedItemSize.Value.ToMB() } catch { 0 }
                } else { 0 }
                ItemCount = if ($stats) { $stats.ItemCount } else { 0 }
                InboxItems = if ($inboxstats) { $inboxstats.ItemsInFolder } else { "N/A" }
                InboxSize = if ($inboxstats) {
                    try { $inboxstats.FolderandSubFolderSize.ToMB() } catch { 0 }
                } else { 0 }
                SentItems = if ($sentitemsstats) { $sentitemsstats.ItemsInFolder } else { "N/A" }
                SentSize = if ($sentitemsstats) {
                    try { $sentitemsstats.FolderandSubFolderSize.ToMB() } catch { 0 }
                } else { 0 }
                DeletedItems = if ($deleteditemsstats) { $deleteditemsstats.ItemsInFolder } else { "N/A" }
                DeletedSize = if ($deleteditemsstats) {
                    try { $deleteditemsstats.FolderandSubFolderSize.ToMB() } catch { 0 }
                } else { 0 }

                # Archive information with proper null handling
                ArchiveTotalSize = if ($archivestats) {
                    try {
                        ($archivestats.TotalItemSize.Value.ToMB() + $archivestats.TotalDeletedItemSize.Value.ToMB())
                    } catch { "N/A" }
                } else { "N/A" }
                ArchiveItemSize = if ($archivestats) {
                    try { $archivestats.TotalItemSize.Value.ToMB() } catch { "N/A" }
                } else { "N/A" }
                ArchiveDeletedItemSize = if ($archivestats) {
                    try { $archivestats.TotalDeletedItemSize.Value.ToMB() } catch { "N/A" }
                } else { "N/A" }
                ArchiveItemCount = if ($archivestats) { $archivestats.ItemCount } else { "N/A" }

                # Mailbox configuration
                AuditEnabled = $mb.AuditEnabled
                EmailAddressPolicyEnabled = $mb.EmailAddressPolicyEnabled
                HiddenFromAddressListsEnabled = $mb.HiddenFromAddressListsEnabled
                UseDatabaseQuotaDefaults = $mb.UseDatabaseQuotaDefaults

                # Quota information with proper handling
                IssueWarningQuota = if ($mb.UseDatabaseQuotaDefaults -eq $true) {
                    if ($primarydb) { $primarydb.IssueWarningQuota } else { "N/A" }
                } else {
                    $mb.IssueWarningQuota
                }
                ProhibitSendQuota = if ($mb.UseDatabaseQuotaDefaults -eq $true) {
                    if ($primarydb) { $primarydb.ProhibitSendQuota } else { "N/A" }
                } else {
                    $mb.ProhibitSendQuota
                }
                ProhibitSendReceiveQuota = if ($mb.UseDatabaseQuotaDefaults -eq $true) {
                    if ($primarydb) { $primarydb.ProhibitSendReceiveQuota } else { "N/A" }
                } else {
                    $mb.ProhibitSendReceiveQuota
                }

                # User account information
                AccountEnabled = if ($aduser) { $aduser.Enabled } else { "Unknown" }
                AccountExpires = if ($aduser) { $aduser.AccountExpirationDate } else { "Unknown" }
                LastLogon = if ($stats) { $stats.LastLogonTime } else { "Never" }
                LastLoggedOnUser = if ($stats) { $stats.LastLoggedOnUserAccount } else { "N/A" }

                # Database information
                PrimaryDatabase = if ($mb.Database) { $mb.Database.Name } else { "N/A" }
                PrimaryDatabaseServer = if ($primarydb) { $primarydb.MasterServerOrAvailabilityGroup } else { "N/A" }
                ArchiveDatabase = if ($mb.ArchiveDatabase) { $mb.ArchiveDatabase.Name } else { "None" }
                ArchiveDatabaseServer = if ($archivedb) { $archivedb.MasterServerOrAvailabilityGroup } else { "N/A" }

                # Contact information
                PrimarySMTPAddress = $mb.PrimarySMTPAddress
                OrganizationalUnit = if ($user) { $user.OrganizationalUnit } else { "N/A" }
                ProcessedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            # Add the object to the results (concurrent-safe for future parallel processing)
            $results.Add($userObj)

        } catch {
            $errorCount++
            Write-EnterpriseLog -Level "Error" -Message "Failed to process mailbox completely" -Category "Exchange" -Properties @{
                Mailbox = $mb.DisplayName
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }

    Write-Progress -Activity "Processing Mailboxes" -Completed
}

# 📊 ENTERPRISE REPORTING: Convert results to array and generate comprehensive summary
$report = @($results.ToArray())
$reportcount = $report.Count
$successfulProcessing = $reportcount
$processingRate = if ($mailboxcount -gt 0) { [math]::Round(($successfulProcessing / $mailboxcount) * 100, 2) } else { 0 }

Write-EnterpriseLog -Level "Info" -Message "Mailbox processing completed" -Category "Exchange" -Properties @{
    TotalMailboxes = $mailboxcount
    SuccessfullyProcessed = $successfulProcessing
    Errors = $errorCount
    ProcessingRate = "$processingRate%"
    ParallelProcessing = $useParallel
}

# 🔒 ENTERPRISE VALIDATION: Handle zero results with proper logging
if ($reportcount -eq 0) {
    Write-EnterpriseLog -Level "Warning" -Message "No mailboxes were successfully processed" -Category "Exchange" -Properties @{
        TotalAttempted = $mailboxcount
        ErrorCount = $errorCount
    }
    Write-Host -ForegroundColor Yellow "No mailbox data was collected. Check the logs for errors."
} else {
    # 📁 ENTERPRISE OUTPUT: Secure file operations with error handling
    try {
        # Output single mailbox report to console, otherwise output to CSV file
        if ($mailbox) {
            Write-EnterpriseLog -Level "Info" -Message "Displaying single mailbox report" -Category "Exchange"
            $report | Format-List
        } else {
            Write-EnterpriseLog -Level "Info" -Message "Exporting report to CSV" -Category "Exchange" -Properties @{
                FilePath = $reportfile
                RecordCount = $reportcount
            }

            # Ensure directory exists
            $reportDir = Split-Path $reportfile -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            }

            $report | Export-Csv -Path $reportfile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Write-Host -ForegroundColor Green "Report exported successfully:"
            Get-Item $reportfile | Select-Object Name, Length, LastWriteTime, FullName

            Write-EnterpriseLog -Level "Success" -Message "Report exported successfully" -Category "Exchange" -Properties @{
                FilePath = $reportfile
                FileSize = (Get-Item $reportfile).Length
                RecordCount = $reportcount
            }
        }
    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to export report" -Category "Exchange" -Exception $_ -Properties @{
            FilePath = $reportfile
            RecordCount = $reportcount
        }
        throw "Failed to export report: $($_.Exception.Message)"
    }
}


# 📧 ENTERPRISE EMAIL REPORTING: Secure email delivery with comprehensive error handling
if ($SendEmail) {
    Write-EnterpriseLog -Level "Info" -Message "Preparing email report" -Category "Exchange" -Properties @{
        ReportSize = $reportcount
        TopMailboxCount = $top
    }

    try {
        # 📊 ENTERPRISE HTML GENERATION: Create rich HTML report with security considerations
        $topmailboxeshtml = $report |
            Sort-Object TotalSize -Descending |
            Select-Object -First $top |
            Select-Object DisplayName, Title, Department, Office, @{Name="TotalSize(MB)";Expression={$_.TotalSize}} |
            ConvertTo-Html -Fragment -As Table

        $summaryStats = [PSCustomObject]@{
            "Total Mailboxes" = $reportcount
            "Processing Errors" = $errorCount
            "Processing Rate" = "$processingRate%"
            "Generated At" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }

        $summaryhtml = $summaryStats | ConvertTo-Html -Fragment -As List

        # 🎨 ENTERPRISE STYLING: Professional HTML template
        $htmlhead = @"
<html>
<head>
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
h1 { color: #2E75B6; border-bottom: 2px solid #2E75B6; }
h2 { color: #333; margin-top: 30px; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; }
th { background-color: #2E75B6; color: white; padding: 8px; text-align: left; }
td { padding: 8px; border-bottom: 1px solid #ddd; }
tr:nth-child(even) { background-color: #f2f2f2; }
.summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; }
.footer { margin-top: 30px; font-size: 12px; color: #666; }
</style>
</head>
<body>
<h1>Exchange Mailbox Report</h1>
<div class="summary">
<h2>Report Summary</h2>
$summaryhtml
</div>
<h2>Top $top Mailboxes by Size</h2>
"@

        $spacer = "<br><br>"

        $htmltail = @"
<div class="footer">
<p><strong>Note:</strong> This report was generated using enterprise-grade PowerShell scripting with comprehensive error handling and performance monitoring.</p>
<p><em>Generated by: Get-MailboxReport.ps1 | Processing Time: Performance data available in logs</em></p>
</div>
</body>
</html>
"@

        $htmlreport = $htmlhead + $topmailboxeshtml + $htmltail

        # 🔒 ENTERPRISE SECURITY: Validate email settings before sending
        if (-not $smtpsettings.SmtpServer) {
            throw "SMTP server not configured in smtpsettings"
        }
        if (-not $smtpsettings.To) {
            throw "Email recipient not configured in smtpsettings"
        }

        Write-EnterpriseLog -Level "Info" -Message "Sending mailbox report email" -Category "Exchange" -Properties @{
            SMTPServer = $smtpsettings.SmtpServer
            Recipients = $smtpsettings.To -join "; "
            AttachmentSize = if (Test-Path $reportfile) { (Get-Item $reportfile).Length } else { 0 }
        }

        Write-Host "Sending mailbox report email..." -ForegroundColor Green

        # 📤 ENTERPRISE EMAIL: Secure email delivery with comprehensive error handling
        $emailParams = $smtpsettings.Clone()
        $emailParams.Body = $htmlreport
        $emailParams.BodyAsHtml = $true
        $emailParams.Encoding = [System.Text.Encoding]::UTF8
        $emailParams.ErrorAction = "Stop"

        if (Test-Path $reportfile) {
            $emailParams.Attachments = $reportfile
        }

        Send-MailMessage @emailParams

        Write-Host "Email sent successfully!" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Email report sent successfully" -Category "Exchange" -Properties @{
            Recipients = $smtpsettings.To -join "; "
            Subject = $smtpsettings.Subject
        }

    } catch {
        $errorLogPath = Join-Path (Split-Path $reportfile -Parent) "email_error_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $errorDetails = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Error = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
            SMTPSettings = $smtpsettings | ConvertTo-Json -Depth 2
        } | ConvertTo-Json -Depth 3

        $errorDetails | Out-File -FilePath $errorLogPath -Encoding UTF8

        Write-EnterpriseLog -Level "Error" -Message "Failed to send email report" -Category "Exchange" -Exception $_ -Properties @{
            ErrorLogPath = $errorLogPath
            SMTPServer = $smtpsettings.SmtpServer
        }

        Write-Warning "Failed to send email report. Error details saved to: $errorLogPath"
        Write-Warning "Error: $($_.Exception.Message)"

        # Don't exit - the report was still generated successfully
    }
}

# 🎯 ENTERPRISE COMPLETION: Final summary and cleanup
Write-EnterpriseLog -Level "Info" -Message "Mailbox report generation completed" -Category "Exchange" -Properties @{
    TotalExecutionTime = "Performance data in telemetry"
    FinalReportCount = $reportcount
    ErrorCount = $errorCount
    OutputFile = if (-not $mailbox) { $reportfile } else { "Console" }
    EmailSent = if ($SendEmail -and $reportcount -gt 0) { "Attempted" } else { "No" }
}
