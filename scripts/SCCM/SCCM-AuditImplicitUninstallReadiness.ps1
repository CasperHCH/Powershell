<#
.SYNOPSIS
    Audits SCCM application deployments for implicit uninstall readiness.

.DESCRIPTION
    Produces a read-only report of application deployments and highlights which
    deployments are eligible for the SCCM implicit uninstall feature.

    Important:
    - This script does not modify deployments.
    - Microsoft documents the implicit uninstall feature in the console UI, but
      does not document a supported PowerShell parameter on
      New-CMApplicationDeployment or Set-CMApplicationDeployment to enable it.
    - Because of that limitation, this script audits readiness and flags items
      for manual console review instead of attempting unsupported WMI changes.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ApplicationName
    Optional application name filter.

.PARAMETER CollectionName
    Optional collection name filter.

.PARAMETER OutputDirectory
    Output directory for CSV and optional JSON reports.

.PARAMETER ExportJson
    Also export JSON in addition to CSV.

.PARAMETER PassThru
    Returns result rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG logging.

.EXAMPLE
    .\SCCM-AuditImplicitUninstallReadiness.ps1 -SiteCode P01

.EXAMPLE
    .\SCCM-AuditImplicitUninstallReadiness.ps1 -SiteCode P01 -ApplicationName Visio -ExportJson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

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

    $explicitPurpose = [string](Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('DeploymentIntent', 'Intent', 'Purpose', 'OfferType'))
    if (-not [string]::IsNullOrWhiteSpace($explicitPurpose)) {
        switch -Regex ($explicitPurpose.Trim()) {
            'required|0' { return 'Required' }
            'available|2' { return 'Available' }
            default { return $explicitPurpose.Trim() }
        }
    }

    $offerTypeId = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('OfferTypeID', 'OfferTypeId')
    if ($null -ne $offerTypeId) {
        switch ([int]$offerTypeId) {
            0 { return 'Required' }
            2 { return 'Available' }
        }
    }

    return 'Unknown'
}

function Resolve-DeploymentAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $DeploymentObject,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $AssignmentObject
    )

    foreach ($sourceObject in @($DeploymentObject, $AssignmentObject)) {
        if ($null -eq $sourceObject) {
            continue
        }

        $explicitAction = [string](Get-SccmObjectPropertyValue -InputObject $sourceObject -PropertyNames @('DeployAction', 'DeploymentAction', 'Action'))
        if (-not [string]::IsNullOrWhiteSpace($explicitAction)) {
            switch -Regex ($explicitAction.Trim()) {
                'install|1' { return 'Install' }
                'uninstall|2' { return 'Uninstall' }
                default { return $explicitAction.Trim() }
            }
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

function Resolve-ImplicitUninstallPropertySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $DeploymentObject,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $AssignmentObject
    )

    $matchingProperties = New-Object System.Collections.Generic.List[string]

    foreach ($sourceObject in @($DeploymentObject, $AssignmentObject)) {
        if ($null -eq $sourceObject) {
            continue
        }

        foreach ($property in @($sourceObject.PSObject.Properties)) {
            if ($null -eq $property) {
                continue
            }

            $propertyName = [string]$property.Name
            if ([string]::IsNullOrWhiteSpace($propertyName)) {
                continue
            }

            if ($propertyName -match '(?i)(implicit|fall.*collection|collection.*fall|auto.*uninstall|uninstall.*collection)') {
                [void]$matchingProperties.Add(("{0}={1}" -f $propertyName, [string]$property.Value))
            }
        }
    }

    if ($matchingProperties.Count -eq 0) {
        return 'NotExposedByDocumentedCmdlets'
    }

    return ($matchingProperties.ToArray() -join '; ')
}

function Get-ManualReviewRecommendation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionType,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentPurpose,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentAction
    )

    if ($DeploymentAction -ne 'Install') {
        return 'Not eligible: deployment action is not Install.'
    }

    if ($DeploymentPurpose -ne 'Required') {
        return 'Not eligible: implicit uninstall only applies to Required deployments.'
    }

    if ($CollectionType -notin @('Device', 'User')) {
        return 'Review collection type manually: deployment collection could not be resolved.'
    }

    return 'Eligible for manual console review. In deployment properties, open Deployment Settings and verify the implicit uninstall option is enabled.'
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = "root/SMS/site_$resolvedSiteCode"

    Write-SccmLog -Level 'INFO' -Message ("Collecting application deployments from site [{0}]." -f $resolvedSiteCode)

    $deviceCollectionIndex = @{}
    foreach ($collection in @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            $deviceCollectionIndex[$collectionId] = $true
        }
    }

    $userCollectionIndex = @{}
    foreach ($collection in @(Get-CMUserCollection -ErrorAction SilentlyContinue)) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            $userCollectionIndex[$collectionId] = $true
        }
    }

    $assignmentById = @{}
    foreach ($assignment in @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_ApplicationAssignment' -ErrorAction Stop)) {
        $assignmentId = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('AssignmentID', 'AssignmentId'))
        if (-not [string]::IsNullOrWhiteSpace($assignmentId)) {
            $assignmentById[$assignmentId] = $assignment
        }
    }

    $deployments = @(Get-CMApplicationDeployment -ErrorAction SilentlyContinue)
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($deployment in $deployments) {
        $deploymentId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('AssignmentID', 'AssignmentId', 'DeploymentID', 'DeploymentId', 'Id'))
        $resolvedApplicationName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'LocalizedDisplayName', 'AssignmentName'))
        $resolvedCollectionId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID', 'TargetCollectionId'))
        $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName'))

        if (-not [string]::IsNullOrWhiteSpace($ApplicationName) -and $resolvedApplicationName -notlike "*$ApplicationName*") {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($CollectionName) -and $resolvedCollectionName -notlike "*$CollectionName*") {
            continue
        }

        $assignment = $null
        if (-not [string]::IsNullOrWhiteSpace($deploymentId) -and $assignmentById.ContainsKey($deploymentId)) {
            $assignment = $assignmentById[$deploymentId]
        }

        if ([string]::IsNullOrWhiteSpace($resolvedCollectionId)) {
            $resolvedCollectionId = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('TargetCollectionID', 'CollectionID', 'CollectionId'))
        }

        if ([string]::IsNullOrWhiteSpace($resolvedCollectionName)) {
            $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('CollectionName', 'TargetCollectionName'))
        }

        if ([string]::IsNullOrWhiteSpace($resolvedApplicationName)) {
            $resolvedApplicationName = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('ApplicationName', 'AssignmentName'))
        }

        $deploymentPurpose = Resolve-DeploymentPurpose -InputObject $(if ($null -ne $assignment) { $assignment } else { $deployment })
        $deploymentAction = Resolve-DeploymentAction -DeploymentObject $deployment -AssignmentObject $assignment
        $collectionType = Resolve-CollectionType -CollectionId $resolvedCollectionId -DeviceCollectionIndex $deviceCollectionIndex -UserCollectionIndex $userCollectionIndex
        $offerFlags = Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('OfferFlags')
        if ($null -eq $offerFlags) {
            $offerFlags = ''
        }

        $eligible = ($deploymentAction -eq 'Install' -and $deploymentPurpose -eq 'Required' -and $collectionType -in @('Device', 'User'))
        $manualRecommendation = Get-ManualReviewRecommendation -CollectionType $collectionType -DeploymentPurpose $deploymentPurpose -DeploymentAction $deploymentAction
        $propertySnapshot = Resolve-ImplicitUninstallPropertySnapshot -DeploymentObject $deployment -AssignmentObject $assignment

        [void]$results.Add([pscustomobject]@{
            ApplicationName                 = $resolvedApplicationName
            CollectionName                  = $resolvedCollectionName
            CollectionId                    = $resolvedCollectionId
            CollectionType                  = $collectionType
            DeploymentId                    = $deploymentId
            DeploymentPurpose               = $deploymentPurpose
            DeploymentAction                = $deploymentAction
            EligibleForImplicitUninstall    = $eligible
            ImplicitUninstallState          = 'ManualConsoleCheckRequired'
            ImplicitUninstallPropertyHint   = $propertySnapshot
            OfferFlags                      = [string]$offerFlags
            ManualReviewRecommendation      = $manualRecommendation
            ConsolePath                     = 'Software Library > Application Management > Applications > Deployment Properties > Deployment Settings'
        })
    }

    $timestamp = Get-SccmTimestampString
    $csvPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ImplicitUninstallReadiness-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject ($results | Sort-Object ApplicationName, CollectionName) -Path $csvPath -Format 'Csv'
    Write-SccmLog -Level 'SUCCESS' -Message ("Implicit uninstall readiness report exported to [{0}]." -f $csvPath)

    if ($ExportJson) {
        $jsonPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ImplicitUninstallReadiness-{0}.json" -f $timestamp)
        $null = Export-SccmData -InputObject ($results | Sort-Object ApplicationName, CollectionName) -Path $jsonPath -Format 'Json'
        Write-SccmLog -Level 'SUCCESS' -Message ("Implicit uninstall readiness JSON exported to [{0}]." -f $jsonPath)
    }

    Write-SccmAuditLog -Action 'SCCM_IMPLICIT_UNINSTALL_READINESS_AUDIT' -Result 'Success' -AdditionalData @{ ResultCount = $results.Count }

    if ($PassThru) {
        return $results.ToArray()
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}