<#
.SYNOPSIS
    Triggers all standard local Configuration Manager client actions.

.DESCRIPTION
    Runs the common actions shown in Configuration Manager Properties on the local device
    by calling SMS_Client TriggerSchedule in WMI namespace root\ccm.

    The script is safe to rerun and logs every attempt to a log file next to the script.
    If a schedule is unavailable on the local client, it is logged as skipped and execution continues.
    Use -WhatIf to preview actions without triggering them.

.PARAMETER DelaySeconds
    Delay in seconds between action triggers.

.PARAMETER ContinueOnError
    Continues processing remaining actions when one action fails.

.PARAMETER IncludeOptionalActions
    Includes additional non-default actions that may not appear on every client.

.PARAMETER PassThru
    Returns action execution results as objects.

.EXAMPLE
    .\SCCM-RunClientActionsLocal.ps1

.EXAMPLE
    .\SCCM-RunClientActionsLocal.ps1 -DelaySeconds 2 -ContinueOnError

.EXAMPLE
    .\SCCM-RunClientActionsLocal.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 60)]
    [int]$DelaySeconds = 1,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnError,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeOptionalActions,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SessionId = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
$script:LogFile = Join-Path -Path $PSScriptRoot -ChildPath 'SCCM-RunClientActionsLocal.log'

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'AUDIT', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$script:SessionId] [$Level] $Message"

    if (-not $Sensitive) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'AUDIT' { 'Cyan' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        Write-Host $entry -ForegroundColor $color
    }

    Add-Content -Path $script:LogFile -Value $entry -ErrorAction SilentlyContinue
}

function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [string]$Result,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage
    )

    $audit = @{
        Timestamp    = (Get-Date).ToString('o')
        SessionId    = $script:SessionId
        Action       = $Action
        Target       = $Target
        Result       = $Result
        Error        = $ErrorMessage
        User         = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        ScriptName   = $MyInvocation.ScriptName
    }

    Write-Log -Message ($audit | ConvertTo-Json -Compress) -Level 'AUDIT' -Sensitive
}

function Test-ClientPrerequisite {
    [CmdletBinding()]
    param()

    try {
        $service = Get-Service -Name 'CcmExec' -ErrorAction Stop
    } catch {
        throw 'SCCM client service (CcmExec) was not found. Ensure Configuration Manager client is installed.'
    }

    if ($service.Status -ne 'Running') {
        throw 'SCCM client service (CcmExec) is not running. Start the service and retry.'
    }

    try {
        Get-CimInstance -Namespace 'root/ccm' -ClassName 'SMS_Client' -ErrorAction Stop | Out-Null
    } catch {
        throw 'Unable to access WMI namespace root/ccm or class SMS_Client. Run as administrator and verify SCCM client health.'
    }
}

function Get-ClientAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IncludeOptional
    )

    $actions = @(
        [pscustomobject]@{ Name = 'Hardware Inventory Collection Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000001}'; Optional = $false }
        [pscustomobject]@{ Name = 'Software Inventory Collection Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000002}'; Optional = $false }
        [pscustomobject]@{ Name = 'Discovery Data Collection Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000003}'; Optional = $false }
        [pscustomobject]@{ Name = 'File Collection Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000010}'; Optional = $false }
        [pscustomobject]@{ Name = 'Machine Policy Retrieval and Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000021}'; Optional = $false }
        [pscustomobject]@{ Name = 'Machine Policy Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000022}'; Optional = $false }
        [pscustomobject]@{ Name = 'User Policy Retrieval Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000026}'; Optional = $false }
        [pscustomobject]@{ Name = 'User Policy Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000027}'; Optional = $false }
        [pscustomobject]@{ Name = 'Software Metering Usage Report Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000031}'; Optional = $false }
        [pscustomobject]@{ Name = 'Windows Installer Source List Update Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000032}'; Optional = $false }
        [pscustomobject]@{ Name = 'Software Updates Scan Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000113}'; Optional = $false }
        [pscustomobject]@{ Name = 'Software Updates Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000114}'; Optional = $false }
        [pscustomobject]@{ Name = 'State Message Refresh'; ScheduleId = '{00000000-0000-0000-0000-000000000111}'; Optional = $false }
        [pscustomobject]@{ Name = 'Application Deployment Evaluation Cycle'; ScheduleId = '{00000000-0000-0000-0000-000000000121}'; Optional = $false }

        # Optional actions can be available depending on client version and enabled features.
        [pscustomobject]@{ Name = 'Refresh Default Management Point Task'; ScheduleId = '{00000000-0000-0000-0000-000000000023}'; Optional = $true }
        [pscustomobject]@{ Name = 'Location Services Refresh'; ScheduleId = '{00000000-0000-0000-0000-000000000024}'; Optional = $true }
        [pscustomobject]@{ Name = 'Location Services Cleanup'; ScheduleId = '{00000000-0000-0000-0000-000000000025}'; Optional = $true }
    )

    if ($IncludeOptional) {
        return ,$actions
    }

    return ,($actions | Where-Object { -not $_.Optional })
}

function Invoke-ClientAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\{[0-9A-Fa-f\-]{36}\}$')]
        [string]$ScheduleId
    )

    Invoke-CimMethod -Namespace 'root/ccm' -ClassName 'SMS_Client' -MethodName 'TriggerSchedule' -Arguments @{ sScheduleID = $ScheduleId } -ErrorAction Stop | Out-Null
}

function Test-IsUnavailableScheduleError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $errorText = [string]$ErrorRecord.Exception.Message
    $errorText += " " + [string]$ErrorRecord.FullyQualifiedErrorId

    if ($errorText -match '(?i)0x80041002' -or $errorText -match '(?i)not found') {
        return $true
    }

    return $false
}

Write-Log -Message 'Starting SCCM local client action run.' -Level 'INFO'

$results = New-Object System.Collections.Generic.List[object]

try {
    Test-ClientPrerequisite
    Write-Log -Message 'Prerequisite checks passed.' -Level 'INFO'

    $actionList = Get-ClientAction -IncludeOptional:$IncludeOptionalActions.IsPresent
    Write-Log -Message ("Prepared {0} action(s) for execution." -f $actionList.Count) -Level 'INFO'

    foreach ($action in $actionList) {
        $status = 'Skipped'
        $errorMessage = $null

        try {
            if ($PSCmdlet.ShouldProcess($action.Name, "Trigger SCCM schedule $($action.ScheduleId)")) {
                Write-Log -Message ("Triggering: {0} ({1})" -f $action.Name, $action.ScheduleId) -Level 'INFO'
                Invoke-ClientAction -ScheduleId $action.ScheduleId
                $status = 'Success'
                Write-Log -Message ("Completed: {0}" -f $action.Name) -Level 'INFO'
            }
        } catch {
            $errorMessage = $_.Exception.Message

            if (Test-IsUnavailableScheduleError -ErrorRecord $_) {
                $status = 'Skipped'
                Write-Log -Message ("Unavailable on this client, skipped: {0} | {1}" -f $action.Name, $errorMessage) -Level 'WARNING'
            } else {
                $status = 'Failed'
                Write-Log -Message ("Failed: {0} | {1}" -f $action.Name, $errorMessage) -Level 'ERROR'
            }

            if ($status -eq 'Failed' -and -not $ContinueOnError) {
                Write-AuditLog -Action 'SCCM_CLIENT_ACTION_RUN_ABORTED' -Target $action.Name -Result $status -ErrorMessage $errorMessage
                throw
            }
        }

        $result = [pscustomobject]@{
            ActionName  = $action.Name
            ScheduleId  = $action.ScheduleId
            IsOptional  = [bool]$action.Optional
            Status      = $status
            Timestamp   = Get-Date
            Error       = $errorMessage
        }
        [void]$results.Add($result)

        Write-AuditLog -Action 'SCCM_CLIENT_ACTION_TRIGGER' -Target $action.Name -Result $status -ErrorMessage $errorMessage

        if ($DelaySeconds -gt 0 -and $action -ne $actionList[-1]) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    $successCount = @($results | Where-Object { $_.Status -eq 'Success' }).Count
    $failedCount = @($results | Where-Object { $_.Status -eq 'Failed' }).Count
    $skippedCount = @($results | Where-Object { $_.Status -eq 'Skipped' }).Count

    Write-Log -Message ("Completed. Success={0} Failed={1} Skipped={2}" -f $successCount, $failedCount, $skippedCount) -Level 'INFO'
    Write-AuditLog -Action 'SCCM_CLIENT_ACTION_RUN_COMPLETED' -Target $env:COMPUTERNAME -Result ("Success={0};Failed={1};Skipped={2}" -f $successCount, $failedCount, $skippedCount)
}
catch {
    Write-Log -Message ("Run failed: {0}" -f $_.Exception.Message) -Level 'ERROR'
    Write-AuditLog -Action 'SCCM_CLIENT_ACTION_RUN_FAILED' -Target $env:COMPUTERNAME -Result 'Failed' -ErrorMessage $_.Exception.Message
    throw
}
finally {
    if ($PassThru) {
        $results
    }
}
