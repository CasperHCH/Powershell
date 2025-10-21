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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Prompt = "Please enter the full path to the PowerShell script you want to sign:"
    )
    # Prompt the user for the script path
    Write-Information $Prompt -InformationAction Continue
    Write-Information "Example: C:\Scripts\MyScript.ps1" -InformationAction Continue
    $scriptPath = Read-Host
    # Check if the provided path exists
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Error: The specified path does not exist: $scriptPath"
        return $null
    }
    return $scriptPath
}

# Function to get an existing code-signing certificate or create a new one
function Get-CodeSigningCertificate {
    [CmdletBinding()]
    param()
    # Attempt to retrieve an existing code-signing certificate from the current user's store
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert | Select-Object -First 1
    if (-not $cert) {
        Write-Warning "No existing code-signing certificate found."
        # Create a new code-signing certificate if none is found
        $cert = New-CodeSigningCertificate
    }
    return $cert
}

# Function to create a new self-signed code-signing certificate
function New-CodeSigningCertificate {
    [CmdletBinding()]
    param()
    Write-Information "Creating a new self-signed code-signing certificate..." -InformationAction Continue
    # Create a new self-signed certificate
    $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -Subject "CN=PowerShell Code Signing" -KeyUsage DigitalSignature -Type CodeSigningCert
    if ($cert) {
        Write-Information "Certificate created successfully." -InformationAction Continue
    } else {
        Write-Error "Failed to create certificate."
    }
    return $cert
}

# Function to sign the script with the provided certificate
function Set-ScriptSignature {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$scriptPath,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$certificate
    )
    try {
        # Attempt to sign the script
        $signature = Set-AuthenticodeSignature -FilePath $scriptPath -Certificate $certificate
        if ($signature.Status -eq 'Valid') {
            Write-Information "Script signed successfully." -InformationAction Continue
        } else {
            Write-Warning "Failed to sign script."
            Write-Warning "Signature status: $($signature.Status)"
        }
    } catch {
        Write-Error "Error occurred while signing script."
        Write-Error $_.Exception.Message
    }
}

# Main script execution
$scriptPath = Get-ScriptToSign
if ($scriptPath) {
    $certificate = Get-CodeSigningCertificate
    if ($certificate) {
        Set-ScriptSignature -scriptPath $scriptPath -certificate $certificate
    }
}
