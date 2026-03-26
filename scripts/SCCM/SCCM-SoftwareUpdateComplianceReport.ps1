<#
.SYNOPSIS
    Exports a software update compliance dashboard from Configuration Manager.

.DESCRIPTION
    Builds a read-only software update compliance report by querying software
    update deployment asset detail classes in the SCCM provider and aggregating
    results by collection and deployment. The script is intended for operations
    review, dashboard export, and compliance trend baselining.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER CollectionName
    Optional collection name filter.

.PARAMETER DeploymentName
    Optional update deployment name filter.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns summary rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-SoftwareUpdateComplianceReport.ps1 -SiteCode P01

.EXAMPLE
    .\SCCM-SoftwareUpdateComplianceReport.ps1 -CollectionName Workstations -DeploymentName Monthly
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [string]$DeploymentName,

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

function Resolve-UpdateComplianceBucket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $InputObject
    )

    $rawStatus = [string](Get-SccmObjectPropertyValue -InputObject $InputObject -PropertyNames @('Status', 'StatusType', 'ComplianceState', 'EnforcementState'))
    $normalizedStatus = $rawStatus.Trim().ToLowerInvariant()

    switch -Regex ($normalizedStatus) {
        'installed|success|compliant|3' { return 'Installed' }
        'missing|required|noncompliant|2' { return 'Missing' }
        'failed|error|4' { return 'Failed' }
        'progress|waiting|1' { return 'InProgress' }
        default { return 'Unknown' }
    }
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = "root/SMS/site_$resolvedSiteCode"

    Write-SccmLog -Level 'INFO' -Message ("Collecting software update compliance data from site [{0}]." -f $resolvedSiteCode)

    $detailRows = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_SUMDeploymentAssetDetails' -ErrorAction Stop)

    if (-not [string]::IsNullOrWhiteSpace($CollectionName)) {
        $detailRows = @($detailRows | Where-Object {
            $resolvedCollectionName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionName', 'TargetCollectionName'))
            $resolvedCollectionName -like "*$CollectionName*"
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($DeploymentName)) {
        $detailRows = @($detailRows | Where-Object {
            $resolvedDeploymentName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('AssignmentName', 'DeploymentName', 'SoftwareName'))
            $resolvedDeploymentName -like "*$DeploymentName*"
        })
    }

    $detailOutput = @($detailRows | ForEach-Object {
        [pscustomobject]@{
            CollectionName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionName', 'TargetCollectionName'))
            DeploymentName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('AssignmentName', 'DeploymentName', 'SoftwareName'))
            DeviceName     = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('DeviceName', 'MachineName', 'NetbiosName'))
            ResourceId     = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ResourceID', 'ResourceId'))
            ComplianceBucket = Resolve-UpdateComplianceBucket -InputObject $_
            RawStatus      = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Status', 'StatusType', 'ComplianceState', 'EnforcementState'))
            LastMessageTime = Resolve-SccmDateTime -Value (Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('LastStatusTime', 'ModificationTime') -AsDateTime)
        }
    })

    $summaryOutput = @($detailOutput | Group-Object CollectionName, DeploymentName | ForEach-Object {
        $collectionNameParts = [string]$_.Name -split ', '
        $groupRows = @($_.Group)
        [pscustomobject]@{
            CollectionName   = $collectionNameParts[0]
            DeploymentName   = if ($collectionNameParts.Count -gt 1) { $collectionNameParts[1] } else { '' }
            TargetedClients  = $groupRows.Count
            InstalledClients = @($groupRows | Where-Object { $_.ComplianceBucket -eq 'Installed' }).Count
            MissingClients   = @($groupRows | Where-Object { $_.ComplianceBucket -eq 'Missing' }).Count
            FailedClients    = @($groupRows | Where-Object { $_.ComplianceBucket -eq 'Failed' }).Count
            InProgressClients = @($groupRows | Where-Object { $_.ComplianceBucket -eq 'InProgress' }).Count
            UnknownClients   = @($groupRows | Where-Object { $_.ComplianceBucket -eq 'Unknown' }).Count
            CompliancePercent = if ($groupRows.Count -gt 0) {
                [math]::Round((@($groupRows | Where-Object { $_.ComplianceBucket -eq 'Installed' }).Count / $groupRows.Count) * 100, 2)
            }
            else {
                0
            }
        }
    } | Sort-Object CollectionName, DeploymentName)

    $timestamp = Get-SccmTimestampString
    $summaryPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-SoftwareUpdateComplianceSummary-{0}.csv" -f $timestamp)
    $detailPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-SoftwareUpdateComplianceDetail-{0}.csv" -f $timestamp)

    $null = Export-SccmData -InputObject $summaryOutput -Path $summaryPath -Format 'Csv'
    $null = Export-SccmData -InputObject $detailOutput -Path $detailPath -Format 'Csv'

    Write-SccmLog -Level 'SUCCESS' -Message ("Software update compliance summary exported to [{0}]." -f $summaryPath)
    Write-SccmLog -Level 'SUCCESS' -Message ("Software update compliance detail exported to [{0}]." -f $detailPath)
    Write-SccmAuditLog -Action 'SCCM_SOFTWARE_UPDATE_COMPLIANCE_REPORT' -Result 'Success' -AdditionalData @{ SummaryRows = $summaryOutput.Count; DetailRows = $detailOutput.Count }

    if ($PassThru) {
        return $summaryOutput
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
