<#
.SYNOPSIS
    Validates content distribution health across distribution points.

.DESCRIPTION
    Produces summary and detail reports for Configuration Manager content
    distribution by querying package status summarizers and DP-level status
    classes. The report highlights failed, retrying, in-progress, or partially
    distributed content so operators can quickly identify broken distribution
    paths.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ContentName
    Optional content name filter.

.PARAMETER PackageId
    Optional package identifier filter.

.PARAMETER IncludeHealthyContent
    Includes content with no failures or retry conditions.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns summary rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-ValidateContentDistribution.ps1 -SiteCode P01

.EXAMPLE
    .\SCCM-ValidateContentDistribution.ps1 -ContentName Firefox -IncludeHealthyContent
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$ContentName,

    [Parameter(Mandatory = $false)]
    [string]$PackageId,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeHealthyContent,

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

function Get-DistributionMetric {
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

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = "root/SMS/site_$resolvedSiteCode"

    $summaryRows = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_PackageStatusDistPointsSummarizer' -ErrorAction Stop)

    if (-not [string]::IsNullOrWhiteSpace($PackageId)) {
        $summaryRows = @($summaryRows | Where-Object {
            $resolvedPackageId = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('PackageID', 'PackageId'))
            $resolvedPackageId -eq $PackageId
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($ContentName)) {
        $summaryRows = @($summaryRows | Where-Object {
            $resolvedName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Name', 'PackageName', 'SourceName'))
            $resolvedName -like "*$ContentName*"
        })
    }

    $summaryOutput = @($summaryRows | ForEach-Object {
        $installedCount = Get-DistributionMetric -InputObject $_ -PropertyNames @('InstalledCount', 'NumberInstalled', 'Installed')
        $targetedCount = Get-DistributionMetric -InputObject $_ -PropertyNames @('TargetedCount', 'NumberTargeted', 'Targeted')
        $failedCount = Get-DistributionMetric -InputObject $_ -PropertyNames @('FailedCount', 'NumberErrors', 'Errors')
        $retryingCount = Get-DistributionMetric -InputObject $_ -PropertyNames @('RetryingCount', 'Retrying')
        $inProgressCount = Get-DistributionMetric -InputObject $_ -PropertyNames @('InProgressCount', 'NumberInProgress', 'InProgress')

        [pscustomobject]@{
            PackageId       = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('PackageID', 'PackageId'))
            ContentName     = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Name', 'PackageName', 'SourceName'))
            TargetedCount   = $targetedCount
            InstalledCount  = $installedCount
            FailedCount     = $failedCount
            RetryingCount   = $retryingCount
            InProgressCount = $inProgressCount
            SuccessPercent  = if ($targetedCount -gt 0) { [math]::Round(($installedCount / $targetedCount) * 100, 2) } else { 0 }
            DistributionHealth = if ($failedCount -gt 0) {
                'Failed'
            }
            elseif ($retryingCount -gt 0 -or $inProgressCount -gt 0) {
                'Attention'
            }
            else {
                'Healthy'
            }
        }
    })

    if (-not $IncludeHealthyContent) {
        $summaryOutput = @($summaryOutput | Where-Object { $_.DistributionHealth -ne 'Healthy' })
    }

    $detailRows = @()
    try {
        $rawDetailRows = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_DistributionDPStatus' -ErrorAction Stop)
        $detailRows = @($rawDetailRows | ForEach-Object {
            [pscustomobject]@{
                PackageId            = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('PackageID', 'PackageId'))
                ContentName          = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('PackageName', 'Name'))
                DistributionPointName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('NALPath', 'ServerNALPath', 'ServerName'))
                State                = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('State', 'Status', 'MessageState'))
                Message              = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Message', 'StatusMessage', 'LastErrorMessage'))
                LastUpdateTime       = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('LastUpdateTime', 'MessageTime') -AsDateTime)
            }
        })

        if (-not [string]::IsNullOrWhiteSpace($PackageId)) {
            $detailRows = @($detailRows | Where-Object { $_.PackageId -eq $PackageId })
        }

        if (-not [string]::IsNullOrWhiteSpace($ContentName)) {
            $detailRows = @($detailRows | Where-Object { $_.ContentName -like "*$ContentName*" })
        }
    }
    catch {
        Write-SccmLog -Level 'DEBUG' -Message ("DP detail query failed: {0}" -f $_.Exception.Message)
    }

    $timestamp = Get-SccmTimestampString
    $summaryPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ContentDistributionSummary-{0}.csv" -f $timestamp)
    $detailPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ContentDistributionDetail-{0}.csv" -f $timestamp)

    $null = Export-SccmData -InputObject ($summaryOutput | Sort-Object FailedCount -Descending, ContentName) -Path $summaryPath -Format 'Csv'
    Write-SccmLog -Level 'SUCCESS' -Message ("Content distribution summary exported to [{0}]." -f $summaryPath)

    if (@($detailRows).Count -gt 0) {
        $null = Export-SccmData -InputObject ($detailRows | Sort-Object PackageId, DistributionPointName) -Path $detailPath -Format 'Csv'
        Write-SccmLog -Level 'SUCCESS' -Message ("Content distribution detail exported to [{0}]." -f $detailPath)
    }

    Write-SccmAuditLog -Action 'SCCM_CONTENT_DISTRIBUTION_VALIDATION' -Result 'Success' -AdditionalData @{ SummaryRows = @($summaryOutput).Count; DetailRows = @($detailRows).Count }

    if ($PassThru) {
        return $summaryOutput
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
