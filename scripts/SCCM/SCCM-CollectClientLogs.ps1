<#
.SYNOPSIS
    Collects Configuration Manager client logs from one or more devices.

.DESCRIPTION
    Copies common Configuration Manager client logs from local or remote devices
    into a time-stamped output folder. The script can optionally compress each
    device folder into a ZIP archive for easier sharing during troubleshooting.

.PARAMETER ComputerName
    One or more devices to collect logs from. Defaults to the local computer.

.PARAMETER LogName
    Specific log file names to collect. When omitted, a practical default set is
    used.

.PARAMETER OutputDirectory
    Directory used for collected log bundles.

.PARAMETER Compress
    Compresses each device folder into a ZIP archive after collection.

.PARAMETER PassThru
    Returns collection results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-CollectClientLogs.ps1 -ComputerName PC001,PC002 -Compress
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory = $false)]
    [string[]]$LogName = @(
        'AppEnforce.log'
        'AppDiscovery.log'
        'ExecMgr.log'
        'CAS.log'
        'ContentTransferManager.log'
        'UpdatesDeployment.log'
        'WUAHandler.log'
        'ClientIDManagerStartup.log'
        'PolicyAgent.log'
    ),

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$Compress,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

$timestamp = Get-SccmTimestampString
$baseOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Resolve-SccmOutputPath -OutputDirectory $null -CreateDirectory -FileName "ClientLogs-$timestamp"
}
else {
    if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
        Join-Path -Path $PSScriptRoot -ChildPath $OutputDirectory
    }
    else {
        $OutputDirectory
    }
}

if (-not (Test-Path -Path $baseOutputDirectory)) {
    $null = New-Item -Path $baseOutputDirectory -ItemType Directory -Force
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($targetComputer in @($ComputerName)) {
    $deviceFolder = Join-Path -Path $baseOutputDirectory -ChildPath $targetComputer
    if (-not (Test-Path -Path $deviceFolder)) {
        $null = New-Item -Path $deviceFolder -ItemType Directory -Force
    }

    $copiedCount = 0
    $missingLogs = New-Object System.Collections.Generic.List[string]

    foreach ($logFile in @($LogName)) {
        $sourceCandidates = @(
            "\\$targetComputer\admin$\CCM\Logs\$logFile"
            "\\$targetComputer\c$\Windows\CCM\Logs\$logFile"
        )

        $copied = $false
        foreach ($sourcePath in $sourceCandidates) {
            try {
                if (Test-Path -Path $sourcePath) {
                    Copy-Item -Path $sourcePath -Destination $deviceFolder -Force -ErrorAction Stop
                    $copiedCount++
                    $copied = $true
                    break
                }
            }
            catch {
                Write-SccmLog -Level 'DEBUG' -Message ("Copy failed from [{0}]: {1}" -f $sourcePath, $_.Exception.Message)
            }
        }

        if (-not $copied) {
            [void]$missingLogs.Add($logFile)
        }
    }

    $archivePath = $null
    if ($Compress -and (Get-ChildItem -Path $deviceFolder -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        $archivePath = Join-Path -Path $baseOutputDirectory -ChildPath ("{0}.zip" -f $targetComputer)
        if (Test-Path -Path $archivePath) {
            Remove-Item -Path $archivePath -Force -ErrorAction SilentlyContinue
        }
        Compress-Archive -Path (Join-Path -Path $deviceFolder -ChildPath '*') -DestinationPath $archivePath -Force
    }

    $result = [pscustomobject]@{
        ComputerName   = $targetComputer
        Destination    = $deviceFolder
        CopiedCount    = $copiedCount
        MissingCount   = @($missingLogs).Count
        MissingLogs    = ($missingLogs -join ' | ')
        ArchivePath    = $archivePath
    }

    [void]$results.Add($result)
    Write-SccmAuditLog -Action 'SCCM_CLIENT_LOG_COLLECTION' -Target $targetComputer -Result 'Success' -AdditionalData @{ CopiedCount = $copiedCount; MissingCount = @($missingLogs).Count }
}

if ($PassThru) {
    return @($results)
}
