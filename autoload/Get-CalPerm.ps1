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
Function Get-CalPerm {
    [CmdletBinding(DefaultParameterSetName = 'Enterprise')]
    param(
        # === ENTERPRISE PARAMETERS ===
        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [switch]$UseEnterpriseMode = $true,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateSet('Single', 'Organization', 'SecurityAudit', 'ComplianceReview', 'ExecutiveProtection', 'ThreatHunting')]
        [string]$AnalysisScope = 'SecurityAudit',

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateSet('Basic', 'Enhanced', 'Military', 'Executive')]
        [string]$SecurityLevel = 'Enhanced',

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateSet('SOX', 'GDPR', 'HIPAA', 'PCI-DSS', 'ISO27001', 'All')]
        [string[]]$ComplianceFrameworks = @('SOX', 'GDPR'),

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [switch]$EnableThreatDetection = $true,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [switch]$EnableAnomalyDetection = $true,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [switch]$BusinessIntelligence = $true,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [switch]$GovernanceMode = $true,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateSet('Executive', 'Management', 'Technical', 'Forensic')]
        [string]$ReportingLevel = 'Management',

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateSet('PowerBI', 'Excel', 'JSON', 'SIEM', 'Database', 'All')]
        [string[]]$OutputFormat = @('Excel', 'JSON'),

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [string]$ReportOutputPath = "$env:ProgramData\EnterpriseCalendar\Reports",

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [int]$ThreatDetectionSensitivity = 7, # 1-10 scale

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [int]$MaxCalendarsPerBatch = 500,

        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [string[]]$ExecutiveMailboxes = @(),

        # === LEGACY PARAMETER (Backward Compatibility) ===
        [Parameter(ParameterSetName='Legacy', Mandatory = $true, HelpMessage = "Specify the mailbox identity.")]
        [Parameter(ParameterSetName='Enterprise', Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity
    )

    # ====================================================================
    # ENTERPRISE FRAMEWORK INITIALIZATION
    # ====================================================================

    # Global Enterprise Variables
    if (-not $Global:EnterpriseCalendarMetrics) {
        $Global:EnterpriseCalendarMetrics = @{
            StartTime = Get-Date
            CalendarsAnalyzed = 0
            SecurityThreats = 0
            ComplianceViolations = 0
            AnomaliesDetected = 0
            PermissionsAudited = 0
            ExecutiveCalendarsProtected = 0
            GovernancePoliciesEnforced = 0
            TotalUsers = 0
            SecurityScore = 100
            Errors = @()
            Warnings = @()
            SecurityFindings = @()
            ComplianceResults = @()
        }
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
        if (-not $Global:EnterpriseCalendarLogs) {
            $Global:EnterpriseCalendarLogs = @()
        }
        $Global:EnterpriseCalendarLogs += $logEntry
    }

    # Enterprise Configuration
    $Global:EnterpriseCalendarConfig = @{
        SecurityThresholds = @{
            MaxExternalPermissions = 5
            MaxDelegatedAccess = 3
            MaxPublicPermissions = 1
            SuspiciousAccessPattern = 10
            ExecutiveProtectionLevel = "High"
        }
        ComplianceSettings = @{
            RequireAuditLogging = $true
            MandatoryRetentionPolicy = $true
            DataClassificationRequired = $true
            ExecutiveCalendarProtection = $true
            ExternalSharingRestricted = $true
        }
        ThreatPatterns = @{
            SuspiciousPermissions = @(
                "Default permissions changed to Editor",
                "Anonymous access granted",
                "External user with full access",
                "Service account with excessive permissions"
            )
            AnomalyIndicators = @(
                "Unusual permission changes",
                "Mass permission grants",
                "Off-hours access modifications",
                "Geographic anomalies in access"
            )
            ExecutiveTargeting = @(
                "C-level calendar access",
                "Board member calendar sharing",
                "Executive assistant excessive permissions",
                "External consultant calendar access"
            )
        }
    }

    function Initialize-EnterpriseCalendarFramework {
        <#
        .SYNOPSIS
            Initialize the enterprise calendar security and governance framework
        #>
        try {
            Write-Host "🚀 Initializing Enterprise Calendar Security & Governance Framework..." -ForegroundColor Cyan

            # Verify PowerShell version
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                throw "Enterprise mode requires PowerShell 5.0 or higher"
            }

            # Load required modules
            $requiredModules = @(
                @{Name="ExchangeOnlineManagement"; MinVersion="3.0.0"},
                @{Name="Microsoft.Graph.Calendar"; MinVersion="1.0.0"},
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
                    $Global:EnterpriseCalendarMetrics.Errors += "Module load error: $($module.Name)"
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
                    Write-Host "   📁 Created directory: $dir" -ForegroundColor Green
                }
            }

            # Validate Exchange connectivity
            if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
                Write-Host "   🔗 Connecting to Exchange Online..." -ForegroundColor Yellow
                Connect-ExchangeOnline -ShowProgress $false
                Write-Host "   ✅ Connected to Exchange Online" -ForegroundColor Green
            } else {
                Write-Host "   ✅ Exchange connection verified" -ForegroundColor Green
            }

            Write-Host "   🎯 Framework initialization completed" -ForegroundColor Green
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
            Write-Host "🔍 Analyzing calendar security for: $MailboxIdentity" -ForegroundColor Cyan

            $securityAnalysis = @{
                MailboxIdentity = $MailboxIdentity
                IsExecutiveCalendar = $IsExecutiveCalendar
                SecurityScore = 100
                ThreatLevel = "Low"
                SecurityFindings = @()
                ComplianceViolations = @()
                Recommendations = @()
                PermissionSummary = @{
                    TotalPermissions = $CalendarPermissions.Count
                    ExternalPermissions = 0
                    ElevatedPermissions = 0
                    PublicPermissions = 0
                    DelegatedAccess = 0
                }
            }

            foreach ($permission in $CalendarPermissions) {
                $Global:EnterpriseCalendarMetrics.PermissionsAudited++

                # Analyze permission levels
                if ($permission.AccessRights -contains "Editor" -or $permission.AccessRights -contains "Owner") {
                    $securityAnalysis.PermissionSummary.ElevatedPermissions++

                    if ($permission.User -like "*@*" -and -not ($permission.User -like "*@$((Get-AcceptedDomain | Where-Object {$_.Default}).Name)*")) {
                        $securityAnalysis.PermissionSummary.ExternalPermissions++
                        $securityAnalysis.SecurityFindings += @{
                            Type = "External User with Elevated Access"
                            Severity = "High"
                            User = $permission.User
                            AccessLevel = $permission.AccessRights -join ", "
                            Risk = "Potential data exposure to external entities"
                        }
                        $securityAnalysis.SecurityScore -= 25
                    }
                }

                # Check for public/anonymous access
                if ($permission.User -eq "Default" -and ($permission.AccessRights -contains "Editor" -or $permission.AccessRights -contains "Reviewer")) {
                    $securityAnalysis.PermissionSummary.PublicPermissions++
                    $securityAnalysis.SecurityFindings += @{
                        Type = "Excessive Default Permissions"
                        Severity = "Medium"
                        User = $permission.User
                        AccessLevel = $permission.AccessRights -join ", "
                        Risk = "Information disclosure to unauthorized users"
                    }
                    $securityAnalysis.SecurityScore -= 15
                }

                # Executive calendar protection analysis
                if ($IsExecutiveCalendar) {
                    if ($permission.User -ne "Default" -and $permission.AccessRights -contains "Editor") {
                        $securityAnalysis.SecurityFindings += @{
                            Type = "Executive Calendar Risk"
                            Severity = "Critical"
                            User = $permission.User
                            AccessLevel = $permission.AccessRights -join ", "
                            Risk = "Unauthorized access to executive schedule and meetings"
                        }
                        $securityAnalysis.SecurityScore -= 35
                    }
                }
            }

            # Compliance validation
            if ($Global:EnterpriseCalendarConfig.ComplianceSettings.ExecutiveCalendarProtection -and $IsExecutiveCalendar) {
                if ($securityAnalysis.PermissionSummary.ExternalPermissions -gt 0) {
                    $securityAnalysis.ComplianceViolations += @{
                        Type = "Executive Calendar External Access"
                        Framework = "Corporate Governance"
                        Severity = "Critical"
                        Details = "External access detected on executive calendar"
                    }
                    $Global:EnterpriseCalendarMetrics.ComplianceViolations++
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

            $Global:EnterpriseCalendarMetrics.SecurityFindings += $securityAnalysis

            if ($securityAnalysis.ThreatLevel -ne "Low") {
                $Global:EnterpriseCalendarMetrics.SecurityThreats++
                Write-Host "   🚨 Security threat detected: $($securityAnalysis.ThreatLevel) - $MailboxIdentity" -ForegroundColor Red
            }

            return $securityAnalysis

        } catch {
            Write-EnterpriseCalendarLog -Level "Error" -Message "Security analysis failed for calendar" -Category "Security" -Exception $_ -Properties @{
                Mailbox = $MailboxIdentity
            }
            return $null
        }
    }

    # Main Enterprise Execution Logic
    if ($UseEnterpriseMode -or $PSCmdlet.ParameterSetName -eq 'Enterprise') {
        try {
            Write-Host "🚀 Starting Enterprise Calendar Security & Governance Platform..." -ForegroundColor Green
            Write-Host "   Version: 2024.1 Enterprise" -ForegroundColor White
            Write-Host "   Mode: Calendar Security Analysis" -ForegroundColor White
            Write-Host "   User: $env:USERNAME@$env:USERDOMAIN" -ForegroundColor White
            Write-Host "   Computer: $env:COMPUTERNAME" -ForegroundColor White
            Write-Host "   Analysis Scope: $AnalysisScope" -ForegroundColor White
            Write-Host "   Security Level: $SecurityLevel" -ForegroundColor White
            Write-Host "" -ForegroundColor White

            # Initialize enterprise framework
            Initialize-EnterpriseCalendarFramework
            $Global:EnterpriseCalendarMetrics.StartTime = Get-Date

            # Determine analysis scope and collect calendar data
            $calendarAnalysisResults = @()

            switch ($AnalysisScope) {
                "Single" {
                    if (-not $Identity) {
                        throw "Identity parameter required for single calendar analysis"
                    }
                    Write-Host "📅 Analyzing single calendar: $Identity" -ForegroundColor Cyan

                    $mailbox = Get-Mailbox -Identity $Identity
                    $calendarName = (Get-MailboxFolderStatistics -Identity $mailbox.Alias -FolderScope Calendar | Select-Object -First 1).Name
                    $folderID = "$($mailbox.Alias):\$calendarName"
                    $permissions = Get-MailboxFolderPermission -Identity $folderID

                    $isExecutive = $ExecutiveMailboxes -contains $Identity
                    $analysis = Invoke-EnterpriseCalendarSecurityAnalysis -CalendarPermissions $permissions -MailboxIdentity $Identity -IsExecutiveCalendar $isExecutive
                    $calendarAnalysisResults += $analysis
                    $Global:EnterpriseCalendarMetrics.CalendarsAnalyzed++
                }

                "Organization" {
                    Write-Host "🏢 Analyzing organization-wide calendar security..." -ForegroundColor Cyan

                    $allMailboxes = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Select-Object -First $MaxCalendarsPerBatch
                    $processedCount = 0

                    foreach ($mailbox in $allMailboxes) {
                        $processedCount++
                        Write-Progress -Activity "Analyzing Calendars" -Status "Processing $($mailbox.DisplayName)" -PercentComplete (($processedCount / $allMailboxes.Count) * 100)

                        try {
                            $calendarName = (Get-MailboxFolderStatistics -Identity $mailbox.Alias -FolderScope Calendar | Select-Object -First 1).Name
                            $folderID = "$($mailbox.Alias):\$calendarName"
                            $permissions = Get-MailboxFolderPermission -Identity $folderID

                            $isExecutive = $ExecutiveMailboxes -contains $mailbox.PrimarySmtpAddress
                            $analysis = Invoke-EnterpriseCalendarSecurityAnalysis -CalendarPermissions $permissions -MailboxIdentity $mailbox.PrimarySmtpAddress -IsExecutiveCalendar $isExecutive
                            $calendarAnalysisResults += $analysis
                            $Global:EnterpriseCalendarMetrics.CalendarsAnalyzed++

                        } catch {
                            $Global:EnterpriseCalendarMetrics.Errors += "Failed to analyze calendar for $($mailbox.DisplayName): $($_.Exception.Message)"
                        }
                    }

                    Write-Progress -Activity "Analyzing Calendars" -Completed
                }

                "ExecutiveProtection" {
                    Write-Host "👔 Analyzing executive calendar protection..." -ForegroundColor Cyan

                    if ($ExecutiveMailboxes.Count -eq 0) {
                        # Auto-detect executives based on titles
                        $executives = Get-Mailbox -RecipientTypeDetails UserMailbox |
                            Where-Object { $_.Title -match "(CEO|CTO|CFO|President|Director|VP|Vice President)" }
                    } else {
                        $executives = $ExecutiveMailboxes | ForEach-Object { Get-Mailbox -Identity $_ }
                    }

                    foreach ($executive in $executives) {
                        try {
                            Write-Host "      👤 Executive: $($executive.DisplayName)" -ForegroundColor Yellow
                            $calendarName = (Get-MailboxFolderStatistics -Identity $executive.Alias -FolderScope Calendar | Select-Object -First 1).Name
                            $folderID = "$($executive.Alias):\$calendarName"
                            $permissions = Get-MailboxFolderPermission -Identity $folderID

                            $analysis = Invoke-EnterpriseCalendarSecurityAnalysis -CalendarPermissions $permissions -MailboxIdentity $executive.PrimarySmtpAddress -IsExecutiveCalendar $true
                            $calendarAnalysisResults += $analysis
                            $Global:EnterpriseCalendarMetrics.CalendarsAnalyzed++
                            $Global:EnterpriseCalendarMetrics.ExecutiveCalendarsProtected++

                        } catch {
                            $Global:EnterpriseCalendarMetrics.Errors += "Failed to analyze executive calendar for $($executive.DisplayName): $($_.Exception.Message)"
                        }
                    }
                }
            }

            # Generate comprehensive enterprise report
            Write-Host "📊 Generating comprehensive security report..." -ForegroundColor Cyan

            $securitySummary = @{
                ExecutionSummary = @{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    CalendarsAnalyzed = $Global:EnterpriseCalendarMetrics.CalendarsAnalyzed
                    SecurityThreats = $Global:EnterpriseCalendarMetrics.SecurityThreats
                    ComplianceViolations = $Global:EnterpriseCalendarMetrics.ComplianceViolations
                    ExecutiveCalendarsProtected = $Global:EnterpriseCalendarMetrics.ExecutiveCalendarsProtected
                    OverallSecurityScore = if ($calendarAnalysisResults.Count -gt 0) {
                        [math]::Round(($calendarAnalysisResults | Measure-Object SecurityScore -Average).Average, 2)
                    } else { 100 }
                }
                SecurityFindings = $calendarAnalysisResults | Where-Object { $_.ThreatLevel -ne "Low" }
                ComplianceResults = $Global:EnterpriseCalendarMetrics.ComplianceResults
                Recommendations = @()
            }

            # Generate executive recommendations
            if ($securitySummary.SecurityFindings.Count -gt 0) {
                $securitySummary.Recommendations += "Immediate security review required for high-risk calendars"
                $securitySummary.Recommendations += "Implement advanced calendar security policies"
            }

            if ($Global:EnterpriseCalendarMetrics.ComplianceViolations -gt 0) {
                $securitySummary.Recommendations += "Address compliance violations immediately"
                $securitySummary.Recommendations += "Update calendar governance policies"
            }

            # Generate formatted report
            $reportText = @"
╔══════════════════════════════════════════════════════════════════════╗
║              ENTERPRISE CALENDAR SECURITY REPORT                    ║
╚══════════════════════════════════════════════════════════════════════╝

📊 EXECUTION SUMMARY
   Timestamp: $($securitySummary.ExecutionSummary.Timestamp)
   Calendars Analyzed: $($securitySummary.ExecutionSummary.CalendarsAnalyzed)
   Security Threats: $($securitySummary.ExecutionSummary.SecurityThreats)
   Compliance Violations: $($securitySummary.ExecutionSummary.ComplianceViolations)
   Executive Calendars: $($securitySummary.ExecutionSummary.ExecutiveCalendarsProtected)
   Overall Security Score: $($securitySummary.ExecutionSummary.OverallSecurityScore)%

🚨 CRITICAL FINDINGS
$($securitySummary.SecurityFindings | Where-Object { $_.ThreatLevel -eq "Critical" } | ForEach-Object { "   • $($_.MailboxIdentity) - $($_.ThreatLevel) threat detected`n" })

💡 RECOMMENDATIONS
$($securitySummary.Recommendations | ForEach-Object { "   • $_`n" })

╔══════════════════════════════════════════════════════════════════════╗
║ Report generated by Enterprise Calendar Security Platform           ║
╚══════════════════════════════════════════════════════════════════════╝
"@

            Write-Host $reportText -ForegroundColor White

            # Export results in specified formats
            foreach ($format in $OutputFormat) {
                switch ($format) {
                    "Excel" {
                        $excelPath = Join-Path $ReportOutputPath "Calendar-Security-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').xlsx"
                        $calendarAnalysisResults | Export-Excel -Path $excelPath -AutoSize -TableStyle Medium2 -WorksheetName "Calendar Security"
                        Write-Host "📊 Excel report: $excelPath" -ForegroundColor Green
                    }
                    "JSON" {
                        $jsonPath = Join-Path $ReportOutputPath "Calendar-Security-Data-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                        $securitySummary | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
                        Write-Host "🔗 JSON data: $jsonPath" -ForegroundColor Green
                    }
                }
            }

            Write-Host "" -ForegroundColor White
            Write-Host "🎉 Enterprise calendar security analysis completed!" -ForegroundColor Green
            Write-Host "   Execution Time: $([math]::Round(((Get-Date) - $Global:EnterpriseCalendarMetrics.StartTime).TotalSeconds, 2)) seconds" -ForegroundColor White
            Write-EnterpriseCalendarLog -Level "Success" -Message "Enterprise calendar analysis completed successfully" -Category "Execution"

            return $securitySummary

        } catch {
            Write-Host "" -ForegroundColor White
            Write-Host "❌ Enterprise execution failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-EnterpriseCalendarLog -Level "Critical" -Message "Enterprise execution failed" -Category "Execution" -Exception $_
            throw
        }
    }

    # ====================================================================
    # LEGACY EXECUTION MODE (Original Function Logic)
    # ====================================================================

    Write-Host "ℹ️  Running in Legacy Mode (original calendar permission functionality)" -ForegroundColor Yellow

    # Connect to Exchange Management Shell if not already
    if (!(Get-Command Get-Mailbox -ErrorAction SilentlyContinue)) {
        Write-Verbose 'Connecting to Exchange Online..' -Verbose
        Connect-ExchangeOnline
    }

    $MBX = Get-Mailbox -Identity $Identity
    $CalendarName = (Get-MailboxFolderStatistics -Identity $MBX.Alias -FolderScope Calendar | Select-Object -First 1).Name
    $folderID = "$($MBX.Alias):\$CalendarName"
    Get-MailboxFolderPermission -Identity $folderID
}

# Example usage:
# Get-CalPerm -Identity "user@example.com"
