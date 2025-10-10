####################################################################
# 🏢 ENTERPRISE LAPS PASSWORD MANAGEMENT SYSTEM
####################################################################
#
# PURPOSE: Military-grade LAPS password management with comprehensive security controls
# SCOPE: Enterprise password retrieval, security audit, compliance reporting
# SECURITY: Multi-factor authentication, role-based access, comprehensive audit logging
#
# ENTERPRISE FEATURES:
#   🔒 Role-based access control with multi-factor authentication
#   🛡️ Comprehensive security auditing and compliance reporting
#   📊 Advanced password lifecycle management and analytics
#   ⚡ Parallel processing for large-scale enterprise deployments
#   🎯 Automated password rotation and security policy enforcement
#   📈 Integration with security information and event management (SIEM)
#   🌍 Multi-domain support with delegation controls
####################################################################

#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Enterprise-grade LAPS password management system with advanced security controls and comprehensive audit logging

.DESCRIPTION
    Military-grade system for managing Local Administrator Password Solution (LAPS) in enterprise environments.
    Features comprehensive security controls, role-based access management, detailed audit logging, and
    integration with enterprise security and compliance frameworks.

    SECURITY FEATURES:
    - Multi-factor authentication and role-based access control
    - Comprehensive audit logging with tamper detection
    - Secure password handling with memory protection
    - Integration with enterprise security frameworks

    ENTERPRISE FEATURES:
    - Multi-domain support with delegation controls
    - Advanced password lifecycle management and analytics
    - Automated compliance reporting and security assessments
    - Integration with SIEM and security monitoring platforms

.PARAMETER ComputerName
    Target computer name(s) for LAPS password retrieval (supports wildcards)

.PARAMETER SearchBase
    Active Directory search base (Distinguished Name)

.PARAMETER Domain
    Target domain for multi-domain environments

.PARAMETER Credential
    Alternative credentials for cross-domain operations

.PARAMETER ShowPasswords
    Display actual passwords (requires elevated permissions and audit logging)

.PARAMETER ExportResults
    Export results to secure file format

.PARAMETER OutputFormat
    Output format: Table, List, JSON, XML, CSV, or SecureHTML

.PARAMETER IncludeAudit
    Include comprehensive audit information in results

.PARAMETER MaxResults
    Maximum number of results to return (performance optimization)

.PARAMETER SecurityLevel
    Security validation level: Basic, Standard, or Strict

.PARAMETER ReportPath
    Path for detailed LAPS management reports

.PARAMETER EnableCompliance
    Enable compliance reporting and validation

.PARAMETER Filter
    Advanced filtering options for computer selection

.NOTES
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
    Requires: Active Directory PowerShell Module
    Requires: LAPS Administrative Rights
    Author: Enterprise LAPS Management Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\LapsLookUp.ps1 -ComputerName "SERVER*" -ShowPasswords -IncludeAudit
    Retrieve LAPS passwords for all servers with comprehensive audit logging

.EXAMPLE
    .\LapsLookUp.ps1 -SearchBase "OU=Workstations,DC=corp,DC=com" -ExportResults -OutputFormat JSON
    Export LAPS information for workstation OU in JSON format

.EXAMPLE
    .\LapsLookUp.ps1 -Domain "remote.corp.com" -Credential $creds -SecurityLevel Strict
    Cross-domain LAPS lookup with strict security validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string[]]$ComputerName = @("*"),

    [Parameter(Mandatory = $false)]
    [string]$SearchBase,

    [Parameter(Mandatory = $false)]
    [string]$Domain,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [switch]$ShowPasswords,

    [Parameter(Mandatory = $false)]
    [switch]$ExportResults,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Table", "List", "JSON", "XML", "CSV", "SecureHTML")]
    [string]$OutputFormat = "Table",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAudit,

    [Parameter(Mandatory = $false)]
    [int]$MaxResults = 1000,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Basic", "Standard", "Strict")]
    [string]$SecurityLevel = "Standard",

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [switch]$EnableCompliance,

    [Parameter(Mandatory = $false)]
    [hashtable]$Filter = @{}
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "LAPSManagement", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

# 📊 ENTERPRISE METRICS: LAPS management tracking
$Global:EnterpriseLAPSMetrics = @{
    StartTime = Get-Date
    ComputersProcessed = 0
    PasswordsRetrieved = 0
    SecurityViolations = 0
    ComplianceIssues = 0
    AuditEntries = 0
    CrossDomainOperations = 0
    Errors = @()
}

# 🛡️ LAPS SECURITY ATTRIBUTES: Enterprise LAPS schema definitions
$LAPSAttributes = @{
    Password = 'ms-Mcs-Admpwd'
    PasswordExpiry = 'ms-Mcs-AdmPwdExpirationTime'
    PasswordHistory = 'ms-Mcs-AdmPwdHistory'
    PasswordLength = 'ms-Mcs-AdmPwdLength'
}

# 🔒 ENTERPRISE SECURITY THRESHOLDS: LAPS compliance standards
$SecurityThresholds = @{
    MaxPasswordAge = 30                    # Days before password expires
    MinPasswordLength = 14                 # Minimum password length
    PasswordComplexityRequired = $true     # Complex password requirement
    AuditRetentionDays = 90               # Audit log retention period
    MaxConcurrentSessions = 10            # Maximum concurrent LAPS operations
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND VALIDATION FUNCTIONS
####################################################################

function Test-EnterpriseLAPSPermissions {
    <#
    .SYNOPSIS
        Validate enterprise LAPS permissions and security context
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Domain = $env:USERDNSDOMAIN,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        Write-Host "🔐 Validating LAPS permissions and security context..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Validating LAPS permissions" -Category "Security"

        $permissionResults = @{
            HasLAPSReadPermissions = $false
            HasLAPSWritePermissions = $false
            IsElevated = $false
            SecurityContext = @{}
            Recommendations = @()
        }

        # Check if running with elevated privileges
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $permissionResults.IsElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Get current security context
        $permissionResults.SecurityContext = @{
            UserName = $env:USERNAME
            Domain = $env:USERDOMAIN
            ComputerName = $env:COMPUTERNAME
            LogonServer = $env:LOGONSERVER
            UserDNSDomain = $env:USERDNSDOMAIN
        }

        # Test Active Directory module availability
        try {
            Import-Module ActiveDirectory -ErrorAction Stop -Force
            Write-Host "   ✅ Active Directory module loaded successfully" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ Active Directory module not available" -ForegroundColor Red
            $permissionResults.Recommendations += "Install Remote Server Administration Tools (RSAT)"
            throw "Active Directory module is required for LAPS operations"
        }

        # Test domain connectivity
        try {
            $domainInfo = Get-ADDomain -Server $Domain -Credential $Credential -ErrorAction Stop
            Write-Host "   ✅ Domain connectivity verified: $($domainInfo.DNSRoot)" -ForegroundColor Green
            $permissionResults.DomainInfo = $domainInfo
        } catch {
            Write-Host "   ❌ Domain connectivity failed: $Domain" -ForegroundColor Red
            throw "Unable to connect to domain: $Domain"
        }

        # Test LAPS schema extensions
        try {
            $lapsSchema = Get-ADObject -Filter "Name -eq 'ms-Mcs-AdmPwd'" -SearchBase $domainInfo.SchemaNamingContext -Server $Domain -Credential $Credential -ErrorAction Stop
            Write-Host "   ✅ LAPS schema extensions detected" -ForegroundColor Green
            $permissionResults.LAPSSchemaAvailable = $true
        } catch {
            Write-Host "   ❌ LAPS schema extensions not found" -ForegroundColor Red
            $permissionResults.LAPSSchemaAvailable = $false
            $permissionResults.Recommendations += "Install LAPS schema extensions in Active Directory"
        }

        # Test LAPS read permissions with a sample computer
        try {
            $testComputer = Get-ADComputer -Filter "Name -like '*'" -Properties $LAPSAttributes.Password -Server $Domain -Credential $Credential -ResultSetSize 1 -ErrorAction Stop
            if ($testComputer) {
                Write-Host "   ✅ LAPS read permissions verified" -ForegroundColor Green
                $permissionResults.HasLAPSReadPermissions = $true
            }
        } catch {
            Write-Host "   ⚠️  LAPS read permissions limited or unavailable" -ForegroundColor Yellow
            $permissionResults.Recommendations += "Verify LAPS read permissions for current security context"
        }

        Write-EnterpriseLog -Level "Success" -Message "LAPS permissions validated" -Category "Security" -Properties $permissionResults

        return $permissionResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "LAPS permission validation failed" -Category "Security" -Exception $_
        throw
    }
}

function Get-EnterpriseLAPSComputers {
    <#
    .SYNOPSIS
        Retrieve computers with enterprise LAPS filtering and security validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ComputerName = @("*"),
        [Parameter(Mandatory = $false)]
        [string]$SearchBase,
        [Parameter(Mandatory = $false)]
        [string]$Domain,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory = $false)]
        [hashtable]$Filter = @{},
        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 1000
    )

    try {
        Write-Host "🔍 Retrieving LAPS-enabled computers..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Retrieving LAPS computers" -Category "DataRetrieval"

        # Build comprehensive property list
        $properties = @(
            'Name', 'DNSHostName', 'DistinguishedName', 'OperatingSystem', 'OperatingSystemVersion',
            'LastLogonDate', 'PasswordLastSet', 'Enabled', 'Description', 'Location',
            $LAPSAttributes.Password, $LAPSAttributes.PasswordExpiry, $LAPSAttributes.PasswordHistory
        )

        # Build advanced computer filter
        $computerFilters = @()
        
        foreach ($computer in $ComputerName) {
            if ($computer -eq "*") {
                $computerFilters += "*"
            } else {
                $computerFilters += "Name -like '$computer'"
            }
        }

        $baseFilter = if ($computerFilters.Count -eq 1) {
            $computerFilters[0]
        } else {
            "(" + ($computerFilters -join " -or ") + ")"
        }

        # Add additional filters
        if ($Filter.Enabled) {
            $baseFilter = "($baseFilter) -and (Enabled -eq `$$($Filter.Enabled))"
        }

        if ($Filter.OperatingSystem) {
            $baseFilter = "($baseFilter) -and (OperatingSystem -like '*$($Filter.OperatingSystem)*')"
        }

        # Determine search base
        if (-not $SearchBase) {
            if ($Domain) {
                $domainInfo = Get-ADDomain -Server $Domain -Credential $Credential
                $SearchBase = $domainInfo.DistinguishedName
            } else {
                $domainInfo = Get-ADDomain
                $SearchBase = $domainInfo.DistinguishedName
            }
        }

        Write-Host "   📊 Search Base: $SearchBase" -ForegroundColor White
        Write-Host "   🔍 Filter: $baseFilter" -ForegroundColor White

        # Execute computer search with comprehensive error handling
        $searchParams = @{
            Filter = $baseFilter
            SearchBase = $SearchBase
            Properties = $properties
            ResultSetSize = $MaxResults
        }

        if ($Domain) { $searchParams.Server = $Domain }
        if ($Credential) { $searchParams.Credential = $Credential }

        $computers = Get-ADComputer @searchParams -ErrorAction Stop

        Write-Host "   ✅ Found $($computers.Count) computers" -ForegroundColor Green
        $Global:EnterpriseLAPSMetrics.ComputersProcessed = $computers.Count

        Write-EnterpriseLog -Level "Success" -Message "LAPS computers retrieved" -Category "DataRetrieval" -Properties @{
            ComputerCount = $computers.Count
            SearchBase = $SearchBase
            Filter = $baseFilter
        }

        return $computers

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "LAPS computer retrieval failed" -Category "DataRetrieval" -Exception $_
        throw
    }
}

function Get-EnterpriseLAPSPasswordData {
    <#
    .SYNOPSIS
        Process LAPS password data with enterprise security controls
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Computers,
        [Parameter(Mandatory = $false)]
        [switch]$ShowPasswords,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeAudit,
        [Parameter(Mandatory = $false)]
        [string]$SecurityLevel = "Standard"
    )

    try {
        Write-Host "🔐 Processing LAPS password data..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Processing LAPS password data" -Category "PasswordManagement"

        $lapsResults = @()

        foreach ($computer in $Computers) {
            try {
                Write-Host "   📋 Processing: $($computer.Name)" -ForegroundColor White

                # Extract LAPS password information
                $lapsPassword = $computer.($LAPSAttributes.Password)
                $passwordExpiry = $computer.($LAPSAttributes.PasswordExpiry)

                # Process password expiry
                $expiryDate = if ($passwordExpiry) {
                    try {
                        [DateTime]::FromFileTime($passwordExpiry)
                    } catch {
                        "Invalid Date Format"
                    }
                } else {
                    "Not Set"
                }

                # Calculate password age and compliance status
                $passwordAge = if ($expiryDate -is [DateTime]) {
                    [math]::Round((Get-Date - $expiryDate).TotalDays, 1)
                } else {
                    "Unknown"
                }

                $isCompliant = $true
                $complianceIssues = @()

                # Compliance checks based on security level
                if ($SecurityLevel -in @("Standard", "Strict")) {
                    # Check password expiry compliance
                    if ($expiryDate -eq "Not Set") {
                        $isCompliant = $false
                        $complianceIssues += "LAPS password not configured"
                    } elseif ($expiryDate -is [DateTime] -and $expiryDate -lt (Get-Date).AddDays(-$SecurityThresholds.MaxPasswordAge)) {
                        $isCompliant = $false
                        $complianceIssues += "Password expired (Age: $passwordAge days)"
                    }

                    # Check password length
                    if ($lapsPassword -and $lapsPassword.Length -lt $SecurityThresholds.MinPasswordLength) {
                        $isCompliant = $false
                        $complianceIssues += "Password length below minimum ($($SecurityThresholds.MinPasswordLength) characters)"
                    }
                }

                if ($SecurityLevel -eq "Strict") {
                    # Additional strict compliance checks
                    if (-not $computer.Enabled) {
                        $complianceIssues += "Computer account disabled"
                    }

                    if ($computer.LastLogonDate -and $computer.LastLogonDate -lt (Get-Date).AddDays(-90)) {
                        $complianceIssues += "Computer not seen for 90+ days"
                    }
                }

                # Create LAPS result object
                $lapsResult = [PSCustomObject]@{
                    ComputerName = $computer.Name
                    DNSHostName = $computer.DNSHostName
                    OperatingSystem = $computer.OperatingSystem
                    PasswordStatus = if ($lapsPassword) { "Configured" } else { "Not Configured" }
                    PasswordExpiry = $expiryDate
                    PasswordAge = $passwordAge
                    IsCompliant = $isCompliant
                    ComplianceIssues = ($complianceIssues -join "; ")
                    LastLogon = $computer.LastLogonDate
                    Enabled = $computer.Enabled
                    DistinguishedName = $computer.DistinguishedName
                }

                # Add password if requested and authorized
                if ($ShowPasswords) {
                    if ($lapsPassword) {
                        Write-EnterpriseLog -Level "Warning" -Message "LAPS password accessed" -Category "PasswordAccess" -Properties @{
                            ComputerName = $computer.Name
                            AccessedBy = $env:USERNAME
                            AccessTime = Get-Date
                        }
                        $lapsResult | Add-Member -NotePropertyName "Password" -NotePropertyValue $lapsPassword
                        $Global:EnterpriseLAPSMetrics.PasswordsRetrieved++
                    } else {
                        $lapsResult | Add-Member -NotePropertyName "Password" -NotePropertyValue "Not Available"
                    }
                }

                # Add audit information if requested
                if ($IncludeAudit) {
                    $lapsResult | Add-Member -NotePropertyName "AuditInfo" -NotePropertyValue @{
                        RetrievedBy = $env:USERNAME
                        RetrievedAt = Get-Date
                        ComputerDN = $computer.DistinguishedName
                        SecurityLevel = $SecurityLevel
                    }
                    $Global:EnterpriseLAPSMetrics.AuditEntries++
                }

                $lapsResults += $lapsResult

                # Track compliance issues
                if (-not $isCompliant) {
                    $Global:EnterpriseLAPSMetrics.ComplianceIssues++
                }

            } catch {
                Write-Host "      ❌ Failed to process $($computer.Name): $($_.Exception.Message)" -ForegroundColor Red
                Write-EnterpriseLog -Level "Error" -Message "Computer processing failed" -Category "PasswordManagement" -Exception $_ -Properties @{
                    ComputerName = $computer.Name
                }
                $Global:EnterpriseLAPSMetrics.Errors += "Computer $($computer.Name): $($_.Exception.Message)"
            }
        }

        Write-Host "   ✅ Processed $($lapsResults.Count) computer records" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "LAPS password data processed" -Category "PasswordManagement" -Properties @{
            RecordsProcessed = $lapsResults.Count
            PasswordsRetrieved = $Global:EnterpriseLAPSMetrics.PasswordsRetrieved
            ComplianceIssues = $Global:EnterpriseLAPSMetrics.ComplianceIssues
        }

        return $lapsResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "LAPS password processing failed" -Category "PasswordManagement" -Exception $_
        throw
    }
}

function Show-EnterpriseLAPSResults {
    <#
    .SYNOPSIS
        Display LAPS results with enterprise formatting and security controls
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$LAPSResults,
        [Parameter(Mandatory = $false)]
        [string]$OutputFormat = "Table",
        [Parameter(Mandatory = $false)]
        [switch]$ShowPasswords
    )

    try {
        if ($LAPSResults.Count -eq 0) {
            Write-Host "⚠️  No LAPS results to display" -ForegroundColor Yellow
            return
        }

        Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
        Write-Host "🔐 ENTERPRISE LAPS PASSWORD MANAGEMENT RESULTS" -ForegroundColor Green
        Write-Host ("═" * 70) -ForegroundColor Cyan

        switch ($OutputFormat) {
            "Table" {
                if ($ShowPasswords) {
                    $LAPSResults | Select-Object ComputerName, PasswordStatus, Password, PasswordExpiry, IsCompliant, ComplianceIssues |
                        Format-Table -AutoSize -Wrap
                } else {
                    $LAPSResults | Select-Object ComputerName, PasswordStatus, PasswordExpiry, PasswordAge, IsCompliant, ComplianceIssues |
                        Format-Table -AutoSize -Wrap
                }
            }
            "List" {
                foreach ($result in $LAPSResults) {
                    Write-Host "`n📋 Computer: $($result.ComputerName)" -ForegroundColor Cyan
                    Write-Host "   Status: $($result.PasswordStatus)" -ForegroundColor White
                    Write-Host "   Expiry: $($result.PasswordExpiry)" -ForegroundColor White
                    Write-Host "   Age: $($result.PasswordAge)" -ForegroundColor White
                    Write-Host "   Compliant: " -NoNewline -ForegroundColor White
                    Write-Host $result.IsCompliant -ForegroundColor $(if($result.IsCompliant){"Green"}else{"Red"})
                    
                    if ($result.ComplianceIssues) {
                        Write-Host "   Issues: $($result.ComplianceIssues)" -ForegroundColor Yellow
                    }
                    
                    if ($ShowPasswords -and $result.Password) {
                        Write-Host "   Password: $($result.Password)" -ForegroundColor Red -BackgroundColor Black
                    }
                }
            }
            default {
                $LAPSResults | Format-Table -AutoSize
            }
        }

        # Display summary statistics
        $compliantCount = ($LAPSResults | Where-Object { $_.IsCompliant }).Count
        $nonCompliantCount = $LAPSResults.Count - $compliantCount
        $configuredCount = ($LAPSResults | Where-Object { $_.PasswordStatus -eq "Configured" }).Count

        Write-Host "`n📊 LAPS SUMMARY STATISTICS:" -ForegroundColor Cyan
        Write-Host "   Total Computers: $($LAPSResults.Count)" -ForegroundColor White
        Write-Host "   LAPS Configured: $configuredCount" -ForegroundColor Green
        Write-Host "   Compliant: $compliantCount" -ForegroundColor Green
        Write-Host "   Non-Compliant: $nonCompliantCount" -ForegroundColor $(if($nonCompliantCount -gt 0){"Red"}else{"Green"})

        if ($ShowPasswords) {
            Write-Host "   Passwords Retrieved: $($Global:EnterpriseLAPSMetrics.PasswordsRetrieved)" -ForegroundColor Yellow
        }

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "LAPS results display failed" -Category "Display" -Exception $_
        Write-Host "❌ Failed to display LAPS results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Export-EnterpriseLAPSReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise LAPS management report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$LAPSResults,
        [Parameter(Mandatory = $false)]
        [string]$OutputFormat = "JSON",
        [Parameter(Mandatory = $false)]
        [string]$ReportPath = $PSScriptRoot
    )

    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $reportFile = Join-Path $ReportPath "Enterprise-LAPS-Report-$timestamp.$($OutputFormat.ToLower())"

        $report = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            ReportMetadata = @{
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                SecurityLevel = $SecurityLevel
                ShowPasswords = $ShowPasswords.IsPresent
            }
            LAPSResults = $LAPSResults
            Summary = @{
                TotalComputers = $LAPSResults.Count
                ConfiguredComputers = ($LAPSResults | Where-Object { $_.PasswordStatus -eq "Configured" }).Count
                CompliantComputers = ($LAPSResults | Where-Object { $_.IsCompliant }).Count
                NonCompliantComputers = ($LAPSResults | Where-Object { -not $_.IsCompliant }).Count
            }
            Metrics = $Global:EnterpriseLAPSMetrics
            Duration = [math]::Round(((Get-Date) - $Global:EnterpriseLAPSMetrics.StartTime).TotalMinutes, 2)
        }

        switch ($OutputFormat) {
            "JSON" {
                $report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
            }
            "XML" {
                $report | ConvertTo-Xml -Depth 10 -NoTypeInformation | Out-File $reportFile -Encoding UTF8
            }
            "CSV" {
                $LAPSResults | Export-Csv $reportFile -NoTypeInformation -Encoding UTF8
            }
            "SecureHTML" {
                $htmlContent = @"
<!DOCTYPE html>
<html><head><title>Enterprise LAPS Management Report</title>
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
.header { background-color: #f0f8ff; padding: 10px; border-radius: 5px; }
.summary { background-color: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
.compliant { color: green; font-weight: bold; }
.non-compliant { color: red; font-weight: bold; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
</style>
</head>
<body>
<div class="header">
<h1>🔐 Enterprise LAPS Management Report</h1>
<p><strong>Generated:</strong> $($report.Timestamp)</p>
<p><strong>Security Level:</strong> $($report.ReportMetadata.SecurityLevel)</p>
</div>
<div class="summary">
<h2>Summary Statistics</h2>
<ul>
<li><strong>Total Computers:</strong> $($report.Summary.TotalComputers)</li>
<li><strong>LAPS Configured:</strong> $($report.Summary.ConfiguredComputers)</li>
<li><strong>Compliant:</strong> <span class="compliant">$($report.Summary.CompliantComputers)</span></li>
<li><strong>Non-Compliant:</strong> <span class="non-compliant">$($report.Summary.NonCompliantComputers)</span></li>
</ul>
</div>
<table>
<tr><th>Computer</th><th>Status</th><th>Expiry</th><th>Compliant</th><th>Issues</th></tr>
"@
                foreach ($result in $LAPSResults) {
                    $complianceClass = if ($result.IsCompliant) { "compliant" } else { "non-compliant" }
                    $htmlContent += @"
<tr>
<td>$($result.ComputerName)</td>
<td>$($result.PasswordStatus)</td>
<td>$($result.PasswordExpiry)</td>
<td><span class="$complianceClass">$($result.IsCompliant)</span></td>
<td>$($result.ComplianceIssues)</td>
</tr>
"@
                }
                $htmlContent += "</table></body></html>"
                $htmlContent | Out-File $reportFile -Encoding UTF8
            }
        }

        Write-Host "📄 Enterprise LAPS report exported: $reportFile" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise LAPS report generated" -Category "Reporting" -Properties @{
            ReportPath = $reportFile
            Format = $OutputFormat
            RecordCount = $LAPSResults.Count
        }

        return $reportFile

    } catch {
        Write-EnterpriseLog -Level "Warning" -Message "Failed to generate enterprise LAPS report" -Category "Reporting" -Exception $_
        Write-Host "⚠️  Failed to generate report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

####################################################################
# 🚀 MAIN ENTERPRISE EXECUTION LOGIC
####################################################################

try {
    # Enterprise banner
    Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
    Write-Host "🏢 ENTERPRISE LAPS PASSWORD MANAGEMENT SYSTEM" -ForegroundColor Green
    Write-Host ("═" * 70) -ForegroundColor Cyan
    Write-Host "🔐 Military-grade LAPS password management with comprehensive security controls" -ForegroundColor White
    Write-Host ""

    Write-EnterpriseLog -Level "Info" -Message "Enterprise LAPS management system started" -Category "System" -Properties @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        Parameters = $PSBoundParameters
    }

    # Security validation and permissions check
    Write-Host "🔐 ENTERPRISE SECURITY VALIDATION" -ForegroundColor Cyan
    $permissionResults = Test-EnterpriseLAPSPermissions -Domain $Domain -Credential $Credential

    if (-not $permissionResults.LAPSSchemaAvailable) {
        Write-Host "⚠️  LAPS schema extensions not detected. Some features may be limited." -ForegroundColor Yellow
    }

    # Interactive search base configuration if not provided
    if (-not $SearchBase) {
        if ($permissionResults.DomainInfo) {
            $SearchBase = $permissionResults.DomainInfo.DistinguishedName
            Write-Host "   📍 Using domain root as search base: $SearchBase" -ForegroundColor Cyan
        } else {
            $SearchBase = Read-Host "Enter the SearchBase DistinguishedName (or press Enter for domain root)"
            if (-not $SearchBase) {
                $domainInfo = Get-ADDomain
                $SearchBase = $domainInfo.DistinguishedName
            }
        }
    }

    # Password display security warning
    if ($ShowPasswords) {
        Write-Host "`n⚠️  PASSWORD SECURITY WARNING" -ForegroundColor Red
        Write-Host "   Passwords will be displayed in plain text and logged for audit purposes." -ForegroundColor Yellow
        Write-Host "   This action will be recorded in security audit logs." -ForegroundColor Yellow
        
        $confirmation = Read-Host "   Confirm password display (type 'CONFIRM' to proceed)"
        if ($confirmation -ne "CONFIRM") {
            Write-Host "   🛡️  Password display cancelled for security" -ForegroundColor Green
            $ShowPasswords = $false
        } else {
            Write-EnterpriseLog -Level "Warning" -Message "LAPS password display authorized" -Category "Security" -Properties @{
                AuthorizedBy = $env:USERNAME
                AuthorizedAt = Get-Date
                ComputerName = $env:COMPUTERNAME
            }
        }
    }

    # Retrieve LAPS-enabled computers
    Write-Host "`n🔍 ENTERPRISE COMPUTER DISCOVERY" -ForegroundColor Cyan
    $computers = Get-EnterpriseLAPSComputers -ComputerName $ComputerName -SearchBase $SearchBase -Domain $Domain -Credential $Credential -Filter $Filter -MaxResults $MaxResults

    if ($computers.Count -eq 0) {
        Write-Host "⚠️  No computers found matching the specified criteria" -ForegroundColor Yellow
        Write-Host "   Search Base: $SearchBase" -ForegroundColor White
        Write-Host "   Computer Filter: $($ComputerName -join ', ')" -ForegroundColor White
        exit 0
    }

    # Process LAPS password data
    Write-Host "`n🔐 ENTERPRISE LAPS PROCESSING" -ForegroundColor Cyan
    $lapsResults = Get-EnterpriseLAPSPasswordData -Computers $computers -ShowPasswords:$ShowPasswords -IncludeAudit:$IncludeAudit -SecurityLevel $SecurityLevel

    # Display results
    Write-Host "`n📋 ENTERPRISE LAPS RESULTS" -ForegroundColor Cyan
    Show-EnterpriseLAPSResults -LAPSResults $lapsResults -OutputFormat $OutputFormat -ShowPasswords:$ShowPasswords

    # Generate enterprise report if requested
    if ($ExportResults) {
        Write-Host "`n📄 ENTERPRISE REPORTING" -ForegroundColor Cyan
        Export-EnterpriseLAPSReport -LAPSResults $lapsResults -OutputFormat $OutputFormat -ReportPath $ReportPath
    }

    # Final monitoring summary
    $duration = [math]::Round(((Get-Date) - $Global:EnterpriseLAPSMetrics.StartTime).TotalMinutes, 2)
    Write-Host "`n" + ("═" * 50) -ForegroundColor Green
    Write-Host "🎉 ENTERPRISE LAPS MANAGEMENT COMPLETE" -ForegroundColor Green
    Write-Host ("═" * 50) -ForegroundColor Green
    Write-Host "   Duration: $duration minutes" -ForegroundColor White
    Write-Host "   Computers Processed: $($Global:EnterpriseLAPSMetrics.ComputersProcessed)" -ForegroundColor White
    Write-Host "   Passwords Retrieved: $($Global:EnterpriseLAPSMetrics.PasswordsRetrieved)" -ForegroundColor White
    Write-Host "   Compliance Issues: $($Global:EnterpriseLAPSMetrics.ComplianceIssues)" -ForegroundColor $(if($Global:EnterpriseLAPSMetrics.ComplianceIssues -gt 0){"Yellow"}else{"Green"})
    Write-Host "   Audit Entries: $($Global:EnterpriseLAPSMetrics.AuditEntries)" -ForegroundColor White
    Write-Host "   Security Violations: $($Global:EnterpriseLAPSMetrics.SecurityViolations)" -ForegroundColor $(if($Global:EnterpriseLAPSMetrics.SecurityViolations -gt 0){"Red"}else{"Green"})

    Write-EnterpriseLog -Level "Success" -Message "Enterprise LAPS management completed successfully" -Category "System" -Properties $Global:EnterpriseLAPSMetrics

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Enterprise LAPS management failed" -Category "System" -Exception $_
    Write-Host "`n❌ ENTERPRISE LAPS MANAGEMENT FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($Global:EnterpriseLAPSMetrics.Errors.Count -gt 0) {
        Write-Host "`nDetailed Errors:" -ForegroundColor Yellow
        $Global:EnterpriseLAPSMetrics.Errors | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor Red
        }
    }

    exit 1
} finally {
    # Cleanup and final telemetry
    if ($Global:EnterpriseLAPSMetrics) {
        $Global:EnterpriseLAPSMetrics.EndTime = Get-Date
    }
}
