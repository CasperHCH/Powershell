<#
.SYNOPSIS
    Reports current SCCM collection membership and optional drift from a baseline.

.DESCRIPTION
    Exports a current membership snapshot for matching device collections and,
    when a baseline CSV is provided, compares the current membership against the
    baseline to identify added and removed members.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER CollectionName
    Collection name filter. At least one matching collection is required.

.PARAMETER BaselineCsvPath
    Optional baseline CSV exported by a previous run.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns current snapshot rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-CollectionMembershipDriftReport.ps1 -CollectionName Firefox

.EXAMPLE
    .\SCCM-CollectionMembershipDriftReport.ps1 -CollectionName Firefox -BaselineCsvPath .\baseline.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$BaselineCsvPath,

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

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = "root/SMS/site_$resolvedSiteCode"

    $collections = @(Get-CMDeviceCollection -Name "*$CollectionName*" -ErrorAction SilentlyContinue)
    if ($collections.Count -eq 0) {
        throw ("No collections matched filter [{0}]." -f $CollectionName)
    }

    $snapshotRows = New-Object System.Collections.Generic.List[object]

    foreach ($collection in $collections) {
        $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        $collectionNameValue = [string](Get-SccmObjectPropertyValue -InputObject $collection -PropertyNames @('Name', 'CollectionName'))

        $members = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_FullCollectionMembership' -Filter ("CollectionID='{0}'" -f $collectionId) -ErrorAction SilentlyContinue)
        foreach ($member in $members) {
            [void]$snapshotRows.Add([pscustomobject]@{
                CollectionName = $collectionNameValue
                CollectionId   = $collectionId
                ResourceId     = [string](Get-SccmObjectPropertyValue -InputObject $member -PropertyNames @('ResourceID', 'ResourceId'))
                DeviceName     = [string](Get-SccmObjectPropertyValue -InputObject $member -PropertyNames @('Name', 'NetbiosName'))
            })
        }
    }

    $timestamp = Get-SccmTimestampString
    $snapshotPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-CollectionMembershipSnapshot-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject ($snapshotRows | Sort-Object CollectionName, DeviceName) -Path $snapshotPath -Format 'Csv'
    Write-SccmLog -Level 'SUCCESS' -Message ("Collection membership snapshot exported to [{0}]." -f $snapshotPath)

    if (-not [string]::IsNullOrWhiteSpace($BaselineCsvPath)) {
        $baselineRows = @(Import-Csv -Path $BaselineCsvPath)
        $currentKeys = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        $baselineKeys = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($row in $snapshotRows) {
            [void]$currentKeys.Add(("{0}|{1}|{2}" -f $row.CollectionId, $row.ResourceId, $row.DeviceName))
        }
        foreach ($row in $baselineRows) {
            [void]$baselineKeys.Add(("{0}|{1}|{2}" -f $row.CollectionId, $row.ResourceId, $row.DeviceName))
        }

        $driftRows = New-Object System.Collections.Generic.List[object]
        foreach ($row in $snapshotRows) {
            $key = ("{0}|{1}|{2}" -f $row.CollectionId, $row.ResourceId, $row.DeviceName)
            if (-not $baselineKeys.Contains($key)) {
                [void]$driftRows.Add([pscustomobject]@{ DriftType = 'Added'; CollectionName = $row.CollectionName; CollectionId = $row.CollectionId; ResourceId = $row.ResourceId; DeviceName = $row.DeviceName })
            }
        }
        foreach ($row in $baselineRows) {
            $key = ("{0}|{1}|{2}" -f $row.CollectionId, $row.ResourceId, $row.DeviceName)
            if (-not $currentKeys.Contains($key)) {
                [void]$driftRows.Add([pscustomobject]@{ DriftType = 'Removed'; CollectionName = $row.CollectionName; CollectionId = $row.CollectionId; ResourceId = $row.ResourceId; DeviceName = $row.DeviceName })
            }
        }

        $driftPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-CollectionMembershipDrift-{0}.csv" -f $timestamp)
        $null = Export-SccmData -InputObject ($driftRows | Sort-Object DriftType, CollectionName, DeviceName) -Path $driftPath -Format 'Csv'
        Write-SccmLog -Level 'SUCCESS' -Message ("Collection membership drift report exported to [{0}]." -f $driftPath)
    }

    Write-SccmAuditLog -Action 'SCCM_COLLECTION_MEMBERSHIP_DRIFT' -Result 'Success' -AdditionalData @{ SnapshotRows = @($snapshotRows).Count }

    if ($PassThru) {
        return @($snapshotRows)
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
