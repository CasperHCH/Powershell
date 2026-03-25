<#
.SYNOPSIS
    Performs common Configuration Manager client remediation actions.

.DESCRIPTION
    Safely applies common corrective actions for Configuration Manager client
    health issues such as restarting the client service, resetting policy, and
    triggering standard evaluation schedules. Optional repair execution can also
    launch ccmrepair.exe.

    The script supports WhatIf and writes an audit log next to the script.

.PARAMETER ComputerName
    One or more device names to remediate. Defaults to the local computer.

.PARAMETER RestartClientService
    Restarts the CcmExec service.

.PARAMETER ResetClientPolicy
    Calls SMS_Client ResetPolicy on the target device.

.PARAMETER TriggerStandardSchedules
    Triggers a standard set of client actions such as policy retrieval,
    application evaluation, hardware inventory, software update scan, and state
    message refresh.

.PARAMETER RunCcmRepair
    Launches ccmrepair.exe on the target device.

.PARAMETER DelaySeconds
    Delay between schedule triggers.

.PARAMETER PassThru
    Returns remediation results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-RepairClientHealth.ps1 -TriggerStandardSchedules -RestartClientService

.EXAMPLE
    .\SCCM-RepairClientHealth.ps1 -ComputerName PC001 -RunCcmRepair -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [Parameter(Mandatory = $false)]
    [switch]$RestartClientService,

    [Parameter(Mandatory = $false)]
    [switch]$ResetClientPolicy,

    [Parameter(Mandatory = $false)]
    [switch]$TriggerStandardSchedules,

    [Parameter(Mandatory = $false)]
    [switch]$RunCcmRepair,

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

if (-not $RestartClientService -and -not $ResetClientPolicy -and -not $TriggerStandardSchedules -and -not $RunCcmRepair) {
    $RestartClientService = $true
    $TriggerStandardSchedules = $true
}

$standardSchedules = @(
    [pscustomobject]@{ Name = 'Machine Policy Retrieval and Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000021}' }
    [pscustomobject]@{ Name = 'Machine Policy Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000022}' }
    [pscustomobject]@{ Name = 'Application Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000121}' }
    [pscustomobject]@{ Name = 'Hardware Inventory Collection Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000001}' }
    [pscustomobject]@{ Name = 'Software Updates Scan Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000113}' }
    [pscustomobject]@{ Name = 'Software Updates Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000114}' }
    [pscustomobject]@{ Name = 'State Message Refresh'; ScheduleId = '{00000000-0000-0000-0000-000000000111}' }
)

function Invoke-RemoteServiceRestart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $service = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Service -Filter "Name='CcmExec'" -ErrorAction Stop
    $null = Invoke-CimMethod -InputObject $service -MethodName 'StopService' -ErrorAction Stop
    Start-Sleep -Seconds 3
    $null = Invoke-CimMethod -InputObject $service -MethodName 'StartService' -ErrorAction Stop
}

function Invoke-RemotePolicyReset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $null = Invoke-CimMethod -ComputerName $ComputerName -Namespace 'root/ccm' -ClassName 'SMS_Client' -MethodName 'ResetPolicy' -Arguments @{ uFlags = 1 } -ErrorAction Stop
}

function Invoke-RemoteClientSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\{[0-9A-Fa-f\-]{36}\}$')]
        [string]$ScheduleId
    )

    $null = Invoke-CimMethod -ComputerName $ComputerName -Namespace 'root/ccm' -ClassName 'SMS_Client' -MethodName 'TriggerSchedule' -Arguments @{ sScheduleID = $ScheduleId } -ErrorAction Stop
}

function Invoke-RemoteCcmRepair {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $commandLine = 'C:\Windows\CCM\ccmrepair.exe'
    $processResult = Invoke-CimMethod -ComputerName $ComputerName -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $commandLine } -ErrorAction Stop
    return [int](Get-SccmObjectPropertyValue -InputObject $processResult -PropertyNames @('ReturnValue', 'ProcessId'))
}

Write-SccmLog -Level 'INFO' -Message ("Starting client remediation for {0} device(s)." -f @($ComputerName).Count)

$results = New-Object System.Collections.Generic.List[object]

foreach ($targetComputer in @($ComputerName)) {
    $steps = New-Object System.Collections.Generic.List[string]
    $status = 'Success'
    $errorMessage = $null

    try {
        if ($RestartClientService -and $PSCmdlet.ShouldProcess($targetComputer, 'Restart CcmExec service')) {
            Invoke-RemoteServiceRestart -ComputerName $targetComputer
            [void]$steps.Add('Restarted CcmExec service')
        }

        if ($ResetClientPolicy -and $PSCmdlet.ShouldProcess($targetComputer, 'Reset Configuration Manager policy')) {
            Invoke-RemotePolicyReset -ComputerName $targetComputer
            [void]$steps.Add('Reset client policy')
        }

        if ($TriggerStandardSchedules) {
            foreach ($schedule in $standardSchedules) {
                if ($PSCmdlet.ShouldProcess($targetComputer, ("Trigger {0}" -f $schedule.Name))) {
                    Invoke-RemoteClientSchedule -ComputerName $targetComputer -ScheduleId $schedule.ScheduleId
                    [void]$steps.Add(("Triggered {0}" -f $schedule.Name))
                    if ($DelaySeconds -gt 0 -and $schedule -ne $standardSchedules[-1]) {
                        Start-Sleep -Seconds $DelaySeconds
                    }
                }
            }
        }

        if ($RunCcmRepair -and $PSCmdlet.ShouldProcess($targetComputer, 'Run ccmrepair.exe')) {
            $repairReturnValue = Invoke-RemoteCcmRepair -ComputerName $targetComputer
            [void]$steps.Add(("Started ccmrepair.exe (ReturnValue={0})" -f $repairReturnValue))
        }
    }
    catch {
        $status = 'Failed'
        $errorMessage = $_.Exception.Message
        Write-SccmLog -Level 'ERROR' -Message ("Client remediation failed for [{0}]: {1}" -f $targetComputer, $errorMessage)
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
    Write-SccmAuditLog -Action 'SCCM_CLIENT_REMEDIATION' -Target $targetComputer -Result $status -ErrorMessage $errorMessage -AdditionalData @{ Steps = @($steps) }
}

if ($PassThru) {
    return $results
}
