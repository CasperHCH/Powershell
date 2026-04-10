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
$sccmCommonPath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'SCCM\SCCM-Common.ps1'
. $sccmCommonPath

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$sccmConfig = $manifest.SCCM
$checks = New-Object 'System.Collections.Generic.List[object]'
$distributionPoints = @($sccmConfig.DistributionPoints)
$boundaryGroups = @($sccmConfig.BoundaryGroups)
$boundaries = @($sccmConfig.Boundaries)
$standardCollections = @($sccmConfig.StandardCollections)
$sourcePathEntries = @()
$providerConnected = $false
$connectionContext = $null
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
    $membershipRules = if ($collection.ContainsKey('MembershipRules')) { $collection.MembershipRules } else { @{} }
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has name' -Passed (-not [string]::IsNullOrWhiteSpace($collection.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has limiting collection' -Passed (-not [string]::IsNullOrWhiteSpace($collection.LimitingCollection)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define LimitingCollection.'))
    foreach ($queryRule in @($membershipRules.QueryRules)) {
        $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection query rule has name' -Passed (-not [string]::IsNullOrWhiteSpace($queryRule.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each query rule must define Name.'))
        $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection query rule has expression' -Passed (-not [string]::IsNullOrWhiteSpace($queryRule.QueryExpression)) -Severity 'Error' -Target $collection.Name -Details 'Each query rule must define QueryExpression.'))
    }
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

if ($cmModulePathPresent) {
    try {
        $connectionContext = Connect-SccmSite -SiteCode $sccmConfig.SiteCode
        $providerConnected = $true
        $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
        $namespace = "root/SMS/site_$resolvedSiteCode"
        $boundaryGroupMembers = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_BoundaryGroupMembers' -ErrorAction SilentlyContinue)

        $checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager provider connection available' -Passed $true -Severity 'Info' -Target $resolvedSiteCode -Details 'Live Configuration Manager provider access succeeded.'))

        foreach ($boundary in $boundaries) {
            $liveBoundary = @(Get-CMBoundary -Name $boundary.Name -ErrorAction SilentlyContinue | Select-Object -First 1)
            $checks.Add((New-InfrastructureCheckResult -Name 'Manifest boundary exists in SCCM' -Passed ($liveBoundary.Count -gt 0) -Severity 'Warning' -Target $boundary.Name -Details ($(if ($liveBoundary.Count -gt 0) { 'Boundary exists in Configuration Manager.' } else { 'Boundary is defined in the manifest but not present in Configuration Manager.' }))))
        }

        foreach ($boundaryGroup in $boundaryGroups) {
            $liveBoundaryGroup = @(Get-CMBoundaryGroup -Name $boundaryGroup.Name -ErrorAction SilentlyContinue | Select-Object -First 1)
            $checks.Add((New-InfrastructureCheckResult -Name 'Manifest boundary group exists in SCCM' -Passed ($liveBoundaryGroup.Count -gt 0) -Severity 'Warning' -Target $boundaryGroup.Name -Details ($(if ($liveBoundaryGroup.Count -gt 0) { 'Boundary group exists in Configuration Manager.' } else { 'Boundary group is defined in the manifest but not present in Configuration Manager.' }))))

            if ($liveBoundaryGroup.Count -gt 0) {
                $groupId = [string](Get-SccmObjectPropertyValue -InputObject $liveBoundaryGroup[0] -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId'))
                foreach ($boundaryName in @($boundaryGroup.BoundaryNames)) {
                    $liveBoundary = @(Get-CMBoundary -Name $boundaryName -ErrorAction SilentlyContinue | Select-Object -First 1)
                    $boundaryId = if ($liveBoundary.Count -gt 0) { [string](Get-SccmObjectPropertyValue -InputObject $liveBoundary[0] -PropertyNames @('BoundaryID', 'BoundaryId')) } else { $null }
                    $membershipExists = $false
                    if (-not [string]::IsNullOrWhiteSpace($groupId) -and -not [string]::IsNullOrWhiteSpace($boundaryId)) {
                        $membershipExists = @($boundaryGroupMembers | Where-Object {
                            [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId')) -eq $groupId -and
                            [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('BoundaryID', 'BoundaryId')) -eq $boundaryId
                        }).Count -gt 0
                    }

                    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group membership exists in SCCM' -Passed $membershipExists -Severity 'Warning' -Target $boundaryGroup.Name -Details ($(if ($membershipExists) { "Boundary '$boundaryName' is linked to the boundary group in Configuration Manager." } else { "Boundary '$boundaryName' is not linked to the boundary group in Configuration Manager." })) -Data $boundaryName))
                }
            }
        }

        foreach ($collection in $standardCollections) {
            $liveCollection = @(Get-CMDeviceCollection -Name $collection.Name -ErrorAction SilentlyContinue | Select-Object -First 1)
            $checks.Add((New-InfrastructureCheckResult -Name 'Manifest collection exists in SCCM' -Passed ($liveCollection.Count -gt 0) -Severity 'Warning' -Target $collection.Name -Details ($(if ($liveCollection.Count -gt 0) { 'Collection exists in Configuration Manager.' } else { 'Collection is defined in the manifest but not present in Configuration Manager.' }))))

            if ($liveCollection.Count -gt 0 -and $collection.ContainsKey('MembershipRules')) {
                $queryRules = @(Get-CMDeviceCollectionQueryMembershipRule -CollectionId $liveCollection[0].CollectionID -ErrorAction SilentlyContinue)
                $includeRules = @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $liveCollection[0].CollectionID -ErrorAction SilentlyContinue)
                $excludeRules = @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $liveCollection[0].CollectionID -ErrorAction SilentlyContinue)

                foreach ($queryRule in @($collection.MembershipRules.QueryRules)) {
                    $queryRuleExists = @($queryRules | Where-Object {
                        [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('RuleName', 'Name')) -eq $queryRule.Name -or
                        [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('QueryExpression', 'QueryRuleExpression')) -eq $queryRule.QueryExpression
                    }).Count -gt 0
                    $checks.Add((New-InfrastructureCheckResult -Name 'Collection query rule exists in SCCM' -Passed $queryRuleExists -Severity 'Warning' -Target $collection.Name -Details ($(if ($queryRuleExists) { "Query rule '$($queryRule.Name)' exists in Configuration Manager." } else { "Query rule '$($queryRule.Name)' is missing from Configuration Manager." })) -Data $queryRule.Name))
                }

                foreach ($includeCollection in @($collection.MembershipRules.IncludeCollections)) {
                    $includeRuleExists = @($includeRules | Where-Object {
                        [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('IncludeCollectionName', 'CollectionName', 'ReferencedCollectionName')) -eq [string]$includeCollection
                    }).Count -gt 0
                    $checks.Add((New-InfrastructureCheckResult -Name 'Collection include rule exists in SCCM' -Passed $includeRuleExists -Severity 'Warning' -Target $collection.Name -Details ($(if ($includeRuleExists) { "Include rule for '$includeCollection' exists in Configuration Manager." } else { "Include rule for '$includeCollection' is missing from Configuration Manager." })) -Data $includeCollection))
                }

                foreach ($excludeCollection in @($collection.MembershipRules.ExcludeCollections)) {
                    $excludeRuleExists = @($excludeRules | Where-Object {
                        [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ExcludeCollectionName', 'CollectionName', 'ReferencedCollectionName')) -eq [string]$excludeCollection
                    }).Count -gt 0
                    $checks.Add((New-InfrastructureCheckResult -Name 'Collection exclude rule exists in SCCM' -Passed $excludeRuleExists -Severity 'Warning' -Target $collection.Name -Details ($(if ($excludeRuleExists) { "Exclude rule for '$excludeCollection' exists in Configuration Manager." } else { "Exclude rule for '$excludeCollection' is missing from Configuration Manager." })) -Data $excludeCollection))
                }
            }
        }
    }
    catch {
        $checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager provider connection available' -Passed $false -Severity 'Warning' -Target $sccmConfig.SiteCode -Details $_.Exception.Message))
    }
    finally {
        Disconnect-SccmSite -ConnectionContext $connectionContext
    }
}
else {
    $checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager provider connection available' -Passed $false -Severity 'Info' -Target $sccmConfig.SiteCode -Details 'Live Configuration Manager provider validation skipped because the console module is unavailable on this host.'))
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
    ProviderConnected = $providerConnected
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
    ProviderConnected = $providerConnected
    OverallStatus = $overallStatus
    TotalChecks = $checkArray.Count
    PassedChecks = @($checkArray | Where-Object Passed).Count
    FailedChecks = $failedChecks.Count
    WarningChecks = $warningChecks.Count
    Checks = $checkArray
}