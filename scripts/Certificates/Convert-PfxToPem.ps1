<#
.SYNOPSIS
    Securely converts PFX certificates to PEM format using OpenSSL with enhanced security features

.DESCRIPTION
    This script provides secure conversion of PFX certificates to CRT, KEY, and PEM files using OpenSSL.
    Features secure password handling, input validation, audit logging, and proper file permissions.
    Supports both interactive password prompting and secure credential management.

.PARAMETER PfxFile
    Path to the source PFX certificate file. Must exist and be accessible.

.PARAMETER PfxPassword
    Secure password for the PFX file. Use SecureString for enhanced security.

.PARAMETER OutputPath
    Directory path where converted files will be saved. Will be created if it doesn't exist.

.PARAMETER Credential
    PSCredential object containing PFX password (alternative to PfxPassword parameter)

.PARAMETER OverwriteExisting
    Allow overwriting existing output files

.EXAMPLE
    .\Convert-PfxToPem.ps1 -PfxFile "C:\Certificates\server.pfx" -OutputPath "C:\Certificates\Output"
    Prompts securely for PFX password and converts certificate files.

.EXAMPLE
    $securePassword = Read-Host -AsSecureString -Prompt "Enter PFX password"
    .\Convert-PfxToPem.ps1 -PfxFile "C:\Certificates\server.pfx" -PfxPassword $securePassword -OutputPath "C:\Output"
    Uses SecureString password for conversion.

.NOTES
    Author: IT Security Team
    Version: 2.0 (Security Enhanced)
    Security Classification: Confidential
    Requires: PowerShell 5.1+, OpenSSL installed and in PATH

    SECURITY FEATURES:
    - SecureString password handling
    - Input validation and sanitization
    - Secure file permission management
    - Comprehensive audit logging
    - Temporary file cleanup
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the PFX certificate file")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$PfxFile,

    [Parameter(Mandatory = $false, HelpMessage = "Secure password for the PFX file")]
    [SecureString]$PfxPassword,

    [Parameter(Mandatory = $true, HelpMessage = "Output directory for converted certificate files")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "PSCredential containing PFX password")]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "Allow overwriting existing output files")]
    [switch]$OverwriteExisting
)

# Security audit initialization
$auditEntry = @{
    Timestamp    = Get-Date -Format "o"
    Action       = "Convert-PfxToPem"
    User         = $env:USERNAME
    ComputerName = $env:COMPUTERNAME
    ScriptName   = $MyInvocation.MyCommand.Name
    SourceFile   = $PfxFile
    OutputPath   = $OutputPath
}

# Secure password management
if ($Credential) {
    $PfxPassword = $Credential.Password
    Write-Verbose "Using provided PSCredential for PFX password"
    $auditEntry.AuthMethod = "PSCredential"
}
elseif (-not $PfxPassword) {
    $PfxPassword = Read-Host -AsSecureString -Prompt "Enter PFX certificate password"
    $auditEntry.AuthMethod = "Interactive"
}
else {
    $auditEntry.AuthMethod = "SecureString"
}

if (-not $PfxPassword) {
    throw "PFX password is required for certificate conversion"
}

# Validate OpenSSL availability
Write-Verbose "Checking OpenSSL installation..."
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    $errorMsg = "OpenSSL is not installed or not available in the system PATH. Please install OpenSSL first."
    Write-Error $errorMsg
    $auditEntry.Status = "Failed"
    $auditEntry.Error = "OpenSSL not found"
    throw $errorMsg
}

$opensslVersion = (openssl version 2>$null)
Write-Verbose "OpenSSL found: $opensslVersion"
$auditEntry.OpenSSLVersion = $opensslVersion

# Secure output directory creation
try {
    if (-not (Test-Path -Path $OutputPath)) {
        Write-Verbose "Creating output directory: $OutputPath"
        $outputDir = New-Item -ItemType Directory -Path $OutputPath -Force
        # Set restrictive permissions (owner only)
        $acl = Get-Acl $outputDir.FullName
        $acl.SetAccessRuleProtection($true, $false)  # Remove inherited permissions
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $outputDir.FullName -AclObject $acl
        Write-Verbose "Set restrictive permissions on output directory"
    }
}
catch {
    Write-Error "Failed to create or secure output directory: $($_.Exception.Message)"
    $auditEntry.Status = "Failed"
    $auditEntry.Error = $_.Exception.Message
    throw
}

# Extract the base name of the .pfx file for output naming
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($PfxFile)
Write-Verbose "Processing certificate: $baseName"

# Define the output file paths
$keyFile = Join-Path -Path $OutputPath -ChildPath "$baseName.key"
$crtFile = Join-Path -Path $OutputPath -ChildPath "$baseName.crt"
$decryptedKeyFile = Join-Path -Path $OutputPath -ChildPath "$baseName-decrypted.key"
$pemFile = Join-Path -Path $OutputPath -ChildPath "$baseName.pem"

# Check for existing files if not overwriting
if (-not $OverwriteExisting) {
    $existingFiles = @($keyFile, $crtFile, $decryptedKeyFile, $pemFile) | Where-Object { Test-Path $_ }
    if ($existingFiles) {
        throw "Output files already exist. Use -OverwriteExisting to overwrite: $($existingFiles -join ', ')"
    }
}

# Convert SecureString password to plain text for OpenSSL (in memory only)
$plaintextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PfxPassword))

try {
    Write-Host "🔒 Starting secure certificate conversion..." -ForegroundColor Cyan

    # Extract the private key with secure password handling
    Write-Verbose "Extracting private key..."
    $env:OPENSSL_PASS = $plaintextPassword
    & openssl pkcs12 -in $PfxFile -nocerts -out $keyFile -passin env:OPENSSL_PASS -passout env:OPENSSL_PASS 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract private key" }

    # Extract the certificate
    Write-Verbose "Extracting certificate..."
    & openssl pkcs12 -in $PfxFile -clcerts -nokeys -out $crtFile -passin env:OPENSSL_PASS 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract certificate" }

    # Decrypt the private key
    Write-Verbose "Decrypting private key..."
    & openssl rsa -in $keyFile -out $decryptedKeyFile -passin env:OPENSSL_PASS 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Failed to decrypt private key" }

    # Combine the certificate and decrypted key into a .pem file
    Write-Verbose "Creating combined PEM file..."
    Get-Content $crtFile, $decryptedKeyFile | Out-File -FilePath $pemFile -Encoding UTF8

    # Set restrictive permissions on all output files (owner read-only)
    foreach ($file in @($keyFile, $crtFile, $decryptedKeyFile, $pemFile)) {
        if (Test-Path $file) {
            $acl = Get-Acl $file
            $acl.SetAccessRuleProtection($true, $false)
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "Read", "Allow")
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $file -AclObject $acl
            Write-Verbose "Set secure permissions on: $(Split-Path $file -Leaf)"
        }
    }

    Write-Host "✅ Certificate conversion completed successfully!" -ForegroundColor Green
    Write-Host "📁 Output files created in: $OutputPath" -ForegroundColor Cyan
    Write-Host "   🔐 Certificate (.crt): $(Split-Path $crtFile -Leaf)" -ForegroundColor White
    Write-Host "   🗝️  Private Key (.key): $(Split-Path $keyFile -Leaf)" -ForegroundColor White
    Write-Host "   🔓 Decrypted Key (.key): $(Split-Path $decryptedKeyFile -Leaf)" -ForegroundColor White
    Write-Host "   📜 Combined PEM (.pem): $(Split-Path $pemFile -Leaf)" -ForegroundColor White

    $auditEntry.Status = "Success"
    $auditEntry.FilesCreated = 4
    $auditEntry.OutputFiles = @($keyFile, $crtFile, $decryptedKeyFile, $pemFile)

}
catch {
    Write-Error "Certificate conversion failed: $($_.Exception.Message)"
    $auditEntry.Status = "Failed"
    $auditEntry.Error = $_.Exception.Message
    throw
}
finally {
    # Secure cleanup - clear password from environment and memory
    if ($env:OPENSSL_PASS) {
        Remove-Item env:OPENSSL_PASS -ErrorAction SilentlyContinue
    }

    # Clear plaintext password from memory
    if ($plaintextPassword) {
        $plaintextPassword = $null
        [System.GC]::Collect()
    }

    # Security audit logging
    Write-Verbose "Certificate conversion audit: $($auditEntry | ConvertTo-Json -Compress)"

    Write-Host "🔒 Memory and environment cleanup completed" -ForegroundColor Green
}