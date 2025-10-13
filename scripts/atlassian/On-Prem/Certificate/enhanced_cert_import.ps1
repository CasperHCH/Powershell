
param(
    [string]$CertFolder = "C:\apache24\conf\ssl",
    [string]$KeytoolPath = "C:\Atlassian\jira\jre\bin\keytool.exe",
    [string]$CacertsPath = "D:\Atlassian\Confluence\jre\lib\security\cacerts",
    [Parameter(Mandatory = $true)]
    [SecureString]$StorePass,
    [switch]$ConvertPfxToCerAndKey
)

# Convert SecureString to plain text for keytool (kept in memory briefly)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($StorePass)
$StorePassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$LogFile = Join-Path $CertFolder "cert_import_log.txt"
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $Message"
    Write-AuditLog -Message "Certificate Import: $Message" -Severity "Info"
}

function Ensure-OpenSSL {
    if (-not (Get-Command openssl.exe -ErrorAction SilentlyContinue)) {
        Log "OpenSSL not found."
        if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
            Write-Warning "Chocolatey is not installed. Please install OpenSSL manually from https://slproweb.com/products/Win32OpenSSL.html"
            Read-Host "Press Enter once OpenSSL is installed and available in PATH"
        }
        else {
            Log "Installing OpenSSL via Chocolatey..."
            choco install openssl.light -y
            $env:Path += ";C:\Program Files\OpenSSL-Win64\bin"
            Log "OpenSSL installed via Chocolatey."
        }
    }
    else {
        Log "OpenSSL is available."
    }
}

# Prompt for missing paths
if (-not (Test-Path $CertFolder)) {
    do {
        $CertFolder = Read-Host "Enter the path to the certificate folder"
    } until (Test-Path $CertFolder)
}
if (-not (Test-Path $KeytoolPath)) {
    do {
        $KeytoolPath = Read-Host "Enter the full path to keytool.exe"
    } until (Test-Path $KeytoolPath)
}
if (-not (Test-Path $CacertsPath)) {
    do {
        $CacertsPath = Read-Host "Enter the full path to the cacerts keystore"
    } until (Test-Path $CacertsPath)
}

Ensure-OpenSSL

$certs = Get-ChildItem -Path $CertFolder -Include *.crt, *.pfx -File

foreach ($c in $certs) {
    $alias = [IO.Path]::GetFileNameWithoutExtension($c.Name)
    $ext = [IO.Path]::GetExtension($c.Name).ToLowerInvariant()

    if ($ext -eq ".pfx") {
        $pfxPass = Read-Host -AsSecureString "Enter password for $($c.Name)"
        $pfxPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPass)
        )

        Log "Importing PFX: $($c.FullName)"
        & $KeytoolPath -importkeystore `
            -srckeystore $c.FullName `
            -srcstoretype PKCS12 `
            -srcstorepass $pfxPassPlain `
            -destkeystore $CacertsPath `
            -deststorepass $StorePassPlain `
            -alias $alias `
            -noprompt
        Log "Imported PFX: $($c.Name)"

        if ($ConvertPfxToCerAndKey) {
            $cerPath = Join-Path $CertFolder "$alias.cer"
            $keyPath = Join-Path $CertFolder "$alias.key"
            Log "Converting $($c.Name) to .cer and .key"
            & openssl pkcs12 -in $c.FullName -clcerts -nokeys -out $cerPath -passin pass:$pfxPassPlain
            & openssl pkcs12 -in $c.FullName -nocerts -nodes -out $keyPath -passin pass:$pfxPassPlain
            Log "Converted to: $cerPath and $keyPath"
        }

    }
    elseif ($ext -eq ".crt") {
        Log "Importing CRT: $($c.FullName)"
        & $KeytoolPath -import `
            -file $c.FullName `
            -alias $alias `
            -keystore $CacertsPath `
            -storepass $StorePassPlain `
            -trustcacerts `
            -noprompt
        Log "Imported CRT: $($c.Name)"
    }
}

# Clear sensitive variables from memory
$StorePassPlain = $null
[System.GC]::Collect()

Write-Host "Certificate import completed."
Write-AuditLog -Message "Certificate import process completed successfully" -Severity "Info"
Log "Certificate import completed."
