<#
.SYNOPSIS
Seeds SQLSysClrTypes.msi into SCCM update staging locations.

.DESCRIPTION
Continuously copies a source SQLSysClrTypes MSI into common Configuration Manager
update staging paths for a detected or supplied update GUID until a stop file is
created. Includes a monitor loop and log output for troubleshooting.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Guid = "",

    [Parameter(Mandatory = $false)]
    [string]$Root = "D:\Program Files\Microsoft Configuration Manager",

    [Parameter(Mandatory = $false)]
    [string]$SourceMsi = "",

    [Parameter(Mandatory = $false)]
    [int]$CopyIntervalSeconds = 2,

    [Parameter(Mandatory = $false)]
    [int]$HeartbeatSeconds = 5,

    [Parameter(Mandatory = $false)]
    [switch]$DisableAutoDiscoverGuid
)

function Resolve-CmUpdateGuid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigMgrRoot
    )

    $guidRegex = '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
    $cmUpdateLog = Join-Path $ConfigMgrRoot "Logs\CMUpdate.log"

    if (Test-Path $cmUpdateLog) {
        $hits = Select-String -Path $cmUpdateLog -Pattern "update package content|ISTR0=|CMUStaging\\|EasySetupPayload\\" -CaseSensitive:$false -ErrorAction SilentlyContinue
        if ($hits) {
            $recentHits = $hits | Select-Object -Last 1000
            for ($i = $recentHits.Count - 1; $i -ge 0; $i--) {
                $line = $recentHits[$i].Line
                $m = [regex]::Match($line, $guidRegex)
                if ($m.Success) {
                    return [pscustomobject]@{
                        Guid = $m.Value.ToUpper()
                        Source = "CMUpdate.log"
                        Detail = $line
                    }
                }
            }
        }
    }

    $stagingPath = Join-Path $ConfigMgrRoot "CMUStaging"
    if (Test-Path $stagingPath) {
        $candidate = Get-ChildItem -Path $stagingPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^$guidRegex$" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($candidate) {
            return [pscustomobject]@{
                Guid = $candidate.Name.ToUpper()
                Source = "CMUStaging folder"
                Detail = $candidate.FullName
            }
        }
    }

    $payloadPath = Join-Path $ConfigMgrRoot "EasySetupPayload"
    if (Test-Path $payloadPath) {
        $candidate = Get-ChildItem -Path $payloadPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^$guidRegex$" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($candidate) {
            return [pscustomobject]@{
                Guid = $candidate.Name.ToUpper()
                Source = "EasySetupPayload folder"
                Detail = $candidate.FullName
            }
        }
    }

    return $null
}

$src = if ([string]::IsNullOrWhiteSpace($SourceMsi)) {
    Join-Path $Root "CD.Latest\Redist\SQLSysClrTypes.msi"
} else {
    $SourceMsi
}
$stop = "D:\Temp\stop_sqlclr_seed.txt"
$logPath = "D:\Temp\sccm-injection.log"
$jobName = "SeedSqlClr"

New-Item -ItemType Directory -Force -Path "D:\Temp" | Out-Null

if (-not (Test-Path $src)) {
    Write-Error "Source MSI not found: $src"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Guid) -and -not $DisableAutoDiscoverGuid) {
    $resolved = Resolve-CmUpdateGuid -ConfigMgrRoot $Root
    if ($resolved) {
        $Guid = $resolved.Guid
        Write-Information "Auto-discovered update GUID: $Guid" -InformationAction Continue
        Write-Information "GUID source: $($resolved.Source)" -InformationAction Continue
        Write-Information "GUID detail: $($resolved.Detail)" -InformationAction Continue
    } else {
        Write-Error "Unable to auto-discover update GUID. Pass -Guid explicitly or verify CMUpdate.log/CMUStaging paths."
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($Guid)) {
    Write-Error "GUID is empty. Pass -Guid explicitly or allow auto-discovery."
    exit 1
}

if (Test-Path $stop) {
    Remove-Item $stop -Force
}

$existingJobs = Get-Job -Name $jobName -ErrorAction SilentlyContinue
if ($existingJobs) {
    $existingJobs | Stop-Job -ErrorAction SilentlyContinue
    $existingJobs | Remove-Job -ErrorAction SilentlyContinue
}

"[$(Get-Date -Format s)] Starting SQL CLR seeding. Source: $src" | Out-File -FilePath $logPath -Encoding utf8 -Append
"[$(Get-Date -Format s)] Using update GUID: $Guid" | Add-Content -Path $logPath
"[$(Get-Date -Format s)] Copy interval seconds: $CopyIntervalSeconds" | Add-Content -Path $logPath

$job = Start-Job -Name $jobName -ScriptBlock {
    $cycle = 0
    while (-not (Test-Path $using:stop)) {
        $cycle++
        $targets = @(
            (Join-Path $using:Root "CD.Latest\SMSSETUP\BIN\X64\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "SMSSetup\Redist\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "SMSSetup\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "CMUStaging\$($using:Guid)\Redist\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "CMUStaging\$($using:Guid)\SMSSetup\Redist\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "CMUStaging\$($using:Guid)\SMSSetup\BIN\X64\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "CMUStaging\$($using:Guid)\SMSSetup\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "EasySetupPayload\$($using:Guid)\Redist\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "EasySetupPayload\$($using:Guid)\SMSSetup\Redist\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "EasySetupPayload\$($using:Guid)\SMSSetup\BIN\X64\SQLSysClrTypes.msi"),
            (Join-Path $using:Root "EasySetupPayload\$($using:Guid)\SMSSetup\SQLSysClrTypes.msi")
        )

        $copied = 0
        $failed = 0

        foreach ($t in $targets) {
            try {
                New-Item -ItemType Directory -Force -Path (Split-Path $t) | Out-Null
                Copy-Item -Path $using:src -Destination $t -Force -ErrorAction Stop
                $copied++
            } catch {
                $failed++
            }
        }

        $line = "[$(Get-Date -Format s)] cycle=$cycle copied=$copied failed=$failed"
        $line | Add-Content -Path $using:logPath
        Write-Output $line

        Start-Sleep -Seconds $using:CopyIntervalSeconds
    }

    $endLine = "[$(Get-Date -Format s)] stop file detected. Seeding job exiting."
    $endLine | Add-Content -Path $using:logPath
    Write-Output $endLine
}

Write-Information "Seeding job started: $($job.Name) (Id=$($job.Id))" -InformationAction Continue
Write-Information "Copy interval: $CopyIntervalSeconds seconds." -InformationAction Continue
Write-Information "Heartbeat every $HeartbeatSeconds seconds. Press Ctrl+C to stop monitoring (job keeps running)." -InformationAction Continue
Write-Information "Log file: $logPath" -InformationAction Continue
Write-Information "When done, create stop file: $stop" -InformationAction Continue

while ($true) {
    Start-Sleep -Seconds $HeartbeatSeconds
    $state = (Get-Job -Name $jobName -ErrorAction SilentlyContinue).State

    if (-not $state) {
        Write-Information "Job not found. Exiting monitor." -InformationAction Continue
        break
    }

    $latest = Receive-Job -Name $jobName -Keep -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($latest) {
        Write-Information $latest -InformationAction Continue
    }

    Write-Information "[$(Get-Date -Format HH:mm:ss)] heartbeat: job-state=$state" -InformationAction Continue

    if (Test-Path $stop) {
        Write-Information "Stop file detected. Exiting monitor." -InformationAction Continue
        break
    }

    if ($state -ne "Running") {
        Write-Information "Job state is $state. Exiting monitor." -InformationAction Continue
        break
    }
}