<#
.SYNOPSIS
    Script to sign PowerShell scripts using a code-signing certificate.
.DESCRIPTION
    This script prompts the user for the path to a PowerShell script and attempts to sign it using a code-signing certificate from the current user's certificate store. If no code-signing certificate is found, a new self-signed certificate is created and used for signing.
.PARAMETER <Parameter_Name>
    None
.INPUTS
    None
.OUTPUTS
    1. The specified script is signed with a code-signing certificate.
    2. Messages indicating the success or failure of the signing process.
.NOTES
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  <Date>
  Purpose/Change: Initial script development
.EXAMPLE
    .\SignScripts.ps1
    Prompts the user for the path to a script and signs it using a code-signing certificate.
#>

# Function to prompt the user for the script path
function Get-ScriptToSign {
    param (
        [string]$Prompt = "Please enter the full path to the PowerShell script you want to sign:"
    )
    # Prompt the user for the script path
    Write-Host $Prompt -ForegroundColor Yellow
    Write-Host "Example: C:\Scripts\MyScript.ps1" -ForegroundColor Yellow
    $scriptPath = Read-Host
    # Check if the provided path exists
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: The specified path does not exist: $scriptPath" -ForegroundColor Red
        return $null
    }
    return $scriptPath
}

# Function to get an existing code-signing certificate or create a new one
function Get-CodeSigningCertificate {
    # Attempt to retrieve an existing code-signing certificate from the current user's store
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert | Select-Object -First 1
    if (-not $cert) {
        Write-Host  -ForegroundColor Red
        # Create a new code-signing certificate if none is found
        $cert = New-CodeSigningCertificate
    }
    return $cert
}

# Function to create a new self-signed code-signing certificate
function New-CodeSigningCertificate {
    Write-Host  -ForegroundColor Yellow
    # Create a new self-signed certificate
    $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -Subject  -KeyUsage DigitalSignature -Type CodeSigningCert
    if ($cert) {
        Write-Host  -ForegroundColor Green
    } else {
        Write-Host  -ForegroundColor Red
    }
    return $cert
}

# Function to sign the script with the provided certificate
function Sign-Script {
    param (
        [string]$scriptPath,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$certificate
    )
    try {
        # Attempt to sign the script
        $signature = Set-AuthenticodeSignature -FilePath $scriptPath -Certificate $certificate
        if ($signature.Status -eq 'Valid') {
            Write-Host  -ForegroundColor Green
        } else {
            Write-Host  -ForegroundColor Red
            Write-Host  -ForegroundColor Red
        }
    } catch {
        Write-Host  -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# Main script execution
$scriptPath = Get-ScriptToSign
if ($scriptPath) {
    $certificate = Get-CodeSigningCertificate
    if ($certificate) {
        Sign-Script -scriptPath $scriptPath -certificate $certificate
    }
}
