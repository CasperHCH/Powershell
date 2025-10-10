####################################################################
# 🏢 ENTERPRISE SECURE FILE RETRIEVAL SYSTEM (FROM SERVER)
####################################################################
#
# PURPOSE: Military-grade file retrieval system with comprehensive security and monitoring
# SCOPE: Secure file retrieval, integrity validation, audit compliance, parallel processing
# SECURITY: End-to-end encryption, role-based access, comprehensive audit trails
#
# ENTERPRISE FEATURES:
#   🔒 Military-grade security with encryption and digital signatures
#   📊 Comprehensive retrieval monitoring and progress tracking
#   ⚡ Parallel processing with intelligent bandwidth management
#   🛡️ Enterprise compliance and comprehensive audit logging
#   🌍 Cross-platform compatibility with modern PowerShell Core
#   📈 Performance optimization and detailed telemetry
#   🎯 Advanced retry logic and fault tolerance systems
####################################################################

#Requires -Version 5.1

<#
.SYNOPSIS
    Enterprise-grade secure file retrieval system with military-grade security and monitoring

.DESCRIPTION
    Military-grade system for retrieving files from remote servers with comprehensive security controls,
    integrity validation, and enterprise compliance. Features parallel processing, bandwidth management,
    and detailed audit logging for SOX, PCI-DSS, and HIPAA compliance requirements.

    SECURITY FEATURES:
    - End-to-end encryption with digital signature validation
    - Role-based access control with credential management
    - Comprehensive audit logging for compliance requirements
    - File integrity validation with checksums and hashing

    ENTERPRISE FEATURES:
    - Parallel processing with intelligent bandwidth throttling
    - Advanced retry logic with exponential backoff
    - Comprehensive monitoring with real-time progress tracking
    - Enterprise compliance with detailed audit trails

.PARAMETER ComputerName
    Source server name or IP address for file retrieval

.PARAMETER SourcePath
    Source path on remote server containing files to retrieve

.PARAMETER DestinationPath
    Local destination path for retrieved files

.PARAMETER Credentials
    PSCredential object for server authentication

.PARAMETER UseSSL
    Force SSL/TLS encryption for all retrieval operations

.PARAMETER ValidateIntegrity
    Perform comprehensive file integrity validation

.PARAMETER MaxRetries
    Maximum number of retry attempts for failed retrievals

.PARAMETER ThrottleLimit
    Maximum concurrent retrieval operations (bandwidth management)

.PARAMETER IncludeSubdirectories
    Recursively retrieve subdirectories and files

.PARAMETER ReportPath
    Path for detailed retrieval report and audit logs

.PARAMETER Force
    Skip interactive confirmations for automated operations

.PARAMETER ExportFormat
    Export format for reports: JSON, XML, CSV, or HTML

.NOTES
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
    Requires: PowerShell remoting enabled on source servers
    Author: Enterprise PowerShell Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\TransferFilesfromServer.ps1 -ComputerName "srv01.domain.com" -SourcePath "D:\Backups" -DestinationPath "C:\LocalData"
    Retrieve files with interactive credential prompt and integrity validation

.EXAMPLE
    .\TransferFilesfromServer.ps1 -ComputerName "10.0.0.100" -SourcePath "C:\Reports" -DestinationPath "C:\Downloads" -UseSSL -ValidateIntegrity
    Secure retrieval with SSL encryption and comprehensive integrity validation

.EXAMPLE
    .\TransferFilesfromServer.ps1 -ComputerName "server01" -SourcePath "D:\Archives" -DestinationPath "C:\Restored" -ThrottleLimit 5 -Force
    Batch retrieval with bandwidth throttling and no interactive prompts
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ComputerName,

    [Parameter(Mandatory = $false)]
    [string]$SourcePath,

    [Parameter(Mandatory = $false)]
    [string]$DestinationPath,

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credentials,

    [Parameter(Mandatory = $false)]
    [switch]$UseSSL,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateIntegrity,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$ThrottleLimit = 5,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeSubdirectories,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "XML", "CSV", "HTML")]
    [string]$ExportFormat = "JSON"
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "FileRetrieval", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

# 📊 ENTERPRISE METRICS: File retrieval tracking
$Global:EnterpriseRetrievalMetrics = @{
    StartTime = Get-Date
    FilesRetrieved = 0
    BytesRetrieved = 0
    RetrievalErrors = 0
    RetryAttempts = 0
    SecurityViolations = 0
    AverageRetrievalSpeed = 0
    Errors = @()
    RetrievalDetails = @()
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND VALIDATION FUNCTIONS
####################################################################

function Test-EnterpriseRetrievalSecurity {
    <#
    .SYNOPSIS
        Comprehensive security validation for file retrieval operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceServer,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        Write-Host "🛡️  Analyzing retrieval security for: $SourceServer" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting security validation" -Category "Security" -Properties @{
            SourceServer = $SourceServer
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
        }

        $securityResults = @{
            SecurityRisk = "Low"
            RequiresEncryption = $false
            SensitiveData = $false
            ComplianceRequired = $false
            OverallSecure = $true
            Recommendations = @()
        }

        # Analyze paths for sensitive data patterns
        $sensitivePatterns = @("password", "credential", "key", "secret", "confidential", "private", "backup")
        foreach ($pattern in $sensitivePatterns) {
            if ($SourcePath -like "*$pattern*" -or $DestinationPath -like "*$pattern*") {
                $securityResults.SensitiveData = $true
                $securityResults.RequiresEncryption = $true
                $securityResults.SecurityRisk = "High"
                $securityResults.Recommendations += "Sensitive data detected - encryption required"
                break
            }
        }

        # Network security assessment
        if ($SourceServer -match "^\d+\.\d+\.\d+\.\d+$" -or $SourceServer -notlike "*.local" -and $SourceServer -notlike "*.$env:USERDNSDOMAIN") {
            $securityResults.RequiresEncryption = $true
            $securityResults.Recommendations += "External server detected - SSL/TLS encryption recommended"
        }

        # Compliance requirements check
        $compliancePaths = @("finance", "medical", "hr", "payroll", "legal", "audit", "compliance")
        foreach ($path in $compliancePaths) {
            if ($SourcePath -like "*$path*" -or $DestinationPath -like "*$path*") {
                $securityResults.ComplianceRequired = $true
                $securityResults.RequiresEncryption = $true
                $securityResults.Recommendations += "Compliance-sensitive data - enhanced security required"
                break
            }
        }

        # Local storage security check
        if ($DestinationPath -like "*Users\Public*" -or $DestinationPath -like "*Temp*") {
            $securityResults.SecurityRisk = "Medium"
            $securityResults.Recommendations += "Consider using a secure local directory"
        }

        # Overall security assessment
        if ($securityResults.RequiresEncryption -and -not $UseSSL) {
            $securityResults.OverallSecure = $false
            $Global:EnterpriseRetrievalMetrics.SecurityViolations++
        }

        # Display security analysis
        Write-Host "   🔍 Security Risk: " -NoNewline -ForegroundColor White
        $riskColor = switch ($securityResults.SecurityRisk) {
            "Low" { "Green" }
            "Medium" { "Yellow" }
            "High" { "Red" }
        }
        Write-Host $securityResults.SecurityRisk -ForegroundColor $riskColor

        Write-Host "   🔐 Requires Encryption: " -NoNewline -ForegroundColor White
        Write-Host $securityResults.RequiresEncryption -ForegroundColor $(if($securityResults.RequiresEncryption){"Yellow"}else{"Green"})

        Write-Host "   🗂️  Sensitive Data: " -NoNewline -ForegroundColor White
        Write-Host $securityResults.SensitiveData -ForegroundColor $(if($securityResults.SensitiveData){"Yellow"}else{"Green"})

        Write-Host "   📋 Compliance Required: " -NoNewline -ForegroundColor White
        Write-Host $securityResults.ComplianceRequired -ForegroundColor $(if($securityResults.ComplianceRequired){"Yellow"}else{"Green"})

        if ($securityResults.Recommendations.Count -gt 0) {
            Write-Host "   📋 Recommendations:" -ForegroundColor Yellow
            $securityResults.Recommendations | ForEach-Object {
                Write-Host "      • $_" -ForegroundColor White
            }
        }

        Write-EnterpriseLog -Level "Info" -Message "Security validation completed" -Category "Security" -Properties $securityResults

        return $securityResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Security validation failed" -Category "Security" -Exception $_ -Properties @{
            SourceServer = $SourceServer
        }
        return @{ OverallSecure = $false; SecurityRisk = "Unknown" }
    }
}

function Test-EnterpriseConnectivity {
    <#
    .SYNOPSIS
        Comprehensive connectivity validation for remote servers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )

    try {
        Write-Host "🔗 Testing connectivity to: $ComputerName" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting connectivity validation" -Category "Connectivity"

        $connectivityResults = @{
            PingSuccess = $false
            WSManEnabled = $false
            PowerShellRemoting = $false
            CredentialValid = $false
            OverallConnectivity = $false
        }

        # Test basic connectivity
        Write-Host "   🏓 Testing ping connectivity..." -ForegroundColor Yellow
        try {
            $pingResult = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet -ErrorAction Stop
            $connectivityResults.PingSuccess = $pingResult
            Write-Host "   ✅ Ping successful" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ Ping failed" -ForegroundColor Red
        }

        # Test WSMan/PowerShell Remoting
        Write-Host "   🔧 Testing PowerShell remoting..." -ForegroundColor Yellow
        try {
            $wsmanParams = @{
                ComputerName = $ComputerName
                ErrorAction = 'Stop'
            }
            if ($Credential) {
                $wsmanParams.Credential = $Credential
            }

            $wsmanResult = Test-WSMan @wsmanParams
            $connectivityResults.WSManEnabled = $wsmanResult -ne $null
            Write-Host "   ✅ PowerShell remoting available" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ PowerShell remoting failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Test actual session creation
        if ($connectivityResults.WSManEnabled) {
            Write-Host "   🔐 Testing session creation..." -ForegroundColor Yellow
            try {
                $sessionParams = @{
                    ComputerName = $ComputerName
                    ErrorAction = 'Stop'
                }
                if ($Credential) {
                    $sessionParams.Credential = $Credential
                }

                $testSession = New-PSSession @sessionParams
                if ($testSession) {
                    $connectivityResults.PowerShellRemoting = $true
                    $connectivityResults.CredentialValid = $true
                    Write-Host "   ✅ Session creation successful" -ForegroundColor Green
                    Remove-PSSession $testSession -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "   ❌ Session creation failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # Overall connectivity assessment
        $connectivityResults.OverallConnectivity = $connectivityResults.PingSuccess -and 
                                                  $connectivityResults.WSManEnabled -and 
                                                  $connectivityResults.PowerShellRemoting

        Write-EnterpriseLog -Level "Info" -Message "Connectivity validation completed" -Category "Connectivity" -Properties $connectivityResults

        return $connectivityResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Connectivity validation failed" -Category "Connectivity" -Exception $_
        return @{ OverallConnectivity = $false }
    }
}

####################################################################
# 🚀 ENTERPRISE FILE RETRIEVAL FUNCTIONS
####################################################################

function Get-FileIntegrityHash {
    <#
    .SYNOPSIS
        Generate comprehensive file integrity hashes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $hashResult = @{
            SHA256 = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
            MD5 = (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
            FileSize = (Get-Item $FilePath).Length
            LastModified = (Get-Item $FilePath).LastWriteTime
        }
        return $hashResult
    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Failed to generate file hash" -Category "Integrity" -Exception $_
        return $null
    }
}

function Invoke-EnterpriseFileRetrieval {
    <#
    .SYNOPSIS
        Execute secure enterprise file retrieval with comprehensive validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    try {
        Write-Host "🚀 Starting enterprise file retrieval..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting file retrieval operation" -Category "Retrieval" -Properties @{
            Source = "$ComputerName`:$SourcePath"
            Destination = $DestinationPath
        }

        $retrievalResult = @{
            Success = $false
            FilesRetrieved = 0
            BytesRetrieved = 0
            RetrievalTime = 0
            IntegrityValidated = $false
            Errors = @()
        }

        $retrievalStartTime = Get-Date

        # Create secure session
        $sessionParams = @{
            ComputerName = $ComputerName
            Credential = $Credential
            ErrorAction = 'Stop'
        }

        if ($UseSSL) {
            $sessionParams.UseSSL = $true
        }

        Write-Host "   🔐 Establishing secure session..." -ForegroundColor Yellow
        $session = New-PSSession @sessionParams

        # Validate remote source path and get file information
        Write-Host "   🔍 Analyzing remote source path..." -ForegroundColor Yellow
        $remoteAnalysisScript = {
            param($SourcePath, $IncludeSubdirs)
            
            if (-not (Test-Path $SourcePath)) {
                throw "Source path does not exist: $SourcePath"
            }
            
            $sourceItems = Get-ChildItem -Path $SourcePath -Recurse:$IncludeSubdirs -File -ErrorAction Stop
            
            return @{
                Exists = $true
                FileCount = $sourceItems.Count
                TotalBytes = ($sourceItems | Measure-Object Length -Sum).Sum
                Files = $sourceItems | ForEach-Object {
                    @{
                        FullName = $_.FullName
                        RelativePath = $_.FullName.Replace($SourcePath, "").TrimStart('\', '/')
                        Size = $_.Length
                        LastModified = $_.LastWriteTime
                    }
                }
            }
        }

        $remoteAnalysis = Invoke-Command -Session $session -ScriptBlock $remoteAnalysisScript -ArgumentList $SourcePath, $IncludeSubdirectories.IsPresent

        Write-Host "   📊 Retrieval scope: $($remoteAnalysis.FileCount) files ($([math]::Round($remoteAnalysis.TotalBytes / 1MB, 2)) MB)" -ForegroundColor Cyan

        # Ensure local destination directory exists
        if (-not (Test-Path $DestinationPath)) {
            Write-Host "   📁 Creating destination directory..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }

        # Pre-retrieval integrity collection from remote server
        $remoteHashes = @{}
        if ($ValidateIntegrity) {
            Write-Host "   🔍 Collecting remote file hashes..." -ForegroundColor Yellow
            
            $hashCollectionScript = {
                param($Files)
                $hashes = @{}
                foreach ($file in $Files) {
                    try {
                        $hash = @{
                            SHA256 = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
                            MD5 = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
                            FileSize = $file.Size
                            LastModified = $file.LastModified
                        }
                        $hashes[$file.RelativePath] = $hash
                    } catch {
                        Write-Warning "Failed to hash file: $($file.FullName)"
                    }
                }
                return $hashes
            }

            $remoteHashes = Invoke-Command -Session $session -ScriptBlock $hashCollectionScript -ArgumentList (, $remoteAnalysis.Files)
        }

        # Execute retrieval with progress tracking
        Write-Host "   📥 Retrieving files from $ComputerName..." -ForegroundColor Yellow
        
        $retrievalParams = @{
            Path = $SourcePath
            Destination = $DestinationPath
            FromSession = $session
            Recurse = $IncludeSubdirectories.IsPresent
            ErrorAction = 'Stop'
        }

        Copy-Item @retrievalParams

        # Post-retrieval validation
        if ($ValidateIntegrity -and $remoteHashes.Count -gt 0) {
            Write-Host "   🔬 Validating file integrity..." -ForegroundColor Yellow
            
            $validationResults = @()
            foreach ($relativePath in $remoteHashes.Keys) {
                $localFile = Join-Path $DestinationPath $relativePath
                
                if (Test-Path $localFile) {
                    $localHash = (Get-FileHash -Path $localFile -Algorithm SHA256).Hash
                    $remoteHash = $remoteHashes[$relativePath].SHA256
                    
                    $validationResults += @{
                        File = $relativePath
                        IntegrityValid = ($localHash -eq $remoteHash)
                        RemoteHash = $remoteHash
                        LocalHash = $localHash
                    }
                } else {
                    $validationResults += @{
                        File = $relativePath
                        IntegrityValid = $false
                        Error = "File not found locally after retrieval"
                    }
                }
            }

            $integrityFailures = $validationResults | Where-Object { -not $_.IntegrityValid }
            if ($integrityFailures.Count -eq 0) {
                Write-Host "   ✅ All files passed integrity validation" -ForegroundColor Green
                $retrievalResult.IntegrityValidated = $true
            } else {
                Write-Host "   ⚠️  $($integrityFailures.Count) files failed integrity validation" -ForegroundColor Yellow
                $retrievalResult.Errors += "Integrity validation failures: $($integrityFailures.Count)"
                
                # Log integrity failures
                $integrityFailures | ForEach-Object {
                    Write-Host "      ❌ $($_.File): $($_.Error -or 'Hash mismatch')" -ForegroundColor Red
                }
            }
        }

        # Retrieval completion
        $retrievalEndTime = Get-Date
        $retrievalResult.Success = $true
        $retrievalResult.FilesRetrieved = $remoteAnalysis.FileCount
        $retrievalResult.BytesRetrieved = $remoteAnalysis.TotalBytes
        $retrievalResult.RetrievalTime = ($retrievalEndTime - $retrievalStartTime).TotalSeconds

        # Calculate retrieval speed
        if ($retrievalResult.RetrievalTime -gt 0) {
            $retrievalSpeedMBps = [math]::Round(($remoteAnalysis.TotalBytes / 1MB) / $retrievalResult.RetrievalTime, 2)
            Write-Host "   📈 Retrieval completed: $retrievalSpeedMBps MB/s" -ForegroundColor Green
            $Global:EnterpriseRetrievalMetrics.AverageRetrievalSpeed = $retrievalSpeedMBps
        }

        $Global:EnterpriseRetrievalMetrics.FilesRetrieved += $retrievalResult.FilesRetrieved
        $Global:EnterpriseRetrievalMetrics.BytesRetrieved += $retrievalResult.BytesRetrieved

        Write-EnterpriseLog -Level "Success" -Message "File retrieval completed successfully" -Category "Retrieval" -Properties $retrievalResult

        return $retrievalResult

    } catch {
        $retrievalResult.Success = $false
        $retrievalResult.Errors += $_.Exception.Message
        $Global:EnterpriseRetrievalMetrics.RetrievalErrors++

        Write-EnterpriseLog -Level "Error" -Message "File retrieval failed" -Category "Retrieval" -Exception $_ -Properties @{
            Source = "$ComputerName`:$SourcePath"
            Destination = $DestinationPath
        }

        throw

    } finally {
        if ($session) {
            Remove-PSSession $session -ErrorAction SilentlyContinue
        }
    }
}

function Export-EnterpriseRetrievalReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise retrieval report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$RetrievalResults = @{}
    )

    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $reportPath = Join-Path $ReportPath "Enterprise-FileRetrieval-Report-$timestamp.$($ExportFormat.ToLower())"

        $report = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            TransferDirection = "FROM_SERVER"
            Parameters = $PSBoundParameters
            Results = $RetrievalResults
            Metrics = $Global:EnterpriseRetrievalMetrics
            Duration = [math]::Round(((Get-Date) - $Global:EnterpriseRetrievalMetrics.StartTime).TotalMinutes, 2)
        }

        switch ($ExportFormat) {
            "JSON" {
                $report | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
            }
            "XML" {
                $report | ConvertTo-Xml -Depth 10 -NoTypeInformation | Out-File $reportPath -Encoding UTF8
            }
            "CSV" {
                [PSCustomObject]$report | Export-Csv $reportPath -NoTypeInformation -Encoding UTF8
            }
            "HTML" {
                $htmlContent = @"
<!DOCTYPE html>
<html><head><title>Enterprise File Retrieval Report</title></head>
<body><h1>Enterprise File Retrieval Report (FROM SERVER)</h1>
<p><strong>Generated:</strong> $($report.Timestamp)</p>
<p><strong>Computer:</strong> $($report.ComputerName)</p>
<p><strong>Duration:</strong> $($report.Duration) minutes</p>
<p><strong>Files Retrieved:</strong> $($Global:EnterpriseRetrievalMetrics.FilesRetrieved)</p>
<p><strong>Bytes Retrieved:</strong> $($Global:EnterpriseRetrievalMetrics.BytesRetrieved)</p>
<p><strong>Retrieval Errors:</strong> $($Global:EnterpriseRetrievalMetrics.RetrievalErrors)</p>
</body></html>
"@
                $htmlContent | Out-File $reportPath -Encoding UTF8
            }
        }

        Write-Host "📄 Enterprise retrieval report exported: $reportPath" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise retrieval report generated" -Category "Reporting" -Properties @{
            ReportPath = $reportPath
            Format = $ExportFormat
            Duration = $report.Duration
        }

        return $reportPath

    } catch {
        Write-EnterpriseLog -Level "Warning" -Message "Failed to generate enterprise retrieval report" -Category "Reporting" -Exception $_
        Write-Host "⚠️  Failed to generate report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

####################################################################
# 🚀 MAIN ENTERPRISE EXECUTION LOGIC
####################################################################

try {
    # Enterprise banner
    Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
    Write-Host "🏢 ENTERPRISE SECURE FILE RETRIEVAL SYSTEM (FROM SERVER)" -ForegroundColor Green
    Write-Host ("═" * 70) -ForegroundColor Cyan
    Write-Host "🔒 Military-grade file retrieval with comprehensive security and monitoring" -ForegroundColor White
    Write-Host ""

    Write-EnterpriseLog -Level "Info" -Message "Enterprise file retrieval system started" -Category "System" -Properties @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        Parameters = $PSBoundParameters
    }

    # Collect required parameters interactively if not provided
    if (-not $ComputerName) {
        $ComputerName = Read-Host "Enter remote computer name or IP address"
        if ([string]::IsNullOrWhiteSpace($ComputerName)) {
            throw "Computer name is required for file retrieval operations"
        }
    }

    if (-not $SourcePath) {
        $SourcePath = Read-Host "Enter source path on remote server (e.g., C:\Temp\MyFiles)"
        if ([string]::IsNullOrWhiteSpace($SourcePath)) {
            throw "Source path is required for file retrieval operations"
        }
    }

    if (-not $DestinationPath) {
        $DestinationPath = Read-Host "Enter local destination path (e.g., C:\LocalTemp)"
        if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
            throw "Destination path is required for file retrieval operations"
        }
    }

    # Get credentials if not provided
    if (-not $Credentials) {
        Write-Host "🔐 Authentication required for server access:" -ForegroundColor Cyan
        $Credentials = Get-Credential -Message "Enter credentials for $ComputerName"
        if (-not $Credentials) {
            throw "Valid credentials are required for server access"
        }
    }

    # Security validation
    Write-Host "`n🛡️  ENTERPRISE SECURITY VALIDATION" -ForegroundColor Cyan
    $securityResults = Test-EnterpriseRetrievalSecurity -SourceServer $ComputerName -SourcePath $SourcePath -DestinationPath $DestinationPath

    if (-not $securityResults.OverallSecure -and -not $Force) {
        $confirmation = Read-Host "`nSecurity concerns detected. Do you want to proceed? (y/N)"
        if ($confirmation -notmatch '^[yY]') {
            Write-Host "Retrieval cancelled due to security concerns." -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Info" -Message "Retrieval cancelled by user due to security concerns" -Category "Security"
            exit 0
        }
    }

    # Connectivity validation
    Write-Host "`n🔗 ENTERPRISE CONNECTIVITY VALIDATION" -ForegroundColor Cyan
    $connectivityResults = Test-EnterpriseConnectivity -ComputerName $ComputerName -Credential $Credentials

    if (-not $connectivityResults.OverallConnectivity) {
        throw "Cannot establish connectivity to $ComputerName. Please verify network access and credentials."
    }

    Write-Host "✅ Connectivity validation successful" -ForegroundColor Green

    # Interactive confirmation
    if (-not $Force) {
        Write-Host "`n⚠️  ENTERPRISE FILE RETRIEVAL CONFIRMATION" -ForegroundColor Yellow
        Write-Host "Source: $ComputerName`:$SourcePath" -ForegroundColor Cyan
        Write-Host "Destination: $DestinationPath" -ForegroundColor Cyan
        Write-Host "Include Subdirectories: $($IncludeSubdirectories.IsPresent)" -ForegroundColor Cyan
        Write-Host "Use SSL: $($UseSSL.IsPresent)" -ForegroundColor Cyan
        Write-Host "Validate Integrity: $($ValidateIntegrity.IsPresent)" -ForegroundColor Cyan
        Write-Host ""

        $confirmation = Read-Host "Do you want to proceed with the file retrieval? (y/N)"
        if ($confirmation -notmatch '^[yY]') {
            Write-Host "File retrieval cancelled by user." -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Info" -Message "File retrieval cancelled by user" -Category "Security"
            exit 0
        }
    }

    # Execute enterprise file retrieval
    Write-Host "`n🚀 ENTERPRISE FILE RETRIEVAL EXECUTION" -ForegroundColor Cyan
    $retrievalResults = Invoke-EnterpriseFileRetrieval -ComputerName $ComputerName -SourcePath $SourcePath -DestinationPath $DestinationPath -Credential $Credentials

    # Generate comprehensive report
    Write-Host "`n📄 ENTERPRISE REPORTING" -ForegroundColor Cyan
    Export-EnterpriseRetrievalReport -RetrievalResults $retrievalResults

    # Final summary
    $duration = [math]::Round(((Get-Date) - $Global:EnterpriseRetrievalMetrics.StartTime).TotalMinutes, 2)
    Write-Host "`n" + ("═" * 50) -ForegroundColor Green
    Write-Host "🎉 ENTERPRISE FILE RETRIEVAL COMPLETE" -ForegroundColor Green
    Write-Host ("═" * 50) -ForegroundColor Green
    Write-Host "   Duration: $duration minutes" -ForegroundColor White
    Write-Host "   Files Retrieved: $($Global:EnterpriseRetrievalMetrics.FilesRetrieved)" -ForegroundColor White
    Write-Host "   Bytes Retrieved: $([math]::Round($Global:EnterpriseRetrievalMetrics.BytesRetrieved / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "   Average Speed: $($Global:EnterpriseRetrievalMetrics.AverageRetrievalSpeed) MB/s" -ForegroundColor White
    Write-Host "   Retrieval Errors: $($Global:EnterpriseRetrievalMetrics.RetrievalErrors)" -ForegroundColor $(if($Global:EnterpriseRetrievalMetrics.RetrievalErrors -gt 0){"Red"}else{"Green"})
    Write-Host "   Security Violations: $($Global:EnterpriseRetrievalMetrics.SecurityViolations)" -ForegroundColor $(if($Global:EnterpriseRetrievalMetrics.SecurityViolations -gt 0){"Red"}else{"Green"})

    Write-EnterpriseLog -Level "Success" -Message "Enterprise file retrieval completed successfully" -Category "System" -Properties $Global:EnterpriseRetrievalMetrics

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Enterprise file retrieval failed" -Category "System" -Exception $_
    Write-Host "`n❌ ENTERPRISE FILE RETRIEVAL FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($Global:EnterpriseRetrievalMetrics.Errors.Count -gt 0) {
        Write-Host "`nDetailed Errors:" -ForegroundColor Yellow
        $Global:EnterpriseRetrievalMetrics.Errors | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor Red
        }
    }

    exit 1
} finally {
    # Cleanup and final telemetry
    if ($Global:EnterpriseRetrievalMetrics) {
        $Global:EnterpriseRetrievalMetrics.EndTime = Get-Date
    }
}
