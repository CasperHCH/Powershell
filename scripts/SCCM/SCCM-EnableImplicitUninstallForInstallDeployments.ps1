<#
.SYNOPSIS
    Enables SCCM implicit uninstall for eligible application deployments.

.DESCRIPTION
    Uses SCCM provider-side properties discovered from SMS_ApplicationAssignment
    to enable implicit uninstall on existing application deployments.

    Eligibility rules:
    - Deployment action must be Install
    - Deployment purpose must be Required
    - Target collection must resolve to a device collection by default
    - User collections are optional with -IncludeUserCollections

    Important:
    - Microsoft documents the implicit uninstall feature in the SCCM console UI.
    - Microsoft does not document a PowerShell parameter on
      New-CMApplicationDeployment or Set-CMApplicationDeployment to enable it.
    - This script relies on provider-side properties discovered in this
      environment:
        - SMS_ApplicationAssignment.AdditionalProperties XML element
          ImplicitUninstallEnabled=true
        - SMS_ApplicationAssignment.OfferFlags bit 64
    - Test with -WhatIf first and use a narrow filter before broad rollout.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ApplicationName
    Optional application name filter.

.PARAMETER CollectionName
    Optional collection name filter.

.PARAMETER IncludeUserCollections
    Also process eligible user-targeted Required install deployments.

.PARAMETER OutputDirectory
    Output directory for CSV and optional JSON reports.

.PARAMETER ExportJson
    Also export JSON in addition to CSV.

.PARAMETER PassThru
    Returns result rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG logging.

.EXAMPLE
    .\SCCM-EnableImplicitUninstallForInstallDeployments.ps1 -SiteCode P03 -WhatIf

.EXAMPLE
    .\SCCM-EnableImplicitUninstallForInstallDeployments.ps1 -SiteCode P03 -ApplicationName '7-Zip 25.01 (build 1)' -CollectionName '7-zip - Install (Required)' -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeUserCollections,

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

function Resolve-DeploymentPurpose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $InputObject
    )

    $offerTypeId = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('OfferTypeID', 'OfferTypeId')
    if ($null -ne $offerTypeId) {
        switch ([int]$offerTypeId) {
            0 { return 'Required' }
            2 { return 'Available' }
        }
    }

    $explicitPurpose = [string](Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('DeploymentIntent', 'Intent', 'Purpose', 'OfferType'))
    if (-not [string]::IsNullOrWhiteSpace($explicitPurpose)) {
        switch -Regex ($explicitPurpose.Trim()) {
            'required|0' { return 'Required' }
            'available|2' { return 'Available' }
        }
    }

    return 'Unknown'
}

function Resolve-DeploymentAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $InputObject
    )

    $desiredConfigType = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('DesiredConfigType')
    if ($null -ne $desiredConfigType) {
        switch ([string]$desiredConfigType) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    $assignmentAction = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('AssignmentAction')
    if ($null -ne $assignmentAction) {
        switch ([string]$assignmentAction) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    return 'Unknown'
}

function Resolve-CollectionType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [hashtable]$DeviceCollectionIndex,

        [Parameter(Mandatory = $true)]
        [hashtable]$UserCollectionIndex
    )

    if ($DeviceCollectionIndex.ContainsKey($CollectionId)) {
        return 'Device'
    }

    if ($UserCollectionIndex.ContainsKey($CollectionId)) {
        return 'User'
    }

    return 'Unknown'
}

function Get-ImplicitUninstallEnabledState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $AssignmentObject
    )

    $offerFlags = Get-SccmObjectPropertyValue -InputObject $AssignmentObject -PropertyNames @('OfferFlags')
    if ($null -ne $offerFlags -and -not [string]::IsNullOrWhiteSpace([string]$offerFlags)) {
        try {
            if (([uint32]$offerFlags -band 64) -eq 64) {
                return $true
            }
        }
        catch {
            Write-Debug -Message 'Get-ImplicitUninstallEnabledState could not parse OfferFlags.'
        }
    }

    $additionalProperties = [string](Get-SccmObjectPropertyValue -InputObject $AssignmentObject -PropertyNames @('AdditionalProperties'))
    if ([string]::IsNullOrWhiteSpace($additionalProperties)) {
        return $false
    }

    try {
        [xml]$xml = $additionalProperties
        $implicitNode = $xml.SelectSingleNode('/Properties/ImplicitUninstallEnabled')
        if ($null -ne $implicitNode) {
            return ([string]$implicitNode.InnerText -match '^(?i:true|1)$')
        }
    }
    catch {
        Write-Debug -Message 'Get-ImplicitUninstallEnabledState could not parse AdditionalProperties XML.'
    }

    return $false
}

function Set-ImplicitUninstallAdditionalProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExistingXml,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if ([string]::IsNullOrWhiteSpace($ExistingXml)) {
        [xml]$xml = '<?xml version="1.0" encoding="utf-16"?><Properties />'
    }
    else {
        try {
            [xml]$xml = $ExistingXml
        }
        catch {
            throw ('Unable to parse AdditionalProperties XML: {0}' -f $_.Exception.Message)
        }
    }

    if ($null -eq $xml.DocumentElement) {
        $root = $xml.CreateElement('Properties')
        $null = $xml.AppendChild($root)
    }
    elseif ($xml.DocumentElement.Name -ne 'Properties') {
        throw 'AdditionalProperties XML root element is not [Properties].'
    }

    $node = $xml.SelectSingleNode('/Properties/ImplicitUninstallEnabled')
    if ($null -eq $node) {
        $node = $xml.CreateElement('ImplicitUninstallEnabled')
        $null = $xml.DocumentElement.AppendChild($node)
    }

    $node.InnerText = if ($Enabled) { 'true' } else { 'false' }

    return $xml.OuterXml
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = 'root/SMS/site_{0}' -f $resolvedSiteCode

    Write-SccmLog -Level 'INFO' -Message ('Collecting application deployments from site [{0}] for implicit uninstall enablement.' -f $resolvedSiteCode)

    $deviceCollectionIndex = @{}
    foreach ($deviceCollection in @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $deviceCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            $deviceCollectionIndex[$collectionId] = $true
        }
    }

    $userCollectionIndex = @{}
    foreach ($userCollection in @(Get-CMUserCollection -ErrorAction SilentlyContinue)) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $userCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            $userCollectionIndex[$collectionId] = $true
        }
    }

    $results = New-Object System.Collections.Generic.List[object]
    $deployments = @(Get-CMApplicationDeployment -ErrorAction SilentlyContinue)

    foreach ($deployment in $deployments) {
        $resolvedApplicationName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'LocalizedDisplayName', 'AssignmentName'))
        $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName'))
        $resolvedCollectionId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID'))
        $deploymentId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('AssignmentID', 'AssignmentId', 'DeploymentID', 'DeploymentId', 'Id'))

        if (-not [string]::IsNullOrWhiteSpace($ApplicationName) -and $resolvedApplicationName -notlike "*$ApplicationName*") {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($CollectionName) -and $resolvedCollectionName -notlike "*$CollectionName*") {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($deploymentId)) {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'Skipped'
                Reason                       = 'Deployment ID could not be resolved.'
                PreviousOfferFlags           = ''
                NewOfferFlags                = ''
                PreviousImplicitUninstall    = ''
                NewImplicitUninstall         = ''
            })
            continue
        }

        $assignment = Get-CimInstance -Namespace $namespace -ClassName SMS_ApplicationAssignment -Filter ("AssignmentID = {0}" -f [int]$deploymentId) -ErrorAction Stop
        $deploymentPurpose = Resolve-DeploymentPurpose -InputObject $assignment
        $deploymentAction = Resolve-DeploymentAction -InputObject $assignment
        $collectionType = Resolve-CollectionType -CollectionId $resolvedCollectionId -DeviceCollectionIndex $deviceCollectionIndex -UserCollectionIndex $userCollectionIndex

        if ($deploymentAction -ne 'Install' -or $deploymentPurpose -ne 'Required') {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'Skipped'
                Reason                       = 'Deployment is not a Required install deployment.'
                PreviousOfferFlags           = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('OfferFlags'))
                NewOfferFlags                = ''
                PreviousImplicitUninstall    = [string](Get-ImplicitUninstallEnabledState -AssignmentObject $assignment)
                NewImplicitUninstall         = ''
            })
            continue
        }

        if ($collectionType -eq 'User' -and -not $IncludeUserCollections) {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'Skipped'
                Reason                       = 'User collection skipped by default. Use -IncludeUserCollections to allow it.'
                PreviousOfferFlags           = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('OfferFlags'))
                NewOfferFlags                = ''
                PreviousImplicitUninstall    = [string](Get-ImplicitUninstallEnabledState -AssignmentObject $assignment)
                NewImplicitUninstall         = ''
            })
            continue
        }

        if ($collectionType -notin @('Device', 'User')) {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'Skipped'
                Reason                       = 'Collection type could not be resolved.'
                PreviousOfferFlags           = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('OfferFlags'))
                NewOfferFlags                = ''
                PreviousImplicitUninstall    = [string](Get-ImplicitUninstallEnabledState -AssignmentObject $assignment)
                NewImplicitUninstall         = ''
            })
            continue
        }

        $previousOfferFlags = [uint32]([string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('OfferFlags')) -as [uint32])
        $previousState = Get-ImplicitUninstallEnabledState -AssignmentObject $assignment

        if ($previousState) {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'AlreadyEnabled'
                Reason                       = 'Implicit uninstall is already enabled.'
                PreviousOfferFlags           = [string]$previousOfferFlags
                NewOfferFlags                = [string]$previousOfferFlags
                PreviousImplicitUninstall    = 'True'
                NewImplicitUninstall         = 'True'
            })
            continue
        }

        $previousAdditionalProperties = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('AdditionalProperties'))
        $newAdditionalProperties = Set-ImplicitUninstallAdditionalProperties -ExistingXml $previousAdditionalProperties -Enabled $true
        $newOfferFlags = ([uint32]$previousOfferFlags -bor 64)
        $targetDescription = '{0} -> {1}' -f $resolvedApplicationName, $resolvedCollectionName

        if ($PSCmdlet.ShouldProcess($targetDescription, 'Enable SCCM implicit uninstall')) {
            try {
                $updatedAssignment = Set-CimInstance -InputObject $assignment -Property @{
                    AdditionalProperties = $newAdditionalProperties
                    OfferFlags           = [uint32]$newOfferFlags
                } -PassThru -ErrorAction Stop

                $newState = Get-ImplicitUninstallEnabledState -AssignmentObject $updatedAssignment

                [void]$results.Add([pscustomobject]@{
                    ApplicationName              = $resolvedApplicationName
                    CollectionName               = $resolvedCollectionName
                    CollectionId                 = $resolvedCollectionId
                    DeploymentId                 = $deploymentId
                    Result                       = if ($newState) { 'Updated' } else { 'UpdatedButStateUnconfirmed' }
                    Reason                       = if ($newState) { 'Implicit uninstall enabled.' } else { 'Update completed, but enabled state should be rechecked.' }
                    PreviousOfferFlags           = [string]$previousOfferFlags
                    NewOfferFlags                = [string]$newOfferFlags
                    PreviousImplicitUninstall    = 'False'
                    NewImplicitUninstall         = [string]$newState
                })

                Write-SccmAuditLog -Action 'SCCM_ENABLE_IMPLICIT_UNINSTALL' -Target $targetDescription -Result 'SUCCESS' -AdditionalData @{ DeploymentId = $deploymentId; PreviousOfferFlags = $previousOfferFlags; NewOfferFlags = $newOfferFlags }
            }
            catch {
                [void]$results.Add([pscustomobject]@{
                    ApplicationName              = $resolvedApplicationName
                    CollectionName               = $resolvedCollectionName
                    CollectionId                 = $resolvedCollectionId
                    DeploymentId                 = $deploymentId
                    Result                       = 'Failed'
                    Reason                       = $_.Exception.Message
                    PreviousOfferFlags           = [string]$previousOfferFlags
                    NewOfferFlags                = [string]$newOfferFlags
                    PreviousImplicitUninstall    = 'False'
                    NewImplicitUninstall         = ''
                })

                Write-SccmAuditLog -Action 'SCCM_ENABLE_IMPLICIT_UNINSTALL' -Target $targetDescription -Result 'FAILED' -ErrorMessage $_.Exception.Message -AdditionalData @{ DeploymentId = $deploymentId }
            }
        }
        else {
            [void]$results.Add([pscustomobject]@{
                ApplicationName              = $resolvedApplicationName
                CollectionName               = $resolvedCollectionName
                CollectionId                 = $resolvedCollectionId
                DeploymentId                 = $deploymentId
                Result                       = 'WhatIf'
                Reason                       = 'Would enable implicit uninstall.'
                PreviousOfferFlags           = [string]$previousOfferFlags
                NewOfferFlags                = [string]$newOfferFlags
                PreviousImplicitUninstall    = 'False'
                NewImplicitUninstall         = 'True'
            })
        }
    }

    $timestamp = Get-SccmTimestampString
    $csvPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ('SCCM-EnableImplicitUninstall-{0}.csv' -f $timestamp)
    $null = Export-SccmData -InputObject ($results | Sort-Object Result, ApplicationName, CollectionName) -Path $csvPath -Format 'Csv'
    Write-SccmLog -Level 'SUCCESS' -Message ('Implicit uninstall enablement report exported to [{0}].' -f $csvPath)

    if ($ExportJson) {
        $jsonPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ('SCCM-EnableImplicitUninstall-{0}.json' -f $timestamp)
        $null = Export-SccmData -InputObject ($results | Sort-Object Result, ApplicationName, CollectionName) -Path $jsonPath -Format 'Json'
        Write-SccmLog -Level 'SUCCESS' -Message ('Implicit uninstall enablement JSON exported to [{0}].' -f $jsonPath)
    }

    Write-SccmAuditLog -Action 'SCCM_ENABLE_IMPLICIT_UNINSTALL_RUN' -Result 'SUCCESS' -AdditionalData @{ ResultCount = $results.Count }

    if ($PassThru) {
        return $results.ToArray()
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}