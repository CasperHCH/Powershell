<#
.SYNOPSIS
    Finds deployment, task sequence, and collection references for SCCM objects.

.DESCRIPTION
    Produces a read-only impact analysis report for applications, packages, or
    collections. The script looks for deployment references, collection
    dependency references, and task sequence references so cleanup or rename
    operations can be evaluated safely before changes are made.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ApplicationName
    Application display name filter.

.PARAMETER PackageId
    Package identifier filter.

.PARAMETER CollectionName
    Collection name filter.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns impact rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-ReferenceImpactAnalysis.ps1 -ApplicationName Firefox

.EXAMPLE
    .\SCCM-ReferenceImpactAnalysis.ps1 -CollectionName "Mozilla Firefox - Install (Required)"
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [string]$PackageId,

    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

if ([string]::IsNullOrWhiteSpace($ApplicationName) -and [string]::IsNullOrWhiteSpace($PackageId) -and [string]::IsNullOrWhiteSpace($CollectionName)) {
    throw 'Provide at least one of -ApplicationName, -PackageId, or -CollectionName.'
}

function Add-ImpactRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$List,

        [Parameter(Mandatory = $true)]
        [string]$ReferenceType,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [string]$SourceName,

        [Parameter(Mandatory = $false)]
        [string]$SourceId,

        [Parameter(Mandatory = $false)]
        [string]$Impact,

        [Parameter(Mandatory = $false)]
        [string]$Notes
    )

    [void]$List.Add([pscustomobject]@{
        ReferenceType = $ReferenceType
        Target        = $Target
        SourceName    = $SourceName
        SourceId      = $SourceId
        Impact        = $Impact
        Notes         = $Notes
    })
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode

    $results = New-Object System.Collections.Generic.List[object]
    $deployments = @(Get-CMDeployment -ErrorAction SilentlyContinue)
    $collections = @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)

    if (-not [string]::IsNullOrWhiteSpace($ApplicationName)) {
        $applications = @(Get-CMApplication -Name "*$ApplicationName*" -Fast -ErrorAction SilentlyContinue)

        foreach ($deployment in @($deployments | Where-Object {
            $softwareName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))
            $softwareName -like "*$ApplicationName*"
        })) {
            Add-ImpactRow -List $results -ReferenceType 'Deployment' -Target $ApplicationName -SourceName ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName'))) -SourceId ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentID', 'AssignmentID'))) -Impact 'Changing or deleting the application may affect this deployment.' -Notes ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName')))
        }

        $taskSequences = @()
        try {
            $taskSequences = @(Get-CMTaskSequence -Fast -ErrorAction SilentlyContinue)
        }
        catch {
            $taskSequences = @(Get-CMTaskSequence -ErrorAction SilentlyContinue)
        }

        foreach ($application in $applications) {
            $appId = [string](Get-SccmObjectPropertyValue -InputObject $application -PropertyNames @('CI_ID', 'Id'))
            $modelName = [string](Get-SccmObjectPropertyValue -InputObject $application -PropertyNames @('ModelName'))
            foreach ($taskSequence in $taskSequences) {
                $sequenceText = [string](Get-SccmObjectPropertyValue -InputObject $taskSequence -PropertyNames @('Sequence'))
                if ([string]::IsNullOrWhiteSpace($sequenceText)) {
                    continue
                }

                if ((-not [string]::IsNullOrWhiteSpace($appId) -and $sequenceText -match [regex]::Escape($appId)) -or (-not [string]::IsNullOrWhiteSpace($modelName) -and $sequenceText -match [regex]::Escape($modelName))) {
                    Add-ImpactRow -List $results -ReferenceType 'TaskSequence' -Target $ApplicationName -SourceName ([string](Get-SccmObjectPropertyValue -InputObject $taskSequence -PropertyNames @('Name'))) -SourceId ([string](Get-SccmObjectPropertyValue -InputObject $taskSequence -PropertyNames @('PackageID', 'PackageId'))) -Impact 'Task sequence install steps reference this application.' -Notes 'Detected via task sequence Sequence content.'
                }
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PackageId)) {
        foreach ($deployment in @($deployments | Where-Object {
            $deploymentId = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('DeploymentID', 'AssignmentID', 'PackageID', 'PackageId'))
            $deploymentId -like "*$PackageId*"
        })) {
            Add-ImpactRow -List $results -ReferenceType 'Deployment' -Target $PackageId -SourceName ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))) -SourceId ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentID', 'AssignmentID', 'PackageID'))) -Impact 'Deployment metadata matched the package identifier filter.' -Notes ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName')))
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($CollectionName)) {
        $matchingCollections = @($collections | Where-Object {
            $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Name', 'CollectionName'))
            $resolvedCollectionName -like "*$CollectionName*"
        })

        foreach ($collection in $matchingCollections) {
            $resolvedCollectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
            $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('Name', 'CollectionName'))

            foreach ($deployment in @($deployments | Where-Object {
                [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionName', 'TargetCollectionName')) -eq $resolvedCollectionName -or
                [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID', 'TargetCollectionId')) -eq $resolvedCollectionId
            })) {
                Add-ImpactRow -List $results -ReferenceType 'CollectionDeployment' -Target $resolvedCollectionName -SourceName ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))) -SourceId ([string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentID', 'AssignmentID'))) -Impact 'Deployment targets this collection.' -Notes ''
            }

            foreach ($candidate in $collections) {
                $candidateId = [string](Get-SccmObjectPropertyValue -InputObject $candidate -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
                $candidateName = [string](Get-SccmObjectPropertyValue -InputObject $candidate -PropertyNames @('Name', 'CollectionName'))

                try {
                    foreach ($rule in @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $candidateId -ErrorAction SilentlyContinue)) {
                        $targetId = [string](Get-SccmObjectPropertyValue -InputObject $rule -PropertyNames @('IncludeCollectionID', 'IncludeCollectionId', 'ReferencedCollectionID', 'ReferencedCollectionId'))
                        if ($targetId -eq $resolvedCollectionId) {
                            Add-ImpactRow -List $results -ReferenceType 'CollectionIncludeRule' -Target $resolvedCollectionName -SourceName $candidateName -SourceId $candidateId -Impact 'This collection is included by another collection.' -Notes ''
                        }
                    }

                    foreach ($rule in @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $candidateId -ErrorAction SilentlyContinue)) {
                        $targetId = [string](Get-SccmObjectPropertyValue -InputObject $rule -PropertyNames @('ExcludeCollectionID', 'ExcludeCollectionId', 'ReferencedCollectionID', 'ReferencedCollectionId'))
                        if ($targetId -eq $resolvedCollectionId) {
                            Add-ImpactRow -List $results -ReferenceType 'CollectionExcludeRule' -Target $resolvedCollectionName -SourceName $candidateName -SourceId $candidateId -Impact 'This collection is excluded by another collection.' -Notes ''
                        }
                    }
                }
                catch {
                    Write-SccmLog -Level 'DEBUG' -Message ("Collection dependency query failed for [{0}]: {1}" -f $candidateName, $_.Exception.Message)
                }

                $limitingCollectionId = [string](Get-SccmObjectPropertyValue -InputObject $candidate -PropertyNames @('LimitToCollectionID', 'LimitToCollectionId', 'LimitingCollectionID', 'LimitingCollectionId'))
                if ($limitingCollectionId -eq $resolvedCollectionId) {
                    Add-ImpactRow -List $results -ReferenceType 'LimitingCollection' -Target $resolvedCollectionName -SourceName $candidateName -SourceId $candidateId -Impact 'This collection is used as a limiting collection.' -Notes ''
                }
            }
        }
    }

    $timestamp = Get-SccmTimestampString
    $reportPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ReferenceImpactAnalysis-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject ($results | Sort-Object ReferenceType, SourceName) -Path $reportPath -Format 'Csv'

    Write-SccmLog -Level 'SUCCESS' -Message ("Reference impact report exported to [{0}]." -f $reportPath)
    Write-SccmAuditLog -Action 'SCCM_REFERENCE_IMPACT_ANALYSIS' -Result 'Success' -AdditionalData @{ ResultCount = @($results).Count }

    if ($PassThru) {
        return @($results)
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
