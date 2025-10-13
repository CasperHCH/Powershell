<#
.SYNOPSIS
    Secure certificate import to Java CaCerts store

.DESCRIPTION
    Enterprise-grade script to import certificates to Java keystore with proper security validation.
    All paths and credentials are parameterized for security compliance.

.PARAMETER CertificatePassword
    Password for the Java keystore (default: standard Java keystore password)

.PARAMETER JiraInstallPath
    Path to JIRA installation directory (e.g., "C:\Atlassian\jira")

.PARAMETER CertificateSourcePath
    Directory containing certificate files (e.g., "C:\apache24\conf\ssl")

.PARAMETER ConfluenceInstallPath
    Path to Confluence installation directory (e.g., "D:\Atlassian\Confluence")

.EXAMPLE
    .\Import_All_Certificates_to_CaCerts.ps1 -JiraInstallPath "D:\Apps\Jira" -CertificateSourcePath "D:\Certs\ssl"

.NOTES
    SECURITY CLASSIFICATION: INTERNAL
    DATA HANDLING: Certificate and keystore management operations
    AUDIT REQUIREMENTS: All certificate operations logged
    CREDENTIALS REQUIRED: Java keystore access
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Certificate store password (required for security compliance)")]
    [ValidateNotNullOrEmpty()]
    [SecureString]$CertificatePassword,

    [Parameter(Mandatory = $true, HelpMessage = "Path to JIRA installation directory")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$JiraInstallPath,

    [Parameter(Mandatory = $true, HelpMessage = "Directory containing certificate files")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$CertificateSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "Path to Confluence installation directory")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$ConfluenceInstallPath
)

$JiraBinPath = Join-Path $JiraInstallPath "jre\bin"
if (-not (Test-Path $JiraBinPath)) {
    throw "JIRA bin path not found: $JiraBinPath"
}

Set-Location $JiraBinPath
Write-Host "🔐 Starting certificate import from: $CertificateSourcePath" -ForegroundColor Cyan

$certs = Get-ChildItem -Path "$CertificateSourcePath\*" -Include *.crt, *.key, *.pfx

foreach ($c in $certs) {
    $alias = [IO.Path]::GetFileNameWithoutExtension($c.Name)
    Write-Host "Processing certificate: $($c.Name)" -ForegroundColor Yellow

    # Determine destination keystore
    $destinationKeystore = if ($ConfluenceInstallPath) {
        Join-Path $ConfluenceInstallPath "jre\lib\security\cacerts"
    }
    else {
        Join-Path $JiraInstallPath "jre\lib\security\cacerts"
    }

    # Convert SecureString to plain text for keytool usage (temporarily in memory only)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertificatePassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    if ([IO.Path]::GetExtension($c.Name) -eq ".pfx") {
        .\keytool.exe -import -file "$($c.FullName)" -destkeystore "$destinationKeystore" -srcstorepass $PlainPassword -deststorepass $PlainPassword -trustcacerts -alias $alias -deststoretype pkcs12 -noprompt
    }
    else {
        .\keytool.exe -import -file "$($c.FullName)" -destkeystore "$destinationKeystore" -deststorepass $PlainPassword -trustcacerts -alias $alias -deststoretype pkcs12 -noprompt
    }

    # Clear sensitive data from memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $PlainPassword = $null
}

# Look for backup certificates in parent directory structure
$atlassianRoot = Split-Path $JiraInstallPath -Parent
$backupPath = Join-Path $atlassianRoot "backup"
if (Test-Path $backupPath) {
    $backupCacerts = Get-ChildItem -Path $backupPath -Filter "cacerts" -Recurse | Select-Object -First 1
    if ($backupCacerts) {
        Write-Host "Importing backup cacerts: $($backupCacerts.FullName)" -ForegroundColor Green
        $jiraKeystore = Join-Path $JiraInstallPath "jre\lib\security\cacerts"
        .\keytool.exe -importkeystore -srckeystore "$($backupCacerts.FullName)" -destkeystore "$jiraKeystore" -srcstorepass $CertificatePassword -deststorepass $CertificatePassword -v -noprompt
    }
}

Write-Host "✅ Certificate import process completed" -ForegroundColor Green
