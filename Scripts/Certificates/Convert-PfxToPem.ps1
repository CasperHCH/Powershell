<#
.SYNOPSIS
    Convert a .pfx certificate to .crt, .key, and .pem files using OpenSSL.
.DESCRIPTION
    This script converts a .pfx certificate to .crt, .key, and .pem files using OpenSSL.
    The .pem file will contain both the certificate and the key.
.PARAMETER PfxFile
    The path to the .pfx file.
.PARAMETER PfxPassword
    The password for the .pfx file.
.PARAMETER OutputPath
    The path to save the output files.
.INPUTS
    None
.OUTPUTS
    .crt, .key, and .pem files.
.NOTES
    Ensure OpenSSL is installed and available in the system PATH.
.EXAMPLE
    .\Convert-PfxToPem.ps1 -PfxFile "C:\path\to\yourfile.pfx" -PfxPassword "yourpassword" -OutputPath "C:\path\to\output"
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "Specify the path to the .pfx file.")]
    [string]$PfxFile,

    [Parameter(Mandatory = $true, HelpMessage = "Specify the password for the .pfx file.")]
    [string]$PfxPassword,

    [Parameter(Mandatory = $true, HelpMessage = "Specify the path to save the output files.")]
    [string]$OutputPath
)

# Ensure OpenSSL is installed
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Error "OpenSSL is not installed or not available in the system PATH."
    exit 1
}

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Extract the base name of the .pfx file
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($PfxFile)

# Define the output file paths
$keyFile = Join-Path -Path $OutputPath -ChildPath "$baseName.key"
$crtFile = Join-Path -Path $OutputPath -ChildPath "$baseName.crt"
$decryptedKeyFile = Join-Path -Path $OutputPath -ChildPath "$baseName-decrypted.key"
$pemFile = Join-Path -Path $OutputPath -ChildPath "$baseName.pem"

# Extract the private key
openssl pkcs12 -in $PfxFile -nocerts -out $keyFile -passin pass:$PfxPassword -passout pass:$PfxPassword

# Extract the certificate
openssl pkcs12 -in $PfxFile -clcerts -nokeys -out $crtFile -passin pass:$PfxPassword

# Decrypt the private key
openssl rsa -in $keyFile -out $decryptedKeyFile -passin pass:$PfxPassword

# Combine the certificate and decrypted key into a .pem file
cat $crtFile, $decryptedKeyFile | Out-File -FilePath $pemFile -Encoding ascii

Write-Host "Conversion completed. The following files have been created:"
Write-Host "Certificate (.crt): $crtFile"
Write-Host "Private Key (.key): $keyFile"
Write-Host "Decrypted Private Key (.key): $decryptedKeyFile"
Write-Host "PEM File (.pem): $pemFile"