<#
.SYNOPSIS
    Enables wake-up packets for uninstall application deployments.

.DESCRIPTION
    Connects to Configuration Manager, enumerates application deployments, and
    enables the deployment wake-up packet setting for deployments that resolve
    to an uninstall action. By default, the script updates all uninstall
    application deployments that do not already have wake-up enabled.

    Use -ApplicationName and/or -CollectionName to scope the change. Use
    -WhatIf to preview changes before updating deployments.

.PARAMETER SiteCode
    Optional SCCM site code. If omitted, the script attempts to resolve it from
    the local Configuration Manager environment.

.PARAMETER ApplicationName
    Optional application name filter. Supports wildcard matching.

.PARAMETER CollectionName
    Optional collection name filter. Supports wildcard matching.

.PARAMETER AssignmentId
    Optional list of assignment IDs to target.

.PARAMETER IncludeDisabled
    Include disabled deployments. By default, disabled deployments are skipped.

.PARAMETER IncludeAlreadyEnabled
    Return/report deployments that already have wake-up enabled.

.PARAMETER PassThru
    Return result objects for the deployments that were evaluated.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-EnableWakeOnLanForUninstallDeployments.ps1 -SiteCode P01 -WhatIf

.EXAMPLE
    .\SCCM-EnableWakeOnLanForUninstallDeployments.ps1 -ApplicationName 'Signal*' -CollectionName 'Workstations*'
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string[]]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [string[]]$CollectionName,

    [Parameter(Mandatory = $false)]
    [int[]]$AssignmentId,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabled,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAlreadyEnabled,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

function Get-DeploymentPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $resolvedValue = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames $PropertyNames
    if ($null -ne $resolvedValue) {
        return $resolvedValue
    }

    foreach ($propertyName in $PropertyNames) {
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        try {
            $directValue = $InputObject.$propertyName
            if ($null -eq $directValue) {
                continue
            }

            if ($directValue -is [string]) {
                if ([string]::IsNullOrWhiteSpace($directValue)) {
                    continue
                }

                return $directValue.Trim()
            }

            return $directValue
        }
        catch {
            Write-Debug -Message ('Get-DeploymentPropertyValue could not inspect direct property [{0}].' -f $propertyName)
        }
    }

    $cimPropertyBag = $null
    try {
        $cimPropertyBag = $InputObject.CimInstanceProperties
    }
    catch {
        $cimPropertyBag = $null
    }

    if ($null -eq $cimPropertyBag) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        try {
            $cimProperty = $cimPropertyBag[$propertyName]
            if ($null -eq $cimProperty) {
                continue
            }

            $value = $cimProperty.Value
            if ($null -eq $value) {
                continue
            }

            if ($value -is [string]) {
                if ([string]::IsNullOrWhiteSpace($value)) {
                    continue
                }

                return $value.Trim()
            }

            return $value
        }
        catch {
            Write-Debug -Message ('Get-DeploymentPropertyValue could not inspect CIM property [{0}].' -f $propertyName)
        }
    }

    return $null
}

function ConvertTo-IntegerValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [int]) {
        return $Value
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $parsedValue = 0
    if ([int]::TryParse($text.Trim(), [ref]$parsedValue)) {
        return $parsedValue
    }

    return $null
}

function ConvertTo-BooleanValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [bool]) {
        return $Value
    }

    if ($Value -is [int]) {
        return ($Value -ne 0)
    }

    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    switch -Regex ($text.ToLowerInvariant()) {
        '^(1|true|yes|enabled)$' { return $true }
        '^(0|false|no|disabled)$' { return $false }
    }

    return $null
}

function Test-PatternMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [string[]]$Pattern
    )

    $patterns = @($Pattern | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($patterns.Count -eq 0) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    foreach ($entry in $patterns) {
        if ($Value -like $entry) {
            return $true
        }
    }

    return $false
}

function Resolve-DeploymentSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject
    )

    $applicationNameValue = [string](Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'ApplicationName',
        'LocalizedDisplayName',
        'SoftwareName',
        'AssignmentName',
        'Name'
    ))

    $collectionNameValue = [string](Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'CollectionName',
        'TargetCollectionName'
    ))

    $collectionIdValue = [string](Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'CollectionID',
        'CollectionId',
        'TargetCollectionID',
        'TargetCollectionId'
    ))

    $assignmentIdValue = ConvertTo-IntegerValue -Value (Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'AssignmentID',
        'AssignmentId',
        'DeploymentID',
        'DeploymentId',
        'Id'
    ))

    $desiredConfigTypeValue = Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'DesiredConfigType',
        'DeployAction',
        'DeploymentAction'
    )

    $assignmentActionValue = Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'AssignmentAction',
        'Action'
    )

    $enabledValue = ConvertTo-BooleanValue -Value (Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'Enabled',
        'IsEnabled'
    ))

    $wakeEnabledValue = ConvertTo-BooleanValue -Value (Get-DeploymentPropertyValue -InputObject $InputObject -PropertyNames @(
        'WoLEnabled',
        'WakeUpEnabled',
        'SendWakeUpPacket',
        'SendWakeupPacket'
    ))

    return [pscustomobject]@{
        ApplicationName   = $applicationNameValue
        CollectionName    = $collectionNameValue
        CollectionId      = $collectionIdValue
        AssignmentId      = $assignmentIdValue
        DesiredConfigType = $desiredConfigTypeValue
        AssignmentAction  = $assignmentActionValue
        Enabled           = $enabledValue
        WakeEnabled       = $wakeEnabledValue
    }
}

function Resolve-DeploymentAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DeploymentSummary
    )

    $explicitAction = [string](Get-DeploymentPropertyValue -InputObject $DeploymentSummary -PropertyNames @(
        'DeployAction',
        'DeploymentAction',
        'DesiredConfigType',
        'Action'
    ))

    if (-not [string]::IsNullOrWhiteSpace($explicitAction)) {
        switch -Regex ($explicitAction.Trim().ToLowerInvariant()) {
            'install|^1$|required' { return 'Install' }
            'uninstall|not_allowed|notallowed|^2$' { return 'Uninstall' }
        }
    }

    $desiredConfigType = Get-DeploymentPropertyValue -InputObject $DeploymentSummary -PropertyNames @('DesiredConfigType')
    if ($null -ne $desiredConfigType) {
        switch ([string]$desiredConfigType) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    $assignmentAction = Get-DeploymentPropertyValue -InputObject $DeploymentSummary -PropertyNames @('AssignmentAction')
    if ($null -ne $assignmentAction) {
        switch ([string]$assignmentAction) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    return 'Unknown'
}

function Set-DeploymentWakeOnLan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Deployment,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DeploymentSummary
    )

    return Set-CimInstance -InputObject $Deployment -Property @{ WoLEnabled = $true } -PassThru -ErrorAction Stop
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = 'root/SMS/site_{0}' -f $resolvedSiteCode
    Write-SccmLog -Level 'INFO' -Message 'Collecting application deployments for wake-up packet remediation.'

    $deployments = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_ApplicationAssignment' -ErrorAction Stop)
    Write-SccmLog -Level 'INFO' -Message ('Retrieved [{0}] application deployment object(s).' -f $deployments.Count)

    $assignmentIdSet = New-Object System.Collections.Generic.HashSet[int]
    foreach ($id in @($AssignmentId)) {
        [void]$assignmentIdSet.Add($id)
    }

    $results = New-Object System.Collections.Generic.List[object]
    $applicationMatchCount = 0
    $collectionMatchCount = 0
    $uninstallMatchCount = 0
    $changeCandidateCount = 0

    foreach ($deployment in $deployments) {
        $summary = Resolve-DeploymentSummary -InputObject $deployment
        $deploymentAction = Resolve-DeploymentAction -DeploymentSummary $summary

        if ($assignmentIdSet.Count -gt 0) {
            $resolvedAssignmentId = ConvertTo-IntegerValue -Value $summary.AssignmentId
            if ($null -eq $resolvedAssignmentId -or -not $assignmentIdSet.Contains($resolvedAssignmentId)) {
                continue
            }
        }

        if (-not (Test-PatternMatch -Value $summary.ApplicationName -Pattern $ApplicationName)) {
            continue
        }
        $applicationMatchCount++

        if (-not (Test-PatternMatch -Value $summary.CollectionName -Pattern $CollectionName)) {
            continue
        }
        $collectionMatchCount++

        if (-not $IncludeDisabled -and $summary.Enabled -eq $false) {
            Write-SccmLog -Level 'DEBUG' -Message ('Skipping disabled deployment [{0}] for application [{1}].' -f $summary.AssignmentId, $summary.ApplicationName)
            continue
        }

        if ($deploymentAction -ne 'Uninstall') {
            continue
        }
        $uninstallMatchCount++

        $targetLabel = ('{0} -> {1} (AssignmentId={2})' -f $summary.ApplicationName, $summary.CollectionName, $summary.AssignmentId)
        $changeCandidateCount++

        if ($summary.WakeEnabled -eq $true) {
            Write-SccmLog -Level 'DEBUG' -Message ('Wake-up packets already enabled for [{0}].' -f $targetLabel)

            if ($IncludeAlreadyEnabled) {
                [void]$results.Add([pscustomobject]@{
                    ApplicationName = $summary.ApplicationName
                    CollectionName  = $summary.CollectionName
                    AssignmentId    = $summary.AssignmentId
                    Changed         = $false
                    WakeEnabled     = $true
                    Status          = 'AlreadyEnabled'
                    Error           = $null
                })
            }

            continue
        }

        $status = 'Pending'
        $errorMessage = $null
        $wakeEnabledAfter = $summary.WakeEnabled
        $changed = $false

        try {
            if ($PSCmdlet.ShouldProcess($targetLabel, 'Enable wake-up packets')) {
                $updatedDeployment = Set-DeploymentWakeOnLan -Deployment $deployment -DeploymentSummary $summary
                $updatedSummary = Resolve-DeploymentSummary -InputObject $updatedDeployment
                $wakeEnabledAfter = if ($null -ne $updatedSummary.WakeEnabled) { $updatedSummary.WakeEnabled } else { $true }
                $status = 'Updated'
                $changed = $true
                Write-SccmLog -Level 'SUCCESS' -Message ('Enabled wake-up packets for [{0}].' -f $targetLabel)
                Write-SccmAuditLog -Action 'SCCM_ENABLE_WAKE_ON_LAN' -Target $targetLabel -Result 'Updated'
            }
            else {
                $status = 'WhatIf'
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-SccmLog -Level 'ERROR' -Message ('Failed to enable wake-up packets for [{0}]: {1}' -f $targetLabel, $errorMessage)
            Write-SccmAuditLog -Action 'SCCM_ENABLE_WAKE_ON_LAN' -Target $targetLabel -Result 'Failed' -ErrorMessage $errorMessage
        }

        [void]$results.Add([pscustomobject]@{
            ApplicationName = $summary.ApplicationName
            CollectionName  = $summary.CollectionName
            AssignmentId    = $summary.AssignmentId
            Changed         = $changed
            WakeEnabled     = $wakeEnabledAfter
            Status          = $status
            Error           = $errorMessage
        })
    }

    $updatedCount = @($results | Where-Object { $_.Status -eq 'Updated' }).Count
    $failedCount = @($results | Where-Object { $_.Status -eq 'Failed' }).Count
    $alreadyEnabledCount = @($results | Where-Object { $_.Status -eq 'AlreadyEnabled' }).Count
    $whatIfCount = @($results | Where-Object { $_.Status -eq 'WhatIf' }).Count

    Write-SccmLog -Level 'INFO' -Message ('Filter counts: ApplicationMatch={0}; CollectionMatch={1}; UninstallMatch={2}; CandidateCount={3}.' -f $applicationMatchCount, $collectionMatchCount, $uninstallMatchCount, $changeCandidateCount)
    Write-SccmLog -Level 'INFO' -Message ('Wake-up packet remediation summary: Updated={0}; Failed={1}; AlreadyEnabled={2}; WhatIf={3}.' -f $updatedCount, $failedCount, $alreadyEnabledCount, $whatIfCount)

    if ($PassThru) {
        return $results
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}