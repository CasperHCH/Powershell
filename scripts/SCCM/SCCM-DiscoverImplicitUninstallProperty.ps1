<#
.SYNOPSIS
    Discovers whether SCCM exposes a scriptable property for implicit uninstall.

.DESCRIPTION
    Captures a snapshot of an application deployment and its backing
    SMS_ApplicationAssignment properties, then optionally compares that snapshot
    to a later capture after you manually toggle the implicit uninstall checkbox
    in the SCCM console.

    This script is read-only. It does not modify deployments.

    Intended workflow:
    1. Run once before changing the deployment in the console.
    2. Enable or disable the implicit uninstall checkbox for one deployment.
    3. Run again with -BaselineSnapshotPath pointing to the first snapshot.
    4. Review the diff output to determine whether SCCM exposes a stable
       property that could be automated.

    Important:
    - Microsoft documents the implicit uninstall feature in the console UI.
    - Microsoft does not document a PowerShell parameter on
      New-CMApplicationDeployment or Set-CMApplicationDeployment to enable it.
    - If this script doesn't show a clear property change, bulk automation would
      require unsupported reverse engineering or UI automation.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ApplicationName
    Exact application display name.

.PARAMETER CollectionName
    Exact target collection name for the deployment.

.PARAMETER BaselineSnapshotPath
    Optional path to a previous snapshot JSON file. When provided, the script
    captures a fresh snapshot and compares it to the baseline.

.PARAMETER OutputDirectory
    Output directory for snapshot and diff files.

.PARAMETER ExportJson
    Also exports the diff result as JSON when comparing.

.PARAMETER EnableDebugLog
    Enables DEBUG logging.

.EXAMPLE
    .\SCCM-DiscoverImplicitUninstallProperty.ps1 -SiteCode P03 -ApplicationName '7-Zip 25.01 (build 1)' -CollectionName '7-zip - Install (Required)'

.EXAMPLE
    .\SCCM-DiscoverImplicitUninstallProperty.ps1 -SiteCode P03 -ApplicationName '7-Zip 25.01 (build 1)' -CollectionName '7-zip - Install (Required)' -BaselineSnapshotPath '.\output\ImplicitUninstallSnapshot-before.json' -ExportJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CollectionName,

    [Parameter(Mandatory = $false)]
    [string]$BaselineSnapshotPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$ExportJson,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

function Convert-SccmValueToComparableString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [datetime]) {
        return $Value.ToString('o')
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [ValueType]) {
        return [string]$Value
    }

    try {
        return ($Value | ConvertTo-Json -Compress -Depth 8)
    }
    catch {
        return [string]$Value
    }
}

function Convert-ObjectToPropertyMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $InputObject
    )

    $map = [ordered]@{}

    if ($null -eq $InputObject) {
        return $map
    }

    foreach ($property in @($InputObject.PSObject.Properties | Sort-Object Name)) {
        if ($null -eq $property) {
            continue
        }

        $propertyName = [string]$property.Name
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        $map[$propertyName] = Convert-SccmValueToComparableString -Value $property.Value
    }

    return $map
}

function Get-TargetDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $deploymentMatches = @(Get-CMApplicationDeployment | Where-Object {
        $_.ApplicationName -eq $ApplicationName -and $_.CollectionName -eq $CollectionName
    })

    if ($deploymentMatches.Count -eq 0) {
        throw ('No application deployment found for application [{0}] and collection [{1}].' -f $ApplicationName, $CollectionName)
    }

    if ($deploymentMatches.Count -gt 1) {
        throw ('Multiple application deployments matched application [{0}] and collection [{1}]. Narrow the target before comparing.' -f $ApplicationName, $CollectionName)
    }

    return $deploymentMatches[0]
}

function Get-ApplicationAssignmentRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $DeploymentObject
    )

    $namespace = 'root\SMS\site_{0}' -f $SiteCode
    $assignmentId = Get-SccmObjectPropertyValue -InputObject $DeploymentObject -PropertyNames @('AssignmentID', 'AssignmentId', 'DeploymentID', 'DeploymentId')

    if ($null -ne $assignmentId -and [string]::IsNullOrWhiteSpace([string]$assignmentId) -eq $false) {
        $assignment = Get-CimInstance -Namespace $namespace -ClassName SMS_ApplicationAssignment -Filter ("AssignmentID = {0}" -f [int]$assignmentId) -ErrorAction SilentlyContinue
        if ($null -ne $assignment) {
            return $assignment
        }
    }

    $escapedCollectionId = $CollectionId.Replace("'", "''")
    $escapedApplicationName = $ApplicationName.Replace("'", "''")
    $assignmentMatches = @(Get-CimInstance -Namespace $namespace -ClassName SMS_ApplicationAssignment -Filter ("TargetCollectionID = '{0}' AND ApplicationName = '{1}'" -f $escapedCollectionId, $escapedApplicationName) -ErrorAction Stop)

    if ($assignmentMatches.Count -eq 0) {
        throw ('No SMS_ApplicationAssignment record found for application [{0}] and collection [{1}].' -f $ApplicationName, $CollectionId)
    }

    if ($assignmentMatches.Count -gt 1) {
        throw ('Multiple SMS_ApplicationAssignment records matched application [{0}] and collection [{1}]. Narrow the target before comparing.' -f $ApplicationName, $CollectionId)
    }

    return $assignmentMatches[0]
}

function Get-DeploymentSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $deployment = Get-TargetDeployment -ApplicationName $ApplicationName -CollectionName $CollectionName
    $collectionId = [string](Get-SccmObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionID', 'CollectionId', 'TargetCollectionID'))
    if ([string]::IsNullOrWhiteSpace($collectionId)) {
        throw ('Unable to resolve collection ID for deployment [{0}] / [{1}].' -f $ApplicationName, $CollectionName)
    }

    $assignment = Get-ApplicationAssignmentRecord -SiteCode $SiteCode -CollectionId $collectionId -ApplicationName $ApplicationName -DeploymentObject $deployment
    $assignmentId = [string](Get-SccmObjectPropertyValue -InputObject $assignment -PropertyNames @('AssignmentID'))

    return [pscustomobject]@{
        SnapshotCapturedAt = (Get-Date).ToString('o')
        SiteCode           = $SiteCode
        ApplicationName    = $ApplicationName
        CollectionName     = $CollectionName
        CollectionId       = $collectionId
        AssignmentId       = $assignmentId
        DeploymentObject   = [pscustomobject](Convert-ObjectToPropertyMap -InputObject $deployment)
        AssignmentObject   = [pscustomobject](Convert-ObjectToPropertyMap -InputObject $assignment)
    }
}

function Compare-PropertyMaps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$BeforeObject,

        [Parameter(Mandatory = $true)]
        [psobject]$AfterObject,

        [Parameter(Mandatory = $true)]
        [string]$SourceName
    )

    $beforeMap = @{}
    foreach ($property in @($BeforeObject.PSObject.Properties)) {
        $beforeMap[[string]$property.Name] = [string]$property.Value
    }

    $afterMap = @{}
    foreach ($property in @($AfterObject.PSObject.Properties)) {
        $afterMap[[string]$property.Name] = [string]$property.Value
    }

    $allKeys = @($beforeMap.Keys + $afterMap.Keys | Sort-Object -Unique)
    $changes = New-Object System.Collections.Generic.List[object]

    foreach ($key in $allKeys) {
        $beforeValue = if ($beforeMap.ContainsKey($key)) { $beforeMap[$key] } else { '' }
        $afterValue = if ($afterMap.ContainsKey($key)) { $afterMap[$key] } else { '' }

        if ($beforeValue -ceq $afterValue) {
            continue
        }

        [void]$changes.Add([pscustomobject]@{
            Source       = $SourceName
            PropertyName = $key
            BeforeValue  = $beforeValue
            AfterValue   = $afterValue
        })
    }

    return $changes.ToArray()
}

$connection = $null

try {
    $connection = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string]$connection.SiteCode

    Write-SccmLog -Level 'INFO' -Message ('Capturing deployment snapshot for application [{0}] and collection [{1}] on site [{2}].' -f $ApplicationName, $CollectionName, $resolvedSiteCode)
    $snapshot = Get-DeploymentSnapshot -SiteCode $resolvedSiteCode -ApplicationName $ApplicationName -CollectionName $CollectionName

    $safeApplicationName = ($ApplicationName -replace '[^A-Za-z0-9._-]', '_')
    $safeCollectionName = ($CollectionName -replace '[^A-Za-z0-9._-]', '_')
    $timestamp = Get-SccmTimestampString

    $snapshotPath = Resolve-SccmOutputPath -FileName ('ImplicitUninstallSnapshot-{0}-{1}-{2}.json' -f $safeApplicationName, $safeCollectionName, $timestamp) -OutputDirectory $OutputDirectory -CreateDirectory
    Export-SccmData -InputObject $snapshot -Path $snapshotPath -Format Json | Out-Null
    Write-SccmLog -Level 'SUCCESS' -Message ('Snapshot exported to [{0}].' -f $snapshotPath)

    if ([string]::IsNullOrWhiteSpace($BaselineSnapshotPath)) {
        Write-SccmAuditLog -Action 'IMPLICIT_UNINSTALL_SNAPSHOT_CAPTURED' -Target $CollectionName -Result 'SUCCESS' -AdditionalData @{ SnapshotPath = $snapshotPath; ApplicationName = $ApplicationName }
        return [pscustomobject]@{
            Mode         = 'CaptureOnly'
            SnapshotPath = $snapshotPath
            Message      = 'Capture complete. Toggle the implicit uninstall checkbox in the console, then rerun with -BaselineSnapshotPath to compare.'
        }
    }

    if (-not (Test-Path -Path $BaselineSnapshotPath)) {
        throw ('Baseline snapshot path [{0}] was not found.' -f $BaselineSnapshotPath)
    }

    $baseline = Get-Content -Path $BaselineSnapshotPath -Raw | ConvertFrom-Json -ErrorAction Stop
    $deploymentChanges = @(Compare-PropertyMaps -BeforeObject $baseline.DeploymentObject -AfterObject $snapshot.DeploymentObject -SourceName 'DeploymentObject')
    $assignmentChanges = @(Compare-PropertyMaps -BeforeObject $baseline.AssignmentObject -AfterObject $snapshot.AssignmentObject -SourceName 'AssignmentObject')
    $allChanges = @($deploymentChanges + $assignmentChanges)

    $diffFileName = 'ImplicitUninstallDiff-{0}-{1}-{2}.csv' -f $safeApplicationName, $safeCollectionName, $timestamp
    $diffPath = Resolve-SccmOutputPath -FileName $diffFileName -OutputDirectory $OutputDirectory -CreateDirectory
    Export-SccmData -InputObject $allChanges -Path $diffPath -Format Csv | Out-Null
    Write-SccmLog -Level 'SUCCESS' -Message ('Diff report exported to [{0}].' -f $diffPath)

    $jsonDiffPath = $null
    if ($ExportJson) {
        $jsonDiffPath = Resolve-SccmOutputPath -FileName ($diffFileName -replace '\.csv$', '.json') -OutputDirectory $OutputDirectory -CreateDirectory
        Export-SccmData -InputObject $allChanges -Path $jsonDiffPath -Format Json | Out-Null
        Write-SccmLog -Level 'SUCCESS' -Message ('Diff JSON exported to [{0}].' -f $jsonDiffPath)
    }

    Write-SccmAuditLog -Action 'IMPLICIT_UNINSTALL_SNAPSHOT_COMPARED' -Target $CollectionName -Result 'SUCCESS' -AdditionalData @{
        SnapshotPath         = $snapshotPath
        BaselineSnapshotPath = $BaselineSnapshotPath
        DiffPath             = $diffPath
        JsonDiffPath         = $jsonDiffPath
        ChangedPropertyCount = $allChanges.Count
        ApplicationName      = $ApplicationName
    }

    [pscustomobject]@{
        Mode                 = 'ComparedToBaseline'
        BaselineSnapshotPath = $BaselineSnapshotPath
        SnapshotPath         = $snapshotPath
        DiffPath             = $diffPath
        JsonDiffPath         = $jsonDiffPath
        ChangedPropertyCount = $allChanges.Count
        Message              = if ($allChanges.Count -eq 0) { 'No exposed property changes detected.' } else { 'Comparison complete. Review changed properties for a stable implicit uninstall marker.' }
    }
}
catch {
    Write-SccmAuditLog -Action 'IMPLICIT_UNINSTALL_DISCOVERY_FAILED' -Target $CollectionName -Result 'FAILED' -ErrorMessage $_.Exception.Message -AdditionalData @{ ApplicationName = $ApplicationName }
    throw
}
finally {
    Disconnect-SccmSite -ConnectionContext $connection
}