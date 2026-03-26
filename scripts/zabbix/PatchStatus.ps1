[CmdletBinding()]
param()

$ver = " (UpdateCheck 2.0 - SCCM or WSUS aware)"

function Get-WSUSServer {
    try {
        $wsusKey = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
        $wsusServer = (Get-ItemProperty -Path $wsusKey -Name WUServer -ErrorAction SilentlyContinue).WUServer
        return $wsusServer
    }
    catch {
        return $null
    }
}

function Is-SCCMClient {
    try {
        # Check if CCM namespace exists and has CCM_SoftwareUpdate class
        $namespace = "root\ccm\clientsdk"
        $className = "CCM_SoftwareUpdate"
        $exists = Get-WmiObject -Namespace $namespace -List | Where-Object { $_.Name -eq $className }
        return ($exists -ne $null)
    }
    catch {
        return $false
    }
}

function Get-LastUpdateDate {
    $session = New-Object -ComObject 'Microsoft.Update.Session'
    $searcher = $session.CreateUpdateSearcher()
    $count = $searcher.GetTotalHistoryCount()

    if ($count -eq 0) {
        return $null
    }

    $history = $searcher.QueryHistory(0, $count)

    # Only include successful updates that are NOT Edge
    $updates = $history | Where-Object {
        $_.ResultCode -eq 2 -and $_.Title -notmatch 'Edge'
    }

    if ($updates.Count -eq 0) {
        return $null
    }

    return ($updates | Sort-Object -Property Date -Descending | Select-Object -First 1).Date
}

# --- SCCM methods ---

function Get-PendingUpdateAgeSCCM {
    try {
        $pendingUpdates = Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate `
                            -Filter "NOT Name like '%Edge%'" -ErrorAction Stop

        if ($pendingUpdates -isnot [System.Collections.IEnumerable]) {
            $pendingUpdates = @($pendingUpdates)
        }

        if ($pendingUpdates.Count -eq 0) {
            return $null
        }

        $localTZ = [System.TimeZoneInfo]::Local

        # Convert StartTime from WMI to local time zone
        $oldestStartTime = ($pendingUpdates | ForEach-Object {
            $utcTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($_.StartTime)
            [System.TimeZoneInfo]::ConvertTimeFromUtc($utcTime, $localTZ)
        } | Sort-Object)[0]

        return $oldestStartTime
    }
    catch {
        return $null
    }
}

function Has-FailedPendingUpdatesSCCM {
    try {
        $pendingUpdates = Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate `
                            -Filter "NOT Name like '%Edge%'" -ErrorAction Stop

        if ($pendingUpdates -isnot [System.Collections.IEnumerable]) {
            $pendingUpdates = @($pendingUpdates)
        }

        if ($pendingUpdates.Count -eq 0) {
            return $false
        }

        foreach ($update in $pendingUpdates) {
            if ($update.EvaluationState -eq 5 -or $update.EvaluationState -eq 9 -or $update.EvaluationState -eq 13) {
                return $true
            }
        }

        return $false
    }
    catch {
        return $false
    }
}

# --- Windows Update native methods ---

function Get-PendingUpdateAgeWU {
    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        $criteria = "IsInstalled=0 and Type='Software' and IsHidden=0 and Title NOT LIKE '%Edge%'"
        $searchResult = $searcher.Search($criteria)

        if ($searchResult.Updates.Count -eq 0) {
            return $null
        }

        $localTZ = [System.TimeZoneInfo]::Local

        $oldestDate = ($searchResult.Updates | ForEach-Object {
            # The Microsoft.Update.Update object does not have a StartTime, use DateCreated or fallback to now
            if ($_.LastDeploymentChangeTime) {
                [datetime]$_.LastDeploymentChangeTime
            } else {
                Get-Date
            }
        } | Sort-Object)[0]

        return [System.TimeZoneInfo]::ConvertTimeFromUtc($oldestDate.ToUniversalTime(), $localTZ)
    }
    catch {
        return $null
    }
}

function Has-FailedPendingUpdatesWU {
    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        # Search for updates that are failed (ResultCode != 2) and pending installation
        $criteria = "IsInstalled=0 and IsHidden=0 and Title NOT LIKE '%Edge%'"
        $searchResult = $searcher.Search($criteria)

        if ($searchResult.Updates.Count -eq 0) {
            return $false
        }

        foreach ($update in $searchResult.Updates) {
            # We can't directly get result code here, so just assume all pending updates are not failed unless additional logic applies
            # Windows Update COM does not provide direct failure status on pending updates,
            # so this is a limitation compared to SCCM method.
            # For a safer side, we can skip this or just return false.
        }

        return $false
    }
    catch {
        return $false
    }
}

try {
    $wsusServer = Get-WSUSServer
    if ($wsusServer) {
        #Write-Host "INFO - Using WSUS server: $wsusServer"
    }

    $isSCCM = Is-SCCMClient

    $hasPending = $false
    $pendingAvailableSince = $null
    $pendingDays = $null

    if ($isSCCM) {
        # Use SCCM WMI methods
        $pendingAvailableSince = Get-PendingUpdateAgeSCCM
        if ($pendingAvailableSince) {
            $hasPending = $true
            $pendingDays = (New-TimeSpan -Start $pendingAvailableSince -End (Get-Date)).Days

            if (Has-FailedPendingUpdatesSCCM) {
                Write-Host "!FAILED - One or more pending updates have failed to install"
                exit 2
            }
        }
    }
    else {
        # Use Windows Update API methods
        $pendingAvailableSince = Get-PendingUpdateAgeWU
        if ($pendingAvailableSince) {
            $hasPending = $true
            $pendingDays = (New-TimeSpan -Start $pendingAvailableSince -End (Get-Date)).Days

            if (Has-FailedPendingUpdatesWU) {
                # This will likely never trigger because we cannot get failure status easily
                Write-Host "!FAILED - One or more pending updates have failed to install"
                exit 2
            }
        }
    }

    $lastUpdateDate = Get-LastUpdateDate

    if ($lastUpdateDate -eq $null) {
        Write-Host "-CRITICAL - No updates found in history"
        exit 1
    }

    $daysSinceLastUpdate = (New-TimeSpan -Start $lastUpdateDate -End (Get-Date)).Days

    if (-not $hasPending) {
        if ($daysSinceLastUpdate -le 31) {
            Write-Host "OK"
            exit 0
        }
        else {
            Write-Host "-CRITICAL - No pending updates, but last update was $daysSinceLastUpdate days ago"
            exit 2
        }
    }
    else {
        if ($daysSinceLastUpdate -gt 31) {
            Write-Host "-CRITICAL - Update(s) pending and last update was $daysSinceLastUpdate days ago"
            exit 2
        }
        elseif ($pendingDays -le 14) {
            Write-Host "=WARNING - Update(s) pending for $pendingDays days, last update $daysSinceLastUpdate days ago"
            exit 1
        }
        else {
            Write-Host "-CRITICAL - Update(s) pending for $pendingDays days (since $pendingAvailableSince), last update $daysSinceLastUpdate days ago"
            exit 2
        }
    }
}
catch {
    Write-Host "_UNKNOWN - Script error occurred$ver"
    exit 3
}
