<#
.SYNOPSIS
    Analyzes stale SCCM collections and deployments.

.DESCRIPTION
    Produces a read-only hygiene report for device collections and deployments.
    The script flags objects that are empty, undeployed, orphaned, or appear
    inactive for longer than the configured threshold.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER InactiveDays
    Number of days used to classify collections or deployments as stale.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns stale candidate rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-AnalyzeStaleCollectionsAndDeployments.ps1 -SiteCode P01
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [ValidateRange(7, 3650)]
    [int]$InactiveDays = 90,

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

function ConvertTo-IntegerValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return 0
    }

    try {
        return [int]$Value
    }
    catch {
        return 0
    }
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    Write-SccmLog -Level 'INFO' -Message 'Collecting collections and deployments for stale-object analysis.'

    $collections = @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)
    $deployments = @(Get-CMDeployment -ErrorAction SilentlyContinue)
    $cutoffDate = (Get-Date).AddDays(-1 * $InactiveDays)

    $deploymentsByCollectionId = @{}
    foreach ($deployment in $deployments) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID', 'TargetCollectionId'))
        if ([string]::IsNullOrWhiteSpace($collectionId)) {
            continue
        }

        if (-not $deploymentsByCollectionId.ContainsKey($collectionId)) {
            $deploymentsByCollectionId[$collectionId] = New-Object System.Collections.Generic.List[object]
        }

        [void]$deploymentsByCollectionId[$collectionId].Add($deployment)
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($collection in $collections) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        $collectionName = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('Name', 'CollectionName'))
        $memberCount = ConvertTo-IntegerValue -Value (Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('MemberCount', 'LocalMemberCount', 'CurrentStatus'))
        $lastRefresh = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('LastRefreshTime', 'LastMemberChangeTime', 'LastChangeTime') -AsDateTime)
        $reasonList = New-Object System.Collections.Generic.List[string]

        $linkedDeployments = if ($deploymentsByCollectionId.ContainsKey($collectionId)) { @($deploymentsByCollectionId[$collectionId]) } else { @() }

        if ($memberCount -eq 0) {
            [void]$reasonList.Add('Collection has zero members.')
        }
        if ($linkedDeployments.Count -eq 0) {
            [void]$reasonList.Add('Collection has no linked deployments.')
        }
        if ($null -ne $lastRefresh -and $lastRefresh -lt $cutoffDate) {
            [void]$reasonList.Add(("Collection refresh is older than {0} days." -f $InactiveDays))
        }

        if (@($reasonList).Count -gt 0) {
            [void]$results.Add([pscustomobject]@{
                ObjectType      = 'Collection'
                Name            = $collectionName
                Identifier      = $collectionId
                MemberCount     = $memberCount
                LastActivity    = $lastRefresh
                RelatedCount    = $linkedDeployments.Count
                ReasonCount     = @($reasonList).Count
                Reasons         = ($reasonList -join ' | ')
            })
        }
    }

    $knownCollectionIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($collection in $collections) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            [void]$knownCollectionIds.Add($collectionId)
        }
    }

    foreach ($deployment in $deployments) {
        $deploymentId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id'))
        $deploymentName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID', 'TargetCollectionId'))
        $targetCount = ConvertTo-IntegerValue -Value (Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('NumberTargeted', 'TargetCount', 'Targeted'))
        $lastModified = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('ModificationTime', 'LastModificationTime', 'CreationTime') -AsDateTime)
        $reasonList = New-Object System.Collections.Generic.List[string]

        if ($targetCount -eq 0) {
            [void]$reasonList.Add('Deployment target count is zero.')
        }
        if (-not [string]::IsNullOrWhiteSpace($collectionId) -and -not $knownCollectionIds.Contains($collectionId)) {
            [void]$reasonList.Add('Deployment references a collection that was not resolved in current collection inventory.')
        }
        if ($null -ne $lastModified -and $lastModified -lt $cutoffDate) {
            [void]$reasonList.Add(("Deployment has not changed in more than {0} days." -f $InactiveDays))
        }

        if (@($reasonList).Count -gt 0) {
            [void]$results.Add([pscustomobject]@{
                ObjectType      = 'Deployment'
                Name            = $deploymentName
                Identifier      = $deploymentId
                MemberCount     = $targetCount
                LastActivity    = $lastModified
                RelatedCount    = 0
                ReasonCount     = @($reasonList).Count
                Reasons         = ($reasonList -join ' | ')
            })
        }
    }

    $timestamp = Get-SccmTimestampString
    $reportPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-StaleObjects-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject ($results | Sort-Object ObjectType, Name) -Path $reportPath -Format 'Csv'

    Write-SccmLog -Level 'SUCCESS' -Message ("Stale object report exported to [{0}]." -f $reportPath)
    Write-SccmAuditLog -Action 'SCCM_STALE_OBJECT_ANALYSIS' -Result 'Success' -AdditionalData @{ ResultCount = @($results).Count }

    if ($PassThru) {
        return @($results)
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
