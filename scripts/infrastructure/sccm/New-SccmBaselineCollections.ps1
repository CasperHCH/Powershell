<#
.SYNOPSIS
    Creates or validates baseline SCCM device collections from the infrastructure manifest.

.DESCRIPTION
    This script reads StandardCollections entries from the SCCM section of the
    manifest, validates the Configuration Manager PowerShell prerequisites,
    checks whether each baseline collection exists, and creates missing device
    collections when not running in validate-only mode.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER ValidateOnly
    Return the collection plan and preflight results without creating collections.

.EXAMPLE
    .\New-SccmBaselineCollections.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$sccmConfig = $manifest.SCCM
$standardCollections = @($sccmConfig.StandardCollections)
$checks = New-Object 'System.Collections.Generic.List[object]'
$existingCollections = New-Object 'System.Collections.Generic.List[object]'
$missingCollections = New-Object 'System.Collections.Generic.List[object]'

$cmModulePath = $null
if (-not [string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
    $cmModulePath = Join-Path -Path $env:SMS_ADMIN_UI_PATH -ChildPath '..\ConfigurationManager.psd1'
}

$cmModuleImported = [bool](Get-Command -Name Get-CMDeviceCollection -ErrorAction SilentlyContinue)
if (-not $cmModuleImported -and -not [string]::IsNullOrWhiteSpace($cmModulePath) -and (Test-Path -Path $cmModulePath)) {
    try {
        Import-Module -Name $cmModulePath -ErrorAction Stop | Out-Null
        $cmModuleImported = [bool](Get-Command -Name Get-CMDeviceCollection -ErrorAction SilentlyContinue)
    }
    catch {
        $cmModuleImported = $false
    }
}

$checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager collection cmdlets available' -Passed $cmModuleImported -Severity 'Error' -Details 'Get-CMDeviceCollection and New-CMDeviceCollection are required.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Site code length valid' -Passed ($sccmConfig.SiteCode.Length -eq 3) -Severity 'Error' -Target $sccmConfig.SiteCode -Details 'Configuration Manager site codes should be three characters.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Standard collections defined in manifest' -Passed ($standardCollections.Count -gt 0) -Severity 'Error' -Details 'SCCM.StandardCollections must contain one or more entries.'))

foreach ($collection in $standardCollections) {
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has name' -Passed (-not [string]::IsNullOrWhiteSpace($collection.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has limiting collection' -Passed (-not [string]::IsNullOrWhiteSpace($collection.LimitingCollection)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define LimitingCollection.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $cmModuleImported) {
    foreach ($collection in $standardCollections) {
        try {
            $existing = Get-CMDeviceCollection -Name $collection.Name -ErrorAction Stop
            $existingCollections.Add([pscustomobject]@{
                Name = $collection.Name
                CollectionId = $existing.CollectionID
                LimitingCollection = $collection.LimitingCollection
                Comment = $collection.Comment
                Status = 'Exists'
            })
        }
        catch {
            $missingCollections.Add([pscustomobject]@{
                Name = $collection.Name
                LimitingCollection = $collection.LimitingCollection
                Comment = $collection.Comment
                Status = 'MissingCollection'
            })
        }
    }
}

$summary = @{
    PlannedAction = 'Create baseline SCCM device collections'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($missingCollections.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingCollections = [object[]]$existingCollections.ToArray()
    MissingCollections = [object[]]$missingCollections.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'SCCM_BASELINE_COLLECTION_PLAN' -Target $sccmConfig.SiteServer -AdditionalData @{
    SiteCode = $sccmConfig.SiteCode
    ValidationStatus = $summary.ValidationStatus
    ExistingCollections = $existingCollections.Count
    MissingCollections = $missingCollections.Count
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    $summary
    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'SCCM baseline collection validation failed.'
    }
    return
}

foreach ($collection in @($missingCollections.ToArray())) {
    if ($PSCmdlet.ShouldProcess($collection.Name, 'Create SCCM device collection')) {
        $createParams = @{
            Name = $collection.Name
            LimitingCollectionName = $collection.LimitingCollection
            Comment = $collection.Comment
            ErrorAction = 'Stop'
        }

        $createdCollection = New-CMDeviceCollection @createParams
        $existingCollections.Add([pscustomobject]@{
            Name = $collection.Name
            CollectionId = $createdCollection.CollectionID
            LimitingCollection = $collection.LimitingCollection
            Comment = $collection.Comment
            Status = 'Created'
        })
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    ExistingOrCreatedCollections = [object[]]$existingCollections.ToArray()
    Checks = [object[]]$checks.ToArray()
}