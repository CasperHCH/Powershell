<#
.SYNOPSIS
    Script to import CA certificates into the cacerts of an Atlassian installation.
.DESCRIPTION
    This script imports all CA certificates from a specified directory into the cacerts keystore of an Atlassian installation.
.PARAMETER CertificatePassword
    The password for the certificates being imported.
.INPUTS
    None
.OUTPUTS
    Messages indicating the success or failure of the import process.
.NOTES
  Version:        1.0
  Author:         GitHub Copilot
  Creation Date:  <Date>
  Purpose/Change: Initial script development
.EXAMPLE
    .\Import_All_Certificates_to_CaCerts.ps1 -CertificatePassword "yourpassword"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$CertificatePassword
)

# Define the path to the Atlassian folder and the cacerts file
$AtlassianFolder = "C:\Atlassian"
$cacertsPath = Join-Path -Path $AtlassianFolder -ChildPath "jre\lib\security\cacerts"

# Get all certificate files from the specified directory
$certs = Get-ChildItem -Path "C:\apache24\conf\ssl" -Include *.crt, *.key, *.pfx

foreach ($cert in $certs) {
    $certPath = $cert.FullName
    $certAlias = [IO.Path]::GetFileNameWithoutExtension($cert.Name)

    if ($cert.Extension -eq ".pfx") {
        # Import PFX certificate
        & keytool -importkeystore -srckeystore $certPath -srcstoretype pkcs12 -srcstorepass $CertificatePassword -destkeystore $cacertsPath -deststorepass changeit -alias $certAlias -trustcacerts -noprompt
    } else {
        # Import CRT or KEY certificate
        & keytool -import -file $certPath -keystore $cacertsPath -storepass changeit -alias $certAlias -trustcacerts -noprompt
    }
}

# Backup the cacerts file
$backupFolder = Join-Path -Path $AtlassianFolder -ChildPath "backup"
if (-not (Test-Path -Path $backupFolder)) {
    New-Item -Path $backupFolder -ItemType Directory
}
$backupCacerts = Join-Path -Path $backupFolder -ChildPath "cacerts.bak"
Copy-Item -Path $cacertsPath -Destination $backupCacerts -Force

Write-Host "All certificates have been imported and the cacerts file has been backed up." -ForegroundColor Green