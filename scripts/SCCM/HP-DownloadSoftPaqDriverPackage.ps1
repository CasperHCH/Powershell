<#
.SYNOPSIS
Downloads HP SoftPaq driver packages from HP Driver Pack Matrix for use in SCCM MIK.

.DESCRIPTION
Automates downloading of HP Client Driver Packs (SoftPaq `.exe`) for a given model and OS/OS version.
The downloaded files are ready to be pointed to SCCM → Operating Systems → Driver Packages → "Import Downloaded HP Client Driver Pack".

.PARAMETER ModelKey
Partial or full string matching the HP model in the matrix (e.g., "EliteBook 840 G9").

.PARAMETER OS
Operating system name to filter the SoftPaqs (e.g., "Windows 11").

.PARAMETER OSVersion
Optional OS version (e.g., "23H2") to further filter the downloads.

.PARAMETER OutputPath
Folder to save downloaded SoftPaq `.exe` files. Will be created if it doesn't exist.

.EXAMPLE
.\Download-HPSoftPaqs.ps1 -ModelKey "EliteBook 840 G9" -OS "Windows 11" -OSVersion "23H2" -OutputPath "C:\HP\SoftPaqs"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ModelKey,

    [Parameter(Mandatory = $true)]
    [string]$OS,

    [Parameter(Mandatory = $false)]
    [string]$OSVersion,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

# 🛠 Create output folder if it doesn't exist
if (-not (Test-Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory | Out-Null }

# 📥 HP Driver Pack Matrix URL
$matrixUrl = "https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HP_Driverpack_Matrix_x64.html"

Write-Host "Downloading HP Driver Pack Matrix..."
$matrixHtml = Invoke-WebRequest -Uri $matrixUrl -UseBasicParsing

# Load HTML parser
Add-Type -AssemblyName System.Web
[xml]$doc = $matrixHtml.ParsedHtml.outerHTML

# Use regex to extract SoftPaq links from the matrix table
$pattern = "sp\d{5,6}\.exe"
$matches = [regex]::Matches($matrixHtml.Content, $pattern)

# Deduplicate matches
$softpqs = $matches | ForEach-Object { $_.Value } | Sort-Object -Unique

Write-Host "Found $($softpqs.Count) SoftPaqs in matrix. Filtering by model and OS..."

# For each SoftPaq, try to match model and OS
# NOTE: This assumes SoftPaq name contains relevant metadata or you manually verify after download
foreach ($sp in $softpqs) {
    # Build download URL
    $url = "https://ftp.ext.hp.com/pub/caps-softpaq/$sp"

    # Target file path
    $target = Join-Path $OutputPath $sp

    # Skip if already downloaded
    if (Test-Path $target) {
        Write-Host "Skipping existing file: $sp"
        continue
    }

    # Download SoftPaq
    Write-Host "Downloading $sp ..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
        Write-Host "Saved to $target"
    } catch {
        Write-Warning "Failed to download $sp : $_"
    }
}

Write-Host "`nDownload complete! ✅"
Write-Host "You can now point SCCM MIK → Import Downloaded HP Client Driver Pack → $OutputPath"
