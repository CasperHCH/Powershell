<#
.SYNOPSIS
    Performs SCCM site health validation from a manifest.

.DESCRIPTION
    This script validates SCCM site settings from the manifest and checks for core
    prerequisites including console-module availability, site and SQL definitions,
    SQL host reachability, management point and software update point settings,
    distribution point definitions, boundary data, and boundary-group relationships.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.EXAMPLE
    .\Test-SccmSiteHealth.ps1 -ManifestPath ..\config\Environment.lab.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$sccmConfig = $manifest.SCCM
$checks = New-Object 'System.Collections.Generic.List[object]'
$distributionPoints = @($sccmConfig.DistributionPoints)
$boundaryGroups = @($sccmConfig.BoundaryGroups)
$boundaries = @($sccmConfig.Boundaries)
$standardCollections = @($sccmConfig.StandardCollections)
$sourcePathEntries = @()
if ($sccmConfig.ContainsKey('SourcePaths')) {
    $sourcePathEntries = @($sccmConfig.SourcePaths.GetEnumerator())
}
$knownBoundaryNames = @($boundaries | ForEach-Object { $_.Name })
$knownSiteSystems = @($distributionPoints | ForEach-Object { $_.ServerName })
if (-not [string]::IsNullOrWhiteSpace($sccmConfig.SiteServer)) {
    $knownSiteSystems += $sccmConfig.SiteServer
}
$knownSiteSystems = @($knownSiteSystems | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

$cmModulePathPresent = $false
if (-not [string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
    $cmModulePathPresent = Test-Path -Path "$env:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
}

$checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager PowerShell module path present' -Passed $cmModulePathPresent -Severity 'Warning' -Details 'The console module should be available on SCCM administration hosts.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Site server defined' -Passed (-not [string]::IsNullOrWhiteSpace($sccmConfig.SiteServer)) -Severity 'Error' -Details 'SCCM.SiteServer must be defined.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Site code length valid' -Passed ($sccmConfig.SiteCode.Length -eq 3) -Severity 'Error' -Target $sccmConfig.SiteCode -Details 'Configuration Manager site codes should be three characters.'))
$checks.Add((New-InfrastructureCheckResult -Name 'SQL server defined' -Passed (-not [string]::IsNullOrWhiteSpace($sccmConfig.SqlServer)) -Severity 'Error' -Details 'SCCM.SqlServer must be defined.'))
$checks.Add((New-InfrastructureCheckResult -Name 'SQL database defined' -Passed (-not [string]::IsNullOrWhiteSpace($sccmConfig.DatabaseName)) -Severity 'Warning' -Details 'SCCM.DatabaseName should be defined for site-health validation.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Management point defined' -Passed (-not [string]::IsNullOrWhiteSpace($sccmConfig.ManagementPoint)) -Severity 'Warning' -Details 'SCCM.ManagementPoint should be defined.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Software update point defined' -Passed (-not [string]::IsNullOrWhiteSpace($sccmConfig.SoftwareUpdatePoint)) -Severity 'Warning' -Details 'SCCM.SoftwareUpdatePoint should be defined.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Distribution points defined' -Passed (@($distributionPoints).Count -gt 0) -Severity 'Warning' -Details 'SCCM.DistributionPoints should contain one or more entries.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Boundary data defined' -Passed (@($boundaries).Count -gt 0) -Severity 'Warning' -Details 'SCCM.Boundaries should contain one or more entries.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Boundary groups defined' -Passed (@($boundaryGroups).Count -gt 0) -Severity 'Warning' -Details 'SCCM.BoundaryGroups should contain one or more entries.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Standard collections defined' -Passed (@($standardCollections).Count -gt 0) -Severity 'Warning' -Details 'SCCM.StandardCollections should contain one or more entries.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Source paths defined' -Passed (@($sourcePathEntries).Count -gt 0) -Severity 'Warning' -Details 'SCCM.SourcePaths should contain source-share definitions.'))

if (-not [string]::IsNullOrWhiteSpace($sccmConfig.SqlServer)) {
    $sqlHostReachable = [bool](Test-Connection -ComputerName $sccmConfig.SqlServer -Count 1 -Quiet -ErrorAction SilentlyContinue)
    $checks.Add((New-InfrastructureCheckResult -Name 'SQL host reachable' -Passed $sqlHostReachable -Severity 'Warning' -Target $sccmConfig.SqlServer -Details ($(if ($sqlHostReachable) { 'ICMP reachability to the SQL host succeeded.' } else { 'Unable to reach the SQL host over ICMP.' }))))

    $sqlTcpReachable = $false
    $sqlTcpDetails = 'Test-NetConnection is unavailable.'
    if ([bool](Get-Command -Name Test-NetConnection -ErrorAction SilentlyContinue)) {
        try {
            $sqlTcpResult = Test-NetConnection -ComputerName $sccmConfig.SqlServer -Port 1433 -WarningAction SilentlyContinue
            $sqlTcpReachable = [bool]$sqlTcpResult.TcpTestSucceeded
            $sqlTcpDetails = if ($sqlTcpReachable) { 'TCP port 1433 responded.' } else { 'TCP port 1433 did not respond.' }
        }
        catch {
            $sqlTcpReachable = $false
            $sqlTcpDetails = $_.Exception.Message
        }
    }
    $checks.Add((New-InfrastructureCheckResult -Name 'SQL TCP connectivity available' -Passed $sqlTcpReachable -Severity 'Warning' -Target $sccmConfig.SqlServer -Details $sqlTcpDetails))
}

foreach ($distributionPoint in $distributionPoints) {
    $siteSystemRoles = @($distributionPoint.SiteSystemRoles)
    $checks.Add((New-InfrastructureCheckResult -Name 'Distribution point has server name' -Passed (-not [string]::IsNullOrWhiteSpace($distributionPoint.ServerName)) -Severity 'Error' -Target $distributionPoint.ServerName -Details 'Each distribution-point entry must define ServerName.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Distribution point has site-system roles' -Passed ($siteSystemRoles.Count -gt 0) -Severity 'Warning' -Target $distributionPoint.ServerName -Details 'Each distribution-point entry should define one or more SiteSystemRoles.'))
}

foreach ($collection in $standardCollections) {
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has name' -Passed (-not [string]::IsNullOrWhiteSpace($collection.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has limiting collection' -Passed (-not [string]::IsNullOrWhiteSpace($collection.LimitingCollection)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define LimitingCollection.'))
}

foreach ($sourcePath in $sourcePathEntries) {
    $pathValue = [string]$sourcePath.Value
    $isUncPath = $pathValue.StartsWith('\\')
    $checks.Add((New-InfrastructureCheckResult -Name 'Source path uses UNC format' -Passed $isUncPath -Severity 'Warning' -Target $sourcePath.Key -Details ($(if ($isUncPath) { 'Source path uses a UNC location.' } else { 'Source path should use a UNC location for shared SCCM content.' })) -Data $pathValue))
}

if (-not [string]::IsNullOrWhiteSpace($sccmConfig.ManagementPoint)) {
    $managementPointKnown = $sccmConfig.ManagementPoint -in $knownSiteSystems
    $checks.Add((New-InfrastructureCheckResult -Name 'Management point matches known site system' -Passed $managementPointKnown -Severity 'Warning' -Target $sccmConfig.ManagementPoint -Details ($(if ($managementPointKnown) { 'The management point is represented in the site-system list.' } else { 'The management point is not represented in SiteServer or DistributionPoints.' }))))
}

if (-not [string]::IsNullOrWhiteSpace($sccmConfig.SoftwareUpdatePoint)) {
    $softwareUpdatePointKnown = $sccmConfig.SoftwareUpdatePoint -in $knownSiteSystems
    $checks.Add((New-InfrastructureCheckResult -Name 'Software update point matches known site system' -Passed $softwareUpdatePointKnown -Severity 'Warning' -Target $sccmConfig.SoftwareUpdatePoint -Details ($(if ($softwareUpdatePointKnown) { 'The software update point is represented in the site-system list.' } else { 'The software update point is not represented in SiteServer or DistributionPoints.' }))))
}

foreach ($boundaryGroup in $boundaryGroups) {
    $boundaryGroupSiteSystems = @($boundaryGroup.SiteSystems)
    $boundaryGroupBoundaryNames = @($boundaryGroup.BoundaryNames)
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group has site systems' -Passed ($boundaryGroupSiteSystems.Count -gt 0) -Severity 'Warning' -Target $boundaryGroup.Name -Details 'Each boundary group should define one or more SiteSystems.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group has boundary references' -Passed ($boundaryGroupBoundaryNames.Count -gt 0) -Severity 'Error' -Target $boundaryGroup.Name -Details 'Each boundary group should define BoundaryNames.'))
    $unknownSiteSystems = @($boundaryGroupSiteSystems | Where-Object { $_ -notin $knownSiteSystems })
    $unknownBoundaryNames = @($boundaryGroupBoundaryNames | Where-Object { $_ -notin $knownBoundaryNames })
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group site systems are known' -Passed ($unknownSiteSystems.Count -eq 0) -Severity 'Warning' -Target $boundaryGroup.Name -Details ($(if ($unknownSiteSystems.Count -eq 0) { 'All boundary-group site systems are present in the known site-system list.' } else { 'Unknown site systems: ' + ($unknownSiteSystems -join ', ') })) -Data $unknownSiteSystems))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group boundaries are known' -Passed ($unknownBoundaryNames.Count -eq 0) -Severity 'Error' -Target $boundaryGroup.Name -Details ($(if ($unknownBoundaryNames.Count -eq 0) { 'All boundary-group boundaries are present in the manifest.' } else { 'Unknown boundaries: ' + ($unknownBoundaryNames -join ', ') })) -Data $unknownBoundaryNames))
}

$checkArray = [object[]]$checks.ToArray()
$failedChecks = @($checkArray | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })
$warningChecks = @($checkArray | Where-Object { -not $_.Passed -and $_.Severity -eq 'Warning' })
$overallStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($warningChecks.Count -gt 0) { 'Warning' } else { 'Healthy' }

Write-InfrastructureAudit -Action 'SCCM_SITE_HEALTH_VALIDATION' -Target $sccmConfig.SiteServer -AdditionalData @{
    Environment = $manifest.Environment.Name
    SiteCode = $sccmConfig.SiteCode
    OverallStatus = $overallStatus
    DistributionPointCount = @($distributionPoints).Count
    BoundaryGroupCount = @($boundaryGroups).Count
    StandardCollectionCount = @($standardCollections).Count
    FailedChecks = $failedChecks.Count
    WarningChecks = $warningChecks.Count
} -LogPath $scriptLogPath

@{
    Environment = $manifest.Environment.Name
    SiteCode = $sccmConfig.SiteCode
    SiteServer = $sccmConfig.SiteServer
    SqlServer = $sccmConfig.SqlServer
    ManagementPoint = $sccmConfig.ManagementPoint
    SoftwareUpdatePoint = $sccmConfig.SoftwareUpdatePoint
    StandardCollectionCount = @($standardCollections).Count
    OverallStatus = $overallStatus
    TotalChecks = $checkArray.Count
    PassedChecks = @($checkArray | Where-Object Passed).Count
    FailedChecks = $failedChecks.Count
    WarningChecks = $warningChecks.Count
    Checks = $checkArray
}