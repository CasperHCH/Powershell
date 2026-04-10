<#
.SYNOPSIS
    Import all certificates to the Java keystore (cacerts) for Atlassian Confluence.
.DESCRIPTION
    This script imports all certificates from a specified directory to the Java keystore (cacerts) used by Atlassian Confluence.
.PARAMETER CertificatePassword
    The password for the certificate files (if applicable).
.PARAMETER AtlassianFolder
    The root folder for Atlassian Confluence (used to locate jre and cacerts).
.PARAMETER CertificateFolder
    The folder containing certificate files to import.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
  Version:        1.1
  Author:         Casper Hjorth Christensen
  Creation Date:  <Date>
  Purpose/Change: Added folder parameters for flexibility
.EXAMPLE
    .\Import_All_Certificates_to_CaCerts.ps1 -CertificatePassword "yourpassword" -AtlassianFolder "C:\Atlassian\confluence" -CertificateFolder "C:\ssl"
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = "Specify the password for the certificate files (if applicable).")]
    [securestring]$CertificatePassword,
    [Parameter(Mandatory = $false, HelpMessage = "Specify the Atlassian Confluence root folder.")]
    [string]$AtlassianFolder = "C:\Atlassian\confluence",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the folder containing certificate files.")]
    [string]$CertificateFolder = "C:\ssl"
)

$plaintextCertificatePassword = $null

if ($CertificatePassword) {
    $plaintextCertificatePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertificatePassword)
    )
}

# Get all certificate files from the specified directory
$certs = Get-ChildItem -Path $CertificateFolder -Include *.crt, *.key, *.pfx

# Import each certificate to the Java keystore (cacerts)
foreach ($c in $certs) {
    $certPath = $c.FullName
    $certAlias = [IO.Path]::GetFileNameWithoutExtension($c.Name)

    if ($c.Extension -eq ".pfx") {
        if ($plaintextCertificatePassword) {
            & "$($AtlassianFolder)\jre\bin\keytool.exe" -importkeystore -srckeystore "$certPath" -srcstorepass "$plaintextCertificatePassword" -destkeystore "$($AtlassianFolder)\jre\lib\security\cacerts" -deststorepass changeit -trustcacerts -alias "$certAlias" -deststoretype pkcs12 -noprompt
        } else {
            Write-Warning "Skipping .pfx certificate $certPath because no password was provided."
        }
    } else {
        & "$($AtlassianFolder)\jre\bin\keytool.exe" -import -file "$certPath" -destkeystore "$($AtlassianFolder)\jre\lib\security\cacerts" -deststorepass changeit -trustcacerts -alias "$certAlias" -noprompt
    }
}

# Backup the current cacerts file
$backupCacerts = Get-ChildItem -Path "$($AtlassianFolder)\backup" -Filter cacerts -Recurse | Select-Object -First 1

if ($backupCacerts) {
    & "$($AtlassianFolder)\jre\bin\keytool.exe" -importkeystore -srckeystore "$($backupCacerts.FullName)" -destkeystore "$($AtlassianFolder)\jre\lib\security\cacerts" -srcstorepass changeit -deststorepass changeit -v -noprompt
} else {
    Write-Warning "No backup cacerts file found in $($AtlassianFolder)\backup."
}

if ($plaintextCertificatePassword) {
    $plaintextCertificatePassword = $null
}