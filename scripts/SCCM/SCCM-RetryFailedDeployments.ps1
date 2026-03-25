<#
.SYNOPSIS
    Retries common client-side actions for failed deployments.

.DESCRIPTION
    Reads device names from a deployment failure report or accepts one or more
    device names directly, then triggers standard Configuration Manager client
    evaluation schedules against those devices. This provides a safe first-line
    remediation path without modifying deployments in the site.

.PARAMETER InputCsvPath
    Path to a CSV file containing a DeviceName column, such as the detail report
    produced by SCCM-DeploymentFailureReport.ps1.

.PARAMETER ComputerName
    One or more device names to remediate directly.

.PARAMETER TriggerPolicy
    Triggers machine policy retrieval and evaluation.

.PARAMETER TriggerApplicationEvaluation
    Triggers application deployment evaluation.

.PARAMETER TriggerUpdateScan
    Triggers software update scan.

.PARAMETER TriggerUpdateDeploymentEvaluation
    Triggers software update deployment evaluation.

.PARAMETER TriggerStateMessageRefresh
    Triggers state message refresh.

.PARAMETER DelaySeconds
    Delay between schedule triggers.

.PARAMETER PassThru
    Returns remediation results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-RetryFailedDeployments.ps1 -InputCsvPath .\output\SCCM-DeploymentFailureDetails.csv

.EXAMPLE
    .\SCCM-RetryFailedDeployments.ps1 -ComputerName PC001,PC002 -TriggerPolicy -TriggerApplicationEvaluation
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$InputCsvPath,

    [Parameter(Mandatory = $false)]
    [string[]]$ComputerName,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerPolicy,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerApplicationEvaluation,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerUpdateScan,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerUpdateDeploymentEvaluation,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerStateMessageRefresh,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 60)]
    [int]$DelaySeconds = 1,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

if (-not $TriggerPolicy -and -not $TriggerApplicationEvaluation -and -not $TriggerUpdateScan -and -not $TriggerUpdateDeploymentEvaluation -and -not $TriggerStateMessageRefresh) {
    $TriggerPolicy = $true
    $TriggerApplicationEvaluation = $true
    $TriggerUpdateScan = $true
    $TriggerUpdateDeploymentEvaluation = $true
    $TriggerStateMessageRefresh = $true
}

$targetComputers = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

foreach ($target in ConvertTo-SccmArray -InputObject $ComputerName) {
    if (-not [string]::IsNullOrWhiteSpace($target)) {
        [void]$targetComputers.Add($target.Trim())
    }
}

if (-not [string]::IsNullOrWhiteSpace($InputCsvPath)) {
    foreach ($row in Import-Csv -Path $InputCsvPath) {
        $deviceName = [string](Get-SccmObjectPropertyValue -InputObject $row -PropertyNames @('DeviceName', 'ComputerName', 'MachineName'))
        if (-not [string]::IsNullOrWhiteSpace($deviceName)) {
            [void]$targetComputers.Add($deviceName.Trim())
        }
    }
}

if ($targetComputers.Count -eq 0) {
    throw 'No target computers were resolved. Provide -ComputerName and/or -InputCsvPath with a DeviceName column.'
}

$schedules = New-Object System.Collections.Generic.List[object]
if ($TriggerPolicy) {
    [void]$schedules.Add([pscustomobject]@{ Name = 'Machine Policy Retrieval and Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000021}' })
    [void]$schedules.Add([pscustomobject]@{ Name = 'Machine Policy Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000022}' })
}
if ($TriggerApplicationEvaluation) {
    [void]$schedules.Add([pscustomobject]@{ Name = 'Application Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000121}' })
}
if ($TriggerUpdateScan) {
    [void]$schedules.Add([pscustomobject]@{ Name = 'Software Updates Scan Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000113}' })
}
if ($TriggerUpdateDeploymentEvaluation) {
    [void]$schedules.Add([pscustomobject]@{ Name = 'Software Updates Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000114}' })
}
if ($TriggerStateMessageRefresh) {
    [void]$schedules.Add([pscustomobject]@{ Name = 'State Message Refresh'; ScheduleId = '{00000000-0000-0000-0000-000000000111}' })
}

Write-SccmLog -Level 'INFO' -Message ("Retrying failed deployments on {0} device(s)." -f $targetComputers.Count)

$results = New-Object System.Collections.Generic.List[object]

foreach ($targetComputer in $targetComputers) {
    $status = 'Success'
    $errorMessage = $null
    $steps = New-Object System.Collections.Generic.List[string]

    foreach ($schedule in $schedules) {
        try {
            if ($PSCmdlet.ShouldProcess($targetComputer, ("Trigger {0}" -f $schedule.Name))) {
                $null = Invoke-CimMethod -ComputerName $targetComputer -Namespace 'root/ccm' -ClassName 'SMS_Client' -MethodName 'TriggerSchedule' -Arguments @{ sScheduleID = $schedule.ScheduleId } -ErrorAction Stop
                [void]$steps.Add(("Triggered {0}" -f $schedule.Name))
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-SccmLog -Level 'ERROR' -Message ("Retry action failed for [{0}] during [{1}]: {2}" -f $targetComputer, $schedule.Name, $errorMessage)
            break
        }

        if ($DelaySeconds -gt 0 -and $schedule -ne $schedules[-1]) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    $result = [pscustomobject]@{
        ComputerName = $targetComputer
        Status       = $status
        StepCount    = @($steps).Count
        Steps        = ($steps -join ' | ')
        Error        = $errorMessage
        Timestamp    = Get-Date
    }

    [void]$results.Add($result)
    Write-SccmAuditLog -Action 'SCCM_DEPLOYMENT_RETRY' -Target $targetComputer -Result $status -ErrorMessage $errorMessage -AdditionalData @{ Steps = @($steps) }
}

if ($PassThru) {
    return $results
}
