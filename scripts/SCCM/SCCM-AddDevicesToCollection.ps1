<#
.SYNOPSIS
    Template for adding devices to an SCCM collection.
.DESCRIPTION
    Blank script template with an empty parameter block.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [string]$DeviceNames,

    [Parameter(Mandatory = $false)]
    [string]$SiteCode
)

# Add your code below
if (-not $SiteCode) {
    Write-Error "SiteCode is required to connect to SCCM."
    return
}

$ConfigMgrPath = if ($env:SMS_ADMIN_UI_PATH) {
    Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1'
} else {
    'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1'
}

if (-not (Test-Path $ConfigMgrPath)) {
    Write-Error "Configuration Manager module not found. Ensure the SCCM console is installed."
    return
}

Import-Module $ConfigMgrPath -Force

try {
    Set-Location "$SiteCode`:"
} catch {
    Write-Error "Failed to connect to SCCM site code $SiteCode. $_"
    return
}

if ($DeviceNames -is [string]) {
    $DeviceNames = $DeviceNames -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

foreach ($Name in $DeviceNames) {
    $Device = Get-CMDevice -Name $Name
    if ($Device) {
        Add-CMDeviceCollectionDirectMembershipRule -CollectionName "$($CollectionName)" -ResourceID $Device.ResourceID
        Write-Host "Added $Name" -ForegroundColor Green
    } else {
        Write-Host "Warning: $Name not found in SCCM!" -ForegroundColor Yellow
    }
}
