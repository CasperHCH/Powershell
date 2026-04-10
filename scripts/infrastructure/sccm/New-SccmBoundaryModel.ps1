<#
.SYNOPSIS
    Creates or validates SCCM boundaries and boundary groups from the infrastructure manifest.

.DESCRIPTION
    This script reads Boundaries and BoundaryGroups entries from the SCCM section of
    the manifest, validates Configuration Manager boundary cmdlet prerequisites,
    checks whether each boundary and boundary group exists, and creates missing
    objects when not running in validate-only mode.

.PARAMETER ManifestPath
    Path to the infrastructure manifest file.

.PARAMETER ValidateOnly
    Return the boundary plan and preflight results without creating SCCM objects.

.EXAMPLE
    .\New-SccmBoundaryModel.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly
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
$sccmCommonPath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'SCCM\SCCM-Common.ps1'
. $sccmCommonPath

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$sccmConfig = $manifest.SCCM
$boundaries = @($sccmConfig.Boundaries)
$boundaryGroups = @($sccmConfig.BoundaryGroups)
$checks = New-Object 'System.Collections.Generic.List[object]'
$existingBoundaries = New-Object 'System.Collections.Generic.List[object]'
$missingBoundaries = New-Object 'System.Collections.Generic.List[object]'
$existingBoundaryGroups = New-Object 'System.Collections.Generic.List[object]'
$missingBoundaryGroups = New-Object 'System.Collections.Generic.List[object]'
$pendingMemberships = New-Object 'System.Collections.Generic.List[object]'
$connectionContext = $null

function Invoke-AddSccmBoundaryMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BoundaryGroupName,

        [Parameter(Mandatory = $true)]
        [string]$BoundaryName,

        [Parameter(Mandatory = $false)]
        [string]$BoundaryId,

        [Parameter(Mandatory = $false)]
        [string]$BoundaryGroupId
    )

    $addCommand = Get-Command -Name Add-CMBoundaryToGroup -ErrorAction Stop
    $parameterNames = @($addCommand.Parameters.Keys)
    $attempts = New-Object 'System.Collections.Generic.List[scriptblock]'

    if (($parameterNames -contains 'BoundaryGroupName') -and ($parameterNames -contains 'BoundaryName')) {
        $targetBoundaryGroupName = $BoundaryGroupName
        $targetBoundaryName = $BoundaryName
        $attempts.Add({ Add-CMBoundaryToGroup -BoundaryGroupName $targetBoundaryGroupName -BoundaryName $targetBoundaryName -ErrorAction Stop | Out-Null })
    }

    if (($parameterNames -contains 'BoundaryGroupName') -and ($parameterNames -contains 'BoundaryId') -and -not [string]::IsNullOrWhiteSpace($BoundaryId)) {
        $targetBoundaryGroupName = $BoundaryGroupName
        $targetBoundaryId = $BoundaryId
        $attempts.Add({ Add-CMBoundaryToGroup -BoundaryGroupName $targetBoundaryGroupName -BoundaryId $targetBoundaryId -ErrorAction Stop | Out-Null })
    }

    if (($parameterNames -contains 'BoundaryGroupId') -and ($parameterNames -contains 'BoundaryName') -and -not [string]::IsNullOrWhiteSpace($BoundaryGroupId)) {
        $targetBoundaryGroupId = $BoundaryGroupId
        $targetBoundaryName = $BoundaryName
        $attempts.Add({ Add-CMBoundaryToGroup -BoundaryGroupId $targetBoundaryGroupId -BoundaryName $targetBoundaryName -ErrorAction Stop | Out-Null })
    }

    if (($parameterNames -contains 'BoundaryGroupId') -and ($parameterNames -contains 'BoundaryId') -and -not [string]::IsNullOrWhiteSpace($BoundaryGroupId) -and -not [string]::IsNullOrWhiteSpace($BoundaryId)) {
        $targetBoundaryGroupId = $BoundaryGroupId
        $targetBoundaryId = $BoundaryId
        $attempts.Add({ Add-CMBoundaryToGroup -BoundaryGroupId $targetBoundaryGroupId -BoundaryId $targetBoundaryId -ErrorAction Stop | Out-Null })
    }

    if ($attempts.Count -eq 0) {
        throw 'Unable to find a supported Add-CMBoundaryToGroup parameter set for boundary membership creation.'
    }

    foreach ($attempt in $attempts) {
        try {
            & $attempt
            return
        }
        catch {
            continue
        }
    }

    throw "Failed to add boundary '$BoundaryName' to boundary group '$BoundaryGroupName'."
}

$cmModulePath = $null
if (-not [string]::IsNullOrWhiteSpace($env:SMS_ADMIN_UI_PATH)) {
    $cmModulePath = Join-Path -Path $env:SMS_ADMIN_UI_PATH -ChildPath '..\ConfigurationManager.psd1'
}

$requiredCmdlets = 'Get-CMBoundary', 'New-CMBoundary', 'Get-CMBoundaryGroup', 'New-CMBoundaryGroup', 'Add-CMBoundaryToGroup'
$cmModuleImported = [bool](Get-Command -Name Get-CMBoundary -ErrorAction SilentlyContinue)
if (-not $cmModuleImported -and -not [string]::IsNullOrWhiteSpace($cmModulePath) -and (Test-Path -Path $cmModulePath)) {
    try {
        Import-Module -Name $cmModulePath -ErrorAction Stop | Out-Null
        $cmModuleImported = [bool](Get-Command -Name Get-CMBoundary -ErrorAction SilentlyContinue)
    }
    catch {
        $cmModuleImported = $false
    }
}

$missingCmdlets = @($requiredCmdlets | Where-Object { -not [bool](Get-Command -Name $_ -ErrorAction SilentlyContinue) })
$checks.Add((New-InfrastructureCheckResult -Name 'Configuration Manager boundary cmdlets available' -Passed ($missingCmdlets.Count -eq 0) -Severity 'Error' -Details ($(if ($missingCmdlets.Count -eq 0) { 'Boundary cmdlets are available.' } else { 'Missing cmdlets: ' + ($missingCmdlets -join ', ') })) -Data $missingCmdlets))
$checks.Add((New-InfrastructureCheckResult -Name 'Boundaries defined in manifest' -Passed ($boundaries.Count -gt 0) -Severity 'Error' -Details 'SCCM.Boundaries must contain one or more entries.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Boundary groups defined in manifest' -Passed ($boundaryGroups.Count -gt 0) -Severity 'Error' -Details 'SCCM.BoundaryGroups must contain one or more entries.'))

foreach ($boundary in $boundaries) {
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary has name' -Passed (-not [string]::IsNullOrWhiteSpace($boundary.Name)) -Severity 'Error' -Target $boundary.Name -Details 'Each boundary must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary has type' -Passed (-not [string]::IsNullOrWhiteSpace($boundary.Type)) -Severity 'Error' -Target $boundary.Name -Details 'Each boundary must define Type.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary has value' -Passed (-not [string]::IsNullOrWhiteSpace($boundary.Value)) -Severity 'Error' -Target $boundary.Name -Details 'Each boundary must define Value.'))
}

$knownBoundaryNames = @($boundaries | ForEach-Object { $_.Name })
foreach ($boundaryGroup in $boundaryGroups) {
    $groupBoundaryNames = @($boundaryGroup.BoundaryNames)
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group has name' -Passed (-not [string]::IsNullOrWhiteSpace($boundaryGroup.Name)) -Severity 'Error' -Target $boundaryGroup.Name -Details 'Each boundary group must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group has site systems' -Passed (@($boundaryGroup.SiteSystems).Count -gt 0) -Severity 'Warning' -Target $boundaryGroup.Name -Details 'Each boundary group should define one or more SiteSystems.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group references boundaries' -Passed ($groupBoundaryNames.Count -gt 0) -Severity 'Error' -Target $boundaryGroup.Name -Details 'Each boundary group must define BoundaryNames.'))
    $unknownBoundaryNames = @($groupBoundaryNames | Where-Object { $_ -notin $knownBoundaryNames })
    $checks.Add((New-InfrastructureCheckResult -Name 'Boundary group boundary references are known' -Passed ($unknownBoundaryNames.Count -eq 0) -Severity 'Error' -Target $boundaryGroup.Name -Details ($(if ($unknownBoundaryNames.Count -eq 0) { 'All referenced boundaries exist in the manifest.' } else { 'Unknown boundaries: ' + ($unknownBoundaryNames -join ', ') })) -Data $unknownBoundaryNames))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $cmModuleImported) {
    try {
        $connectionContext = Connect-SccmSite -SiteCode $sccmConfig.SiteCode
        $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
        $namespace = "root/SMS/site_$resolvedSiteCode"
        $boundaryGroupMembers = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_BoundaryGroupMembers' -ErrorAction SilentlyContinue)

    foreach ($boundary in $boundaries) {
        try {
            $existingBoundary = Get-CMBoundary -Name $boundary.Name -ErrorAction Stop
            $existingBoundaries.Add([pscustomobject]@{
                Name = $boundary.Name
                Type = $boundary.Type
                Value = $boundary.Value
                BoundaryId = $existingBoundary.BoundaryID
                Status = 'Exists'
            })
        }
        catch {
            $missingBoundaries.Add([pscustomobject]@{
                Name = $boundary.Name
                Type = $boundary.Type
                Value = $boundary.Value
                Status = 'MissingBoundary'
            })
        }
    }

    foreach ($boundaryGroup in $boundaryGroups) {
        try {
            $existingBoundaryGroup = Get-CMBoundaryGroup -Name $boundaryGroup.Name -ErrorAction Stop
            $groupId = [string](Get-SccmObjectPropertyValue -InputObject $existingBoundaryGroup -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId'))
            $existingBoundaryGroups.Add([pscustomobject]@{
                Name = $boundaryGroup.Name
                BoundaryGroupId = $groupId
                SiteSystems = @($boundaryGroup.SiteSystems)
                BoundaryNames = @($boundaryGroup.BoundaryNames)
                Status = 'Exists'
            })
        }
        catch {
            $missingBoundaryGroups.Add([pscustomobject]@{
                Name = $boundaryGroup.Name
                SiteSystems = @($boundaryGroup.SiteSystems)
                BoundaryNames = @($boundaryGroup.BoundaryNames)
                SiteAssignment = [bool]$boundaryGroup.SiteAssignment
                Status = 'MissingBoundaryGroup'
            })
        }

        foreach ($boundaryName in @($boundaryGroup.BoundaryNames)) {
            $resolvedBoundary = @($existingBoundaries.ToArray() + $missingBoundaries.ToArray() | Where-Object { $_.Name -eq $boundaryName } | Select-Object -First 1)
            $resolvedBoundaryGroup = @($existingBoundaryGroups.ToArray() + $missingBoundaryGroups.ToArray() | Where-Object { $_.Name -eq $boundaryGroup.Name } | Select-Object -First 1)
            $existingMembership = $false

            if ($resolvedBoundary.Count -gt 0 -and $resolvedBoundaryGroup.Count -gt 0 -and
                $resolvedBoundary[0].PSObject.Properties.Match('BoundaryId').Count -gt 0 -and
                $resolvedBoundaryGroup[0].PSObject.Properties.Match('BoundaryGroupId').Count -gt 0 -and
                -not [string]::IsNullOrWhiteSpace([string]$resolvedBoundary[0].BoundaryId) -and
                -not [string]::IsNullOrWhiteSpace([string]$resolvedBoundaryGroup[0].BoundaryGroupId)) {
                $boundaryIdString = [string]$resolvedBoundary[0].BoundaryId
                $groupIdString = [string]$resolvedBoundaryGroup[0].BoundaryGroupId
                $existingMembership = @($boundaryGroupMembers | Where-Object {
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('BoundaryID', 'BoundaryId')) -eq $boundaryIdString -and
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId')) -eq $groupIdString
                }).Count -gt 0
            }

            if (-not $existingMembership) {
                $pendingMemberships.Add([pscustomobject]@{
                    BoundaryGroupName = $boundaryGroup.Name
                    BoundaryName = $boundaryName
                    BoundaryId = if ($resolvedBoundary.Count -gt 0 -and $resolvedBoundary[0].PSObject.Properties.Match('BoundaryId').Count -gt 0) { [string]$resolvedBoundary[0].BoundaryId } else { $null }
                    BoundaryGroupId = if ($resolvedBoundaryGroup.Count -gt 0 -and $resolvedBoundaryGroup[0].PSObject.Properties.Match('BoundaryGroupId').Count -gt 0) { [string]$resolvedBoundaryGroup[0].BoundaryGroupId } else { $null }
                })
            }
        }
    }
    }
    finally {
        Disconnect-SccmSite -ConnectionContext $connectionContext
        $connectionContext = $null
    }
}

$summary = @{
    PlannedAction = 'Create SCCM boundary model'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($missingBoundaries.Count -gt 0 -or $missingBoundaryGroups.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingBoundaries = [object[]]$existingBoundaries.ToArray()
    MissingBoundaries = [object[]]$missingBoundaries.ToArray()
    ExistingBoundaryGroups = [object[]]$existingBoundaryGroups.ToArray()
    MissingBoundaryGroups = [object[]]$missingBoundaryGroups.ToArray()
    PendingMemberships = [object[]]$pendingMemberships.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'SCCM_BOUNDARY_MODEL_PLAN' -Target $sccmConfig.SiteServer -AdditionalData @{
    SiteCode = $sccmConfig.SiteCode
    ValidationStatus = $summary.ValidationStatus
    ExistingBoundaries = $existingBoundaries.Count
    MissingBoundaries = $missingBoundaries.Count
    ExistingBoundaryGroups = $existingBoundaryGroups.Count
    MissingBoundaryGroups = $missingBoundaryGroups.Count
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    $summary
    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'SCCM boundary model validation failed.'
    }
    return
}

foreach ($boundary in @($missingBoundaries.ToArray())) {
    if ($PSCmdlet.ShouldProcess($boundary.Name, 'Create SCCM boundary')) {
        $createdBoundary = New-CMBoundary -DisplayName $boundary.Name -Type $boundary.Type -Value $boundary.Value -ErrorAction Stop
        $existingBoundaries.Add([pscustomobject]@{
            Name = $boundary.Name
            Type = $boundary.Type
            Value = $boundary.Value
            BoundaryId = $createdBoundary.BoundaryID
            Status = 'Created'
        })
    }
}

foreach ($boundaryGroup in @($missingBoundaryGroups.ToArray())) {
    if ($PSCmdlet.ShouldProcess($boundaryGroup.Name, 'Create SCCM boundary group')) {
        $createdBoundaryGroup = New-CMBoundaryGroup -Name $boundaryGroup.Name -ErrorAction Stop
        $existingBoundaryGroups.Add([pscustomobject]@{
            Name = $boundaryGroup.Name
            BoundaryGroupId = $createdBoundaryGroup.GroupID
            SiteSystems = @($boundaryGroup.SiteSystems)
            BoundaryNames = @($boundaryGroup.BoundaryNames)
            Status = 'Created'
        })
    }
}

$boundaryLookup = @{}
foreach ($boundary in @($existingBoundaries.ToArray())) {
    $boundaryLookup[$boundary.Name] = $boundary
}

$boundaryGroupLookup = @{}
foreach ($boundaryGroup in @($existingBoundaryGroups.ToArray())) {
    $boundaryGroupLookup[$boundaryGroup.Name] = $boundaryGroup
}

foreach ($membership in @($pendingMemberships.ToArray())) {
    if ($PSCmdlet.ShouldProcess($membership.BoundaryGroupName, "Add boundary '$($membership.BoundaryName)' to group")) {
        $resolvedBoundary = if ($boundaryLookup.ContainsKey($membership.BoundaryName)) { $boundaryLookup[$membership.BoundaryName] } else { $null }
        $resolvedBoundaryGroup = if ($boundaryGroupLookup.ContainsKey($membership.BoundaryGroupName)) { $boundaryGroupLookup[$membership.BoundaryGroupName] } else { $null }
        Invoke-AddSccmBoundaryMembership -BoundaryGroupName $membership.BoundaryGroupName -BoundaryName $membership.BoundaryName -BoundaryId $(if ($null -ne $resolvedBoundary) { [string]$resolvedBoundary.BoundaryId } else { $null }) -BoundaryGroupId $(if ($null -ne $resolvedBoundaryGroup) { [string]$resolvedBoundaryGroup.BoundaryGroupId } else { $null })
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    ExistingOrCreatedBoundaries = [object[]]$existingBoundaries.ToArray()
    ExistingOrCreatedBoundaryGroups = [object[]]$existingBoundaryGroups.ToArray()
    Checks = [object[]]$checks.ToArray()
}