<#
.SYNOPSIS
    Requests a certificate using a .inf configuration file with support for domain controller or self-signed certificates.

.DESCRIPTION
    This script accepts a .inf file and generates a certificate request. It supports:
    - Domain controller-based certificate requests
    - Self-signed certificate generation
    - Custom password or auto-generated passwords
    - Comprehensive logging and audit trail

.PARAMETER InfFilePath
    Path to the certificate request configuration file (.inf format).

.PARAMETER CertificatePassword
    Secure password to protect the exported certificate. If not provided, a secure password will be auto-generated.

.PARAMETER UseDomainController
    Use domain controller for certificate request. Requires a valid domain environment.

.PARAMETER DomainControllerName
    Hostname or IP of the domain controller to use for certificate issuance.

.PARAMETER TemplateId
    Certificate template name or OID on the domain controller.

.PARAMETER ExportPath
    Directory path where the certificate will be exported. Defaults to script directory.

.PARAMETER TimeoutSeconds
    Timeout for certificate operations in seconds.

.EXAMPLE
    .\RequestCertificate.ps1 -InfFilePath "C:\certs\request.inf" -UseDomainController -DomainControllerName "dc01.example.org"

.EXAMPLE
    $password = Read-Host -AsSecureString -Prompt "Enter certificate password"
    .\RequestCertificate.ps1 -InfFilePath "C:\certs\request.inf" -CertificatePassword $password -ExportPath "C:\certificates"

.NOTES
    Author: PowerShell Automation Team
    Requires: Administrator privileges for certificate operations
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(
        Mandatory=$true,
        Position=0,
        HelpMessage="Path to .inf configuration file"
    )]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [ValidatePattern('\.(inf|txt)$', ErrorMessage='File must be .inf or .txt format')]
    [string]$InfFilePath,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Certificate password (auto-generated if not provided)"
    )]
    [securestring]$CertificatePassword,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Use domain controller for certificate request"
    )]
    [switch]$UseDomainController,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Domain controller hostname or IP"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$DomainControllerName,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Certificate template name or OID"
    )]
    [string]$TemplateId = "WebServer",

    [Parameter(
        Mandatory=$false,
        HelpMessage="Directory for certificate export"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$ExportPath = $PSScriptRoot,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Timeout for certificate operations in seconds"
    )]
    [ValidateRange(10, 600)]
    [int]$TimeoutSeconds = 120
)

# ============================================================================
# INITIALIZATION & LOGGING
# ============================================================================

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "CertificateRequest_Audit.log"
$script:PasswordLogFile = Join-Path $PSScriptRoot "CertificatePasswords_Secure.log"
$script:InfFilePath = $InfFilePath
$script:CertificatePassword = $CertificatePassword
$script:UseDomainController = $UseDomainController
$script:DomainControllerName = $DomainControllerName
$script:TemplateId = $TemplateId
$script:ExportPath = $ExportPath
$script:TimeoutSeconds = $TimeoutSeconds

function Write-CertificateLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $displayMessage = $Message

    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"
    $fullLogEntry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"

    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    try {
        Add-Content -Path $script:LogFile -Value $fullLogEntry -ErrorAction Stop
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
        Target = $Target
        User = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        Error = $Error
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditEntry | ConvertTo-Json -Compress
    Write-CertificateLog -Message $auditJson -Level "AUDIT" -Sensitive $true
}

# ============================================================================
# VALIDATION & PREREQUISITES
# ============================================================================

function Test-Prerequisite {
    Write-Host "🔍 Validating prerequisites..." -ForegroundColor Cyan

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "❌ This script requires administrator privileges" -ForegroundColor Red
        Write-AuditLog -Action "PREREQ_FAILED" -Error "Insufficient privileges"
        exit 1
    }
    Write-Host "✅ Administrator privileges verified" -ForegroundColor Green

    # Validate export path
    if (-not (Test-Path $ExportPath)) {
        try {
            New-Item -ItemType Directory -Path $ExportPath -Force -ErrorAction Stop | Out-Null
            Write-Host "✅ Export directory created: $ExportPath" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to create export directory: $_" -ForegroundColor Red
            Write-AuditLog -Action "EXPORT_PATH_CREATION_FAILED" -Target $ExportPath -Error $_.Exception.Message
            exit 1
        }
    }
    Write-Host "✅ Export path validated" -ForegroundColor Green

    # Validate .inf file
    if (-not (Test-Path $InfFilePath)) {
        Write-Host "❌ Configuration file not found: $InfFilePath" -ForegroundColor Red
        Write-AuditLog -Action "CONFIG_FILE_NOT_FOUND" -Target $InfFilePath
        exit 1
    }
    Write-Host "✅ Configuration file found" -ForegroundColor Green

    # Validate domain controller connectivity if specified
    if ($UseDomainController) {
        if (-not $DomainControllerName) {
            Write-Host "⚠️  UseDomainController specified but no DomainControllerName provided" -ForegroundColor Yellow
            $script:DomainControllerName = Read-Host "Enter domain controller hostname or IP"
        }

        $dcTest = Test-NetConnection -ComputerName $DomainControllerName -Port 389 -WarningAction SilentlyContinue
        if (-not $dcTest.TcpTestSucceeded) {
            Write-Host "❌ Cannot reach domain controller: $DomainControllerName" -ForegroundColor Red
            Write-AuditLog -Action "DC_CONNECTIVITY_FAILED" -Target $DomainControllerName
            exit 1
        }
        Write-Host "✅ Domain controller connectivity verified" -ForegroundColor Green
    }
}

# ============================================================================
# PASSWORD MANAGEMENT
# ============================================================================

function Get-SecurePassword {
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateRange(12, 32)]
        [int]$Length = 16
    )

    $uppercase = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowercase = [char[]]'abcdefghijklmnopqrstuvwxyz'
    $numbers = [char[]]'0123456789'
    $symbols = [char[]]'!@#$%^&*()-_=+[]{}|;:,.<>?'

    $allChars = $uppercase + $lowercase + $numbers + $symbols
    $password = @()

    $password += Get-Random -InputObject $uppercase
    $password += Get-Random -InputObject $lowercase
    $password += Get-Random -InputObject $numbers
    $password += Get-Random -InputObject $symbols

    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += Get-Random -InputObject $allChars
    }

    $randomPassword = -join ($password | Get-Random -Count $password.Count | ForEach-Object { $_ })
    $securePassword = New-Object System.Security.SecureString
    foreach ($character in $randomPassword.ToCharArray()) {
        $securePassword.AppendChar($character)
    }
    $securePassword.MakeReadOnly()
    return $securePassword
}

function Save-CertificatePasswordSecurely {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CertificateName,

        [Parameter(Mandatory=$true)]
        [securestring]$Password
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $encryptedPassword = ConvertFrom-SecureString -SecureString $Password
    $passwordEntry = "[$timestamp] [$script:SessionId] Certificate: $CertificateName | EncryptedPassword: $encryptedPassword"

    try {
        Add-Content -Path $script:PasswordLogFile -Value $passwordEntry -ErrorAction Stop
        Write-CertificateLog "Certificate password stored securely" -Level "AUDIT" -Sensitive $true
    } catch {
        Write-CertificateLog "Failed to store password securely: $_" -Level "ERROR" -Sensitive $true
    }
}

# ============================================================================
# CERTIFICATE REQUEST & GENERATION
# ============================================================================

function New-CertificateRequest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InfPath,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    Write-Host "📋 Creating certificate request..." -ForegroundColor Cyan

    try {
        $requestPath = Join-Path $OutputPath "cert_request.req"

        if (-not $PSCmdlet.ShouldProcess($requestPath, "Create certificate request from INF file")) {
            return $requestPath
        }

        # Use certreq to process the .inf file
        $certReqOutput = & certreq -new $InfPath $requestPath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Certificate request creation failed: $certReqOutput"
        }

        Write-Host "✅ Certificate request created successfully" -ForegroundColor Green
        Write-AuditLog -Action "CERT_REQUEST_CREATED" -Target $requestPath

        return $requestPath
    } catch {
        Write-Host "❌ Certificate request creation failed: $_" -ForegroundColor Red
        Write-AuditLog -Action "CERT_REQUEST_FAILED" -Error $_.Exception.Message
        throw
    }
}

function Submit-CertificateRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RequestPath,

        [Parameter(Mandatory=$true)]
        [string]$DomainController,

        [Parameter(Mandatory=$true)]
        [string]$Template,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    Write-Host "📤 Submitting certificate request to $DomainController..." -ForegroundColor Cyan

    try {
        $responsePath = Join-Path $OutputPath "cert_response.cer"

        # Submit to domain controller
        $certReqOutput = & certreq -submit -config "$DomainController\$Template" $RequestPath $responsePath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Certificate submission failed: $certReqOutput"
        }

        Write-Host "✅ Certificate received from domain controller" -ForegroundColor Green
        Write-AuditLog -Action "CERT_SUBMITTED_TO_DC" -Target "$DomainController\$Template"

        return $responsePath
    } catch {
        Write-Host "❌ Certificate submission failed: $_" -ForegroundColor Red
        Write-AuditLog -Action "CERT_SUBMISSION_FAILED" -Target $DomainController -Error $_.Exception.Message
        throw
    }
}

function Approve-CertificateRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResponePath
    )

    Write-Host "✔️  Installing certificate response..." -ForegroundColor Cyan

    try {
        $certInstallOutput = & certreq -accept $ResponePath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Certificate installation failed: $certInstallOutput"
        }

        Write-Host "✅ Certificate installed successfully" -ForegroundColor Green
        Write-AuditLog -Action "CERT_INSTALLED" -Target $ResponePath
    } catch {
        Write-Host "❌ Certificate installation failed: $_" -ForegroundColor Red
        Write-AuditLog -Action "CERT_INSTALLATION_FAILED" -Error $_.Exception.Message
        throw
    }
}

function New-LocalSelfSignedCertificate {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Subject,

        [Parameter(Mandatory=$true)]
        [string]$FriendlyName,

        [Parameter(Mandatory=$true)]
        [securestring]$Password,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    Write-Host "🔐 Generating self-signed certificate..." -ForegroundColor Cyan

    try {
        $certPath = Join-Path $OutputPath "$FriendlyName.pfx"

        if (-not $PSCmdlet.ShouldProcess($certPath, "Create and export self-signed certificate")) {
            return @{ Path = $certPath; Thumbprint = $null; Subject = $Subject }
        }

        $cert = New-SelfSignedCertificate -Subject $Subject `
                                          -FriendlyName $FriendlyName `
                                          -CertStoreLocation "Cert:\CurrentUser\My" `
                                          -KeyUsage DigitalSignature, KeyEncipherment `
                                          -TextExtension "2.5.29.37={text}1.3.6.1.5.5.7.3.1" `
                                          -ErrorAction Stop

        Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $Password -ErrorAction Stop | Out-Null

        Write-Host "✅ Self-signed certificate created: $certPath" -ForegroundColor Green
        Write-AuditLog -Action "SELF_SIGNED_CERT_CREATED" -Target $certPath -AdditionalData @{Thumbprint=$cert.Thumbprint; Subject=$Subject}

        return @{
            Path = $certPath
            Thumbprint = $cert.Thumbprint
            Subject = $Subject
        }
    } catch {
        Write-Host "❌ Self-signed certificate creation failed: $_" -ForegroundColor Red
        Write-AuditLog -Action "SELF_SIGNED_CERT_FAILED" -Error $_.Exception.Message
        throw
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "🚀 Starting certificate request process..." -ForegroundColor Cyan
    Write-CertificateLog "Certificate request process initiated" -Level "AUDIT"

    try {
        # Run prerequisites
        Test-Prerequisite

        # Handle password
        if ($null -eq $script:CertificatePassword) {
            Write-Host "🔑 Generating secure password..." -ForegroundColor Cyan
            $securePassword = Get-SecurePassword
            Write-Host "✅ Password generated (see secure log)" -ForegroundColor Green
        } else {
            $securePassword = $script:CertificatePassword
        }

        # Extract subject from .inf file
        $infContent = Get-Content $script:InfFilePath -Raw
        $subjectMatch = $infContent | Select-String -Pattern 'Subject\s*=\s*"?([^"]+)"?' | Select-Object -First 1
        $subject = if ($subjectMatch) { $subjectMatch.Matches[0].Groups[1].Value } else { "CN=GeneratedCertificate" }
        $friendlyName = $subject -replace 'CN=', '' -replace ',O=.*', ''
        $outputCertificatePath = $script:ExportPath

        if ($PSCmdlet.ShouldProcess($subject, "Generate Certificate")) {
            if ($script:UseDomainController) {
                # Domain Controller-based flow
                $requestPath = New-CertificateRequest -InfPath $script:InfFilePath -OutputPath $script:ExportPath
                $responsePath = Submit-CertificateRequest -RequestPath $requestPath `
                                                         -DomainController $script:DomainControllerName `
                                                         -Template $script:TemplateId `
                                                         -OutputPath $script:ExportPath
                Approve-CertificateRequest -ResponePath $responsePath
                $outputCertificatePath = $responsePath
            } else {
                # Self-signed flow
                $certResult = New-LocalSelfSignedCertificate -Subject $subject `
                                                             -FriendlyName $friendlyName `
                                                             -Password $securePassword `
                                                             -OutputPath $script:ExportPath
                $outputCertificatePath = $certResult.Path
            }

            # Store password securely
            Save-CertificatePasswordSecurely -CertificateName $friendlyName -Password $securePassword

            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "✅ Certificate request completed successfully!" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "📁 Export Path: $script:ExportPath" -ForegroundColor White
            Write-Host "📄 Certificate Output: $outputCertificatePath" -ForegroundColor White
            Write-Host "🔒 Certificate Protected: Yes (check password log)" -ForegroundColor White
            Write-Host "📋 Audit Log: $script:LogFile" -ForegroundColor White
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

            Write-AuditLog -Action "PROCESS_COMPLETED" -Target $subject
        }
    } catch {
        Write-Host "❌ Process failed: $_" -ForegroundColor Red
        Write-AuditLog -Action "PROCESS_FAILED" -Error $_.Exception.Message
        exit 1
    }
}

# ============================================================================
# CERTIFICATE REQUEST .INF TEMPLATE
# ============================================================================
<#
.TEMPLATE

; ---------------------------------------------------------------------------
; CERTREQ INF TEMPLATE REFERENCE
; ---------------------------------------------------------------------------
; This is a sample request file for certreq.exe.
; Replace the example values with values that match the certificate you need.
; Lines beginning with ';' are comments inside the INF template.
; ---------------------------------------------------------------------------

[Version]
; Required header for certreq INF files.
; Leave this value exactly as shown.
Signature="$Windows NT$"

[NewRequest]
; Subject is the certificate identity in X.500 format.
; Fill in the values that identify the certificate owner.
; Common entries:
;   CN = Common Name. Usually the primary DNS name of the service.
;   O  = Organization name.
;   OU = Organizational unit. Optional.
;   L  = City or locality.
;   S  = State or province.
;   C  = Two-letter country code.
; Example for a web certificate:
;   Subject = "CN=portal.example.org, O=Example Org, L=Copenhagen, S=Capital Region, C=DK"
Subject = "CN=example.org, O=Organization Name, L=City, S=State, C=US"

; FriendlyName is the closest Windows equivalent to a Java keytool alias.
; It is a local label used in the Windows certificate store / exported PFX.
; It is NOT the certificate identity itself and is generally not embedded into
; the CSR the way a Java keystore alias identifies an entry.
; Use a short, descriptive value that helps operators recognize the cert.
; Example: FriendlyName = "webserver-example-org"
FriendlyName = "example-org-webserver"

; KeySpec controls intended private-key usage for legacy CSP providers.
; 1 = AT_KEYEXCHANGE, commonly used for TLS/server authentication.
; 2 = AT_SIGNATURE, more common for signing-only scenarios.
; Keep 1 for standard web/server certificates unless your CA requires otherwise.
KeySpec = 1

; KeyLength is the RSA key size in bits.
; Typical values: 2048 or 4096.
; 2048 is broadly compatible. 4096 increases size and CPU cost.
KeyLength = 2048

; Exportable controls whether the private key can be exported later.
; TRUE is useful when you need a PFX for another server or appliance.
; FALSE is stricter if the key must never leave the original machine.
Exportable = TRUE

; MachineKeySet stores the private key in the computer context.
; TRUE for server/service certificates.
; FALSE for user certificates stored under the current user profile.
MachineKeySet = TRUE

; SMIME enables Secure/Multipurpose Internet Mail Extensions behavior.
; Leave FALSE unless this certificate is specifically for email signing/encryption.
SMIME = FALSE

; PrivateKeyArchive requests key archival if your CA supports it.
; Usually FALSE for ordinary TLS certificates.
PrivateKeyArchive = FALSE

; UserProtected prompts for user interaction when the private key is used.
; Keep FALSE for unattended services, IIS bindings, and automation.
UserProtected = FALSE

; UseExistingKeySet tells certreq to reuse an existing private key.
; FALSE creates a new key pair.
; TRUE is only for renewal/reuse scenarios where a key already exists.
UseExistingKeySet = FALSE

; ProviderName selects the crypto provider.
; This sample uses the classic RSA SChannel provider for compatibility.
; If your environment requires CNG instead, you would typically switch to a
; CNG provider and use KeyAlgorithm/ProviderName values approved by your CA.
ProviderName = "Microsoft RSA SChannel Cryptographic Provider v1.0"

; ProviderType is the legacy provider type for the selected CSP.
; Leave this paired with the ProviderName above unless you intentionally change both.
ProviderType = 12

; RequestType defines what kind of request is generated.
; PKCS10 is the normal choice for a new certificate signing request.
; PKCS7 is used for some enrollment/renewal workflows.
RequestType = PKCS10

; KeyUsage is a bitmask defining allowed cryptographic operations.
; 0xa0 is a common value for Digital Signature + Key Encipherment.
; Keep this for standard TLS server certificates unless your CA template says otherwise.
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
; Enhanced Key Usage (EKU) defines what the certificate is allowed to be used for.
; Add one OID per intended usage.
; Common EKUs:
;   1.3.6.1.5.5.7.3.1 = Server Authentication
;   1.3.6.1.5.5.7.3.2 = Client Authentication
; Remove entries you do not need. Least privilege applies here too.
OID = 1.3.6.1.5.5.7.3.1
OID = 1.3.6.1.5.5.7.3.2

[Extensions]
; Subject Alternative Name (SAN) extension.
; Modern TLS clients validate SANs, not just CN.
; Include every DNS name clients will use to reach the service.
; Use '&' between values.
; Examples:
;   DNS=portal.example.org
;   DNS=www.example.org
;   IP Address=10.10.10.25
; Avoid adding names you do not actually need.
2.5.29.17 = "{text}DNS=example.org&DNS=www.example.org&DNS=mail.example.org"

[RequestAttributes]
; CertificateTemplate is the AD CS template name expected by the issuing CA.
; Replace WebServer with the exact template display/short name your PKI team provided.
; Examples: WebServer, Computer, User, VPNUser, InternalWebServer
CertificateTemplate = WebServer

TEMPLATE PROPERTIES:
; QUICK FILL-IN GUIDE
; 1. Set Subject CN to the primary hostname or identity.
; 2. Add every required DNS name in the SAN extension.
; 3. Keep MachineKeySet=TRUE for server certificates.
; 4. Use FriendlyName as your local alias-style label.
; 5. Confirm the template name with the CA / PKI administrator.
; 6. Use 2048-bit RSA unless policy requires 4096.
; 7. Remove Client Authentication EKU if the cert is server-only.

; KEYTOOL ALIAS NOTE
; Java keytool stores certificates inside a keystore entry identified by an alias.
; A certreq INF does not have a true keystore-entry alias in the same sense.
; The closest Windows-side property is FriendlyName, which is a local display label.
; The actual certificate identity is still defined by Subject + SAN + EKU.

.TEMPLATE
#>

Main
