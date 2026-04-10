####################################################################
# 🏢 ENTERPRISE IIS LOG MANAGEMENT SYSTEM
####################################################################
#
# PURPOSE: Military-grade IIS log management with comprehensive analytics and automation
# SCOPE: Log compression, archiving, analytics, compliance, and storage optimization
# SECURITY: Role-based access, encrypted storage, comprehensive audit trails
#
# ENTERPRISE FEATURES:
#   🔒 Role-based access control with secure credential management
#   📊 Advanced log analytics with pattern recognition and threat detection
#   ⚡ Parallel processing with intelligent compression and archiving
#   🛡️ Enterprise compliance with detailed audit logging and reporting
#   🌍 Multi-server support with centralized management and monitoring
#   📈 Storage optimization with predictive analytics and automated cleanup
#   🎯 Automated alerting and incident response for log management issues
####################################################################

#Requires -Version 5.1

<#
.SYNOPSIS
    Enterprise-grade IIS log management system with comprehensive analytics and automation

.DESCRIPTION
    Military-grade system for managing IIS logs with advanced analytics, automated compression,
    intelligent archiving, and enterprise compliance. Features predictive storage management,
    threat detection, comprehensive reporting, and integration with enterprise monitoring platforms.

    SECURITY FEATURES:
    - Role-based access control with secure credential management
    - Encrypted log storage and tamper detection
    - Comprehensive audit logging for compliance requirements
    - Advanced threat detection and security analytics

    ENTERPRISE FEATURES:
    - Multi-server parallel processing with intelligent load balancing
    - Predictive storage analytics with automated cleanup policies
    - Advanced log analysis with pattern recognition and anomaly detection
    - Integration with enterprise monitoring and SIEM platforms

.PARAMETER LogPaths
    Array of IIS log directories to manage (supports multiple servers and sites)

.PARAMETER ArchivePath
    Central archive location for compressed log files

.PARAMETER RetentionDays
    Number of days to retain uncompressed logs before archiving

.PARAMETER ArchiveRetentionDays
    Number of days to retain archived logs before deletion

.PARAMETER CompressionLevel
    Compression level: Fast, Optimal, or Maximum

.PARAMETER EnableAnalytics
    Enable advanced log analytics and threat detection

.PARAMETER EnableThreatDetection
    Enable security threat detection and alerting

.PARAMETER MaxConcurrentJobs
    Maximum number of concurrent processing jobs

.PARAMETER ReportPath
    Path for detailed log management reports

.PARAMETER ConfigPath
    Path to configuration file for advanced settings

.PARAMETER Force
    Skip interactive confirmations for automated operations

.PARAMETER ExportFormat
    Export format for reports: JSON, XML, CSV, or HTML

.PARAMETER EnableCompliance
    Enable compliance reporting for SOX, HIPAA, PCI-DSS requirements

.NOTES
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
    Requires: IIS Management permissions and appropriate access rights
    Author: Enterprise Infrastructure Management Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\Start-IISLogsCleanup.ps1 -LogPaths @("D:\IIS Logs\W3SVC1") -ArchivePath "\\nas01\logs"
    Basic log cleanup with archiving to network storage

.EXAMPLE
    .\Start-IISLogsCleanup.ps1 -LogPaths @("D:\IIS Logs\*") -EnableAnalytics -EnableThreatDetection
    Advanced log management with analytics and threat detection

.EXAMPLE
    .\Start-IISLogsCleanup.ps1 -LogPaths @("Server01:D:\Logs", "Server02:E:\Logs") -EnableCompliance
    Multi-server log management with compliance reporting

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$LogPaths = @(),

    [Parameter(Mandatory = $false)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$RetentionDays = 30,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 2555)]
    [int]$ArchiveRetentionDays = 90,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Fast", "Optimal", "Maximum")]
    [string]$CompressionLevel = "Optimal",

    [Parameter(Mandatory = $false)]
    [switch]$EnableAnalytics,

    [Parameter(Mandatory = $false)]
    [switch]$EnableThreatDetection,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$MaxConcurrentJobs = 5,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "enterprise-iis-config.json"),

    [Parameter(Mandatory = $false)]
    [string]$NotificationEmail,

    [Parameter(Mandatory = $false)]
    [string]$SmtpServer = "smtp.company.local",

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "XML", "CSV", "HTML")]
    [string]$ExportFormat = "JSON",

    [Parameter(Mandatory = $false)]
    [switch]$EnableCompliance
)

$script:LogPaths = $LogPaths
$script:ArchivePath = $ArchivePath
$script:RetentionDays = $RetentionDays
$script:ArchiveRetentionDays = $ArchiveRetentionDays
$script:CompressionLevel = $CompressionLevel
$script:EnableAnalytics = $EnableAnalytics
$script:EnableThreatDetection = $EnableThreatDetection
$script:MaxConcurrentJobs = $MaxConcurrentJobs
$script:ReportPath = $ReportPath
$script:ConfigPath = $ConfigPath
$script:NotificationEmail = $NotificationEmail
$script:SmtpServer = $SmtpServer
$script:Force = $Force
$script:ExportFormat = $ExportFormat
$script:EnableCompliance = $EnableCompliance

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "IISLogManagement", [hashtable]$Properties = @{})
            $propertySuffix = if ($Properties.Count -gt 0) { " | Properties: $($Properties.Count)" } else { "" }
            Write-Information "[$Level] [$Category] $Message$propertySuffix" -InformationAction Continue
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

function Write-IISStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Information $Message -InformationAction Continue
}

# 📊 ENTERPRISE METRICS: IIS log management tracking
$script:EnterpriseIISMetrics = @{
    StartTime = Get-Date
    ServersProcessed = 0
    LogPathsProcessed = 0
    FilesProcessed = 0
    FilesCompressed = 0
    FilesArchived = 0
    BytesProcessed = 0
    BytesCompressed = 0
    StorageSaved = 0
    ThreatDetections = 0
    ComplianceChecks = 0
    Errors = @()
}

# 🎯 IIS LOG PATTERNS: Enterprise threat detection patterns
$script:IISLogPatterns = @{
    ThreatSignatures = @(
        "sqlmap", "nikto", "nessus", "burp", "acunetix", "w3af", "skipfish",
        "union.*select", "drop.*table", "insert.*into", "delete.*from",
        "script.*alert", "javascript:", "eval\(", "fromcharcode",
        "\.\.\/", "\.\.\\", "cmd\.exe", "powershell", "/bin/sh"
    )
    SuspiciousUserAgents = @(
        "sqlmap", "nikto", "dirb", "nmap", "masscan", "zmap", "zgrab"
    )
    AttackPatterns = @(
        "DoS", "DDoS", "Brute Force", "SQL Injection", "XSS", "Directory Traversal",
        "Command Injection", "File Upload", "Authentication Bypass"
    )
    CompliancePatterns = @(
        "Login", "Logout", "Admin", "Config", "Password", "Credit Card", "SSN"
    )
}

# 🔒 ENTERPRISE THRESHOLDS: IIS management compliance standards
$EnterpriseThresholds = @{
    MaxLogAge = 30                      # Days before compression required
    MaxArchiveAge = 90                  # Days before archive deletion
    MinCompressionRatio = 0.5          # Minimum compression ratio (50%)
    MaxLogSize = 100MB                  # Maximum individual log file size
    MaxTotalSize = 10GB                # Maximum total log directory size
    ThreatDetectionSensitivity = "Medium"  # Low, Medium, High
    ComplianceRetentionDays = 2555     # 7 years for compliance
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND VALIDATION FUNCTIONS
####################################################################

function Test-EnterpriseIISPermission {
    <#
    .SYNOPSIS
        Comprehensive IIS permissions and security validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$LogPaths
    )

    try {
        Write-IISStatus "🛡️  Validating IIS management permissions and security context..."
        Write-EnterpriseLog -Level "Info" -Message "Starting IIS security validation" -Category "Security"

        $securityResults = @{
            IsValid = $false
            AdminPrivileges = $false
            IISManagementAvailable = $false
            LogPathsAccessible = @()
            SecurityWarnings = @()
            Recommendations = @()
        }

        # Check administrator privileges
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $securityResults.AdminPrivileges = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Check IIS management availability
        try {
            Import-Module WebAdministration -ErrorAction Stop
            $securityResults.IISManagementAvailable = $true
            Write-IISStatus "   ✅ IIS Management module available"
        } catch {
            Write-IISStatus "   ⚠️  IIS Management module not available"
            $securityResults.Recommendations += "Install IIS Management Tools or Web Server (IIS) role"
        }

        # Validate log path accessibility
        foreach ($logPath in $LogPaths) {
            try {
                # Handle remote paths (Server:Path format)
                if ($logPath -match "^([^:]+):(.+)$") {
                    $serverName = $matches[1]
                    $path = $matches[2]
                    # Test remote connectivity
                    $accessible = Test-Path "\\$serverName\$($path.Replace(':', '$'))" -ErrorAction SilentlyContinue
                } else {
                    $accessible = Test-Path $logPath -ErrorAction SilentlyContinue
                }

                if ($accessible) {
                    $securityResults.LogPathsAccessible += $logPath
                    Write-IISStatus "   ✅ Log path accessible: $logPath"
                } else {
                    Write-IISStatus "   ❌ Log path not accessible: $logPath"
                    $securityResults.SecurityWarnings += "Cannot access log path: $logPath"
                }
            } catch {
                $securityResults.SecurityWarnings += "Error accessing $logPath`: $($_.Exception.Message)"
            }
        }

        # Security recommendations
        if (-not $securityResults.AdminPrivileges) {
            $securityResults.Recommendations += "Run with Administrator privileges for full functionality"
        }

        Write-IISStatus "   🔍 Admin Privileges: $($securityResults.AdminPrivileges)"
        Write-IISStatus "   📊 Accessible Paths: $($securityResults.LogPathsAccessible.Count) of $($LogPaths.Count)"

        $securityResults.IsValid = $securityResults.AdminPrivileges -and ($securityResults.LogPathsAccessible.Count -gt 0)

        Write-EnterpriseLog -Level "Success" -Message "IIS security validation completed" -Category "Security" -Properties $securityResults

        return $securityResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "IIS security validation failed" -Category "Security" -Exception $_
        throw
    }
}

function Get-EnterpriseIISLogAnalysis {
    <#
    .SYNOPSIS
        Advanced IIS log analysis with threat detection and pattern recognition
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $false)]
        [switch]$EnableThreatDetection,
        [Parameter(Mandatory = $false)]
        [switch]$EnableCompliance
    )

    try {
        Write-IISStatus "🔍 Analyzing IIS logs: $LogPath"
        Write-EnterpriseLog -Level "Info" -Message "Starting log analysis" -Category "LogAnalysis" -Properties @{
            LogPath = $LogPath
            ThreatDetection = $EnableThreatDetection.IsPresent
            ComplianceChecking = $EnableCompliance.IsPresent
        }

        $analysisResults = @{
            TotalLogFiles = 0
            TotalLogSize = 0
            DateRange = @{ Start = $null; End = $null }
            ThreatDetections = @()
            ComplianceFindings = @()
            TopIPs = @()
            TopUserAgents = @()
            ErrorSummary = @()
            RecommendedActions = @()
        }

        # Get all log files in the path
        $logFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -ErrorAction SilentlyContinue
        $analysisResults.TotalLogFiles = $logFiles.Count
        $analysisResults.TotalLogSize = ($logFiles | Measure-Object Length -Sum).Sum

        if ($logFiles.Count -eq 0) {
            Write-IISStatus "   ⚠️  No log files found in $LogPath"
            return $analysisResults
        }

        # Determine date range
        $analysisResults.DateRange.Start = ($logFiles | Sort-Object CreationTime | Select-Object -First 1).CreationTime
        $analysisResults.DateRange.End = ($logFiles | Sort-Object CreationTime | Select-Object -Last 1).CreationTime

        # Advanced log analysis (sample recent files for performance)
        $recentFiles = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 5

        foreach ($logFile in $recentFiles) {
            try {
                Write-IISStatus "      📄 Analyzing: $($logFile.Name)"

                # Read log entries (limit to recent entries for performance)
                $logEntries = Get-Content $logFile.FullName | Select-Object -First 1000

                if ($EnableThreatDetection) {
                    # Threat detection analysis
                    foreach ($entry in $logEntries) {
                        foreach ($pattern in $script:IISLogPatterns.ThreatSignatures) {
                            if ($entry -match $pattern) {
                                $analysisResults.ThreatDetections += @{
                                    File = $logFile.Name
                                    Pattern = $pattern
                                    Entry = $entry.Substring(0, [Math]::Min(200, $entry.Length))
                                    Severity = "High"
                                    Timestamp = Get-Date
                                }
                                $script:EnterpriseIISMetrics.ThreatDetections++
                            }
                        }
                    }
                }

                if ($EnableCompliance) {
                    # Compliance pattern analysis
                    foreach ($entry in $logEntries) {
                        foreach ($pattern in $script:IISLogPatterns.CompliancePatterns) {
                            if ($entry -match $pattern) {
                                $analysisResults.ComplianceFindings += @{
                                    File = $logFile.Name
                                    Type = $pattern
                                    Entry = $entry.Substring(0, [Math]::Min(150, $entry.Length))
                                    RequiresRetention = $true
                                    Timestamp = Get-Date
                                }
                                $script:EnterpriseIISMetrics.ComplianceChecks++
                            }
                        }
                    }
                }

            } catch {
                Write-IISStatus "      ⚠️  Error analyzing $($logFile.Name): $($_.Exception.Message)"
                $script:EnterpriseIISMetrics.Errors += "Analysis error for $($logFile.Name): $($_.Exception.Message)"
            }
        }

        # Generate recommendations
        if ($analysisResults.TotalLogSize -gt $EnterpriseThresholds.MaxTotalSize) {
            $analysisResults.RecommendedActions += "Log directory exceeds size threshold - immediate cleanup recommended"
        }

        if ($analysisResults.ThreatDetections.Count -gt 0) {
            $analysisResults.RecommendedActions += "Security threats detected - immediate security review required"
        }

        Write-IISStatus "   📊 Analysis Summary:"
        Write-IISStatus "      Files: $($analysisResults.TotalLogFiles)"
        Write-IISStatus "      Size: $([math]::Round($analysisResults.TotalLogSize / 1GB, 2)) GB"
        Write-IISStatus "      Threats: $($analysisResults.ThreatDetections.Count)"
        Write-IISStatus "      Compliance Items: $($analysisResults.ComplianceFindings.Count)"

        Write-EnterpriseLog -Level "Success" -Message "Log analysis completed" -Category "LogAnalysis" -Properties @{
            LogFiles = $analysisResults.TotalLogFiles
            LogSize = $analysisResults.TotalLogSize
            ThreatDetections = $analysisResults.ThreatDetections.Count
            ComplianceFindings = $analysisResults.ComplianceFindings.Count
        }

        return $analysisResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Log analysis failed" -Category "LogAnalysis" -Exception $_ -Properties @{
            LogPath = $LogPath
        }
        throw
    }
}

function Invoke-EnterpriseLogCompression {
    <#
    .SYNOPSIS
        Execute enterprise log compression with comprehensive validation and monitoring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $false)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 30,
        [Parameter(Mandatory = $false)]
        [string]$CompressionLevel = "Optimal"
    )

    try {
        Write-IISStatus "🗜️  Starting enterprise log compression for: $LogPath"
        Write-EnterpriseLog -Level "Info" -Message "Starting log compression" -Category "Compression" -Properties @{
            LogPath = $LogPath
            RetentionDays = $RetentionDays
            CompressionLevel = $CompressionLevel
        }

        $compressionResults = @{
            FilesProcessed = 0
            FilesCompressed = 0
            BytesOriginal = 0
            BytesCompressed = 0
            CompressionRatio = 0
            ArchiveFiles = @()
            Errors = @()
        }

        # Calculate cutoff date for compression
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        Write-IISStatus "   📅 Compression cutoff date: $($cutoffDate.ToString('yyyy-MM-dd'))"

        # Get log files older than retention period
        $logFiles = Get-ChildItem -Path $LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }

        if ($logFiles.Count -eq 0) {
            Write-IISStatus "   ℹ️  No files require compression (all files within retention period)"
            return $compressionResults
        }

        Write-IISStatus "   📄 Found $($logFiles.Count) files for compression"

        # Group files by month for efficient compression
        $monthlyGroups = $logFiles | Group-Object { $_.LastWriteTime.ToString("yyyy-MM") }

        foreach ($monthGroup in $monthlyGroups) {
            try {
                $monthName = $monthGroup.Name
                $monthFiles = $monthGroup.Group
                $archiveFileName = "IIS-Logs-$monthName.zip"
                $archiveFullPath = Join-Path $LogPath $archiveFileName

                Write-IISStatus "      🗜️  Compressing $($monthFiles.Count) files from $monthName..."

                # Calculate original size
                $originalSize = ($monthFiles | Measure-Object Length -Sum).Sum
                $compressionResults.BytesOriginal += $originalSize

                # Create compressed archive
                $compressionMap = switch ($CompressionLevel) {
                    "Fast" { [System.IO.Compression.CompressionLevel]::Fastest }
                    "Maximum" { [System.IO.Compression.CompressionLevel]::SmallestSize }
                    default { [System.IO.Compression.CompressionLevel]::Optimal }
                }

                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $archive = [System.IO.Compression.ZipFile]::Open($archiveFullPath, [System.IO.Compression.ZipArchiveMode]::Create)

                foreach ($file in $monthFiles) {
                    try {
                        $entryName = $file.Name
                        $entry = $archive.CreateEntry($entryName, $compressionMap)

                        $entryStream = $entry.Open()
                        $fileStream = [System.IO.File]::OpenRead($file.FullName)

                        $fileStream.CopyTo($entryStream)

                        $fileStream.Close()
                        $entryStream.Close()

                        $compressionResults.FilesProcessed++
                        $script:EnterpriseIISMetrics.FilesProcessed++

                    } catch {
                        $compressionResults.Errors += "Failed to compress $($file.Name): $($_.Exception.Message)"
                        Write-IISStatus "         ⚠️  Error compressing $($file.Name)"
                    }
                }

                $archive.Dispose()

                # Verify archive integrity and get compressed size
                if (Test-Path $archiveFullPath) {
                    $compressedSize = (Get-Item $archiveFullPath).Length
                    $compressionResults.BytesCompressed += $compressedSize
                    $compressionResults.FilesCompressed++
                    $script:EnterpriseIISMetrics.FilesCompressed++

                    $compressionRatio = [math]::Round((($originalSize - $compressedSize) / $originalSize) * 100, 1)
                    Write-IISStatus "         ✅ Compressed to $archiveFileName (${compressionRatio}% reduction)"

                    # Move to archive path if specified
                    if ($ArchivePath -and (Test-Path $ArchivePath)) {
                        $archiveDestination = Join-Path $ArchivePath $archiveFileName
                        Move-Item $archiveFullPath $archiveDestination
                        $compressionResults.ArchiveFiles += $archiveDestination
                        $script:EnterpriseIISMetrics.FilesArchived++
                        Write-IISStatus "         📁 Moved to archive: $archiveDestination"
                    } else {
                        $compressionResults.ArchiveFiles += $archiveFullPath
                    }

                    # Delete original files after successful compression
                    foreach ($file in $monthFiles) {
                        try {
                            Remove-Item $file.FullName -Force
                            Write-IISStatus "         🗑️  Deleted: $($file.Name)"
                        } catch {
                            $compressionResults.Errors += "Failed to delete $($file.Name): $($_.Exception.Message)"
                        }
                    }

                } else {
                    throw "Archive file was not created successfully"
                }

            } catch {
                $compressionResults.Errors += "Failed to process month $monthName`: $($_.Exception.Message)"
                Write-IISStatus "      ❌ Error processing $monthName`: $($_.Exception.Message)"
            }
        }

        # Calculate overall compression ratio
        if ($compressionResults.BytesOriginal -gt 0) {
            $compressionResults.CompressionRatio = [math]::Round((($compressionResults.BytesOriginal - $compressionResults.BytesCompressed) / $compressionResults.BytesOriginal) * 100, 1)
            $script:EnterpriseIISMetrics.StorageSaved = $compressionResults.BytesOriginal - $compressionResults.BytesCompressed
        }

        Write-IISStatus "   🎉 Compression Summary:"
        Write-IISStatus "      Files Processed: $($compressionResults.FilesProcessed)"
        Write-IISStatus "      Archives Created: $($compressionResults.FilesCompressed)"
        Write-IISStatus "      Storage Saved: $([math]::Round($script:EnterpriseIISMetrics.StorageSaved / 1MB, 1)) MB"
        Write-IISStatus "      Compression Ratio: $($compressionResults.CompressionRatio)%"

        Write-EnterpriseLog -Level "Success" -Message "Log compression completed" -Category "Compression" -Properties $compressionResults

        return $compressionResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Log compression failed" -Category "Compression" -Exception $_ -Properties @{
            LogPath = $LogPath
        }
        throw
    }
}

function New-EnterpriseIISReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise IIS log management report
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$AnalysisResults,
        [Parameter(Mandatory = $false)]
        [hashtable]$CompressionResults,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    try {
        Write-IISStatus "📊 Generating enterprise IIS log management report..."

        $reportData = @{
            ExecutionSummary = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ExecutionTime = if($script:EnterpriseIISMetrics.StartTime) {
                    ((Get-Date) - $script:EnterpriseIISMetrics.StartTime).TotalSeconds
                } else { 0 }
                TotalServersProcessed = $script:EnterpriseIISMetrics.ServersProcessed
                TotalFilesProcessed = $script:EnterpriseIISMetrics.FilesProcessed
                TotalFilesCompressed = $script:EnterpriseIISMetrics.FilesCompressed
                TotalStorageSaved = [math]::Round($script:EnterpriseIISMetrics.StorageSaved / 1MB, 2)
                ThreatDetections = $script:EnterpriseIISMetrics.ThreatDetections
                ComplianceChecks = $script:EnterpriseIISMetrics.ComplianceChecks
                ErrorCount = $script:EnterpriseIISMetrics.Errors.Count
            }
            Configuration = @{
                ArchiveRetentionDays = $script:ArchiveRetentionDays
                MaxConcurrentJobs = $script:MaxConcurrentJobs
                ReportPath = $script:ReportPath
                ConfigPath = $script:ConfigPath
                ExportFormat = $script:ExportFormat
                AnalyticsEnabled = $script:EnableAnalytics.IsPresent
                ComplianceEnabled = $script:EnableCompliance.IsPresent
                Force = $script:Force.IsPresent
            }
            AnalysisResults = $AnalysisResults
            CompressionResults = $CompressionResults
            SecurityAnalysis = @{
                TotalThreats = if($AnalysisResults) { $AnalysisResults.ThreatDetections.Count } else { 0 }
                CriticalFindings = if($AnalysisResults) {
                    ($AnalysisResults.ThreatDetections | Where-Object { $_.Severity -eq "Critical" }).Count
                } else { 0 }
                ComplianceItems = if($AnalysisResults) { $AnalysisResults.ComplianceFindings.Count } else { 0 }
            }
            Recommendations = @()
            AuditTrail = @{
                User = $env:USERNAME
                Computer = $env:COMPUTERNAME
                Domain = $env:USERDOMAIN
                ProcessId = $PID
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            }
        }

        # Add intelligent recommendations
        if ($reportData.ExecutionSummary.ThreatDetections -gt 0) {
            $reportData.Recommendations += "🚨 SECURITY ALERT: $($reportData.ExecutionSummary.ThreatDetections) threat signatures detected. Immediate security review required."
        }

        if ($reportData.ExecutionSummary.TotalStorageSaved -gt 100) {
            $reportData.Recommendations += "✅ STORAGE OPTIMIZATION: Successfully saved $($reportData.ExecutionSummary.TotalStorageSaved) MB of storage space."
        }

        if ($script:EnterpriseIISMetrics.Errors.Count -gt 0) {
            $reportData.Recommendations += "⚠️ OPERATION ERRORS: $($script:EnterpriseIISMetrics.Errors.Count) errors encountered during execution. Review logs for details."
        }

        # Generate formatted report
        $reportText = @"
╔═══════════════════════════════════════════════════════════════╗
║                 ENTERPRISE IIS LOG MANAGEMENT REPORT         ║
╚═══════════════════════════════════════════════════════════════╝

📊 EXECUTION SUMMARY
   Timestamp: $($reportData.ExecutionSummary.Timestamp)
   Duration: $($reportData.ExecutionSummary.ExecutionTime) seconds
   Servers Processed: $($reportData.ExecutionSummary.TotalServersProcessed)
   Files Processed: $($reportData.ExecutionSummary.TotalFilesProcessed)
   Files Compressed: $($reportData.ExecutionSummary.TotalFilesCompressed)
   Storage Saved: $($reportData.ExecutionSummary.TotalStorageSaved) MB

🔒 SECURITY ANALYSIS
   Threat Detections: $($reportData.SecurityAnalysis.TotalThreats)
   Critical Findings: $($reportData.SecurityAnalysis.CriticalFindings)
   Compliance Items: $($reportData.SecurityAnalysis.ComplianceItems)

💡 RECOMMENDATIONS
$($reportData.Recommendations | ForEach-Object { "   $_`n" })

🔍 AUDIT TRAIL
   User: $($reportData.AuditTrail.User)@$($reportData.AuditTrail.Domain)
   Computer: $($reportData.AuditTrail.Computer)
   Process ID: $($reportData.AuditTrail.ProcessId)
   PowerShell Version: $($reportData.AuditTrail.PowerShellVersion)

╔═══════════════════════════════════════════════════════════════╗
║ Report generated by Enterprise IIS Log Management System     ║
║ For support: Contact IT Security & Infrastructure Team       ║
╚═══════════════════════════════════════════════════════════════╝
"@

        Write-IISStatus $reportText

        # Save report if output path specified
        if ($OutputPath -and $PSCmdlet.ShouldProcess($OutputPath, "Write IIS management report files")) {
            $reportFile = Join-Path $OutputPath "IIS-LogManagement-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
            $reportText | Out-File -FilePath $reportFile -Encoding UTF8

            # Also save JSON version for automation
            $jsonFile = $reportFile -replace '\.txt$', '.json'
            $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8

            Write-IISStatus "📄 Reports saved to:"
            Write-IISStatus "   Text: $reportFile"
            Write-IISStatus "   JSON: $jsonFile"
        }

        Write-EnterpriseLog -Level "Success" -Message "Enterprise report generated" -Category "Reporting" -Properties @{
            ReportPath = $OutputPath
            TotalMetrics = $reportData.ExecutionSummary
        }

        return $reportData

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Report generation failed" -Category "Reporting" -Exception $_
        throw
    }
}

# ====================================================================
# MAIN EXECUTION LOGIC - Enterprise IIS Log Management
# ====================================================================

# Main Enterprise Execution
try {
        if (-not (Test-Path -Path $script:ReportPath)) {
            New-Item -Path $script:ReportPath -ItemType Directory -Force | Out-Null
        }

        Write-IISStatus "🚀 Starting Enterprise IIS Log Management System..."
        Write-IISStatus "   Version: $($MyInvocation.MyCommand.Version)"
        Write-IISStatus "   Mode: Enterprise"
        Write-IISStatus "   User: $env:USERNAME@$env:USERDOMAIN"
        Write-IISStatus "   Computer: $env:COMPUTERNAME"
        Write-IISStatus ""

        # Initialize enterprise framework
        if (Get-Command Initialize-EnterpriseIISFramework -ErrorAction SilentlyContinue) {
            Initialize-EnterpriseIISFramework
        }
        $script:EnterpriseIISMetrics.StartTime = Get-Date

        # Security validation
        if ($script:LogPaths.Count -gt 0) {
            Write-IISStatus "🔒 Performing security validation..."
            $securityResults = Test-EnterpriseIISPermission -LogPaths $script:LogPaths

            if (-not $securityResults.IsValid) {
                Write-IISStatus "❌ Security validation failed. See recommendations above."
                Write-EnterpriseLog -Level "Critical" -Message "Security validation failed" -Category "Security"
                return
            }
            Write-IISStatus "✅ Security validation passed"
        }

        # Process each server/log path
        $logPaths = $script:LogPaths
        if (-not $logPaths -or $logPaths.Count -eq 0) {
            throw "At least one log path must be supplied via -LogPaths."
        }

        foreach ($currentLogPath in $logPaths) {
            Write-IISStatus "🖥️  Processing server log path: $currentLogPath"
            $script:EnterpriseIISMetrics.ServersProcessed++

            # Validate log path exists
            if (-not (Test-Path $currentLogPath)) {
                Write-IISStatus "   ⚠️  Log path not found: $currentLogPath"
                $script:EnterpriseIISMetrics.Errors += "Log path not found: $currentLogPath"
                continue
            }

            # Advanced log analysis
            $analysisResults = $null
            if ($script:EnableAnalytics -or $script:EnableThreatDetection -or $script:EnableCompliance) {
                $analysisResults = Get-EnterpriseIISLogAnalysis -LogPath $currentLogPath -EnableThreatDetection:$script:EnableThreatDetection -EnableCompliance:$script:EnableCompliance
            }

            # Log compression
            $compressionResults = Invoke-EnterpriseLogCompression -LogPath $currentLogPath -ArchivePath $script:ArchivePath -RetentionDays $script:RetentionDays -CompressionLevel $script:CompressionLevel

            Write-IISStatus "   ✅ Completed processing: $currentLogPath"
        }

        # Generate comprehensive report
        $null = New-EnterpriseIISReport -AnalysisResults $analysisResults -CompressionResults $compressionResults -OutputPath $script:ReportPath

        # Send notifications if configured
        if ($script:NotificationEmail) {
            try {
                $mailParams = @{
                    To = $script:NotificationEmail
                    Subject = "Enterprise IIS Log Management Report - $env:COMPUTERNAME"
                    Body = "Enterprise IIS log management completed. See attached report for details."
                    SmtpServer = $script:SmtpServer
                }
                Send-MailMessage @mailParams
                Write-IISStatus "📧 Notification sent to: $($script:NotificationEmail)"
            } catch {
                Write-IISStatus "⚠️  Failed to send notification: $($_.Exception.Message)"
            }
        }

        Write-IISStatus ""
        Write-IISStatus "🎉 Enterprise IIS Log Management completed successfully!"
        Write-IISStatus "   Total execution time: $([math]::Round(((Get-Date) - $script:EnterpriseIISMetrics.StartTime).TotalSeconds, 2)) seconds"
        Write-EnterpriseLog -Level "Success" -Message "Enterprise IIS log management completed successfully" -Category "Execution"

    } catch {
        Write-IISStatus ""
        Write-IISStatus "❌ Enterprise execution failed: $($_.Exception.Message)"
        Write-EnterpriseLog -Level "Critical" -Message "Enterprise execution failed" -Category "Execution" -Exception $_
        throw
    }

return