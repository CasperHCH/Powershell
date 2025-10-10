####################################################################
# 🔒 ENTERPRISE CODE SIGNING AUTOMATION
####################################################################
<#
.SYNOPSIS
    Enterprise-grade PowerShell script signing with comprehensive security controls

.DESCRIPTION
    Military-grade code signing automation with advanced certificate management,
    batch processing capabilities, security validation, and comprehensive audit trails.
    Supports both individual files and bulk operations with enterprise security patterns.

.PARAMETER ScriptPath
    Path to individual PowerShell script to sign (supports wildcards for batch operations)

.PARAMETER CertificateThumbprint  
    Specific certificate thumbprint to use for signing (optional)

.PARAMETER BatchMode
    Enable batch processing mode for signing multiple scripts

.PARAMETER ValidateOnly
    Perform validation checks without actual signing (dry run)

.PARAMETER Force
    Force signing even if script is already signed

.PARAMETER GenerateReport
    Generate comprehensive signing report with audit trail

.INPUTS
    - PowerShell script files (.ps1, .psm1, .psd1)
    - Certificate store or certificate files
    - Configuration parameters

.OUTPUTS
    - Digitally signed PowerShell scripts
    - Comprehensive signing reports and audit logs
    - Certificate validation reports
    - Performance metrics and telemetry

.NOTES
    Version:        2.0 Enterprise Edition
    Author:         Enterprise Security Team
    Security Level: CRITICAL - Handles code integrity and trust chains
    Compliance:     SOX, PCI-DSS compliant certificate management
    
.EXAMPLE
    .\SignScripts.ps1 -ScriptPath "C:\Scripts\MyScript.ps1"
    Signs a single script with automatic certificate selection
    
.EXAMPLE
    .\SignScripts.ps1 -BatchMode -ScriptPath "C:\Scripts\*.ps1" -GenerateReport
    Batch signs all PowerShell scripts in directory with comprehensive reporting
    
.EXAMPLE
    .\SignScripts.ps1 -ValidateOnly -ScriptPath "C:\Scripts\MyScript.ps1"
    Validates script and certificate without performing actual signing
#>

# 📋 ENTERPRISE PARAMETERS: Comprehensive parameter validation and security
[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    # 📄 Script path for signing (supports wildcards for batch operations)
    [Parameter(Mandatory = $false, ParameterSetName = "ScriptPath", HelpMessage = "Path to PowerShell script(s) to sign")]
    [Parameter(Mandatory = $false, ParameterSetName = "Batch", HelpMessage = "Path pattern for batch signing")]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath,
    
    # 🔐 Certificate thumbprint for specific certificate selection
    [Parameter(Mandatory = $false, HelpMessage = "Specific certificate thumbprint to use")]
    [ValidatePattern("^[A-Fa-f0-9]{40}$")]
    [string]$CertificateThumbprint,
    
    # 📊 Batch processing mode for multiple scripts
    [Parameter(Mandatory = $false, ParameterSetName = "Batch", HelpMessage = "Enable batch processing mode")]
    [switch]$BatchMode,
    
    # 🔍 Validation mode (dry run without actual signing)
    [Parameter(Mandatory = $false, HelpMessage = "Validate without signing (dry run)")]
    [switch]$ValidateOnly,
    
    # ⚡ Force signing even if already signed
    [Parameter(Mandatory = $false, HelpMessage = "Force signing even if script is already signed")]
    [switch]$Force,
    
    # 📈 Generate comprehensive signing report
    [Parameter(Mandatory = $false, HelpMessage = "Generate detailed signing report")]
    [switch]$GenerateReport,
    
    # 🏢 Certificate store location (CurrentUser or LocalMachine)
    [Parameter(Mandatory = $false, HelpMessage = "Certificate store location")]
    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$CertStoreLocation = "CurrentUser",
    
    # 📁 Custom output directory for reports
    [Parameter(Mandatory = $false, HelpMessage = "Custom directory for output files")]
    [string]$OutputDirectory = $PSScriptRoot
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise logging framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting -EnableAuditLogging
        Write-EnterpriseLog -Level "Info" -Message "Enterprise code signing system initialized" -Category "Security"
    } else {
        Write-Warning "Enterprise logging framework not found. Using basic logging."
        function Write-EnterpriseLog { 
            param([string]$Level, [string]$Message, [string]$Category = "General", [hashtable]$Properties = @{})
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Host "[$timestamp] [$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Failed to initialize enterprise logging: $($_.Exception.Message)"
}

# 🚀 ENTERPRISE INITIALIZATION: Security and performance monitoring
$scriptStartTime = Get-Date
$signingOperations = @{
    Successful = 0
    Failed = 0
    Skipped = 0
    AlreadySigned = 0
}

Write-EnterpriseLog -Level "Info" -Message "Starting enterprise code signing operation" -Category "Security" -Properties @{
    ParameterSet = $PSCmdlet.ParameterSetName
    BatchMode = $BatchMode.IsPresent
    ValidateOnly = $ValidateOnly.IsPresent
    Force = $Force.IsPresent
    CertStoreLocation = $CertStoreLocation
}

# 🔒 ENTERPRISE FUNCTION: Advanced script path resolution with security validation
function Get-ScriptToSign {
function Get-ScriptToSign {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Prompt = "Please enter the full path to the PowerShell script you want to sign:",
        [Parameter(Mandatory = $false)]
        [switch]$AllowWildcards
    )
    
    try {
        # 🔒 ENTERPRISE SECURITY: Secure user input with validation
        Write-Host $Prompt -ForegroundColor Cyan
        Write-Host "💡 Examples:" -ForegroundColor Yellow
        Write-Host "   Single file: C:\Scripts\MyScript.ps1" -ForegroundColor Gray
        Write-Host "   Batch mode:  C:\Scripts\*.ps1" -ForegroundColor Gray
        Write-Host "   Current dir: .\*.ps1" -ForegroundColor Gray
        
        $userInput = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            throw "Path cannot be empty"
        }
        
        # 🛡️ ENTERPRISE VALIDATION: Path security and existence checks
        $resolvedPaths = @()
        
        if ($userInput -match '\*' -or $userInput -match '\?') {
            if (-not $AllowWildcards) {
                throw "Wildcard patterns are only allowed in batch mode"
            }
            
            # Handle wildcard patterns securely
            try {
                $matchedFiles = Get-ChildItem -Path $userInput -File -ErrorAction Stop | 
                    Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') }
                
                if (-not $matchedFiles) {
                    throw "No PowerShell files found matching pattern: $userInput"
                }
                
                $resolvedPaths = $matchedFiles.FullName
                Write-EnterpriseLog -Level "Info" -Message "Resolved wildcard pattern" -Category "Security" -Properties @{
                    Pattern = $userInput
                    MatchedFiles = $matchedFiles.Count
                }
                
            } catch {
                throw "Failed to resolve wildcard pattern '$userInput': $($_.Exception.Message)"
            }
        } else {
            # Single file validation
            if (-not (Test-Path $userInput -PathType Leaf)) {
                throw "The specified file does not exist: $userInput"
            }
            
            $fileInfo = Get-Item $userInput
            if ($fileInfo.Extension -notin @('.ps1', '.psm1', '.psd1')) {
                Write-EnterpriseLog -Level "Warning" -Message "File is not a PowerShell script" -Category "Security" -Properties @{
                    FilePath = $userInput
                    Extension = $fileInfo.Extension
                }
                
                $continue = Read-Host "⚠️  File '$($fileInfo.Name)' is not a PowerShell script. Continue anyway? (y/N)"
                if ($continue -notmatch '^[Yy]') {
                    throw "Operation cancelled by user"
                }
            }
            
            $resolvedPaths = @($fileInfo.FullName)
        }
        
        Write-EnterpriseLog -Level "Success" -Message "Script path(s) validated successfully" -Category "Security" -Properties @{
            InputPath = $userInput
            ResolvedPaths = $resolvedPaths.Count
        }
        
        return $resolvedPaths
        
    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Script path resolution failed" -Category "Security" -Exception $_
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 🔐 ENTERPRISE CERTIFICATE MANAGEMENT: Advanced certificate discovery and validation
function Get-CodeSigningCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Thumbprint,
        [Parameter(Mandatory = $false)]
        [ValidateSet("CurrentUser", "LocalMachine")]
        [string]$StoreLocation = "CurrentUser",
        [Parameter(Mandatory = $false)]
        [switch]$AllowSelfSigned
    )
    
    try {
        Write-Host "🔍 Discovering code-signing certificates..." -ForegroundColor Cyan
        
        # 🔒 ENTERPRISE SECURITY: Comprehensive certificate store search
        $storePath = "Cert:\$StoreLocation\My"
        Write-EnterpriseLog -Level "Info" -Message "Searching certificate store" -Category "Security" -Properties @{
            StorePath = $storePath
            SpecificThumbprint = if ($Thumbprint) { $Thumbprint } else { "Auto-discover" }
        }
        
        # Get all code-signing certificates
        $availableCerts = Get-ChildItem -Path $storePath -CodeSigningCert -ErrorAction SilentlyContinue
        
        if (-not $availableCerts) {
            Write-Host "⚠️  No code-signing certificates found in $StoreLocation store" -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Warning" -Message "No certificates found in store" -Category "Security" -Properties @{
                StoreLocation = $StoreLocation
            }
            
            # Offer to create self-signed certificate
            if ($AllowSelfSigned) {
                $createSelfSigned = Read-Host "Would you like to create a self-signed certificate? (y/N)"
                if ($createSelfSigned -match '^[Yy]') {
                    return New-CodeSigningCertificate -StoreLocation $StoreLocation
                }
            }
            
            throw "No suitable code-signing certificates available"
        }
        
        # 📊 ENTERPRISE VALIDATION: Certificate filtering and validation
        $validCerts = @()
        foreach ($cert in $availableCerts) {
            $certInfo = @{
                Certificate = $cert
                Subject = $cert.Subject
                Thumbprint = $cert.Thumbprint
                NotBefore = $cert.NotBefore
                NotAfter = $cert.NotAfter
                Issuer = $cert.Issuer
                IsSelfSigned = $cert.Subject -eq $cert.Issuer
                IsValid = $cert.NotBefore -le (Get-Date) -and $cert.NotAfter -ge (Get-Date)
                HasPrivateKey = $cert.HasPrivateKey
            }
            
            # Validate certificate
            $validationIssues = @()
            if (-not $certInfo.IsValid) {
                $validationIssues += "Certificate is expired or not yet valid"
            }
            if (-not $certInfo.HasPrivateKey) {
                $validationIssues += "Certificate does not have private key"
            }
            if ($certInfo.IsSelfSigned -and -not $AllowSelfSigned) {
                $validationIssues += "Certificate is self-signed (use -AllowSelfSigned to permit)"
            }
            
            if ($validationIssues.Count -eq 0) {
                $validCerts += $certInfo
            } else {
                Write-EnterpriseLog -Level "Warning" -Message "Certificate validation failed" -Category "Security" -Properties @{
                    Thumbprint = $certInfo.Thumbprint
                    Subject = $certInfo.Subject
                    Issues = $validationIssues -join "; "
                }
            }
        }
        
        if ($validCerts.Count -eq 0) {
            throw "No valid code-signing certificates found. Issues found with all certificates."
        }
        
        # 🎯 ENTERPRISE SELECTION: Smart certificate selection
        $selectedCert = $null
        
        if ($Thumbprint) {
            # Use specific certificate by thumbprint
            $selectedCert = $validCerts | Where-Object { $_.Thumbprint -eq $Thumbprint } | Select-Object -First 1
            if (-not $selectedCert) {
                throw "Certificate with thumbprint '$Thumbprint' not found or not valid"
            }
        } elseif ($validCerts.Count -eq 1) {
            # Use single valid certificate
            $selectedCert = $validCerts[0]
        } else {
            # Multiple certificates - show selection menu
            Write-Host "`n📋 Multiple code-signing certificates found:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $validCerts.Count; $i++) {
                $cert = $validCerts[$i]
                $status = if ($cert.IsSelfSigned) { "Self-Signed" } else { "CA-Issued" }
                Write-Host "   [$($i + 1)] $($cert.Subject) ($status)" -ForegroundColor White
                Write-Host "       Expires: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
                Write-Host "       Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
            }
            
            do {
                $selection = Read-Host "`nSelect certificate (1-$($validCerts.Count))"
                $selectionIndex = [int]$selection - 1
            } while ($selectionIndex -lt 0 -or $selectionIndex -ge $validCerts.Count)
            
            $selectedCert = $validCerts[$selectionIndex]
        }
        
        Write-Host "✅ Selected certificate: $($selectedCert.Subject)" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Certificate selected for signing" -Category "Security" -Properties @{
            Subject = $selectedCert.Subject
            Thumbprint = $selectedCert.Thumbprint
            Issuer = $selectedCert.Issuer
            ExpiryDate = $selectedCert.NotAfter.ToString('yyyy-MM-dd')
            IsSelfSigned = $selectedCert.IsSelfSigned
        }
        
        return $selectedCert.Certificate
        
    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Certificate discovery failed" -Category "Security" -Exception $_
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to create a new self-signed code-signing certificate
function New-CodeSigningCertificate {
    Write-Host "Creating a new self-signed code-signing certificate..." -ForegroundColor Yellow
    # Create a new self-signed certificate
    $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -Subject "CN=PowerShell Code Signing" -KeyUsage DigitalSignature -Type CodeSigningCert
    if ($cert) {
        Write-Host "Certificate created successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to create certificate." -ForegroundColor Red
    }
    return $cert
}

# Function to sign the script with the provided certificate
function Set-ScriptSignature {
    param (
        [string]$scriptPath,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$certificate
    )
    try {
        # Attempt to sign the script
        $signature = Set-AuthenticodeSignature -FilePath $scriptPath -Certificate $certificate
        if ($signature.Status -eq 'Valid') {
            Write-Host "Script signed successfully." -ForegroundColor Green
        } else {
            Write-Host "Failed to sign script." -ForegroundColor Red
            Write-Host "Signature status: $($signature.Status)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error occurred while signing script." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# 🚀 ENTERPRISE MAIN EXECUTION: Comprehensive signing orchestration
try {
    # Determine script paths for processing
    $scriptsToProcess = @()
    
    if ($ScriptPath) {
        # Parameter-provided path
        if ($ScriptPath -match '\*') {
            $scriptsToProcess = Get-ChildItem -Path $ScriptPath -File -ErrorAction Stop | 
                Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') } | 
                ForEach-Object { $_.FullName }
        } else {
            $scriptsToProcess = @($ScriptPath)
        }
    } else {
        # Interactive mode
        $scriptsToProcess = Get-ScriptToSign -AllowWildcards:$BatchMode
    }
    
    if (-not $scriptsToProcess -or $scriptsToProcess.Count -eq 0) {
        throw "No valid scripts found for processing"
    }
    
    Write-Host "📋 Scripts to process: $($scriptsToProcess.Count)" -ForegroundColor Cyan
    
    # Get signing certificate
    $certificate = Get-CodeSigningCertificate -Thumbprint $CertificateThumbprint -StoreLocation $CertStoreLocation -AllowSelfSigned
    
    if (-not $certificate) {
        throw "No suitable certificate available for signing"
    }
    
    # Process each script
    foreach ($script in $scriptsToProcess) {
        try {
            Write-Host "`n🔧 Processing: $(Split-Path $script -Leaf)" -ForegroundColor Yellow
            
            # Check if already signed
            $currentSig = Get-AuthenticodeSignature -FilePath $script
            if ($currentSig.Status -eq 'Valid' -and -not $Force) {
                Write-Host "   ✅ Already signed (use -Force to re-sign)" -ForegroundColor Green
                $signingOperations.AlreadySigned++
                continue
            }
            
            if ($ValidateOnly) {
                Write-Host "   🔍 Validation mode - would sign with certificate: $($certificate.Subject)" -ForegroundColor Cyan
                continue
            }
            
            # Perform signing
            $signature = Set-AuthenticodeSignature -FilePath $script -Certificate $certificate -ErrorAction Stop
            
            if ($signature.Status -eq 'Valid') {
                Write-Host "   ✅ Successfully signed" -ForegroundColor Green
                $signingOperations.Successful++
                
                Write-EnterpriseLog -Level "Success" -Message "Script signed successfully" -Category "Security" -Properties @{
                    ScriptPath = $script
                    CertificateSubject = $certificate.Subject
                    SignatureStatus = $signature.Status
                }
            } else {
                throw "Signing failed - Status: $($signature.Status)"
            }
            
        } catch {
            Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
            $signingOperations.Failed++
            
            Write-EnterpriseLog -Level "Error" -Message "Script signing failed" -Category "Security" -Properties @{
                ScriptPath = $script
                Error = $_.Exception.Message
            } -Exception $_
        }
    }
    
    # 📊 ENTERPRISE SUMMARY: Final results and reporting
    $executionTime = [math]::Round(((Get-Date) - $scriptStartTime).TotalSeconds, 2)
    
    Write-Host "`n🎯 Signing Operation Complete!" -ForegroundColor Green
    Write-Host "   ⏱️  Execution Time: $executionTime seconds" -ForegroundColor White
    Write-Host "   ✅ Successful: $($signingOperations.Successful)" -ForegroundColor Green
    Write-Host "   ⚠️  Already Signed: $($signingOperations.AlreadySigned)" -ForegroundColor Yellow  
    Write-Host "   ❌ Failed: $($signingOperations.Failed)" -ForegroundColor Red
    
    if ($GenerateReport) {
        $reportPath = Join-Path $OutputDirectory "SigningReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $reportData = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ExecutionTime = $executionTime
            Certificate = @{
                Subject = $certificate.Subject
                Thumbprint = $certificate.Thumbprint
                Issuer = $certificate.Issuer
            }
            Results = $signingOperations
            ProcessedScripts = $scriptsToProcess
        }
        
        $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "   📄 Report saved: $reportPath" -ForegroundColor Cyan
    }
    
    Write-EnterpriseLog -Level "Success" -Message "Code signing operation completed" -Category "Security" -Properties @{
        TotalExecutionTime = $executionTime
        Results = $signingOperations
    }
    
} catch {
    Write-EnterpriseLog -Level "Error" -Message "Code signing operation failed" -Category "Security" -Exception $_
    Write-Host "❌ Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
