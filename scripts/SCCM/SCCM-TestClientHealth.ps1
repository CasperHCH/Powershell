<#
.SYNOPSIS
    Tests Configuration Manager client health on one or more devices.

.DESCRIPTION
    Performs a non-destructive health assessment of the Configuration Manager
    client by checking service state, WMI accessibility, core client properties,
    recent client activity, inventory timestamps, and common reboot indicators.

    The script is safe to rerun and produces CSV and optional JSON output next
    to the script by default.

.PARAMETER ComputerName
    One or more device names to assess. Defaults to the local computer.

.PARAMETER MaxLogAgeHours
    Maximum age in hours before recent client activity is considered stale.

.PARAMETER OutputDirectory
    Directory used for report output. Defaults to an output folder next to the
    script.

.PARAMETER ExportJson
    Exports a JSON copy of the results in addition to CSV.

.PARAMETER PassThru
    Returns health results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-TestClientHealth.ps1

.EXAMPLE
    .\SCCM-TestClientHealth.ps1 -ComputerName PC001,PC002 -ExportJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 720)]
    [int]$MaxLogAgeHours = 72,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog
$script:MaxClientLogAgeHours = $MaxLogAgeHours

function Get-PendingRebootState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    try {
        $baseKey = if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq '.' -or $ComputerName -eq 'localhost') {
            [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
        }
        else {
            [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ComputerName)
        }

        $checks = @(
            'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        )

        foreach ($checkPath in $checks) {
            $subKey = $baseKey.OpenSubKey($checkPath)
            if ($null -ne $subKey) {
                return $true
            }
        }

        $sessionManagerKey = $baseKey.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager')
        if ($null -ne $sessionManagerKey) {
            $pendingRenameOperations = $sessionManagerKey.GetValue('PendingFileRenameOperations', $null)
            if ($null -ne $pendingRenameOperations) {
                return $true
            }
        }
    }
    catch {
        Write-SccmLog -Level 'DEBUG' -Message ("Pending reboot check failed for [{0}]: {1}" -f $ComputerName, $_.Exception.Message)
    }

    return $false
}

function Get-RemoteLogTimestamp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [string]$LogName
    )

    $candidatePaths = @(
        "\\$ComputerName\admin$\CCM\Logs\$LogName"
        "\\$ComputerName\c$\Windows\CCM\Logs\$LogName"
    )

    foreach ($candidatePath in $candidatePaths) {
        try {
            if (Test-Path -Path $candidatePath) {
                return (Get-Item -Path $candidatePath -ErrorAction Stop).LastWriteTime
            }
        }
        catch {
            Write-SccmLog -Level 'DEBUG' -Message ("Could not read log path [{0}]: {1}" -f $candidatePath, $_.Exception.Message)
        }
    }

    return $null
}

function Get-InventoryStatusMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $statusMap = @{}

    try {
        $inventoryItems = @(Get-CimInstance -ComputerName $ComputerName -Namespace 'root/ccm/InvAgt' -ClassName 'InventoryActionStatus' -ErrorAction Stop)
        foreach ($inventoryItem in $inventoryItems) {
            $inventoryActionId = [string](Get-SccmObjectPropertyValue -InputObject $inventoryItem -PropertyNames @('InventoryActionID', 'ActionID'))
            if ([string]::IsNullOrWhiteSpace($inventoryActionId)) {
                continue
            }

            $statusMap[$inventoryActionId] = [pscustomobject]@{
                LastCycleStarted   = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $inventoryItem -PropertyNames @('LastCycleStartedDate') -AsDateTime)
                LastCycleCompleted = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $inventoryItem -PropertyNames @('LastCycleCompletedDate') -AsDateTime)
                LastMajorReport    = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $inventoryItem -PropertyNames @('LastMajorReportVersion') -AsDateTime)
            }
        }
    }
    catch {
        Write-SccmLog -Level 'DEBUG' -Message ("Inventory status query failed for [{0}]: {1}" -f $ComputerName, $_.Exception.Message)
    }

    return $statusMap
}

function Get-ClientHealthResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $serviceStatus = 'Unknown'
    $wmiAvailable = $false
    $assignedSiteCode = $null
    $managementPoint = $null
    $clientVersion = $null
    $hardwareInventoryDate = $null
    $softwareInventoryDate = $null
    $policyLogDate = $null
    $scanLogDate = $null
    $pendingReboot = $false
    $overallHealth = 'Healthy'
    $issues = New-Object System.Collections.Generic.List[string]

    try {
        $service = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Service -Filter "Name='CcmExec'" -ErrorAction Stop
        $serviceStatus = [string](Get-SccmObjectPropertyValue -InputObject $service -PropertyNames @('State', 'Status'))
        if ($serviceStatus -ne 'Running') {
            [void]$issues.Add('CcmExec service is not running.')
        }
    }
    catch {
        $serviceStatus = 'Missing'
        [void]$issues.Add('CcmExec service was not found or could not be queried.')
    }

    try {
        $client = Get-CimInstance -ComputerName $ComputerName -Namespace 'root/ccm' -ClassName 'SMS_Client' -ErrorAction Stop
        $wmiAvailable = $true
        $assignedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $client -PropertyNames @('AssignedSiteCode', 'SiteCode'))
        $managementPoint = [string](Get-SccmObjectPropertyValue -InputObject $client -PropertyNames @('CurrentManagementPoint', 'ManagementPoint'))
        $clientVersion = [string](Get-SccmObjectPropertyValue -InputObject $client -PropertyNames @('ClientVersion', 'Version'))
    }
    catch {
        [void]$issues.Add('root/ccm SMS_Client query failed.')
    }

    $inventoryStatusMap = Get-InventoryStatusMap -ComputerName $ComputerName
    if ($inventoryStatusMap.ContainsKey('{00000000-0000-0000-0000-000000000001}')) {
        $hardwareInventoryDate = $inventoryStatusMap['{00000000-0000-0000-0000-000000000001}'].LastCycleCompleted
    }
    if ($inventoryStatusMap.ContainsKey('{00000000-0000-0000-0000-000000000002}')) {
        $softwareInventoryDate = $inventoryStatusMap['{00000000-0000-0000-0000-000000000002}'].LastCycleCompleted
    }

    $policyLogDate = Get-RemoteLogTimestamp -ComputerName $ComputerName -LogName 'PolicyAgent.log'
    $scanLogDate = Get-RemoteLogTimestamp -ComputerName $ComputerName -LogName 'ScanAgent.log'
    $pendingReboot = Get-PendingRebootState -ComputerName $ComputerName

    if ($wmiAvailable -and [string]::IsNullOrWhiteSpace($assignedSiteCode)) {
        [void]$issues.Add('Assigned site code is missing.')
    }

    if ($wmiAvailable -and [string]::IsNullOrWhiteSpace($managementPoint)) {
        [void]$issues.Add('Current management point is missing.')
    }

    if ($null -eq $hardwareInventoryDate) {
        [void]$issues.Add('Hardware inventory timestamp was not found.')
    }
    elseif ($hardwareInventoryDate -lt (Get-Date).AddDays(-14)) {
        [void]$issues.Add('Hardware inventory appears stale.')
    }

    if ($null -eq $policyLogDate) {
        [void]$issues.Add('PolicyAgent.log timestamp could not be determined.')
    }
    elseif ($policyLogDate -lt (Get-Date).AddHours(-1 * $script:MaxClientLogAgeHours)) {
        [void]$issues.Add('Policy activity appears stale.')
    }

    if ($null -ne $scanLogDate -and $scanLogDate -lt (Get-Date).AddDays(-14)) {
        [void]$issues.Add('Software update scan activity appears stale.')
    }

    if ($pendingReboot) {
        [void]$issues.Add('Pending reboot detected.')
    }

    if (@($issues).Count -gt 0) {
        $overallHealth = 'Degraded'
    }

    if (-not $wmiAvailable -or $serviceStatus -eq 'Missing' -or $serviceStatus -eq 'Stopped') {
        $overallHealth = 'Unhealthy'
    }

    return [pscustomobject]@{
        ComputerName           = $ComputerName
        OverallHealth          = $overallHealth
        CcmExecServiceStatus   = $serviceStatus
        WmiAvailable           = $wmiAvailable
        ClientVersion          = $clientVersion
        AssignedSiteCode       = $assignedSiteCode
        ManagementPoint        = $managementPoint
        HardwareInventoryDate  = $hardwareInventoryDate
        SoftwareInventoryDate  = $softwareInventoryDate
        PolicyLogLastWriteTime = $policyLogDate
        ScanLogLastWriteTime   = $scanLogDate
        PendingReboot          = $pendingReboot
        IssueCount             = @($issues).Count
        Issues                 = ($issues -join ' | ')
    }
}

Write-SccmLog -Level 'INFO' -Message ("Starting client health assessment for {0} device(s)." -f @($ComputerName).Count)

$results = foreach ($targetComputer in @($ComputerName)) {
    Write-SccmLog -Level 'INFO' -Message ("Assessing client health on [{0}]." -f $targetComputer)
    $result = Get-ClientHealthResult -ComputerName $targetComputer
    Write-SccmAuditLog -Action 'SCCM_CLIENT_HEALTH_TEST' -Target $targetComputer -Result $result.OverallHealth -AdditionalData @{ IssueCount = $result.IssueCount }
    $result
}

$timestamp = Get-SccmTimestampString
$csvPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ClientHealth-{0}.csv" -f $timestamp)
$null = Export-SccmData -InputObject $results -Path $csvPath -Format 'Csv'
Write-SccmLog -Level 'SUCCESS' -Message ("Client health report exported to [{0}]." -f $csvPath)

if ($ExportJson) {
    $jsonPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ClientHealth-{0}.json" -f $timestamp)
    $null = Export-SccmData -InputObject $results -Path $jsonPath -Format 'Json'
    Write-SccmLog -Level 'SUCCESS' -Message ("Client health JSON exported to [{0}]." -f $jsonPath)
}

if ($PassThru) {
    return $results
}
