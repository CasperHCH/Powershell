<#
.SYNOPSIS
    Builds a Configuration Manager deployment failure report.

.DESCRIPTION
    Queries deployments in the specified site and produces a summary report of
    deployments that contain failed, unknown, or in-progress states. When asset
    detail classes are available in the provider, the script also produces a
    detail report containing device-level deployment failures.

    The script is read-only and safe to rerun.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER DeploymentName
    Optional deployment name filter.

.PARAMETER CollectionName
    Optional collection name filter.

.PARAMETER IncludeAssetDetails
    Attempts to collect asset-level deployment detail rows.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns the summary results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-DeploymentFailureReport.ps1 -SiteCode P01 -IncludeAssetDetails

.EXAMPLE
    .\SCCM-DeploymentFailureReport.ps1 -DeploymentName Chrome
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$DeploymentName,

    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAssetDetails,

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

function Get-DeploymentMetricValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    $value = Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames $PropertyNames
    if ($null -eq $value) {
        return 0
    }

    try {
        return [int]$value
    }
    catch {
        return 0
    }
}

function Get-DeploymentAssetDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentId,

        [Parameter(Mandatory = $false)]
        [string]$ResolvedDeploymentName,

        [Parameter(Mandatory = $false)]
        [string]$ResolvedCollectionName
    )

    $namespace = "root/SMS/site_$SiteCode"
    $detailClasses = @(
        'SMS_AppDeploymentAssetDetails'
        'SMS_ClassicDeploymentAssetDetails'
        'SMS_SUMDeploymentAssetDetails'
    )

    foreach ($detailClass in $detailClasses) {
        try {
            $classRows = @(Get-CimInstance -Namespace $namespace -ClassName $detailClass -ErrorAction Stop | Where-Object {
                $rowDeploymentId = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('AssignmentID', 'AssignmentId', 'DeploymentID', 'DeploymentId'))
                $rowDeploymentId -eq $DeploymentId
            })

            if ($classRows.Count -eq 0) {
                continue
            }

            return @($classRows | ForEach-Object {
                [pscustomobject]@{
                    DeploymentId   = $DeploymentId
                    DeploymentName = $ResolvedDeploymentName
                    CollectionName = $ResolvedCollectionName
                    DeviceName     = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('DeviceName', 'MachineName', 'NetbiosName'))
                    ResourceId     = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ResourceID', 'ResourceId', 'MachineID'))
                    Status         = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('StatusType', 'Status', 'EnforcementState'))
                    ErrorCode      = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ErrorCode', 'LastErrorCode'))
                    ErrorDescription = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ErrorDescription', 'StatusDescription', 'StatusMessage'))
                    DetailClass    = $detailClass
                }
            })
        }
        catch {
            Write-SccmLog -Level 'DEBUG' -Message ("Asset detail class [{0}] query failed for deployment [{1}]: {2}" -f $detailClass, $DeploymentId, $_.Exception.Message)
        }
    }

    return @()
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    Write-SccmLog -Level 'INFO' -Message ("Connected to SCCM site [{0}]." -f $resolvedSiteCode)

    $deployments = @(Get-CMDeployment -ErrorAction SilentlyContinue)

    if (-not [string]::IsNullOrWhiteSpace($DeploymentName)) {
        $deployments = @($deployments | Where-Object {
            $name = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))
            $name -like "*$DeploymentName*"
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($CollectionName)) {
        $deployments = @($deployments | Where-Object {
            $targetCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionName', 'TargetCollectionName'))
            $targetCollectionName -like "*$CollectionName*"
        })
    }

    $summaryResults = New-Object System.Collections.Generic.List[object]
    $detailResults = New-Object System.Collections.Generic.List[object]

    foreach ($deployment in $deployments) {
        $resolvedDeploymentId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id'))
        $resolvedDeploymentName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('SoftwareName', 'ApplicationName', 'DeploymentName', 'PackageName'))
        $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName'))
        $deploymentIntent = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('DeploymentIntent', 'Purpose'))

        $successCount = Get-DeploymentMetricValue -InputObject $deployment -PropertyNames @('NumberSuccess', 'SuccessCount', 'Success')
        $inProgressCount = Get-DeploymentMetricValue -InputObject $deployment -PropertyNames @('NumberInProgress', 'InProgressCount', 'InProgress')
        $unknownCount = Get-DeploymentMetricValue -InputObject $deployment -PropertyNames @('NumberUnknown', 'UnknownCount', 'Unknown')
        $errorCount = Get-DeploymentMetricValue -InputObject $deployment -PropertyNames @('NumberErrors', 'ErrorCount', 'Errors')
        $targetCount = Get-DeploymentMetricValue -InputObject $deployment -PropertyNames @('NumberTargeted', 'TargetCount', 'Targeted')

        if (($errorCount + $unknownCount + $inProgressCount) -eq 0) {
            continue
        }

        $summaryResult = [pscustomobject]@{
            DeploymentId   = $resolvedDeploymentId
            DeploymentName = $resolvedDeploymentName
            CollectionName = $resolvedCollectionName
            Intent         = $deploymentIntent
            TargetCount    = $targetCount
            SuccessCount   = $successCount
            InProgressCount = $inProgressCount
            UnknownCount   = $unknownCount
            ErrorCount     = $errorCount
            FailureRank    = ($errorCount * 1000) + ($unknownCount * 100) + $inProgressCount
        }

        [void]$summaryResults.Add($summaryResult)

        if ($IncludeAssetDetails -and -not [string]::IsNullOrWhiteSpace($resolvedDeploymentId)) {
            foreach ($detailRow in Get-DeploymentAssetDetail -SiteCode $resolvedSiteCode -DeploymentId $resolvedDeploymentId -ResolvedDeploymentName $resolvedDeploymentName -ResolvedCollectionName $resolvedCollectionName) {
                [void]$detailResults.Add($detailRow)
            }
        }
    }

    $timestamp = Get-SccmTimestampString
    $summaryPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-DeploymentFailureSummary-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject (@($summaryResults) | Sort-Object FailureRank -Descending, DeploymentName) -Path $summaryPath -Format 'Csv'
    Write-SccmLog -Level 'SUCCESS' -Message ("Deployment failure summary exported to [{0}]." -f $summaryPath)

    if ($detailResults.Count -gt 0) {
        $detailPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-DeploymentFailureDetails-{0}.csv" -f $timestamp)
        $null = Export-SccmData -InputObject (@($detailResults) | Sort-Object DeploymentName, DeviceName) -Path $detailPath -Format 'Csv'
        Write-SccmLog -Level 'SUCCESS' -Message ("Deployment failure detail exported to [{0}]." -f $detailPath)
    }

    Write-SccmAuditLog -Action 'SCCM_DEPLOYMENT_FAILURE_REPORT' -Result 'Success' -AdditionalData @{ DeploymentRows = $summaryResults.Count; DetailRows = $detailResults.Count }

    if ($PassThru) {
        return @($summaryResults)
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
