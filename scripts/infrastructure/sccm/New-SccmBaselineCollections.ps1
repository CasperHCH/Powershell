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
$sccmCommonPath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'SCCM\SCCM-Common.ps1'
. $sccmCommonPath

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$sccmConfig = $manifest.SCCM
$standardCollections = @($sccmConfig.StandardCollections)
$checks = New-Object 'System.Collections.Generic.List[object]'
$existingCollections = New-Object 'System.Collections.Generic.List[object]'
$missingCollections = New-Object 'System.Collections.Generic.List[object]'
$pendingQueryRules = New-Object 'System.Collections.Generic.List[object]'
$pendingIncludeRules = New-Object 'System.Collections.Generic.List[object]'
$pendingExcludeRules = New-Object 'System.Collections.Generic.List[object]'
$connectionContext = $null

function Get-SccmCollectionRuleSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionDefinition
    )

    $membershipRules = if ($CollectionDefinition.ContainsKey('MembershipRules')) { $CollectionDefinition.MembershipRules } else { @{} }
    if ($null -eq $membershipRules) {
        $membershipRules = @{}
    }

    return [pscustomobject]@{
        QueryRules = @($membershipRules.QueryRules)
        IncludeCollections = @($membershipRules.IncludeCollections)
        ExcludeCollections = @($membershipRules.ExcludeCollections)
    }
}

function Invoke-AddSccmCollectionReferenceRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Include', 'Exclude')]
        [string]$RuleType,

        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [string]$ReferencedCollectionName,

        [Parameter(Mandatory = $false)]
        [string]$CollectionId
    )

    $commandName = if ($RuleType -eq 'Include') { 'Add-CMDeviceCollectionIncludeMembershipRule' } else { 'Add-CMDeviceCollectionExcludeMembershipRule' }
    $command = Get-Command -Name $commandName -ErrorAction Stop
    $parameterNames = @($command.Parameters.Keys)
    $attempts = New-Object 'System.Collections.Generic.List[scriptblock]'

    if (($parameterNames -contains 'CollectionName') -and ($parameterNames -contains ($RuleType + 'CollectionName'))) {
        $targetCollectionName = $CollectionName
        $targetReferencedCollectionName = $ReferencedCollectionName
        if ($RuleType -eq 'Include') {
            $attempts.Add({ Add-CMDeviceCollectionIncludeMembershipRule -CollectionName $targetCollectionName -IncludeCollectionName $targetReferencedCollectionName -ErrorAction Stop | Out-Null })
        }
        else {
            $attempts.Add({ Add-CMDeviceCollectionExcludeMembershipRule -CollectionName $targetCollectionName -ExcludeCollectionName $targetReferencedCollectionName -ErrorAction Stop | Out-Null })
        }
    }

    if (($parameterNames -contains 'CollectionId') -and ($parameterNames -contains ($RuleType + 'CollectionName')) -and -not [string]::IsNullOrWhiteSpace($CollectionId)) {
        $targetCollectionId = $CollectionId
        $targetReferencedCollectionName = $ReferencedCollectionName
        if ($RuleType -eq 'Include') {
            $attempts.Add({ Add-CMDeviceCollectionIncludeMembershipRule -CollectionId $targetCollectionId -IncludeCollectionName $targetReferencedCollectionName -ErrorAction Stop | Out-Null })
        }
        else {
            $attempts.Add({ Add-CMDeviceCollectionExcludeMembershipRule -CollectionId $targetCollectionId -ExcludeCollectionName $targetReferencedCollectionName -ErrorAction Stop | Out-Null })
        }
    }

    if ($attempts.Count -eq 0) {
        throw "Unable to find a supported parameter set for $commandName."
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

    throw "Failed to add $RuleType rule from '$CollectionName' to '$ReferencedCollectionName'."
}

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
    $ruleSpec = Get-SccmCollectionRuleSpec -CollectionDefinition $collection
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has name' -Passed (-not [string]::IsNullOrWhiteSpace($collection.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Standard collection has limiting collection' -Passed (-not [string]::IsNullOrWhiteSpace($collection.LimitingCollection)) -Severity 'Error' -Target $collection.Name -Details 'Each standard collection must define LimitingCollection.'))
    foreach ($queryRule in $ruleSpec.QueryRules) {
        $checks.Add((New-InfrastructureCheckResult -Name 'Query membership rule has name' -Passed (-not [string]::IsNullOrWhiteSpace($queryRule.Name)) -Severity 'Error' -Target $collection.Name -Details 'Each query membership rule must define Name.'))
        $checks.Add((New-InfrastructureCheckResult -Name 'Query membership rule has expression' -Passed (-not [string]::IsNullOrWhiteSpace($queryRule.QueryExpression)) -Severity 'Error' -Target $collection.Name -Details 'Each query membership rule must define QueryExpression.'))
    }
    foreach ($includeCollection in $ruleSpec.IncludeCollections) {
        $checks.Add((New-InfrastructureCheckResult -Name 'Include membership rule has target collection' -Passed (-not [string]::IsNullOrWhiteSpace([string]$includeCollection)) -Severity 'Error' -Target $collection.Name -Details 'IncludeCollections entries must be non-empty.'))
    }
    foreach ($excludeCollection in $ruleSpec.ExcludeCollections) {
        $checks.Add((New-InfrastructureCheckResult -Name 'Exclude membership rule has target collection' -Passed (-not [string]::IsNullOrWhiteSpace([string]$excludeCollection)) -Severity 'Error' -Target $collection.Name -Details 'ExcludeCollections entries must be non-empty.'))
    }
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $cmModuleImported) {
    try {
        $connectionContext = Connect-SccmSite -SiteCode $sccmConfig.SiteCode

        foreach ($collection in $standardCollections) {
        $ruleSpec = Get-SccmCollectionRuleSpec -CollectionDefinition $collection
        try {
            $existing = Get-CMDeviceCollection -Name $collection.Name -ErrorAction Stop
            $existingCollections.Add([pscustomobject]@{
                Name = $collection.Name
                CollectionId = $existing.CollectionID
                LimitingCollection = $collection.LimitingCollection
                Comment = $collection.Comment
                Status = 'Exists'
            })

            $queryRules = @(Get-CMDeviceCollectionQueryMembershipRule -CollectionId $existing.CollectionID -ErrorAction SilentlyContinue)
            $includeRules = @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $existing.CollectionID -ErrorAction SilentlyContinue)
            $excludeRules = @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $existing.CollectionID -ErrorAction SilentlyContinue)

            foreach ($queryRule in $ruleSpec.QueryRules) {
                $existingQueryRule = @($queryRules | Where-Object {
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('RuleName', 'Name')) -eq $queryRule.Name -or
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('QueryExpression', 'QueryRuleExpression')) -eq $queryRule.QueryExpression
                })
                if ($existingQueryRule.Count -eq 0) {
                    $pendingQueryRules.Add([pscustomobject]@{
                        CollectionName = $collection.Name
                        CollectionId = [string]$existing.CollectionID
                        RuleName = $queryRule.Name
                        QueryExpression = $queryRule.QueryExpression
                    })
                }
            }

            foreach ($includeCollection in $ruleSpec.IncludeCollections) {
                $existingIncludeRule = @($includeRules | Where-Object {
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('IncludeCollectionName', 'CollectionName', 'ReferencedCollectionName')) -eq [string]$includeCollection
                })
                if ($existingIncludeRule.Count -eq 0) {
                    $pendingIncludeRules.Add([pscustomobject]@{
                        CollectionName = $collection.Name
                        CollectionId = [string]$existing.CollectionID
                        ReferencedCollectionName = [string]$includeCollection
                    })
                }
            }

            foreach ($excludeCollection in $ruleSpec.ExcludeCollections) {
                $existingExcludeRule = @($excludeRules | Where-Object {
                    [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ExcludeCollectionName', 'CollectionName', 'ReferencedCollectionName')) -eq [string]$excludeCollection
                })
                if ($existingExcludeRule.Count -eq 0) {
                    $pendingExcludeRules.Add([pscustomobject]@{
                        CollectionName = $collection.Name
                        CollectionId = [string]$existing.CollectionID
                        ReferencedCollectionName = [string]$excludeCollection
                    })
                }
            }
        }
        catch {
            $missingCollections.Add([pscustomobject]@{
                Name = $collection.Name
                LimitingCollection = $collection.LimitingCollection
                Comment = $collection.Comment
                MembershipRules = $ruleSpec
                Status = 'MissingCollection'
            })
        }
    }
    }
    finally {
        Disconnect-SccmSite -ConnectionContext $connectionContext
        $connectionContext = $null
    }
}

$summary = @{
    PlannedAction = 'Create baseline SCCM device collections'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($missingCollections.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingCollections = [object[]]$existingCollections.ToArray()
    MissingCollections = [object[]]$missingCollections.ToArray()
    PendingQueryRules = [object[]]$pendingQueryRules.ToArray()
    PendingIncludeRules = [object[]]$pendingIncludeRules.ToArray()
    PendingExcludeRules = [object[]]$pendingExcludeRules.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'SCCM_BASELINE_COLLECTION_PLAN' -Target $sccmConfig.SiteServer -AdditionalData @{
    SiteCode = $sccmConfig.SiteCode
    ValidationStatus = $summary.ValidationStatus
    ExistingCollections = $existingCollections.Count
    MissingCollections = $missingCollections.Count
    PendingQueryRules = $pendingQueryRules.Count
    PendingIncludeRules = $pendingIncludeRules.Count
    PendingExcludeRules = $pendingExcludeRules.Count
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

        foreach ($queryRule in @($collection.MembershipRules.QueryRules)) {
            $pendingQueryRules.Add([pscustomobject]@{
                CollectionName = $collection.Name
                CollectionId = [string]$createdCollection.CollectionID
                RuleName = $queryRule.Name
                QueryExpression = $queryRule.QueryExpression
            })
        }

        foreach ($includeCollection in @($collection.MembershipRules.IncludeCollections)) {
            $pendingIncludeRules.Add([pscustomobject]@{
                CollectionName = $collection.Name
                CollectionId = [string]$createdCollection.CollectionID
                ReferencedCollectionName = [string]$includeCollection
            })
        }

        foreach ($excludeCollection in @($collection.MembershipRules.ExcludeCollections)) {
            $pendingExcludeRules.Add([pscustomobject]@{
                CollectionName = $collection.Name
                CollectionId = [string]$createdCollection.CollectionID
                ReferencedCollectionName = [string]$excludeCollection
            })
        }
    }
}

foreach ($queryRule in @($pendingQueryRules.ToArray())) {
    if ($PSCmdlet.ShouldProcess($queryRule.CollectionName, "Add query rule '$($queryRule.RuleName)'")) {
        Add-CMDeviceCollectionQueryMembershipRule -CollectionId $queryRule.CollectionId -RuleName $queryRule.RuleName -QueryExpression $queryRule.QueryExpression -ErrorAction Stop | Out-Null
    }
}

foreach ($includeRule in @($pendingIncludeRules.ToArray())) {
    if ($PSCmdlet.ShouldProcess($includeRule.CollectionName, "Add include rule for '$($includeRule.ReferencedCollectionName)'")) {
        Invoke-AddSccmCollectionReferenceRule -RuleType Include -CollectionName $includeRule.CollectionName -ReferencedCollectionName $includeRule.ReferencedCollectionName -CollectionId $includeRule.CollectionId
    }
}

foreach ($excludeRule in @($pendingExcludeRules.ToArray())) {
    if ($PSCmdlet.ShouldProcess($excludeRule.CollectionName, "Add exclude rule for '$($excludeRule.ReferencedCollectionName)'")) {
        Invoke-AddSccmCollectionReferenceRule -RuleType Exclude -CollectionName $excludeRule.CollectionName -ReferencedCollectionName $excludeRule.ReferencedCollectionName -CollectionId $excludeRule.CollectionId
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    ExistingOrCreatedCollections = [object[]]$existingCollections.ToArray()
    AppliedQueryRules = [object[]]$pendingQueryRules.ToArray()
    AppliedIncludeRules = [object[]]$pendingIncludeRules.ToArray()
    AppliedExcludeRules = [object[]]$pendingExcludeRules.ToArray()
    Checks = [object[]]$checks.ToArray()
}