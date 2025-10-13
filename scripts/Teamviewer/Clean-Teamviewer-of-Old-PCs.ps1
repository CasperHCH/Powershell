##   In order to create a token, do the following:
##   1. When you are logged in click your Profile in the top right then click Edit Profile.
##
##   2. Click the Apps tab on the left and then create a new script token.
##
##   3. Change Group Management to
##
##   4. Change Computers & Contacts to
##
##   5. Click Save then copy your API Token into the script.

##   TeamViewer API Cleanup Script - Remove Old/Offline Devices
##   In order to create a token, do the following:
##   1. When you are logged in click your Profile in the top right then click Edit Profile.
##   2. Click the Apps tab on the left and then create a new script token.
##   3. Change Group Management to "Create, read, edit and delete your groups"
##   4. Change Computers & Contacts to "Create, read, edit and delete your computers & contacts"
##   5. Click Save then copy your API Token into the script.

param(
    [Parameter(Mandatory = $true)]
    [string]$Token,
    [int]$DaysOffline = 60,
    [switch]$WhatIf
)

$token = $Token #Change this token to the one provided through Teamviewer Management Console.
$bearer = "Bearer", $token

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("Authorization", $bearer -join " ")

try {
    Write-Host "Fetching devices from TeamViewer API..." -ForegroundColor Cyan
    $devices = (Invoke-RestMethod -Uri "https://webapi.teamviewer.com/api/v1/devices" -Method Get -Headers $header).devices
    Write-Host "Found $($devices.Count) devices" -ForegroundColor Green
}
catch {
    Write-Error "Failed to fetch devices: $($_.Exception.Message)"
    exit 1
}

$cutoffDate = (Get-Date).AddDays(-$DaysOffline)
$60Days = $cutoffDate.ToString("yyyy-MM-dd")

$devicesToRemove = @()
foreach ($device in $devices) {
    if ($device.online_state -eq "offline") {
        $ID = $device.device_id
        $Lastseen = $device.last_seen

        if ($Lastseen -ne $null) {
            $LastSeen = ($device.last_seen).Split()[0]
            [datetime]$DateLastSeen = $LastSeen

            if ($DateLastSeen -le $cutoffDate) {
                $devicesToRemove += $device
                Write-Host "Device marked for removal: $($device.alias) (ID: $ID, Last seen: $LastSeen)" -ForegroundColor Yellow

                try {
                    $deleteUri = "https://webapi.teamviewer.com/api/v1/devices/$ID"
                    $response = Invoke-WebRequest -Uri $deleteUri -Method Delete -Headers $header -ErrorAction Stop
                    Write-Host "✅ Successfully removed: $($device.alias)" -ForegroundColor Green
                }
                catch {
                    Write-Host "❌ Failed to remove $($device.alias): $($_.Exception.Message)" -ForegroundColor Red
                }

                $LastSeen = $null
            }
        }
    }