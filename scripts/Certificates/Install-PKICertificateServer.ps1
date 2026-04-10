<#
.SYNOPSIS
    Configures a Windows Server as a Certificate Authority with self-signed certificate and CSR generation.

.DESCRIPTION
    This script installs and configures Active Directory Certificate Services (AD CS) on a clean Windows Server.
    Since the server has no internet access and no root/intermediate CA access, it:
    1. Installs AD CS role
    2. Prepares the server for offline CA certificate issuance
    3. Generates a Certificate Signing Request (CSR) for CA approval
    4. Saves the CSR alongside this script for transfer to an external CA
    5. Relies on Install-PKICertificateResponse.ps1 to package the signed response on the CA and install it back on this server

.PARAMETER CertCommonName
    The Common Name (CN) for the certificate (e.g., "Company-Root-CA").
    
.PARAMETER OrganizationName
    Organization name for the certificate.
    
.PARAMETER OrganizationUnit
    Organizational unit for the certificate.
    
.PARAMETER LocalityName
    City/Locality for the certificate.
    
.PARAMETER StateName
    State/Province for the certificate.
    
.PARAMETER CountryCode
    Two-letter country code (e.g., "US").
    
.PARAMETER CAServerName
    NetBIOS name for this Certificate Authority server.

.PARAMETER KeyLength
    RSA key length (2048, 4096). Default: 4096.
    
.PARAMETER ValidityYears
    Certificate validity period in years. Default: 10.

.EXAMPLE
    .\Install-PKICertificateServer.ps1 -CertCommonName "Company-Root-CA" -OrganizationName "Contoso" `
        -OrganizationUnit "IT Security" -LocalityName "Seattle" -StateName "Washington" `
        -CountryCode "US" -CAServerName "PKI-CA-01"

.EXAMPLE
    .\Install-PKICertificateServer.ps1 -CertCommonName "Company-Root-CA" -OrganizationName "Contoso" `
        -OrganizationUnit "IT Security" -LocalityName "Seattle" -StateName "Washington" `
        -CountryCode "US" -CAServerName "PKI-CA-01"

    After the CSR is generated:
    1. Transfer the .req file to the CA server.
    2. On the CA server, run .\Install-PKICertificateResponse.ps1 -RequestFilePath <csr-path> -CertificateAuthorityConfig <server\ca-name>.
    3. Transfer the generated response package back to this server.
    4. On this server, run .\Install-PKICertificateResponse.ps1 -ResponseInputPath <response-package-path>.

.NOTES
    Author: PowerShell Team
    Version: 1.0
    Security: This script performs sensitive PKI operations and must be code-signed.
    
    Prerequisites:
    - Windows Server 2016 or later
    - Administrator with local machine access
    - No internet connection required
    
    Post-Installation:
    - Review the generated CSR file (saved in script directory)
    - Transfer CSR to external CA for signing
    - Use the companion script (Install-PKICertificateResponse.ps1) on the CA with -RequestFilePath to prepare a response package
    - Transfer the response package back to this server
    - Run Install-PKICertificateResponse.ps1 on this server with -ResponseInputPath to install the issued certificate

.INPUTS
    None. All parameters must be provided.

.OUTPUTS
    Log files: ScriptAudit.log, ScriptExecution.log
    CSR file: [CertCommonName]-CSR-[timestamp].req
    Certificate archive: [CertCommonName]-Cert-Archive-[timestamp].zip

#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="Common Name for the certificate (e.g., Company-Root-CA)")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(3, 64)]
    [string]$CertCommonName,

    [Parameter(Mandatory=$true, HelpMessage="Organization name for certificate")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(2, 64)]
    [string]$OrganizationName,

    [Parameter(Mandatory=$true, HelpMessage="Organizational unit (department/team name)")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(2, 64)]
    [string]$OrganizationUnit,

    [Parameter(Mandatory=$true, HelpMessage="City/Locality name")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(2, 128)]
    [string]$LocalityName,

    [Parameter(Mandatory=$true, HelpMessage="State/Province name")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(2, 128)]
    [string]$StateName,

    [Parameter(Mandatory=$true, HelpMessage="Two-letter country code (e.g., US)")]
    [ValidatePattern('^[A-Z]{2}$')]
    [string]$CountryCode,

    [Parameter(Mandatory=$true, HelpMessage="NetBIOS name for this CA server")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 15)]
    [string]$CAServerName,

    [Parameter(Mandatory=$false, HelpMessage="RSA key length: 2048 or 4096")]
    [ValidateSet(2048, 4096)]
    [int]$KeyLength = 4096,

    [Parameter(Mandatory=$false, HelpMessage="Certificate validity in years")]
    [ValidateRange(1, 30)]
    [int]$ValidityYears = 10,

    [Parameter(Mandatory=$false, HelpMessage="Preview changes without executing")]
    [switch]$WhatIf
)

#region Initialize Script Environment
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogFile = Join-Path $script:ScriptPath "ScriptAudit.log"
$script:ExecutionLogFile = Join-Path $script:ScriptPath "ScriptExecution.log"
$script:CSRPath = Join-Path $script:ScriptPath "$CertCommonName-CSR-$(Get-Date -Format 'yyyyMMdd-HHmmss').req"
$script:ConfigFile = Join-Path $script:ScriptPath "PKI-ServerConfig.json"

# Import required modules
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module PSPKI -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
} catch {
    Write-Warning "Some PKI modules not available - will install if needed"
}

#endregion

#region Logging Functions
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive,

        [Parameter(Mandatory=$false)]
        [string]$LogPath = $script:LogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $displayMessage = $Message

    $logEntry = "[$timestamp] [$($script:SessionId)] [$Level] $displayMessage"

    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    $fullLogEntry = "[$timestamp] [$($script:SessionId)] [$Level] [$env:USERNAME] $Message"
    try {
        Add-Content -Path $LogPath -Value $fullLogEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$Target,

        [Parameter(Mandatory=$false)]
        [string]$Error,

        [Parameter(Mandatory=$false)]
        [hashtable]$AdditionalData
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        SessionId = $script:SessionId
        Action = $Action
        User = $env:USERNAME
        Target = $Target
        Error = $Error
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-Log -Message $auditJson -Level "AUDIT" -Sensitive $true
}

#endregion

#region Validation Functions
function Test-Prerequisites {
    Write-Log "🔍 Validating prerequisites..."

    $validationResults = @()

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $validationResults += @{
        Check = "Administrator Privileges"
        Passed = $isAdmin
        Message = if ($isAdmin) { "Running with administrator privileges" } else { "CRITICAL: Script requires administrator rights" }
        Severity = if ($isAdmin) { "Info" } else { "Critical" }
    }

    # Check OS version
    $osVersion = [Environment]::OSVersion.Version
    $supported = $osVersion.Major -ge 10 # Windows Server 2016+
    $validationResults += @{
        Check = "Windows OS Version"
        Passed = $supported
        Message = if ($supported) { "OS version $osVersion is supported" } else { "OS version $osVersion is not supported (requires Server 2016+)" }
        Severity = if ($supported) { "Info" } else { "Critical" }
    }

    # Check disk space
    $diskSpace = (Get-Item $script:ScriptPath).Root.AvailableFreeSpace / 1GB
    $hasDiskSpace = $diskSpace -gt 5
    $validationResults += @{
        Check = "Available Disk Space"
        Passed = $hasDiskSpace
        Message = if ($hasDiskSpace) { "Available space: $([math]::Round($diskSpace, 2)) GB" } else { "CRITICAL: Less than 5GB available" }
        Severity = if ($hasDiskSpace) { "Info" } else { "Critical" }
    }

    # Check network configuration
    $networkAdapter = Get-NetAdapter | Where-Object { $_.AdminStatus -eq "Up" }
    $hasNetwork = $null -ne $networkAdapter
    $validationResults += @{
        Check = "Network Configuration"
        Passed = $hasNetwork
        Message = if ($hasNetwork) { "Network adapter found: $($networkAdapter.Name)" } else { "WARNING: No active network adapter found" }
        Severity = if ($hasNetwork) { "Info" } else { "Warning" }
    }

    # Display results
    $criticalFailures = $validationResults | Where-Object { -not $_.Passed -and $_.Severity -eq "Critical" }
    $warnings = $validationResults | Where-Object { -not $_.Passed -and $_.Severity -eq "Warning" }

    foreach ($result in $validationResults) {
        $status = if ($result.Passed) { "✅" } else { "❌" }
        $color = if ($result.Passed) { "Green" } else { if ($result.Severity -eq "Critical") { "Red" } else { "Yellow" } }
        Write-Host "$status $($result.Check): $($result.Message)" -ForegroundColor $color
    }

    if ($criticalFailures) {
        Write-Log "Validation failed with $($criticalFailures.Count) critical issues" -Level ERROR
        Write-AuditLog -Action "VALIDATION_FAILED" -Error "Critical validation failures detected" -AdditionalData @{
            CriticalFailures = $criticalFailures | ConvertTo-Json
        }
        return $false
    }

    Write-Log "✅ All prerequisite checks passed" -Level INFO
    Write-AuditLog -Action "VALIDATION_PASSED" -Target "PKI-Installation"
    return $true
}

#endregion

#region AD CS Installation
function Install-ADCSRole {
    Write-Log "🚀 Installing Active Directory Certificate Services..."

    if ($PSCmdlet.ShouldProcess("AD CS Role", "Install")) {
        try {
            # Check if already installed
            $adcsFeature = Get-WindowsFeature -Name "ADCS-Cert-Authority"
            if ($adcsFeature.Installed) {
                Write-Log "ℹ️  AD CS role already installed" -Level INFO
                return $true
            }

            # Install AD CS role
            $installResult = Install-WindowsFeature -Name "ADCS-Cert-Authority" -IncludeManagementTools -Restart:$false
            
            if ($installResult.Success) {
                Write-Log "✅ AD CS role installed successfully" -Level INFO
                Write-AuditLog -Action "ADCS_ROLE_INSTALLED" -Target "AD-CS"
                return $true
            } else {
                Write-Log "❌ Failed to install AD CS role: $($installResult.RestartNeeded)" -Level ERROR
                Write-AuditLog -Action "ADCS_ROLE_INSTALLATION_FAILED" -Error "Role installation unsuccessful"
                return $false
            }
        } catch {
            Write-Log "❌ Exception during AD CS installation: $($_.Exception.Message)" -Level ERROR
            Write-AuditLog -Action "ADCS_INSTALLATION_ERROR" -Error $_.Exception.Message
            return $false
        }
    } else {
        Write-Host "🔍 WhatIf: Would install AD CS role" -ForegroundColor Yellow
        return $true
    }
}

#endregion

#region Certificate Request Generation
function New-CertificateSigningRequest {
    Write-Log "📝 Generating Certificate Signing Request (CSR)..."

    if ($PSCmdlet.ShouldProcess("Certificate Signing Request", "Create")) {
        try {
            # Create INF file for certificate request
            $infContent = @"
[Version]
Signature="`$Windows NT`$"

[NewRequest]
Subject="CN=$CertCommonName, OU=$OrganizationUnit, O=$OrganizationName, L=$LocalityName, S=$StateName, C=$CountryCode"
KeySpec=2
KeyLength=$KeyLength
Exportable=TRUE
MachineKeySet=TRUE
ProviderName="Microsoft RSA SChannel Cryptographic Provider v1.0"
ProviderType=1
HashAlgorithm=sha256
RequestType=PKCS10

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1 ; Server Authentication
OID=1.3.6.1.5.5.7.3.2 ; Client Authentication

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$CAServerName&"

[RequestAttributes]
CertificateTemplate=RootCA
"@

            $infPath = Join-Path $script:ScriptPath "$CertCommonName-CSR.inf"
            Set-Content -Path $infPath -Value $infContent -Encoding ASCII

            Write-Log "ℹ️  INF template created: $infPath" -Level DEBUG

            # Generate CSR using certreq
            $certreqResult = & certreq -new $infPath $script:CSRPath
            
            if (Test-Path $script:CSRPath) {
                Write-Log "✅ Certificate Signing Request generated: $script:CSRPath" -Level INFO
                Write-AuditLog -Action "CSR_GENERATED" -Target $script:CSRPath -AdditionalData @{
                    CommonName = $CertCommonName
                    KeyLength = $KeyLength
                }
                
                # Clean up INF file
                Remove-Item -Path $infPath -Force -ErrorAction SilentlyContinue
                
                return $true
            } else {
                Write-Log "❌ Failed to generate CSR" -Level ERROR
                Write-AuditLog -Action "CSR_GENERATION_FAILED" -Error "CertReq command failed"
                return $false
            }
        } catch {
            Write-Log "❌ Exception during CSR generation: $($_.Exception.Message)" -Level ERROR
            Write-AuditLog -Action "CSR_GENERATION_ERROR" -Error $_.Exception.Message
            return $false
        }
    } else {
        Write-Host "🔍 WhatIf: Would generate Certificate Signing Request" -ForegroundColor Yellow
        return $true
    }
}

#endregion

#region Configuration Backup
function Save-ConfigurationFile {
    Write-Log "💾 Saving configuration for reference..."

    try {
        $config = @{
            Timestamp = Get-Date -Format "o"
            CertificateCommonName = $CertCommonName
            Organization = $OrganizationName
            OrganizationUnit = $OrganizationUnit
            Locality = $LocalityName
            State = $StateName
            CountryCode = $CountryCode
            CAServerName = $CAServerName
            KeyLength = $KeyLength
            ValidityYears = $ValidityYears
            ScriptPath = $script:ScriptPath
            CSRPath = $script:CSRPath
            SessionId = $script:SessionId
            HostName = $env:COMPUTERNAME
        }

        $config | ConvertTo-Json | Set-Content -Path $script:ConfigFile -Encoding UTF8
        Write-Log "✅ Configuration saved: $script:ConfigFile" -Level INFO
        Write-AuditLog -Action "CONFIG_SAVED" -Target $script:ConfigFile
        
        return $true
    } catch {
        Write-Log "⚠️  Warning: Failed to save configuration file: $($_.Exception.Message)" -Level WARNING
        return $false
    }
}

#endregion

#region Main Execution
function Main {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "🔐 PKI Certificate Server Installation" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host ""

    Write-Log "🟢 Script execution started" -Level INFO
    Write-AuditLog -Action "SCRIPT_START" -Target "Install-PKICertificateServer" -AdditionalData @{
        CertCommonName = $CertCommonName
        KeyLength = $KeyLength
    }

    # Step 1: Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Host "`n❌ Prerequisites validation failed. Aborting." -ForegroundColor Red
        Write-Log "Script aborted due to validation failure" -Level ERROR
        exit 1
    }

    # Step 2: Install AD CS role
    if (-not (Install-ADCSRole)) {
        Write-Host "`n❌ AD CS installation failed. Aborting." -ForegroundColor Red
        Write-Log "Script aborted due to installation failure" -Level ERROR
        exit 1
    }

    # Step 3: Generate CSR
    if (-not (New-CertificateSigningRequest)) {
        Write-Host "`n❌ CSR generation failed. Aborting." -ForegroundColor Red
        Write-Log "Script aborted due to CSR generation failure" -Level ERROR
        exit 1
    }

    # Step 4: Save configuration
    Save-ConfigurationFile | Out-Null

    # Final Summary
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "✅ Installation Complete" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Transfer the CSR file to your CA server:" -ForegroundColor White
    Write-Host "   📁 $script:CSRPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2. On the CA server, run Install-PKICertificateResponse.ps1 with -RequestFilePath and -CertificateAuthorityConfig" -ForegroundColor White
    Write-Host "3. Transfer the generated response package back to this server" -ForegroundColor White
    Write-Host "4. On this server, run Install-PKICertificateResponse.ps1 with -ResponseInputPath to install the certificate" -ForegroundColor White
    Write-Host ""
    Write-Host "📝 Documentation:" -ForegroundColor Cyan
    Write-Host "   Audit Log: $script:LogFile" -ForegroundColor Gray
    Write-Host "   Config:    $script:ConfigFile" -ForegroundColor Gray
    Write-Host ""

    Write-Log "🟢 Script execution completed successfully" -Level INFO
    Write-AuditLog -Action "SCRIPT_COMPLETE" -Target "Install-PKICertificateServer"
}

# Execute main function
Main