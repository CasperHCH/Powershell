<#
.SYNOPSIS
    Consolidates software-related collections, creates master collections,
    manages supersedence, and cleans up old collections, applications,
    and empty folders under "DeviceCollection\Application Deployment".

.DESCRIPTION
    This script is designed to:
    - Find all collections related to a given software name (for example, "Firefox")
    - Resolve a canonical name (for example, "Mozilla Firefox")
    - Ensure three master collections exist per software:
        * <Canonical> - Install (Available)
        * <Canonical> - Install (Required)
        * <Canonical> - Uninstall
    - Place master collections in:
        <SiteCode>:\DeviceCollection\Application Deployment\<TargetFolder>
    - Populate master collections with members using this logic:

        OldAvailable:
            = all legacy collections with "Install (Available)" in the name

        OldRequired:
            = all legacy collections with "Install" in the name
              (regardless of folder or parenthesis variants)
              MINUS OldAvailable

        Available (master):
            = UNION(OldAvailable)

        Required (master):
            = UNION(OldRequired) MINUS UNION(OldAvailable)

    - Build a linear supersedence chain between applications for the same software:
        v1 -> v2 -> v3 -> ... -> vN

    - Keep the two newest application versions plus all applications referenced
      by Task Sequences
    - Delete legacy collections, applications, and deployments
    - Clean up empty folders under:
        <SiteCode>:\DeviceCollection\Application Deployment\

.PARAMETER SiteCode
    SCCM site code, for example "P03".

.PARAMETER SoftwareName
    Name or partial name of the software to consolidate,
    for example "Firefox".

.PARAMETER TargetFolder
    Name of the subfolder under:
        <SiteCode>:\DeviceCollection\Application Deployment\<TargetFolder>
    where master collections should be placed.
    Example: "Mozilla Firefox"

.PARAMETER ManageSupersedence
    If specified, build a linear supersedence chain between applications
    related to SoftwareName.

.PARAMETER DeleteOldCollections
    If specified, delete old version-specific collections after consolidation.

.PARAMETER AutoApprove
    If specified, perform cleanup without interactive confirmation.

.PARAMETER DryRun
    If specified, log all planned actions but do not execute any changes.

.PARAMETER RetryCount
    Number of retry rounds for failed deletions (deployments, apps, collections).

.PARAMETER RetryDelaySeconds
    Number of seconds between retry rounds.

.PARAMETER EnableDebugLog
    If specified, show and write DEBUG log entries.
    If omitted, all [DEBUG] messages are suppressed.

.PARAMETER CleanupCollectionMembershipDependencies
    If true, detect collection dependencies and safely remove include/exclude
    membership rules that point to collections scheduled for deletion.

.PARAMETER ReassignLimitingCollectionDependencies
    If specified, collections that use a collection scheduled for deletion as
    limiting collection are reassigned to another limiting collection first.

.PARAMETER FallbackLimitingCollectionName
    Name of the limiting collection used during reassignment when
    ReassignLimitingCollectionDependencies is specified. Default is "All Systems".

.PARAMETER ScriptBuildId
    Optional build identifier for cross-machine verification.
    Example: "2026.03.20-rc2" or a CI run id.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [string]$SoftwareName,

    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $false)]
    [switch]$ManageSupersedence,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteOldCollections,

    [Parameter(Mandatory = $false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$RetryCount = 1,

    [Parameter(Mandatory = $false)]
    [int]$RetryDelaySeconds = 60,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog,

    [Parameter(Mandatory = $false)]
    [bool]$CleanupCollectionMembershipDependencies = $true,

    [Parameter(Mandatory = $false)]
    [switch]$ReassignLimitingCollectionDependencies,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$FallbackLimitingCollectionName = 'All Systems',

    [Parameter(Mandatory = $false)]
    [string]$ScriptBuildId = ''
)

# ------------------------------------------------------------
# GLOBAL STATE
# ------------------------------------------------------------

$failedApps         = New-Object System.Collections.Generic.List[object]
$failedCollections  = New-Object System.Collections.Generic.List[object]
$failedDeployments  = New-Object System.Collections.Generic.List[object]
$deploymentMigrationAudit = New-Object System.Collections.Generic.List[object]

# Runtime caches reduce repeated SCCM provider calls during one execution.
# They are intentionally in-memory only and reset between retry rounds.
$script:ApplicationQueryCache = @{}
$script:VersionedApplicationCache = @{}
$script:TaskSequenceReferenceCache = $null
$script:CommandMetadataCache = @{}
$script:AllDeploymentsCache = $null
$script:AllDeviceCollectionsCache = $null
$script:CmCollectionByNameCache = @{}
$script:CollectionDependencyIndexCache = $null

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------

<#
.SYNOPSIS
    Writes timestamped log messages with optional DEBUG suppression.

.DESCRIPTION
    Central logging helper used by all workflows. DEBUG messages are emitted only
    when EnableDebugLog is specified, which keeps normal runs readable.
#>
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO','WARN','ERROR','SUCCESS', 'DEBUG')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Level -eq 'DEBUG' -and -not $EnableDebugLog) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host ("{0} [{1}] {2}" -f $timestamp, $Level, $Message)
}

<#
.SYNOPSIS
    Writes log entries in a consistent scope/action/detail format.

.DESCRIPTION
    Use this helper for operational logs so long-running runs are easier to scan.
    Format: [Scope] Action: Detail
#>
function Write-LogEvent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO','WARN','ERROR','SUCCESS', 'DEBUG')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Detail
    )

    $normalizedScope = 'GENERAL'
    $normalizedAction = 'Event'
    $detailText = ''

    try {
        $scopeValue = [string]$Scope
        if (-not [string]::IsNullOrWhiteSpace($scopeValue)) {
            $normalizedScope = $scopeValue.Trim().ToUpperInvariant()
        }
    }
    catch {
    }

    try {
        $actionValue = [string]$Action
        if (-not [string]::IsNullOrWhiteSpace($actionValue)) {
            $normalizedAction = $actionValue.Trim()
        }
    }
    catch {
    }

    try {
        $detailText = [string]$Detail
    }
    catch {
        $detailText = '[Detail conversion failed]'
    }

    $prefix = ("[{0}] {1}" -f $normalizedScope, $normalizedAction)

    try {
        if ([string]::IsNullOrWhiteSpace($detailText)) {
            Write-Log -Level $Level -Message $prefix
        }
        else {
            Write-Log -Level $Level -Message ("{0}: {1}" -f $prefix, $detailText)
        }
    }
    catch {
        # Last-resort logging path; never let logging failures crash the workflow.
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host ("{0} [ERROR] [LOGGING] Write-LogEvent fallback | Level={1}; Scope={2}; Action={3}; Detail={4}; Error={5}" -f $timestamp, $Level, $normalizedScope, $normalizedAction, $detailText, $_.Exception.Message)
    }
}

<#
.SYNOPSIS
    Returns runtime script identity details.

.DESCRIPTION
    Provides host, file path, last-write timestamp, and a SHA256 hash so the
    executed script can be verified across machines even when file names differ.
#>
function Get-ScriptIdentity {
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    $hash = 'Unavailable'
    $lastWrite = 'Unknown'

    if (-not [string]::IsNullOrWhiteSpace($scriptPath) -and (Test-Path -LiteralPath $scriptPath)) {
        try {
            $hash = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256 -ErrorAction Stop).Hash
        }
        catch {
            $hash = 'HashError'
        }

        try {
            $lastWrite = (Get-Item -LiteralPath $scriptPath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
        catch {
            $lastWrite = 'TimeError'
        }
    }

    return [pscustomobject]@{
        BuildId    = ($ScriptBuildId -as [string])
        Computer   = $env:COMPUTERNAME
        User       = $env:USERNAME
        ScriptPath = $scriptPath
        LastWrite  = $lastWrite
        Sha256     = $hash
    }
}

<#
.SYNOPSIS
    Executes an action or logs it when DryRun mode is enabled.

.DESCRIPTION
    This helper enforces the script safety model. Any operation that modifies SCCM
    should run through this wrapper so simulation and live execution stay aligned.
#>
function Invoke-DryRunAction {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Would execute action' -Detail $Description
    }
    else {
        & $Action
    }
}

<#
.SYNOPSIS
    Attempts multiple SCCM command variants until one succeeds.

.DESCRIPTION
    SCCM cmdlet parameter sets vary between environments. This helper improves
    portability by trying known non-interactive alternatives in sequence.
#>
function Invoke-CmCommandWithFallback {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock[]]$Attempts,
        [Parameter(Mandatory=$false)]
        [string]$ActionName = 'command'
    )

    foreach ($attempt in $Attempts) {
        try {
            # Invoke with explicit non-interactive error handling to catch any prompts
            $result = & $attempt -ErrorAction Stop
            return @{ Success = $true; Result = $result }
        }
        catch {
            # Sanitize error to avoid information disclosure
            $sanitizedMsg = $_.Exception.Message -replace '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]'
            Write-LogEvent -Level 'DEBUG' -Scope 'Operations' -Action 'Debug' -Detail ("Fallback {0} attempt failed: {1}" -f $ActionName, $sanitizedMsg)
        }
    }

    return @{ Success = $false; Result = $null }
}

<#
.SYNOPSIS
    Reads the first non-empty property value from a list of candidate names.

.DESCRIPTION
    SCCM object models differ by cmdlet and version. This helper normalizes access
    by trying multiple aliases for the same conceptual field.
#>
function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    foreach ($propertyName in $PropertyNames) {
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        try {
            $property = $InputObject.PSObject.Properties[$propertyName]
            if ($property -and $null -ne $property.Value -and -not [string]::IsNullOrWhiteSpace(($property.Value -as [string]))) {
                return $property.Value
            }
        }
        catch {
        }
    }

    return $null
}

<#
.SYNOPSIS
    Normalizes pipeline or scalar output to a safe PowerShell array.

.DESCRIPTION
    SCCM cmdlets can return either arrays or single objects that still expose a
    Count property. This helper ensures downstream Count/index operations are
    performed on an actual array and not on scalar values.
#>
function Convert-ToSafeArray {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    return @($InputObject)
}

function Get-CachedCommand {
    <#
    .SYNOPSIS
        Returns a cached command object for faster repeated capability checks.

    .DESCRIPTION
        Many flows call Get-Command before attempting SCCM cmdlets. This helper
        caches the command metadata so we only pay the discovery cost once per run.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($script:CommandMetadataCache.ContainsKey($Name)) {
        return $script:CommandMetadataCache[$Name]
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    $script:CommandMetadataCache[$Name] = $command
    return $command
}

function Get-CachedAllDeployments {
    <#
    .SYNOPSIS
        Returns all deployments from SCCM using a run-scoped cache.

    .DESCRIPTION
        Deployment enumeration is one of the most expensive operations in this
        script. We cache the full set and let callers filter in memory.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )

    if ($Refresh -or $null -eq $script:AllDeploymentsCache) {
        try {
            $script:AllDeploymentsCache = @(Get-CMDeployment -ErrorAction SilentlyContinue)
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Deployments' -Action 'Debug' -Detail ("Could not query all deployments: {0}" -f $_.Exception.Message)
            $script:AllDeploymentsCache = @()
        }
    }

    return @($script:AllDeploymentsCache)
}

function Get-CachedDeploymentsForCollectionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    if ([string]::IsNullOrWhiteSpace($CollectionName)) {
        return @()
    }

    $allDeployments = Get-CachedAllDeployments
    if ($allDeployments.Count -eq 0) {
        return @()
    }

    return @($allDeployments | Where-Object {
        $deploymentCollectionName = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionName', 'TargetCollectionName'))
        $deploymentCollectionName -eq $CollectionName
    })
}

function Get-CachedDeploymentById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeploymentId
    )

    if ([string]::IsNullOrWhiteSpace($DeploymentId)) {
        return $null
    }

    $allDeployments = Get-CachedAllDeployments
    if ($allDeployments.Count -eq 0) {
        return $null
    }

    $match = @($allDeployments | Where-Object {
        $depId = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id'))
        $depId -eq $DeploymentId
    } | Select-Object -First 1)

    if ($match.Count -gt 0) {
        return $match[0]
    }

    return $null
}

function Get-CachedAllDeviceCollections {
    <#
    .SYNOPSIS
        Returns all device collections from SCCM using a run-scoped cache.

    .DESCRIPTION
        Dependency analysis and delete flows repeatedly need collection metadata.
        This avoids repeated full provider scans for each candidate collection.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )

    if ($Refresh -or $null -eq $script:AllDeviceCollectionsCache) {
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail 'Priming device collection cache (full scan - this may take a moment in large environments)...'
        try {
            $script:AllDeviceCollectionsCache = @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)
            Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Device collection cache primed with {0} collections." -f $script:AllDeviceCollectionsCache.Count)
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Could not enumerate device collections: {0}" -f $_.Exception.Message)
            $script:AllDeviceCollectionsCache = @()
        }
    }

    return @($script:AllDeviceCollectionsCache)
}

function Get-CachedDeviceCollectionById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionId
    )

    if ([string]::IsNullOrWhiteSpace($CollectionId)) {
        return $null
    }

    $allCollections = Get-CachedAllDeviceCollections
    if ($allCollections.Count -eq 0) {
        return $null
    }

    $match = @($allCollections | Where-Object {
        $candidateId = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        $candidateId -eq $CollectionId
    } | Select-Object -First 1)

    if ($match.Count -gt 0) {
        return $match[0]
    }

    return $null
}

function Get-CachedDeviceCollectionByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    if ([string]::IsNullOrWhiteSpace($CollectionName)) {
        return $null
    }

    $allCollections = Get-CachedAllDeviceCollections
    if ($allCollections.Count -eq 0) {
        return $null
    }

    $match = @($allCollections | Where-Object {
        $candidateName = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('Name', 'CollectionName'))
        $candidateName -eq $CollectionName
    } | Select-Object -First 1)

    if ($match.Count -gt 0) {
        return $match[0]
    }

    return $null
}

function Get-CachedCmCollectionByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $cacheKey = ($CollectionName -as [string]).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return $null
    }

    if ($script:CmCollectionByNameCache.ContainsKey($cacheKey)) {
        return $script:CmCollectionByNameCache[$cacheKey]
    }

    $collection = $null
    try {
        $collection = @(Get-CMCollection -Name $CollectionName -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($collection.Count -gt 0) {
            $collection = $collection[0]
        }
        else {
            $collection = $null
        }
    }
    catch {
        Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Could not resolve CM collection '{0}': {1}" -f $CollectionName, $_.Exception.Message)
        $collection = $null
    }

    $script:CmCollectionByNameCache[$cacheKey] = $collection
    return $collection
}

function Get-CachedCollectionDependencyIndex {
    <#
    .SYNOPSIS
        Builds and returns a cached index of collection dependencies.

    .DESCRIPTION
        Instead of querying include/exclude rules for each target collection,
        this function performs a single pass across all collections and builds
        lookup tables keyed by target collection id/name.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )

    if (-not $Refresh -and $null -ne $script:CollectionDependencyIndexCache) {
        return $script:CollectionDependencyIndexCache
    }

    $allCollections = Get-CachedAllDeviceCollections -Refresh:$Refresh

    $index = [ordered]@{
        IncludeByTargetId   = @{}
        IncludeByTargetName = @{}
        ExcludeByTargetId   = @{}
        ExcludeByTargetName = @{}
        LimitingByTargetId  = @{}
        LimitingByTargetName = @{}
    }

    if ($allCollections.Count -eq 0) {
        $script:CollectionDependencyIndexCache = [pscustomobject]$index
        return $script:CollectionDependencyIndexCache
    }

    $collectionIdByName = @{}
    foreach ($col in $allCollections) {
        $id = [string](Get-ObjectPropertyValue -InputObject $col -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        $name = [string](Get-ObjectPropertyValue -InputObject $col -PropertyNames @('Name', 'CollectionName'))
        if (-not [string]::IsNullOrWhiteSpace($id) -and -not [string]::IsNullOrWhiteSpace($name)) {
            $collectionIdByName[$name.Trim().ToLowerInvariant()] = $id
        }
    }

    $addReference = {
        param(
            [hashtable]$Bucket,
            [string]$TargetKey,
            [object]$DependentEntry
        )

        if ([string]::IsNullOrWhiteSpace($TargetKey) -or -not $DependentEntry) {
            return
        }

        if (-not $Bucket.ContainsKey($TargetKey)) {
            $Bucket[$TargetKey] = New-Object System.Collections.Generic.List[object]
        }

        [void]$Bucket[$TargetKey].Add($DependentEntry)
    }

    $includeRuleCommand = Get-CachedCommand -Name 'Get-CMDeviceCollectionIncludeMembershipRule'
    $excludeRuleCommand = Get-CachedCommand -Name 'Get-CMDeviceCollectionExcludeMembershipRule'

    foreach ($candidate in $allCollections) {
        if (-not $candidate) { continue }

        $candidateId = [string](Get-ObjectPropertyValue -InputObject $candidate -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        $candidateName = [string](Get-ObjectPropertyValue -InputObject $candidate -PropertyNames @('Name', 'CollectionName'))

        if ([string]::IsNullOrWhiteSpace($candidateId) -and [string]::IsNullOrWhiteSpace($candidateName)) {
            continue
        }

        $dependentEntry = [pscustomobject]@{
            CollectionID = $candidateId
            Name         = $candidateName
        }

        $candidateLimitingCollectionId = [string](Get-ObjectPropertyValue -InputObject $candidate -PropertyNames @('LimitToCollectionID', 'LimitToCollectionId', 'LimitingCollectionID', 'LimitingCollectionId'))
        if (-not [string]::IsNullOrWhiteSpace($candidateLimitingCollectionId)) {
            & $addReference $index.LimitingByTargetId $candidateLimitingCollectionId $dependentEntry
        }

        $candidateLimitingCollectionName = [string](Get-ObjectPropertyValue -InputObject $candidate -PropertyNames @('LimitToCollectionName', 'LimitingCollectionName'))
        if (-not [string]::IsNullOrWhiteSpace($candidateLimitingCollectionName)) {
            & $addReference $index.LimitingByTargetName $candidateLimitingCollectionName.Trim().ToLowerInvariant() $dependentEntry
        }

        # IncludeExcludeCollectionsCount=0 means this collection has no include/
        # exclude membership rules at all — skip both provider calls for it.
        # If the property is absent on the object, fall through and query anyway.
        $hasIncludeExcludeRules = $true
        $ruleCountVal = Get-ObjectPropertyValue -InputObject $candidate -PropertyNames @('IncludeExcludeCollectionsCount')
        if (-not [string]::IsNullOrWhiteSpace($ruleCountVal)) {
            try {
                $ruleCountInt = 0
                if ([int]::TryParse([string]$ruleCountVal, [ref]$ruleCountInt)) {
                    $hasIncludeExcludeRules = $ruleCountInt -gt 0
                }
            }
            catch {
                Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail (
                    "Could not parse IncludeExcludeCollectionsCount for '{0}' ({1}): {2}" -f
                    $candidateName,
                    $candidateId,
                    $_.Exception.Message
                )
            }
        }

        if ($includeRuleCommand -and $hasIncludeExcludeRules -and -not [string]::IsNullOrWhiteSpace($candidateId)) {
            try {
                $candidateIdStr = [string]$candidateId
                $includeRules = @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $candidateIdStr -ErrorAction SilentlyContinue)
                foreach ($includeRule in $includeRules) {
                    $targetId = [string](Get-ObjectPropertyValue -InputObject $includeRule -PropertyNames @('IncludeCollectionID', 'IncludeCollectionId', 'ReferencedCollectionID', 'ReferencedCollectionId'))
                    $targetName = [string](Get-ObjectPropertyValue -InputObject $includeRule -PropertyNames @('IncludeCollectionName', 'ReferencedCollectionName', 'CollectionName'))

                    if ([string]::IsNullOrWhiteSpace($targetId) -and -not [string]::IsNullOrWhiteSpace($targetName)) {
                        $lookupKey = $targetName.Trim().ToLowerInvariant()
                        if ($collectionIdByName.ContainsKey($lookupKey)) {
                            $targetId = [string]$collectionIdByName[$lookupKey]
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($targetId)) {
                        & $addReference $index.IncludeByTargetId $targetId $dependentEntry
                    }

                    if (-not [string]::IsNullOrWhiteSpace($targetName)) {
                        & $addReference $index.IncludeByTargetName $targetName.Trim().ToLowerInvariant() $dependentEntry
                    }
                }
            }
            catch {
                Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Could not query include membership rules for collection '{0}' ({1}): {2}" -f $candidateName, $candidateId, $_.Exception.Message)
            }
        }

        if ($excludeRuleCommand -and $hasIncludeExcludeRules -and -not [string]::IsNullOrWhiteSpace($candidateId)) {
            try {
                $candidateIdStr = [string]$candidateId
                $excludeRules = @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $candidateIdStr -ErrorAction SilentlyContinue)
                foreach ($excludeRule in $excludeRules) {
                    $targetId = [string](Get-ObjectPropertyValue -InputObject $excludeRule -PropertyNames @('ExcludeCollectionID', 'ExcludeCollectionId', 'ReferencedCollectionID', 'ReferencedCollectionId'))
                    $targetName = [string](Get-ObjectPropertyValue -InputObject $excludeRule -PropertyNames @('ExcludeCollectionName', 'ReferencedCollectionName', 'CollectionName'))

                    if ([string]::IsNullOrWhiteSpace($targetId) -and -not [string]::IsNullOrWhiteSpace($targetName)) {
                        $lookupKey = $targetName.Trim().ToLowerInvariant()
                        if ($collectionIdByName.ContainsKey($lookupKey)) {
                            $targetId = [string]$collectionIdByName[$lookupKey]
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($targetId)) {
                        & $addReference $index.ExcludeByTargetId $targetId $dependentEntry
                    }

                    if (-not [string]::IsNullOrWhiteSpace($targetName)) {
                        & $addReference $index.ExcludeByTargetName $targetName.Trim().ToLowerInvariant() $dependentEntry
                    }
                }
            }
            catch {
                Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Could not query exclude membership rules for collection '{0}' ({1}): {2}" -f $candidateName, $candidateId, $_.Exception.Message)
            }
        }
    }

    $script:CollectionDependencyIndexCache = [pscustomobject]$index
    return $script:CollectionDependencyIndexCache
}

function Reset-SccmRuntimeCaches {
    <#
    .SYNOPSIS
        Clears runtime caches between phases that may change SCCM state.

    .DESCRIPTION
        Retries run after delete attempts and should not rely on stale snapshots.
        This function resets cached command/data lookups to force fresh reads.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeAppCaches,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeTaskSequenceCache
    )

    $script:AllDeploymentsCache = $null
    $script:AllDeviceCollectionsCache = $null
    $script:CmCollectionByNameCache = @{}
    $script:CollectionDependencyIndexCache = $null
    $script:CommandMetadataCache = @{}

    if ($IncludeAppCaches) {
        $script:ApplicationQueryCache = @{}
        $script:VersionedApplicationCache = @{}
    }

    if ($IncludeTaskSequenceCache) {
        $script:TaskSequenceReferenceCache = $null
    }
}

<#
.SYNOPSIS
    Retrieves applications that match a software name pattern.

.DESCRIPTION
    Returns a cached list of CM applications whose display name matches the input
    pattern, reducing repeated provider calls during one script execution.
#>
function Get-ApplicationsForSoftwareName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    $cacheKey = ($SoftwareName -as [string]).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return @()
    }

    if ($script:ApplicationQueryCache.ContainsKey($cacheKey)) {
        return @($script:ApplicationQueryCache[$cacheKey])
    }

    Write-LogEvent -Level 'INFO' -Scope 'Applications' -Action 'Status' -Detail ("Querying applications for '{0}'..." -f $SoftwareName)
    try {
        # Use a provider-side name filter to avoid a full application scan.
        $apps = @(Get-CMApplication -Name ("*{0}*" -f $SoftwareName) -ErrorAction Stop)
    }
    catch {
        Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Filtered CMApplication query failed, falling back to full scan: {0}" -f $_.Exception.Message)
        try {
            $apps = @(Get-CMApplication -ErrorAction SilentlyContinue | Where-Object {
                $_.LocalizedDisplayName -like ("*{0}*" -f $SoftwareName)
            })
        }
        catch {
            Write-LogEvent -Level 'WARN' -Scope 'Applications' -Action 'Warning' -Detail ("Could not query applications for '{0}': {1}" -f $SoftwareName, $_.Exception.Message)
            $apps = @()
        }
    }

    $script:ApplicationQueryCache[$cacheKey] = @($apps)
    return @($apps)
}

function Find-ExistingApplicationDeployment {
    <#
    .SYNOPSIS
        Checks whether a collection already has a deployment for the target app.

    .DESCRIPTION
        Matching is resilient across environments and compares by CI id, model id,
        then name. This prevents duplicate deployments during migration and ensures
        idempotent reruns.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        $Application
    )

    $appName = Get-ObjectPropertyValue -InputObject $Application -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name')
    $appCiId = Get-ObjectPropertyValue -InputObject $Application -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId')
    $appModelName = Get-ObjectPropertyValue -InputObject $Application -PropertyNames @('ModelName', 'ModelId', 'PackageID', 'PackageId')

    $deploymentSets = @()

    $byCollection = Get-CachedDeploymentsForCollectionName -CollectionName $CollectionName
    if ($byCollection.Count -gt 0) {
        $deploymentSets += [pscustomobject]@{
            Scope = 'ByCollection'
            Items = $byCollection
        }
    }

    $allDeployments = Get-CachedAllDeployments
    if ($allDeployments.Count -gt 0) {
        $deploymentSets += [pscustomobject]@{
            Scope = 'All'
            Items = $allDeployments
        }
    }

    foreach ($deploymentSet in $deploymentSets) {
        # Iterate each deployment source (collection-scoped and full deployment list)
        # to maximize compatibility across SCCM environments.
        foreach ($deployment in $deploymentSet.Items) {
            $deploymentCollectionName = Get-ObjectPropertyValue -InputObject $deployment -PropertyNames @('CollectionName', 'TargetCollectionName')
            $deploymentAppName = Get-ObjectPropertyValue -InputObject $deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name', 'LocalizedDisplayName')
            $deploymentAppId = Get-ObjectPropertyValue -InputObject $deployment -PropertyNames @('ApplicationCIID', 'ApplicationCI_ID', 'CI_ID', 'CIId', 'ModelID', 'ModelId')
            $deploymentModelName = Get-ObjectPropertyValue -InputObject $deployment -PropertyNames @('ModelName', 'PackageID', 'PackageId')

            $collectionMatches = $false
            if ($deploymentCollectionName) {
                $collectionMatches = $deploymentCollectionName -eq $CollectionName
            }
            elseif ($deploymentSet.Scope -eq 'ByCollection') {
                $collectionMatches = $true
            }

            if (-not $collectionMatches) {
                continue
            }

            $appMatches = $false
            if ($appCiId -and $deploymentAppId) {
                $appMatches = [string]$deploymentAppId -eq [string]$appCiId
            }

            if (-not $appMatches -and $appModelName -and $deploymentModelName) {
                $appMatches = [string]$deploymentModelName -eq [string]$appModelName
            }

            if (-not $appMatches -and $appName -and $deploymentAppName) {
                $appMatches = [string]$deploymentAppName -eq [string]$appName
            }

            # Return immediately when a matching deployment is found because the
            # caller only needs to know whether one already exists.
            if ($appMatches) {
                return $deployment
            }
        }
    }

    return $null
}

<#
.SYNOPSIS
    Retrieves deployments targeting a specific collection.

.DESCRIPTION
    Uses deployment cache filtering to avoid repeated SCCM provider scans.
#>
function Get-CollectionDeployments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    return @(Get-CachedDeploymentsForCollectionName -CollectionName $CollectionName)
}

<#
.SYNOPSIS
    Resolves a normalized four-part version for an application.

.DESCRIPTION
    Prefers SoftwareVersion when available and falls back to version extraction
    from application display name.
#>
function Get-AppVersionNormalized {
    param(
        [Parameter(Mandatory=$true)]
        $App
    )

    if (-not $App) { return $null }

    if (-not [string]::IsNullOrWhiteSpace($App.SoftwareVersion)) {
        $norm = Normalize-VersionString -VersionString $App.SoftwareVersion
        if ($norm) { return $norm }
    }

    return Extract-VersionFromName -Name $App.LocalizedDisplayName
}

<#
.SYNOPSIS
    Builds a sorted list of unique versioned applications for a software family.

.DESCRIPTION
    Deduplicates by CI id, resolves normalized versions, and returns a descending
    sort suitable for keep/delete and migration decisions.
#>
function Get-VersionedApplicationsForSoftwareName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    $cacheKey = ($SoftwareName -as [string]).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return @()
    }

    if ($script:VersionedApplicationCache.ContainsKey($cacheKey)) {
        return @($script:VersionedApplicationCache[$cacheKey])
    }

    $apps = Get-ApplicationsForSoftwareName -SoftwareName $SoftwareName
    if ($apps.Count -eq 0) {
        $script:VersionedApplicationCache[$cacheKey] = @()
        return @()
    }

    $appsWithVersion = @()
    $seenAppIds = New-Object System.Collections.Generic.HashSet[string]

    foreach ($app in $apps) {
        # Build a unique set of versioned applications by CI id so renamed app
        # objects do not appear as duplicate versions in cleanup decisions.
        $appCiId = [string](Get-ObjectPropertyValue -InputObject $app -PropertyNames @('CI_ID','CIId','ModelID','ModelId'))
        if ([string]::IsNullOrWhiteSpace($appCiId)) {
            continue
        }

        if ($seenAppIds.Contains($appCiId)) {
            continue
        }

        $norm = Get-AppVersionNormalized -App $app
        if ($norm) {
            $appsWithVersion += [pscustomobject]@{
                App     = $app
                Version = $norm
            }
            [void]$seenAppIds.Add($appCiId)
        }
    }

    $sorted = @($appsWithVersion |
        Sort-Object -Property @(
            @{ Expression = { [version]$_.Version }; Descending = $true },
            @{ Expression = { [string](Get-ObjectPropertyValue -InputObject $_.App -PropertyNames @('CI_ID','CIId','ModelID','ModelId')) }; Descending = $true },
            @{ Expression = { [string]$_.App.LocalizedDisplayName }; Descending = $false }
        ))

    $script:VersionedApplicationCache[$cacheKey] = @($sorted)
    return @($sorted)
}

<#
.SYNOPSIS
    Returns the newest versioned application in a software family.

.DESCRIPTION
    Reads from the versioned application cache and returns the first (highest)
    entry when available.
#>
function Get-LatestVersionedApplication {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    $versioned = Convert-ToSafeArray -InputObject (Get-VersionedApplicationsForSoftwareName -SoftwareName $SoftwareName)
    if ($versioned.Count -eq 0) {
        return $null
    }

    return $versioned[0].App
}

<#
.SYNOPSIS
    Maps a deployment object to action and purpose intent.

.DESCRIPTION
    Converts SCCM offer/config fields into normalized DeployAction and
    DeployPurpose values used by migration and deployment creation logic.
#>
function Get-DeploymentIntent {
    param(
        [Parameter(Mandatory = $true)]
        $Deployment
    )

    $offerTypeId = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('OfferTypeID', 'OfferTypeId')
    $desiredConfigType = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('DesiredConfigType', 'AssignmentAction')

    $purpose = 'Required'
    if ([string]$offerTypeId -eq '2') {
        $purpose = 'Available'
    }

    $action = 'Install'
    if ([string]$desiredConfigType -eq '2') {
        $action = 'Uninstall'
    }

    return [pscustomobject]@{
        DeployAction  = $action
        DeployPurpose = $purpose
    }
}

<#
.SYNOPSIS
    Ensures a collection has a deployment for the latest application version.

.DESCRIPTION
    Checks for an existing latest deployment, writes audit records, and creates a
    replacement deployment when needed (or logs planned action in DryRun mode).
#>
function Ensure-LatestDeploymentForCollection {
    param(
        [Parameter(Mandatory = $true)]
        $Deployment,

        [Parameter(Mandatory = $true)]
        $LatestApp
    )

    $collectionName = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('CollectionName', 'TargetCollectionName')
    $deploymentId = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id')

    if ([string]::IsNullOrWhiteSpace(($collectionName -as [string]))) {
        $audit = [pscustomobject]@{
            Timestamp         = (Get-Date).ToString('o')
            SourceDeployment  = $deploymentId
            CollectionName    = $collectionName
            SourceAppName     = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName     = $LatestApp.LocalizedDisplayName
            Status            = 'Skipped'
            Notes             = 'Missing collection name on source deployment.'
        }
        [void]$deploymentMigrationAudit.Add($audit)
        return $false
    }

    $existing = Find-ExistingApplicationDeployment -CollectionName $collectionName -Application $LatestApp
    if ($existing) {
        $audit = [pscustomobject]@{
            Timestamp         = (Get-Date).ToString('o')
            SourceDeployment  = $deploymentId
            CollectionName    = $collectionName
            SourceAppName     = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName     = $LatestApp.LocalizedDisplayName
            Status            = 'AlreadyExists'
            Notes             = 'Latest deployment already present for target collection.'
        }
        [void]$deploymentMigrationAudit.Add($audit)
        return $true
    }

    $intent = Get-DeploymentIntent -Deployment $Deployment

    if ($DryRun) {
        $audit = [pscustomobject]@{
            Timestamp         = (Get-Date).ToString('o')
            SourceDeployment  = $deploymentId
            CollectionName    = $collectionName
            SourceAppName     = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName     = $LatestApp.LocalizedDisplayName
            Status            = 'Planned'
            Notes             = ("[DryRun] Would migrate deployment with Action={0}; Purpose={1}" -f $intent.DeployAction, $intent.DeployPurpose)
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'INFO' -Scope 'Deployments' -Action 'Status' -Detail ("[DryRun] Would migrate deployment for collection '{0}' to latest app '{1}' ({2}/{3})." -f $collectionName, $LatestApp.LocalizedDisplayName, $intent.DeployAction, $intent.DeployPurpose)
        return $true
    }

    try {
        $deployAttempts = @()
        if ($intent.DeployPurpose) {
            $deployAttempts += {
                New-CMApplicationDeployment -CollectionName $collectionName -Name $LatestApp.LocalizedDisplayName -DeployAction $intent.DeployAction -DeployPurpose $intent.DeployPurpose -ErrorAction Stop | Out-Null
            }
        }
        $deployAttempts += {
            New-CMApplicationDeployment -CollectionName $collectionName -Name $LatestApp.LocalizedDisplayName -DeployAction $intent.DeployAction -ErrorAction Stop | Out-Null
        }

        $result = Invoke-CmCommandWithFallback -Attempts $deployAttempts -ActionName 'New-CMApplicationDeployment (migrate)'
        if (-not $result.Success) {
            throw 'All deployment creation attempts failed.'
        }

        $audit = [pscustomobject]@{
            Timestamp         = (Get-Date).ToString('o')
            SourceDeployment  = $deploymentId
            CollectionName    = $collectionName
            SourceAppName     = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName     = $LatestApp.LocalizedDisplayName
            Status            = 'Created'
            Notes             = ("Action={0}; Purpose={1}" -f $intent.DeployAction, $intent.DeployPurpose)
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'SUCCESS' -Scope 'Deployments' -Action 'Success' -Detail ("Migrated deployment for collection '{0}' to latest app '{1}' ({2}/{3})." -f $collectionName, $LatestApp.LocalizedDisplayName, $intent.DeployAction, $intent.DeployPurpose)
        return $true
    }
    catch {
        $audit = [pscustomobject]@{
            Timestamp         = (Get-Date).ToString('o')
            SourceDeployment  = $deploymentId
            CollectionName    = $collectionName
            SourceAppName     = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName     = $LatestApp.LocalizedDisplayName
            Status            = 'Failed'
            Notes             = $_.Exception.Message
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'WARN' -Scope 'Deployments' -Action 'Warning' -Detail ("Could not migrate deployment for collection '{0}' to latest app '{1}': {2}" -f $collectionName, $LatestApp.LocalizedDisplayName, $_.Exception.Message)
        return $false
    }
}

# ------------------------------------------------------------
# CONNECT TO SCCM
# ------------------------------------------------------------

<#
.SYNOPSIS
    Connects the session to the target SCCM site drive.

.DESCRIPTION
    Imports the ConfigurationManager module, ensures a site PSDrive exists, and
    switches location so SCCM cmdlets operate in the intended site context.
#>
function Connect-SccmSite {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode
    )

    try {
        Import-Module ConfigurationManager -ErrorAction Stop

        $siteDriveName = "${SiteCode}:"
        if (-not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
            try {
                New-PSDrive -Name $SiteCode -PSProvider "AdminUI.PS.Provider\CMSite" -Root $env:COMPUTERNAME -ErrorAction Stop | Out-Null
            }
            catch {
                Write-LogEvent -Level 'WARN' -Scope 'Connect' -Action 'Warning' -Detail ("Could not create PSDrive with AdminUI.PS.Provider.CMSite: {0}" -f $_.Exception.Message)
                $provider = Get-PSProvider | Where-Object { $_.Name -match 'CMSite' } | Select-Object -First 1
                if ($provider) {
                    try {
                        New-PSDrive -Name $SiteCode -PSProvider $provider.Name -Root $env:COMPUTERNAME -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-LogEvent -Level 'WARN' -Scope 'Connect' -Action 'Warning' -Detail ("Could not create PSDrive with provider $($provider.Name): {0}" -f $_.Exception.Message)
                    }
                }
            }
        }

        if (-not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
            Write-LogEvent -Level 'WARN' -Scope 'Connect' -Action 'Warning' -Detail ("PSDrive ${SiteCode}: does not exist after attempts. Trying Set-Location directly.")
        }

        Set-Location -Path $siteDriveName
        Write-LogEvent -Level 'SUCCESS' -Scope 'Connect' -Action 'Success' -Detail ("Connected to SCCM site '{0}'." -f $SiteCode)
    }
    catch {
        Write-LogEvent -Level 'ERROR' -Scope 'Connect' -Action 'Error' -Detail ("Failed to connect to SCCM site '{0}': {1}" -f $SiteCode, $_.Exception.Message)
        throw
    }
}

# ------------------------------------------------------------
# VERSION HELPERS
# ------------------------------------------------------------

<#
.SYNOPSIS
    Normalizes version text into a four-part dotted format.

.DESCRIPTION
    Pads missing parts with zeros so version comparison can be done safely using
    PowerShell/System.Version semantics.
#>
function Normalize-VersionString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionString
    )

    $clean = $VersionString.Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return $null
    }

    $parts = $clean.Split('.')
    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    $normalized = $parts[0..3] -join '.'
    return $normalized
}

<#
.SYNOPSIS
    Extracts a semantic version from free-text names.

.DESCRIPTION
    Finds the first 2-4 part numeric sequence in a name and normalizes it for
    stable version sorting.
#>
function Extract-VersionFromName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pattern = '\d+(\.\d+){1,3}'
    $match = [System.Text.RegularExpressions.Regex]::Match($Name, $pattern)
    if ($match.Success) {
        return Normalize-VersionString -VersionString $match.Value
    }

    return $null
}

# ------------------------------------------------------------
# TARGET FOLDER PATH HELPER
# ------------------------------------------------------------

<#
.SYNOPSIS
    Builds the SCCM folder path for master collection placement.

.DESCRIPTION
    Combines SiteCode and TargetFolder into the canonical
    DeviceCollection\Application Deployment path.
#>
function Get-TargetFolderPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $basePath = "{0}:\DeviceCollection\Application Deployment" -f $SiteCode
    return (Join-Path -Path $basePath -ChildPath $TargetFolder)
}

# ------------------------------------------------------------
# FOLDER HELPERS (CMFolder)
# ------------------------------------------------------------

<#
.SYNOPSIS
    Ensures the target collection folder exists and returns its resolved path.

.DESCRIPTION
    Tries multiple folder query and creation parameter patterns to support
    environment-specific SCCM cmdlet differences.
#>
function Ensure-CollectionFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $fullFolderPath = Get-TargetFolderPath -SiteCode $SiteCode -TargetFolder $TargetFolder
    $normalizedCandidates = @()
    $normalizedCandidates += $fullFolderPath
    $normalizedCandidates += $fullFolderPath -replace '^[^:]+:\\', ''
    $normalizedCandidates += $fullFolderPath -replace '^[^:]+:', ''
    $normalizedCandidates += "DeviceCollection\\Application Deployment\\$TargetFolder"
    $normalizedCandidates += "\\DeviceCollection\\Application Deployment\\$TargetFolder"
    $normalizedCandidates = $normalizedCandidates | Sort-Object -Unique

    try {
        $folder = $null
        foreach ($candidate in $normalizedCandidates) {
            if ($folder) { break }

            $queries = @(
                { Get-CMFolder -FolderPath $candidate -ErrorAction SilentlyContinue },
                { Get-CMFolder -Path $candidate -ErrorAction SilentlyContinue },
                { Get-CMFolder -Name $TargetFolder -ErrorAction SilentlyContinue | Where-Object { $_.FolderPath -eq $candidate } },
                { Get-CMFolder -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FolderPath -eq $candidate } }
            )

            foreach ($q in $queries) {
                try {
                    $result = & $q
                    if ($result) {
                        $folder = $result
                        break
                    }
                }
                catch {
                }
            }
        }

        if (-not $folder) {
            if ($DryRun) {
                Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("[DryRun] Would create folder: {0}" -f $fullFolderPath)
                return $fullFolderPath
            }
            else {
                $createAttempts = @(
                    { New-CMFolder -Name $TargetFolder -ParentFolderPath "DeviceCollection\\Application Deployment" -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $TargetFolder -ParentPath "DeviceCollection\\Application Deployment" -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $TargetFolder -Path "DeviceCollection\\Application Deployment" -ErrorAction Stop | Out-Null },
                    { New-CMFolder -FolderPath $fullFolderPath -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Path $fullFolderPath -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $TargetFolder -ObjectType SMS_Collection -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $TargetFolder -ObjectType SMS_ApplicationDeployment -ErrorAction Stop | Out-Null }
                )

                $result = Invoke-CmCommandWithFallback -Attempts $createAttempts -ActionName 'New-CMFolder'
                if ($result.Success) {
                    Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Created folder: {0}" -f $fullFolderPath)
                    return $fullFolderPath
                }

                Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("Could not create folder '{0}': no supported parameters succeeded." -f $fullFolderPath)
                return $fullFolderPath
            }
        }
        else {
            $resolvedPath = $folder.FolderPath
            if (-not $resolvedPath) {
                $resolvedPath = $fullFolderPath
            }
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Found existing folder: {0}" -f $resolvedPath)
            return $resolvedPath
        }
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("Could not ensure folder '{0}': {1}" -f $fullFolderPath, $_.Exception.Message)
        return $fullFolderPath
    }
}


<#
.SYNOPSIS
    Moves a collection object into a target SCCM folder.

.DESCRIPTION
    Executes multiple move command variants so the operation remains compatible
    across differing SCCM cmdlet parameter sets.
#>
function Move-CollectionToFolder {
    param(
        [Parameter(Mandatory = $true)]
        $Collection,
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $attempts = @(
        { Move-CMObject -ObjectId $Collection.CollectionID -FolderPath $FolderPath -ErrorAction Stop },
        { Move-CMObject -ObjectId $Collection.CollectionID -InputObject $Collection -FolderPath $FolderPath -ErrorAction Stop },
        { Move-CMObject -InputObject $Collection -FolderPath $FolderPath -ErrorAction Stop },
        { Move-CMObject -InputObject $Collection -Path $FolderPath -ErrorAction Stop },
        { Move-CMObject -InputObject $Collection -DestinationPath $FolderPath -ErrorAction Stop },
        { Move-CMObject -InputObject $Collection -Destination $FolderPath -ErrorAction Stop },
        { Move-CMObject -InputObject $Collection -TargetPath $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionId $Collection.CollectionID -FolderPath $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionName $Collection.Name -FolderPath $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionId $Collection.CollectionID -Path $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionId $Collection.CollectionID -DestinationPath $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionId $Collection.CollectionID -Destination $FolderPath -ErrorAction Stop },
        { Move-CMDeviceCollection -CollectionId $Collection.CollectionID -TargetPath $FolderPath -ErrorAction Stop }
    )

    $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Move collection'
    return $result.Success
}

# ------------------------------------------------------------
# GET ALL RELEVANT COLLECTIONS FOR SOFTWARE
# ------------------------------------------------------------

<#
.SYNOPSIS
    Retrieves all collections matching the requested software pattern.

.DESCRIPTION
    Queries SCCM by collection name wildcard and returns matches from all folders.
#>
function Get-SoftwareCollections {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Retrieving collections matching '{0}'..." -f $SoftwareName)

    try {
        $namePattern = ("*{0}*" -f $SoftwareName)
        # Query all collections matching the pattern (includes all folders)
        $collections = @(Get-CMDeviceCollection -Name $namePattern -ErrorAction Stop)
        Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Found {0} collections matching pattern '{1}'" -f $collections.Count, $namePattern)
        return $collections
    }
    catch {
        if ($_.Exception.Message -like '*Not found*') {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No collections found matching '{0}'." -f $SoftwareName)
            return @()
        }
        throw
    }
}

<#
.SYNOPSIS
    Extracts normalized ID and Name from a collection object.

.DESCRIPTION
    Centralizes property extraction logic to handle property name aliases
    across SCCM versions. Returns a PSObject with Id, Name, and IsValid properties.
#>
function Get-CollectionIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @{ Id = ''; Name = ''; IsValid = $false }
    }

    $id = [string](Get-ObjectPropertyValue -InputObject $InputObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $name = [string](Get-ObjectPropertyValue -InputObject $InputObject -PropertyNames @('Name', 'CollectionName'))

    return @{
        Id      = $id
        Name    = $name
        IsValid = (-not [string]::IsNullOrWhiteSpace($id) -or -not [string]::IsNullOrWhiteSpace($name))
    }
}

<#
.SYNOPSIS
    Safely executes a command with consistent error logging.

.DESCRIPTION
    Wraps try/catch logic to avoid repeated error-handling patterns
    across the script. Logs failures at DEBUG level.
#>
function Invoke-CmCommandSafe {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessageTemplate = "Command failed: {0}"
    )

    try {
        return & $Command
    }
    catch {
        $message = $ErrorMessageTemplate -f $_.Exception.Message
        Write-LogEvent -Level 'DEBUG' -Scope $Scope -Action 'Debug' -Detail $message
        return $null
    }
}

<#
.SYNOPSIS
    Creates or verifies application deployment to a master collection.

.DESCRIPTION
    Unified deployment logic for Available, Required, and Uninstall
    deployment purposes. Checks existing deployments, skips duplicates,
    and executes single deployment creation.
#>
function Ensure-MasterCollectionDeployment {
    param(
        [Parameter(Mandatory = $true)]
        $Application,

        [Parameter(Mandatory = $true)]
        $MasterCollection,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentPurpose,

        [Parameter(Mandatory = $false)]
        [string]$DeploymentAction = 'Install'
    )

    if (-not $MasterCollection -or -not $MasterCollection.Name) {
        return
    }

    $collectionName = $MasterCollection.Name
    $appName = $Application.LocalizedDisplayName

    # Check if deployment already exists
    $collectionDeployments = Get-CollectionDeployments -CollectionName $collectionName
    $existingDeployment = Find-ExistingApplicationDeployment -CollectionName $collectionName -Application $Application

    if ($existingDeployment -or $collectionDeployments.Count -gt 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appName, $collectionName)
        return
    }

    # Create new deployment
    try {
        $deployParams = @{
            CollectionName = $collectionName
            Name           = $appName
            DeployAction   = $DeploymentAction
            ErrorAction    = 'Stop'
        }

        if ($DeploymentAction -eq 'Install') {
            $deployParams['DeployPurpose'] = $DeploymentPurpose
        }

        Invoke-DryRunAction -Action {
            New-CMApplicationDeployment @deployParams | Out-Null
            Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Deployed '{0}' as '{1}' to collection '{2}'" -f $appName, $DeploymentPurpose, $collectionName)
        } -Description "deploy '$appName' as $DeploymentPurpose to collection '$collectionName'"
    }
    catch {
        if ($_.Exception.Message -match 'already been deployed') {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appName, $collectionName)
        }
        else {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not deploy '{0}' as '{1}' to collection '{2}': {3}" -f $appName, $DeploymentPurpose, $collectionName, $_.Exception.Message)
        }
    }
}

# ------------------------------------------------------------
# CANONICAL NAME RESOLUTION
# ------------------------------------------------------------
# This function resolves the canonical (clean, normalized) name
# used for master collections and folder structure.
#
# Improvements over the old version:
#   - Case-insensitive matching
#   - Supports partial matches (for example, "Notepad" -> "Notepad++")
#   - Supports auto-detected SoftwareName (e.g. "Notepad Notepad")
#   - Allows multiple mapping keys to point to the same canonical name
#   - Falls back safely to the input SoftwareName
#   - Easy to extend without breaking existing logic
# ------------------------------------------------------------

<#
.SYNOPSIS
    Resolves a canonical software family name.

.DESCRIPTION
    Uses a mapping table and tolerant matching rules (exact and partial) so
    naming differences in SCCM still converge to one master naming convention.
#>
function Get-CanonicalName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    # Canonical mapping table
    # Keys may be:
    #   - exact names
    #   - simplified names
    #   - auto-detected names
    #
    # Values are the canonical names used for master collections.
    $map = @{
        "Firefox"          = "Mozilla Firefox"
        "Mozilla Firefox"  = "Mozilla Firefox"

        "Chrome"           = "Google Chrome"
        "Google Chrome"    = "Google Chrome"

        # Notepad family
        "Notepad"          = "Notepad++"
        "Notepad Notepad"  = "Notepad++"
        "Notepad++"        = "Notepad++"

        # Brave family
        "Brave"                    = "MediaCellen Browser Brave"
        "Brave Browser"            = "MediaCellen Browser Brave"
        "MediaCellen Brave"        = "MediaCellen Browser Brave"
        "MediaCellen Browser Brave"= "MediaCellen Browser Brave"
    }

    # Normalize input for case-insensitive matching
    $normalizedInput = $SoftwareName.Trim().ToLower()

    # First: try exact (case-insensitive) match
    foreach ($key in $map.Keys) {
        if ($key.ToLower() -eq $normalizedInput) {
            return $map[$key]
        }
    }

    # Second: try partial match (e.g. "notepad" matches "notepad notepad")
    foreach ($key in $map.Keys) {
        if ($key.ToLower().Contains($normalizedInput)) {
            return $map[$key]
        }
    }

    # Third: try reverse partial match (e.g. "notepad notepad" matches "notepad")
    foreach ($key in $map.Keys) {
        if ($normalizedInput.Contains($key.ToLower())) {
            return $map[$key]
        }
    }

    # Fallback: return the input unchanged
    return $SoftwareName
}

<#
.SYNOPSIS
    Creates a master device collection with fallback parameter sets.

.DESCRIPTION
    Wraps New-CMDeviceCollection with environment-compatible attempts and returns
    the created object when successful.
#>
function New-MasterDeviceCollection {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Comment,
        [Parameter(Mandatory=$true)][string]$LimitingCollectionName,
        [Parameter(Mandatory=$true)][string]$FolderPath
    )

    $cmd = Get-CachedCommand -Name 'New-CMDeviceCollection'
    if (-not $cmd) {
        return $null
    }

    $attempts = @(
        { New-CMDeviceCollection -Name $Name -LimitingCollectionName $LimitingCollectionName -Comment $Comment -FolderPath $FolderPath -ErrorAction Stop },
        { New-CMDeviceCollection -Name $Name -LimitingCollectionName $LimitingCollectionName -Comment $Comment -Path $FolderPath -ErrorAction Stop },
        { New-CMDeviceCollection -Name $Name -LimitingCollectionName $LimitingCollectionName -Comment $Comment -CollectionFolderPath $FolderPath -ErrorAction Stop },
        { New-CMDeviceCollection -Name $Name -LimitingCollectionName $LimitingCollectionName -Comment $Comment -ErrorAction Stop }
    )

    $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'New-CMDeviceCollection'
    if ($result.Success) {
        return $result.Result
    }

    return $null
}

# ------------------------------------------------------------
# ENSURE MASTER COLLECTIONS (IN TARGET FOLDER)
# ------------------------------------------------------------

<#
.SYNOPSIS
    Ensures the three master collections exist for a canonical software name.

.DESCRIPTION
    Creates Install (Available), Install (Required), and Uninstall collections
    when missing, and moves them into the configured target folder.
#>
function Ensure-MasterCollections {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $fullFolderPath = Ensure-CollectionFolder -SiteCode $SiteCode -TargetFolder $TargetFolder

    $installAvailName = "{0} - Install (Available)" -f $CanonicalName
    $installReqName   = "{0} - Install (Required)"  -f $CanonicalName
    $uninstallName    = "{0} - Uninstall"           -f $CanonicalName

    # Use targeted per-name queries here instead of going through the full-scan
    # cache. The all-collections fetch takes 2+ minutes in large environments and
    # is only needed for dependency resolution, which happens later in the run.
    $installAvailCol = @(Get-CMDeviceCollection -Name $installAvailName -ErrorAction SilentlyContinue) | Select-Object -First 1
    $installReqCol   = @(Get-CMDeviceCollection -Name $installReqName   -ErrorAction SilentlyContinue) | Select-Object -First 1
    $uninstallCol    = @(Get-CMDeviceCollection -Name $uninstallName    -ErrorAction SilentlyContinue) | Select-Object -First 1

    if (-not $installAvailCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $installAvailName)
            $installAvailCol = [pscustomobject]@{ Name = $installAvailName; CollectionID = 0 }
        }
        else {
            $installAvailCol = New-MasterDeviceCollection -Name $installAvailName -LimitingCollectionName "All Systems" -Comment ("Master available install collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($installAvailCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $installAvailName)
            }
            else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not create master collection: {0}" -f $installAvailName)
            }
        }
    }

    if (-not $installReqCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $installReqName)
            $installReqCol = [pscustomobject]@{ Name = $installReqName; CollectionID = 0 }
        }
        else {
            $installReqCol = New-MasterDeviceCollection -Name $installReqName -LimitingCollectionName "All Systems" -Comment ("Master required install collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($installReqCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $installReqName)
            }
            else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not create master collection: {0}" -f $installReqName)
            }
        }
    }

    if (-not $uninstallCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $uninstallName)
            $uninstallCol = [pscustomobject]@{ Name = $uninstallName; CollectionID = 0 }
        }
        else {
            $uninstallCol = New-MasterDeviceCollection -Name $uninstallName -LimitingCollectionName "All Systems" -Comment ("Master uninstall collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($uninstallCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $uninstallName)
            }
            else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not create master collection: {0}" -f $uninstallName)
            }
        }
    }

    # Move newly created or discovered master collections into the target folder.
    if ($fullFolderPath -and -not $DryRun) {
        foreach ($col in @($installAvailCol, $installReqCol, $uninstallCol)) {
            if (-not $col) { continue }

            $moved = Move-CollectionToFolder -Collection $col -FolderPath $fullFolderPath
            if ($moved) {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Moved collection '{0}' to folder '{1}'." -f $col.Name, $fullFolderPath)
            }
            else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not move collection '{0}' to folder '{1}'. All move methods failed." -f $col.Name, $fullFolderPath)
            }
        }
    }

    return [pscustomobject]@{
        InstallAvailable = $installAvailCol
        InstallRequired  = $installReqCol
        Uninstall        = $uninstallCol
    }
}

# ------------------------------------------------------------
# CLEAR DIRECT MEMBERSHIP RULES
# ------------------------------------------------------------

<#
.SYNOPSIS
    Returns direct member ResourceIDs for a collection.

.DESCRIPTION
    Reads direct membership rules and returns a de-duplicated hash set used by
    union and difference calculations in master population.
#>
function Get-DirectMembershipResourceIds {
    param(
        [Parameter(Mandatory = $true)]
        $Collection
    )

    $ids = New-Object System.Collections.Generic.HashSet[int]

    if (-not $Collection -or -not $Collection.CollectionID -or $Collection.CollectionID -eq 0) {
        return ,$ids
    }

    try {
        $rules = Get-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionID -ErrorAction SilentlyContinue
        foreach ($rule in $rules) {
            if ($rule.ResourceID) { [void]$ids.Add($rule.ResourceID) }
        }
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not read direct membership rules for collection '{0}': {1}" -f ($Collection.Name -as [string]), $_.Exception.Message)
    }

    return ,$ids
}

<#
.SYNOPSIS
    Adds direct membership rules that are missing from a collection.

.DESCRIPTION
    Compares desired and existing ResourceIDs and only adds missing entries,
    preserving idempotency across repeated runs.
#>
function Add-DirectMembershipRulesIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        $Collection,
        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.HashSet[int]]$DesiredIds
    )

    if (-not $Collection -or -not $Collection.CollectionID -or $Collection.CollectionID -eq 0) {
        return
    }

    if (-not $DesiredIds -or $DesiredIds.Count -eq 0) {
        return
    }

    $existingIds = Get-DirectMembershipResourceIds -Collection $Collection
    $toAdd = @()
    foreach ($id in $DesiredIds) {
        if (-not $existingIds -or -not $existingIds.Contains($id)) { $toAdd += $id }
    }

    if ($toAdd.Count -eq 0) {
        return
    }

    foreach ($id in $toAdd) {
        Invoke-DryRunAction -Action {
            try {
                Add-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionID -ResourceId $id -ErrorAction Stop
            }
            catch {
                # Relationship may already exist from concurrent operations; ignore duplicate errors.
            }
        } -Description "add device ($id) to collection $($Collection.CollectionID)"
    }
}

# ------------------------------------------------------------
# GET MEMBERS FROM A SET OF COLLECTIONS
# ------------------------------------------------------------

<#
.SYNOPSIS
    Aggregates direct members from multiple collections.

.DESCRIPTION
    Collects direct member ResourceIDs across source collections into a single
    de-duplicated set used for master collection composition.
#>
function Get-DeviceMembersFromCollections {
    param(
        $Collections
    )

    $ids = New-Object System.Collections.Generic.HashSet[int]

    if (-not $Collections) {
        return ,$ids
    }

    $collectionList = @($Collections)
    if ($collectionList.Count -eq 0) {
        return ,$ids
    }

    foreach ($col in $collectionList) {
        # Pull direct membership rules from each source collection and merge
        # ResourceIDs into a de-duplicated hash set.
        if (-not $col -or -not $col.CollectionID -or $col.CollectionID -eq 0) {
            continue
        }

        try {
            $rules = Get-CMDeviceCollectionDirectMembershipRule -CollectionId $col.CollectionID -ErrorAction SilentlyContinue
            if (-not $rules) { continue }

            foreach ($rule in $rules) {
                if (-not $rule -or -not $rule.ResourceID) { continue }
                [void]$ids.Add($rule.ResourceID)
            }
        }
        catch {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not get members from collection '{0}': {1}" -f ($col.Name -as [string]), $_.Exception.Message)
        }
    }

    return ,$ids
}


# ------------------------------------------------------------
# POPULATE MASTER COLLECTIONS (AVAILABLE / REQUIRED / UNINSTALL)
# ------------------------------------------------------------

<#
.SYNOPSIS
    Populates master collections and ensures required deployments exist.

.DESCRIPTION
    Computes Available/Required/Uninstall membership sets from legacy collections,
    applies set logic, and ensures deployment coverage for each master collection.
#>
function Populate-MasterCollections {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        # Original user-supplied software name (may include year/edition qualifiers
        # such as '2019 x64').  Used to prefer a version-matched app over the
        # globally latest app in the family when no exact canonical match exists.
        [Parameter(Mandatory = $false)]
        [string]$RequestedSoftwareName = '',

        [Parameter(Mandatory = $true)]
        $Masters,

        [Parameter(Mandatory = $true)]
        $AllCollections
    )

    $populationStage = 'initialization'

    try {
        if (-not $CanonicalName) {
            Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Populate-MasterCollections aborted: CanonicalName is missing."
            return
        }

        if (-not $Masters -or -not $Masters.InstallAvailable -or -not $Masters.InstallRequired -or -not $Masters.Uninstall) {
            Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Populate-MasterCollections aborted: Master collection objects are missing or invalid."
            return
        }

        $populationStage = 'normalize inputs'
        $masterInstallAvailableName = "{0} - Install (Available)" -f $CanonicalName
        $masterInstallRequiredName  = "{0} - Install (Required)"  -f $CanonicalName
        $masterUninstallName        = "{0} - Uninstall"           -f $CanonicalName

        $masterInstallAvailable = $Masters.InstallAvailable
        $masterInstallRequired = $Masters.InstallRequired
        $masterUninstall = $Masters.Uninstall

        $all = Convert-ToSafeArray -InputObject $AllCollections
        if ($all.Count -eq 0) {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail "Populate-MasterCollections: AllCollections is empty. No members to calculate."
            return
        }

        $getCollectionName = {
            param($Collection)
            return [string](Get-ObjectPropertyValue -InputObject $Collection -PropertyNames @('Name', 'CollectionName'))
        }

        $populationStage = 'classify legacy collections'
        $legacyInstallAvailableCollections = @($all | Where-Object {
            $candidateName = [string](& $getCollectionName $_)
            $candidateName -like '*Install (Available)*' -and $candidateName -ne $masterInstallAvailableName
        })

        $legacyInstallRequiredCollections = @($all |
            Where-Object {
                $candidateName = [string](& $getCollectionName $_)
                $candidateName -like '*Install*'
            } |
            Where-Object {
                $candidateName = [string](& $getCollectionName $_)
                $candidateName -notlike '*Install (Available)*'
            } |
            Where-Object {
                $candidateName = [string](& $getCollectionName $_)
                $candidateName -notlike '*Uninstall*'
            } |
            Where-Object {
                $candidateName = [string](& $getCollectionName $_)
                $candidateName -ne $masterInstallRequiredName -and
                $candidateName -ne $masterInstallAvailableName -and
                $candidateName -ne $masterUninstallName
            })

        $legacyUninstallCollections = @($all | Where-Object {
            $candidateName = [string](& $getCollectionName $_)
            $candidateName -like '*Uninstall*' -and $candidateName -ne $masterUninstallName
        })

        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Legacy Install (Available): {0}" -f ((@($legacyInstallAvailableCollections | ForEach-Object { [string](& $getCollectionName $_) }) -join ', ')))
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Legacy Install (Required):  {0}" -f ((@($legacyInstallRequiredCollections | ForEach-Object { [string](& $getCollectionName $_) }) -join ', ')))
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Legacy Uninstall:           {0}" -f ((@($legacyUninstallCollections | ForEach-Object { [string](& $getCollectionName $_) }) -join ', ')))

        $populationStage = 'resolve deployable application'
        $canonicalApps = Convert-ToSafeArray -InputObject (Get-ApplicationsForSoftwareName -SoftwareName $CanonicalName)
        $appForMasterDeploy = @($canonicalApps | Where-Object { [string]$_.LocalizedDisplayName -eq $CanonicalName } | Select-Object -First 1)
        if ($appForMasterDeploy.Count -gt 0) {
            $appForMasterDeploy = $appForMasterDeploy[0]
        }
        else {
            # If the caller supplied a more specific name (e.g. includes a year or
            # architecture qualifier), try that first so we stay within the right
            # product generation rather than jumping to the globally latest app.
            if (-not [string]::IsNullOrWhiteSpace($RequestedSoftwareName) -and
                $RequestedSoftwareName -ne $CanonicalName) {
                $appForMasterDeploy = Get-LatestVersionedApplication -SoftwareName $RequestedSoftwareName
            }
            if (-not $appForMasterDeploy) {
                $appForMasterDeploy = Get-LatestVersionedApplication -SoftwareName $CanonicalName
            }
            if ($appForMasterDeploy) {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail (
                    "No exact canonical-name app found for '{0}'. Using latest versioned app '{1}' for master deployments." -f $CanonicalName, ([string]$appForMasterDeploy.LocalizedDisplayName)
                )
            }
        }

        $populationStage = 'handle empty available sources'
        if ($legacyInstallAvailableCollections.Count -eq 0) {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail "No previous 'Available' collections found. Creating empty master 'Available' collection and deploying software as 'Available'."
            $masterInstallAvailableNameResolved = [string](Get-ObjectPropertyValue -InputObject $masterInstallAvailable -PropertyNames @('Name', 'CollectionName'))

            if ($masterInstallAvailable -and -not [string]::IsNullOrWhiteSpace($masterInstallAvailableNameResolved)) {
                if (-not $DryRun) {
                    $app = $appForMasterDeploy
                    if ($app) {
                        $collectionDeployments = Get-CollectionDeployments -CollectionName $masterInstallAvailableNameResolved
                        $existingDeployment = Find-ExistingApplicationDeployment -CollectionName $masterInstallAvailableNameResolved -Application $app

                        if ($existingDeployment -or $collectionDeployments.Count -gt 0) {
                            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f ([string]$app.LocalizedDisplayName), $masterInstallAvailableNameResolved)
                        }
                        else {
                            try {
                                Invoke-DryRunAction -Action {
                                    New-CMApplicationDeployment -CollectionName $masterInstallAvailableNameResolved -Name $app.LocalizedDisplayName -DeployAction Install -DeployPurpose Available -ErrorAction Stop | Out-Null
                                    Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Deployed '{0}' as 'Available' to collection '{1}'" -f ([string]$app.LocalizedDisplayName), $masterInstallAvailableNameResolved)
                                } -Description "deploy '$($app.LocalizedDisplayName)' as Available to collection '$masterInstallAvailableNameResolved'"
                            }
                            catch {
                                if ($_.Exception.Message -match 'already been deployed') {
                                    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f ([string]$app.LocalizedDisplayName), $masterInstallAvailableNameResolved)
                                }
                                else {
                                    throw
                                }
                            }
                        }
                    }
                    else {
                        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No deployable application found for '{0}'. Deployment to master Available collection skipped." -f $CanonicalName)
                    }
                }
                else {
                    $dryRunAppName = $CanonicalName
                    if ($appForMasterDeploy) {
                        $dryRunAppName = [string]$appForMasterDeploy.LocalizedDisplayName
                    }
                    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would deploy '{0}' as 'Available' to collection '{1}'" -f $dryRunAppName, $masterInstallAvailableNameResolved)
                }
            }
            else {
                Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Master 'Available' collection does not exist or has no name."
            }
        }

        $populationStage = 'calculate memberships'
        $availableIds = Get-DeviceMembersFromCollections -Collections $legacyInstallAvailableCollections
        $requiredSourceIds = Get-DeviceMembersFromCollections -Collections $legacyInstallRequiredCollections
        $uninstallIds = Get-DeviceMembersFromCollections -Collections $legacyUninstallCollections

        $requiredIds = New-Object System.Collections.Generic.HashSet[int]
        if (-not $availableIds) {
            $availableIds = New-Object System.Collections.Generic.HashSet[int]
        }

        if ($requiredSourceIds) {
            foreach ($id in $requiredSourceIds) {
                if (-not $id) {
                    continue
                }

                if (-not ($availableIds -and $availableIds.Contains($id))) {
                    [void]$requiredIds.Add($id)
                }
            }
        }

        $availableCount = 0
        $requiredCount = 0
        $uninstallCount = 0
        if ($availableIds) { $availableCount = $availableIds.Count }
        if ($requiredIds) { $requiredCount = $requiredIds.Count }
        if ($uninstallIds) { $uninstallCount = $uninstallIds.Count }

        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Available members (count): {0}" -f $availableCount)
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Required members (count): {0}" -f $requiredCount)
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Uninstall members (count): {0}" -f $uninstallCount)

        $populationStage = 'apply memberships and deployments'
        if (-not $DryRun) {
            if ($masterInstallAvailable -and $masterInstallAvailable.CollectionID -and $masterInstallAvailable.CollectionID -ne 0) {
                Add-DirectMembershipRulesIfMissing -Collection $masterInstallAvailable -DesiredIds $availableIds
            }

            if ($masterInstallRequired -and $masterInstallRequired.CollectionID -and $masterInstallRequired.CollectionID -ne 0) {
                Add-DirectMembershipRulesIfMissing -Collection $masterInstallRequired -DesiredIds $requiredIds
            }

            if ($masterUninstall -and $masterUninstall.CollectionID -and $masterUninstall.CollectionID -ne 0) {
                Add-DirectMembershipRulesIfMissing -Collection $masterUninstall -DesiredIds $uninstallIds
            }

            $app = $appForMasterDeploy
            if ($app) {
                Ensure-MasterCollectionDeployment -Application $app -MasterCollection $masterInstallAvailable -DeploymentPurpose 'Available'
                Ensure-MasterCollectionDeployment -Application $app -MasterCollection $masterInstallRequired -DeploymentPurpose 'Required'
                Ensure-MasterCollectionDeployment -Application $app -MasterCollection $masterUninstall -DeploymentPurpose 'Uninstall' -DeploymentAction 'Uninstall'
            }
            else {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No deployable application found for '{0}'. Skipping master collection deployment creation." -f $CanonicalName)
            }
        }
        else {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail '[DryRun] Would populate master collections with calculated members.'
        }
    }
    catch {
        Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail ("Populate-MasterCollections failed during stage '{0}': {1}" -f $populationStage, $_.Exception.Message)
        return
    }
}

# ------------------------------------------------------------
# FIND TASK SEQUENCES REFERENCING AN APP
# ------------------------------------------------------------

function Find-TaskSequencesReferencingApp {
    param(
        [Parameter(Mandatory = $false)]
        $AppCI_ID = $null,

        [Parameter(Mandatory = $false)]
        [string]$AppModelName = ''
    )

    try {
        if ($null -eq $script:TaskSequenceReferenceCache) {
            $script:TaskSequenceReferenceCache = @{}

            try {
                # Use -Fast to avoid loading lazy properties and suppress warnings in newer CM environments.
                $taskSequences = @(Get-CMTaskSequence -Fast -ErrorAction SilentlyContinue)
            }
            catch {
                try {
                    $taskSequences = @(Get-CMTaskSequence -ErrorAction SilentlyContinue)
                }
                catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Applications' -Action 'Warning' -Detail ("Could not retrieve task sequences: {0}" -f $_.Exception.Message)
                    $taskSequences = @()
                }
            }

            foreach ($ts in $taskSequences) {
                # Parse each task sequence once, then index all discovered references
                # so later lookups are fast key-based reads.
                $sequenceText = [string]($ts.Sequence -as [string])
                if ([string]::IsNullOrWhiteSpace($sequenceText)) {
                    continue
                }

                $tsEntry = [pscustomobject]@{
                    TaskSequenceName = [string]$ts.Name
                    PackageId        = [string]$ts.PackageID
                }

                $addToCache = {
                    param([string]$Key)
                    if ([string]::IsNullOrWhiteSpace($Key)) { return }
                    if (-not $script:TaskSequenceReferenceCache.ContainsKey($Key)) {
                        $script:TaskSequenceReferenceCache[$Key] = New-Object System.Collections.Generic.List[object]
                    }
                    [void]$script:TaskSequenceReferenceCache[$Key].Add($tsEntry)
                }

                # Index by numeric CI_ID values (<CI_ID>12345</CI_ID>).
                $ciIdMatches = [System.Text.RegularExpressions.Regex]::Matches($sequenceText, '<CI_ID>\s*(\d+)\s*</CI_ID>')
                foreach ($match in $ciIdMatches) {
                    if ($match.Success -and $match.Groups.Count -gt 1) {
                        & $addToCache ([string]$match.Groups[1].Value)
                    }
                }

                # Index by ModelName strings (ScopeId_xxx/Application_xxx).
                # SCCM task sequences reference installed apps via ModelName in
                # AppInfo XML blocks, which is the primary reference mechanism
                # for Install Application steps.
                $modelMatches = [System.Text.RegularExpressions.Regex]::Matches(
                    $sequenceText,
                    'ScopeId_[0-9A-Fa-f\-]+/Application_[0-9A-Fa-f\-]+'
                )
                foreach ($match in $modelMatches) {
                    if ($match.Success) {
                        & $addToCache ([string]$match.Value)
                    }
                }

                # XML fallback for CI_ID when regex found nothing numeric.
                $hasNumericKeys = $false
                foreach ($k in $script:TaskSequenceReferenceCache.Keys) {
                    if ([string]$k -match '^\d+$') {
                        $hasNumericKeys = $true
                        break
                    }
                }
                if (-not $hasNumericKeys) {
                    try {
                        $xml = [xml]$sequenceText
                        $ciNodes = $xml.SelectNodes("//*[local-name()='CI_ID']")
                        if ($ciNodes) {
                            foreach ($ciNode in $ciNodes) {
                                & $addToCache ([string]$ciNode.InnerText)
                            }
                        }
                    }
                    catch { }
                }
            }

            Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Cached task sequence application references for {0} key(s) (CI_ID + ModelName)." -f $script:TaskSequenceReferenceCache.Keys.Count)
        }

        $results = @()
        $resultKeys = @{}

        if (-not ($script:TaskSequenceReferenceCache -is [hashtable])) {
            $script:TaskSequenceReferenceCache = @{}
        }

        $addResult = {
            param($Entry)
            if (-not $Entry) { return }
            $pk = [string](Get-ObjectPropertyValue -InputObject $Entry -PropertyNames @('PackageId'))
            $nm = [string](Get-ObjectPropertyValue -InputObject $Entry -PropertyNames @('TaskSequenceName'))
            $key = ("{0}|{1}" -f $pk, $nm)
            if (-not $resultKeys.ContainsKey($key)) {
                $resultKeys[$key] = $true
                $results += $Entry
            }
        }

        # Check by numeric CI_ID.
        $ciIdKey = [string]$AppCI_ID
        if (-not [string]::IsNullOrWhiteSpace($ciIdKey)) {
            if ($script:TaskSequenceReferenceCache.ContainsKey($ciIdKey)) {
                foreach ($r in $script:TaskSequenceReferenceCache[$ciIdKey]) {
                    & $addResult $r
                }
            }
        }

        # Check by ModelName (the more reliable reference in modern SCCM).
        if (-not [string]::IsNullOrWhiteSpace($AppModelName)) {
            if ($script:TaskSequenceReferenceCache.ContainsKey($AppModelName)) {
                foreach ($r in $script:TaskSequenceReferenceCache[$AppModelName]) {
                    & $addResult $r
                }
            }
        }

        return @($results)
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Applications' -Action 'Warning' -Detail ("Task sequence reference lookup failed for CI_ID='{0}', ModelName='{1}': {2}" -f ([string]$AppCI_ID), ([string]$AppModelName), $_.Exception.Message)
        return @()
    }
}

<#
.SYNOPSIS
    Applies supersedence using compatible parameter-set fallbacks.

.DESCRIPTION
    Resolves deployment type metadata when required and iterates known
    Set-CMApplicationSupersedence parameter combinations until one succeeds.
#>
function Try-Set-ApplicationSupersedence {
    param(
        [Parameter(Mandatory=$true)]
        $OlderApp,
        [Parameter(Mandatory=$true)]
        $NewerApp
    )

    $cmd = Get-CachedCommand -Name 'Set-CMApplicationSupersedence'
    if (-not $cmd) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Supersedence' -Action 'Debug' -Detail "Set-CMApplicationSupersedence command is unavailable."
        return $false
    }

    $paramNames = @($cmd.Parameters.Keys)
    $attempts = @()

    # Resolve deployment type metadata when required by this SCCM parameter set.
    $requiresCurrentDt = ($paramNames -contains 'CurrentDeploymentTypeId' -or $paramNames -contains 'CurrentDeploymentTypeName' -or $paramNames -contains 'CurrentDeploymentType')
    $requiresOldDt = ($paramNames -contains 'OldDeploymentTypeId' -or $paramNames -contains 'OldDeploymentTypeName' -or $paramNames -contains 'OldDeploymentType')

    $newerDt = $null
    $olderDt = $null

    if ($requiresCurrentDt -or $requiresOldDt) {
        $getDeploymentTypeCommand = Get-CachedCommand -Name 'Get-CMDeploymentType'

        $resolveDt = {
            param($App)

            if (-not $getDeploymentTypeCommand) {
                return $null
            }

            $dtAttempts = @(
                { @(Get-CMDeploymentType -InputObject $App -ErrorAction Stop) },
                { @(Get-CMDeploymentType -ApplicationName $App.LocalizedDisplayName -ErrorAction Stop) },
                { @(Get-CMDeploymentType -ApplicationId $App.CI_ID -ErrorAction Stop) }
            )

            foreach ($dtAttempt in $dtAttempts) {
                try {
                    $resolved = & $dtAttempt
                    if ($resolved -and @($resolved).Count -gt 0) {
                        return @($resolved)[0]
                    }
                }
                catch {
                }
            }

            return $null
        }

        if ($requiresCurrentDt) {
            $newerDt = & $resolveDt $NewerApp
        }
        if ($requiresOldDt) {
            $olderDt = & $resolveDt $OlderApp
        }
    }

    $newerDtId = $null
    $newerDtName = $null
    $olderDtId = $null
    $olderDtName = $null

    if ($newerDt) {
        $newerDtId = Get-ObjectPropertyValue -InputObject $newerDt -PropertyNames @('CI_ID', 'CIId', 'DeploymentTypeID', 'DeploymentTypeId', 'ModelID', 'ModelId')
        $newerDtName = Get-ObjectPropertyValue -InputObject $newerDt -PropertyNames @('LocalizedDisplayName', 'DeploymentTypeName', 'Name', 'Title')
    }
    if ($olderDt) {
        $olderDtId = Get-ObjectPropertyValue -InputObject $olderDt -PropertyNames @('CI_ID', 'CIId', 'DeploymentTypeID', 'DeploymentTypeId', 'ModelID', 'ModelId')
        $olderDtName = Get-ObjectPropertyValue -InputObject $olderDt -PropertyNames @('LocalizedDisplayName', 'DeploymentTypeName', 'Name', 'Title')
    }

    # Build parameter sets that include Current/Old deployment type values when required.
    if (($paramNames -contains 'InputObject') -and ($paramNames -contains 'SupersededApplicationId')) {
        if (($paramNames -contains 'CurrentDeploymentTypeId') -and ($paramNames -contains 'OldDeploymentTypeId') -and $newerDtId -and $olderDtId) {
            $attempts += [pscustomobject]@{
                Label = 'InputObject+SupersededApplicationId+CurrentDeploymentTypeId+OldDeploymentTypeId'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentTypeId $newerDtId -OldDeploymentTypeId $olderDtId -Force -ErrorAction Stop }
            }
        }
        if (($paramNames -contains 'CurrentDeploymentTypeName') -and ($paramNames -contains 'OldDeploymentTypeName') -and $newerDtName -and $olderDtName) {
            $attempts += [pscustomobject]@{
                Label = 'InputObject+SupersededApplicationId+CurrentDeploymentTypeName+OldDeploymentTypeName'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentTypeName $newerDtName -OldDeploymentTypeName $olderDtName -Force -ErrorAction Stop }
            }
        }
        if (($paramNames -contains 'CurrentDeploymentType') -and ($paramNames -contains 'OldDeploymentType') -and $newerDt -and $olderDt) {
            $attempts += [pscustomobject]@{
                Label = 'InputObject+SupersededApplicationId+CurrentDeploymentType+OldDeploymentType'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentType $newerDt -OldDeploymentType $olderDt -Force -ErrorAction Stop }
            }
        }
    }

    # Fallback sets (for environments that do not require deployment type arguments).
    if (($paramNames -contains 'InputObject') -and ($paramNames -contains 'SupersededApplicationId')) {
        $attempts += [pscustomobject]@{
            Label = 'InputObject+SupersededApplicationId'
            Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -Force -ErrorAction Stop }
        }
    }
    if (($paramNames -contains 'Id') -and ($paramNames -contains 'SupersededApplicationId')) {
        $attempts += [pscustomobject]@{
            Label = 'Id+SupersededApplicationId'
            Action = { & $cmd -Id $NewerApp.CI_ID -SupersededApplicationId $OlderApp.CI_ID -Force -ErrorAction Stop }
        }
    }
    if (($paramNames -contains 'Name') -and ($paramNames -contains 'SupersededApplicationName')) {
        $attempts += [pscustomobject]@{
            Label = 'Name+SupersededApplicationName'
            Action = { & $cmd -Name $NewerApp.LocalizedDisplayName -SupersededApplicationName $OlderApp.LocalizedDisplayName -Force -ErrorAction Stop }
        }
    }

    if ($attempts.Count -eq 0) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Supersedence' -Action 'Debug' -Detail "No known parameter set available for Set-CMApplicationSupersedence; skipping supersedence set call. Available params: $($paramNames -join ', ')"
        return $false
    }

    foreach ($attempt in $attempts) {
        try {
            & $attempt.Action
            Write-LogEvent -Level 'DEBUG' -Scope 'Supersedence' -Action 'Debug' -Detail ("Applied supersedence for '{0}' -> '{1}' with params: {2}" -f $OlderApp.LocalizedDisplayName, $NewerApp.LocalizedDisplayName, $attempt.Label)
            return $true
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Supersedence' -Action 'Debug' -Detail ("Could not apply supersedence for '{0}' -> '{1}' with params {2}: {3}" -f $OlderApp.LocalizedDisplayName, $NewerApp.LocalizedDisplayName, $attempt.Label, $_.Exception.Message)
        }
    }

    return $false
}

# ------------------------------------------------------------
# SUPERSEDENCE (LINEAR CHAIN)
# ------------------------------------------------------------

<#
.SYNOPSIS
    Builds and applies a linear supersedence chain for a software family.

.DESCRIPTION
    Sorts versioned applications from oldest to newest and links each adjacent
    pair to form a deterministic supersedence chain.
#>
function Apply-SupersedenceAndDeployments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName,

        [Parameter(Mandatory = $false)]
        [switch]$ManageSupersedence
    )

    if (-not $ManageSupersedence) {
        Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Skipped' -Detail 'ManageSupersedence not specified.'
        return
    }

    $normalizedSoftwareName = ($SoftwareName -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedSoftwareName) -or $normalizedSoftwareName.Length -lt 3) {
        Write-LogEvent -Level 'WARN' -Scope 'Supersedence' -Action 'Skipped' -Detail ("SoftwareName '{0}' is too short for safe scope." -f $SoftwareName)
        return
    }

    Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Enabled'

    $supersedenceCmd = Get-CachedCommand -Name 'Set-CMApplicationSupersedence'
    if (-not $supersedenceCmd) {
        Write-LogEvent -Level 'WARN' -Scope 'Supersedence' -Action 'Skipped' -Detail 'Set-CMApplicationSupersedence is unavailable in this SCCM environment.'
        return
    }

    $appsWithVersion = Get-VersionedApplicationsForSoftwareName -SoftwareName $normalizedSoftwareName

    if (-not $appsWithVersion -or $appsWithVersion.Count -lt 2) {
        Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Skipped' -Detail 'Not enough versioned applications to build a chain.'
        return
    }

    $appsSorted = @($appsWithVersion | Sort-Object { [version]$_.Version })  # oldest -> newest

    # Normalize entries so reruns with partial/odd SCCM objects do not crash.
    $chainEntries = @()
    foreach ($entry in $appsSorted) {
        if (-not $entry) { continue }

        $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
        if (-not $entryApp) { continue }

        $entryName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName','Name'))
        if ([string]::IsNullOrWhiteSpace($entryName)) {
            $entryName = '[Unnamed application]'
        }

        $entryVersionRaw = [string](Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('Version'))
        if ([string]::IsNullOrWhiteSpace($entryVersionRaw)) {
            $entryVersionRaw = [string](Extract-VersionFromName -Name $entryName)
        }

        $entryVersion = [version]'0.0.0'
        if (-not [string]::IsNullOrWhiteSpace($entryVersionRaw)) {
            try { $entryVersion = [version]$entryVersionRaw } catch {}
        }

        $chainEntries += [pscustomobject]@{
            App     = $entryApp
            Name    = $entryName
            Version = $entryVersion
        }
    }

    $chainEntries = @($chainEntries | Sort-Object -Property Version)

    if ($chainEntries.Count -lt 2) {
        Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Skipped' -Detail 'Not enough valid applications to build a chain after normalization.'
        return
    }

    $chainDisplay = [string]::Join(' -> ', @($chainEntries | ForEach-Object { $_.Name }))
    Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Build chain' -Detail $chainDisplay

    for ($i = 0; $i -lt $chainEntries.Count - 1; $i++) {
        # Create adjacent pairs (older -> newer) to form a linear supersedence
        # chain that is easy to reason about and troubleshoot.
        $olderEntry = $chainEntries[$i]
        $newerEntry = $chainEntries[$i+1]
        $older = $olderEntry.App
        $newer = $newerEntry.App

        try {
            if (-not $DryRun) {
                $ok = Try-Set-ApplicationSupersedence -OlderApp $older -NewerApp $newer
                if (-not $ok) {
                    throw "Set-CMApplicationSupersedence command not supported with detected parameter set."
                }
            }

            Write-LogEvent -Level 'SUCCESS' -Scope 'Supersedence' -Action 'Linked' -Detail (("'{0}' supersedes '{1}'") -f $newerEntry.Name, $olderEntry.Name)
        }
        catch {
            Write-LogEvent -Level 'WARN' -Scope 'Supersedence' -Action 'Link failed' -Detail (("'{0}' -> '{1}' | {2}") -f $olderEntry.Name, $newerEntry.Name, $_.Exception.Message)
        }
    }
}
# ------------------------------------------------------------
# ROBUST DEPLOYMENT REMOVAL
# ------------------------------------------------------------

<#
.SYNOPSIS
    Deletes deployments using resilient non-interactive fallback calls.

.DESCRIPTION
    Attempts delete by input object, deployment id, or app/collection pair based
    on environment support, and records failures for retry/reporting.
#>
function Remove-Deployment-Robust {
    param(
        [Parameter(Mandatory = $true)]
        $Deployment
    )

    $deploymentId = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id')
    $collectionName = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('CollectionName', 'TargetCollectionName')
    $applicationName = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name')
    $packageName = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('PackageName', 'PackageID', 'PackageId')

    if ([string]::IsNullOrWhiteSpace(($deploymentId -as [string])) -and
        [string]::IsNullOrWhiteSpace(($applicationName -as [string]))) {

        Write-LogEvent -Level 'WARN' -Scope 'Deployments' -Action 'Warning' -Detail ("Could not delete deployment: neither DeploymentId nor ApplicationName was available (Collection: {0})." -f ($collectionName -as [string]))
        [void]$failedDeployments.Add(
            [pscustomobject]@{
                DeploymentID   = $deploymentId
                CollectionName = $collectionName
                Error          = 'Missing DeploymentId/ApplicationName on deployment object'
            }
        )
        return
    }

    if ([string]::IsNullOrWhiteSpace(($applicationName -as [string])) -and
        -not [string]::IsNullOrWhiteSpace(($packageName -as [string]))) {

        Write-LogEvent -Level 'WARN' -Scope 'Deployments' -Action 'Warning' -Detail ("Skipping non-application deployment cleanup item (Package: {0}, Collection: {1})." -f ($packageName -as [string]), ($collectionName -as [string]))
        [void]$failedDeployments.Add(
            [pscustomobject]@{
                DeploymentID   = $deploymentId
                CollectionName = $collectionName
                Error          = 'Non-application deployment; skipped by script'
            }
        )
        return
    }

    try {
        $removeDeploymentCommand = Get-CachedCommand -Name 'Remove-CMDeployment'
        if (-not $removeDeploymentCommand) {
            throw "Remove-CMDeployment command is not available in current session."
        }

        # Parameters on binary SCCM cmdlets uses lazy initialization. On the very
        # first access in a session the property can be null before the assembly
        # finishes loading its metadata. Detect this and force a fresh lookup so
        # the metadata is resolved before building the attempt list.
        $commandParameters = $null
        try { $commandParameters = $removeDeploymentCommand.Parameters } catch {}
        if ($null -eq $commandParameters) {
            $removeDeploymentCommand = Get-Command 'Remove-CMDeployment' -ErrorAction SilentlyContinue
            $script:CommandMetadataCache['Remove-CMDeployment'] = $removeDeploymentCommand
            try { $commandParameters = $removeDeploymentCommand.Parameters } catch {}
        }
        $commandParameterNames = if ($null -ne $commandParameters) { @($commandParameters.Keys) } else { @() }

        $attempts = @()

        # Only add InputObject attempt if the Deployment parameter is valid and non-null
        if (($commandParameterNames -contains 'InputObject') -and ($null -ne $Deployment)) {
            $attempts += {
                Remove-CMDeployment -InputObject $Deployment -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
            }
        }

        # Fresh-fetch attempt: if InputObject failed due to object corruption, try getting a fresh copy by ID
        if (($commandParameterNames -contains 'InputObject') -and
            -not [string]::IsNullOrWhiteSpace(($deploymentId -as [string]))) {
            $attempts += {
                $freshDeployment = Get-CMDeployment -DeploymentId $deploymentId -ErrorAction Stop
                if ($null -ne $freshDeployment) {
                    Remove-CMDeployment -InputObject $freshDeployment -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
                }
                else {
                    throw "Could not retrieve fresh deployment object for ID: $deploymentId"
                }
            }
        }

        if (($commandParameterNames -contains 'DeploymentId') -and
            -not [string]::IsNullOrWhiteSpace(($deploymentId -as [string]))) {
            $attempts += {
                Remove-CMDeployment -DeploymentId $deploymentId -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
            }
        }

        if (($commandParameterNames -contains 'ApplicationName') -and
            ($commandParameterNames -contains 'CollectionName') -and
            -not [string]::IsNullOrWhiteSpace(($applicationName -as [string])) -and
            -not [string]::IsNullOrWhiteSpace(($collectionName -as [string]))) {
            $attempts += {
                Remove-CMDeployment -ApplicationName $applicationName -CollectionName $collectionName -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
            }
        }

        if ($attempts.Count -eq 0) {
            throw ("No valid non-interactive Remove-CMDeployment call could be built. Available params: {0}" -f ($commandParameterNames -join ', '))
        }

        Invoke-DryRunAction -Action {
            $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Remove-CMDeployment'
            if (-not $result.Success) {
                throw "All Remove-CMDeployment fallback attempts failed."
            }
        } -Description "delete deployment '$($deploymentId -as [string])' (collection '$($collectionName -as [string])')"

        if (-not $DryRun) {
            Write-LogEvent -Level 'SUCCESS' -Scope 'Deployments' -Action 'Success' -Detail ("Deleted deployment: {0} (Collection: {1})" -f ($deploymentId -as [string]), ($collectionName -as [string]))
        }
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Deployments' -Action 'Warning' -Detail ("Could not delete deployment {0}: {1}" -f ($deploymentId -as [string]), $_.Exception.Message)
        if ($_.ScriptStackTrace) {
            Write-LogEvent -Level 'DEBUG' -Scope 'Deployments' -Action 'Debug' -Detail ("Stack: {0}" -f $_.ScriptStackTrace)
        }

        [void]$failedDeployments.Add(
            [pscustomobject]@{
                DeploymentID   = $deploymentId
                CollectionName = $collectionName
                Error          = $_.Exception.Message
            }
        )
    }
}

function Get-CollectionDependencySnapshot {
    <#
    .SYNOPSIS
        Captures include, exclude and limiting references to a collection.

    .DESCRIPTION
        Collection delete can fail if other collections reference it. This helper
        builds a pre-delete dependency snapshot used for logging, cleanup and
        blocker diagnostics.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TargetCollection,

        [Parameter(Mandatory = $false)]
        [switch]$RefreshIndex
    )

    $targetCollectionId = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $targetCollectionName = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('Name', 'CollectionName'))

    $includeDependents = New-Object System.Collections.Generic.List[object]
    $excludeDependents = New-Object System.Collections.Generic.List[object]
    $limitingDependents = New-Object System.Collections.Generic.List[object]

    if ([string]::IsNullOrWhiteSpace($targetCollectionId) -and [string]::IsNullOrWhiteSpace($targetCollectionName)) {
        return [pscustomobject]@{
            IncludeDependents  = @()
            ExcludeDependents  = @()
            LimitingDependents = @()
        }
    }

    $dependencyIndex = Get-CachedCollectionDependencyIndex -Refresh:$RefreshIndex

    if (-not $dependencyIndex) {
        return [pscustomobject]@{
            IncludeDependents  = @()
            ExcludeDependents  = @()
            LimitingDependents = @()
        }
    }

    $collectUniqueDependents = {
        param(
            [object[]]$Entries,
            [string]$SelfId,
            [string]$SelfName
        )

        $unique = @{}
        foreach ($entry in @($Entries)) {
            if (-not $entry) { continue }

            $entryId = [string](Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
            $entryName = [string](Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('Name', 'CollectionName'))

            if (($entryId -and $SelfId -and $entryId -eq $SelfId) -or
                ($entryName -and $SelfName -and $entryName -eq $SelfName)) {
                continue
            }

            $uniqueKey = ("{0}|{1}" -f $entryId, $entryName)
            if (-not $unique.ContainsKey($uniqueKey)) {
                $unique[$uniqueKey] = [pscustomobject]@{
                    CollectionID = $entryId
                    Name         = $entryName
                    RuleCount    = 0
                }
            }

            $current = $unique[$uniqueKey]
            $current.RuleCount = [int]$current.RuleCount + 1
        }

        return @($unique.Values)
    }

    $includeEntries = @()
    $excludeEntries = @()
    $limitingEntries = @()

    if (-not [string]::IsNullOrWhiteSpace($targetCollectionId)) {
        if ($dependencyIndex.IncludeByTargetId.ContainsKey($targetCollectionId)) {
            $includeEntries += @($dependencyIndex.IncludeByTargetId[$targetCollectionId])
        }
        if ($dependencyIndex.ExcludeByTargetId.ContainsKey($targetCollectionId)) {
            $excludeEntries += @($dependencyIndex.ExcludeByTargetId[$targetCollectionId])
        }
        if ($dependencyIndex.LimitingByTargetId.ContainsKey($targetCollectionId)) {
            $limitingEntries += @($dependencyIndex.LimitingByTargetId[$targetCollectionId])
        }
    }

    $targetNameKey = $null
    if (-not [string]::IsNullOrWhiteSpace($targetCollectionName)) {
        $targetNameKey = $targetCollectionName.Trim().ToLowerInvariant()
    }

    if (-not [string]::IsNullOrWhiteSpace($targetNameKey)) {
        if ($dependencyIndex.IncludeByTargetName.ContainsKey($targetNameKey)) {
            $includeEntries += @($dependencyIndex.IncludeByTargetName[$targetNameKey])
        }
        if ($dependencyIndex.ExcludeByTargetName.ContainsKey($targetNameKey)) {
            $excludeEntries += @($dependencyIndex.ExcludeByTargetName[$targetNameKey])
        }
        if ($dependencyIndex.LimitingByTargetName.ContainsKey($targetNameKey)) {
            $limitingEntries += @($dependencyIndex.LimitingByTargetName[$targetNameKey])
        }
    }

    foreach ($includeDependent in & $collectUniqueDependents $includeEntries $targetCollectionId $targetCollectionName) {
        [void]$includeDependents.Add($includeDependent)
    }

    foreach ($excludeDependent in & $collectUniqueDependents $excludeEntries $targetCollectionId $targetCollectionName) {
        [void]$excludeDependents.Add($excludeDependent)
    }

    foreach ($limitingDependent in & $collectUniqueDependents $limitingEntries $targetCollectionId $targetCollectionName) {
        $limitingCollectionName = $null
        if (-not [string]::IsNullOrWhiteSpace($targetNameKey)) {
            $limitingCollectionName = $targetCollectionName
        }

        [void]$limitingDependents.Add([pscustomobject]@{
            CollectionID           = $limitingDependent.CollectionID
            Name                   = $limitingDependent.Name
            LimitingCollectionId   = $targetCollectionId
            LimitingCollectionName = $limitingCollectionName
        })
    }

    return [pscustomobject]@{
        IncludeDependents  = @($includeDependents)
        ExcludeDependents  = @($excludeDependents)
        LimitingDependents = @($limitingDependents)
    }
}

<#
.SYNOPSIS
    Logs include/exclude/limiting dependency details for a collection.

.DESCRIPTION
    Produces human-readable diagnostics before deletion so operators can quickly
    understand blockers and planned cleanup scope.
#>
function Write-CollectionDependencyLog {
    param(
        [Parameter(Mandatory = $true)]
        $TargetCollection,

        [Parameter(Mandatory = $true)]
        $DependencySnapshot
    )

    $targetCollectionId = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $targetCollectionName = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('Name', 'CollectionName'))

    $includeDependents = @($DependencySnapshot.IncludeDependents)
    $excludeDependents = @($DependencySnapshot.ExcludeDependents)
    $limitingDependents = @($DependencySnapshot.LimitingDependents)

    if (($includeDependents.Count + $excludeDependents.Count + $limitingDependents.Count) -eq 0) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("No collection reference dependencies found for '{0}' ({1})." -f $targetCollectionName, $targetCollectionId)
        return
    }

    if ($includeDependents.Count -gt 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Dependencies' -Action 'Status' -Detail ("Collection '{0}' ({1}) is included by: {2}" -f $targetCollectionName, $targetCollectionId, (($includeDependents | ForEach-Object { "{0} ({1})" -f $_.Name, $_.CollectionID }) -join ', '))
    }

    if ($excludeDependents.Count -gt 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Dependencies' -Action 'Status' -Detail ("Collection '{0}' ({1}) is excluded by: {2}" -f $targetCollectionName, $targetCollectionId, (($excludeDependents | ForEach-Object { "{0} ({1})" -f $_.Name, $_.CollectionID }) -join ', '))
    }

    if ($limitingDependents.Count -gt 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Collection '{0}' ({1}) is used as limiting collection by: {2}" -f $targetCollectionName, $targetCollectionId, (($limitingDependents | ForEach-Object { "{0} ({1})" -f $_.Name, $_.CollectionID }) -join ', '))
    }
}

<#
.SYNOPSIS
    Removes include membership rule dependencies for a collection delete target.

.DESCRIPTION
    Executes compatible SCCM cmdlet variants to remove include references from
    dependent collections to the target collection.
#>
function Remove-CollectionIncludeDependencyRule {
    param(
        [Parameter(Mandatory = $true)]
        $DependentCollection,

        [Parameter(Mandatory = $true)]
        $TargetCollection
    )

    $dependentObject = @($DependentCollection) | Select-Object -First 1
    $targetObject = @($TargetCollection) | Select-Object -First 1

    $dependentCollectionId = [string](Get-ObjectPropertyValue -InputObject $dependentObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $dependentCollectionName = [string](Get-ObjectPropertyValue -InputObject $dependentObject -PropertyNames @('Name', 'CollectionName'))
    $targetCollectionId = [string](Get-ObjectPropertyValue -InputObject $targetObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $targetCollectionName = [string](Get-ObjectPropertyValue -InputObject $targetObject -PropertyNames @('Name', 'CollectionName'))

    $dependentCollectionId = [string]$dependentCollectionId
    $targetCollectionId = [string]$targetCollectionId
    $dependentCollectionName = [string]$dependentCollectionName
    $targetCollectionName = [string]$targetCollectionName

    $removeCommand = Get-CachedCommand -Name 'Remove-CMDeviceCollectionIncludeMembershipRule'
    if (-not $removeCommand) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Cannot remove include dependency for '{0}' because Remove-CMDeviceCollectionIncludeMembershipRule is unavailable." -f $dependentCollectionName)
        return $false
    }

    $attempts = @()
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionId) -and -not [string]::IsNullOrWhiteSpace($targetCollectionId)) {
        $attempts += { Remove-CMDeviceCollectionIncludeMembershipRule -CollectionId $dependentCollectionId -IncludeCollectionId $targetCollectionId -Force -Confirm:$false -ErrorAction Stop }
    }
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionName) -and -not [string]::IsNullOrWhiteSpace($targetCollectionId)) {
        $attempts += { Remove-CMDeviceCollectionIncludeMembershipRule -CollectionName $dependentCollectionName -IncludeCollectionId $targetCollectionId -Force -Confirm:$false -ErrorAction Stop }
    }
    if (-not [string]::IsNullOrWhiteSpace($targetCollectionName)) {
        $attempts += { Remove-CMDeviceCollectionIncludeMembershipRule -InputObject $dependentObject -IncludeCollectionName $targetCollectionName -Force -Confirm:$false -ErrorAction Stop }
    }

    if ($attempts.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not build include dependency removal call for '{0}' -> '{1}'." -f $dependentCollectionName, $targetCollectionName)
        return $false
    }

    try {
        Invoke-DryRunAction -Action {
            $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Remove-CMDeviceCollectionIncludeMembershipRule'
            if (-not $result.Success) {
                throw 'All include membership rule removal attempts failed.'
            }
        } -Description "remove include rule from '$dependentCollectionName' to '$targetCollectionName'"

        if (-not $DryRun) {
            Write-LogEvent -Level 'SUCCESS' -Scope 'Dependencies' -Action 'Success' -Detail ("Removed include dependency from '{0}' to '{1}'." -f $dependentCollectionName, $targetCollectionName)
        }

        return $true
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not remove include dependency from '{0}' to '{1}': {2}" -f $dependentCollectionName, $targetCollectionName, $_.Exception.Message)
        return $false
    }
}

<#
.SYNOPSIS
    Removes exclude membership rule dependencies for a collection delete target.

.DESCRIPTION
    Executes compatible SCCM cmdlet variants to remove exclude references from
    dependent collections to the target collection.
#>
function Remove-CollectionExcludeDependencyRule {
    param(
        [Parameter(Mandatory = $true)]
        $DependentCollection,

        [Parameter(Mandatory = $true)]
        $TargetCollection
    )

    $dependentObject = @($DependentCollection) | Select-Object -First 1
    $targetObject = @($TargetCollection) | Select-Object -First 1

    $dependentCollectionId = [string](Get-ObjectPropertyValue -InputObject $dependentObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $dependentCollectionName = [string](Get-ObjectPropertyValue -InputObject $dependentObject -PropertyNames @('Name', 'CollectionName'))
    $targetCollectionId = [string](Get-ObjectPropertyValue -InputObject $targetObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $targetCollectionName = [string](Get-ObjectPropertyValue -InputObject $targetObject -PropertyNames @('Name', 'CollectionName'))

    $dependentCollectionId = [string]$dependentCollectionId
    $targetCollectionId = [string]$targetCollectionId
    $dependentCollectionName = [string]$dependentCollectionName
    $targetCollectionName = [string]$targetCollectionName

    $removeCommand = Get-CachedCommand -Name 'Remove-CMDeviceCollectionExcludeMembershipRule'
    if (-not $removeCommand) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Cannot remove exclude dependency for '{0}' because Remove-CMDeviceCollectionExcludeMembershipRule is unavailable." -f $dependentCollectionName)
        return $false
    }

    $attempts = @()
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionId) -and -not [string]::IsNullOrWhiteSpace($targetCollectionId)) {
        $attempts += { Remove-CMDeviceCollectionExcludeMembershipRule -CollectionId $dependentCollectionId -ExcludeCollectionId $targetCollectionId -Force -Confirm:$false -ErrorAction Stop }
    }
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionName) -and -not [string]::IsNullOrWhiteSpace($targetCollectionId)) {
        $attempts += { Remove-CMDeviceCollectionExcludeMembershipRule -CollectionName $dependentCollectionName -ExcludeCollectionId $targetCollectionId -Force -Confirm:$false -ErrorAction Stop }
    }
    if (-not [string]::IsNullOrWhiteSpace($targetCollectionName)) {
        $attempts += { Remove-CMDeviceCollectionExcludeMembershipRule -InputObject $dependentObject -ExcludeCollectionName $targetCollectionName -Force -Confirm:$false -ErrorAction Stop }
    }

    if ($attempts.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not build exclude dependency removal call for '{0}' -> '{1}'." -f $dependentCollectionName, $targetCollectionName)
        return $false
    }

    try {
        Invoke-DryRunAction -Action {
            $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Remove-CMDeviceCollectionExcludeMembershipRule'
            if (-not $result.Success) {
                throw 'All exclude membership rule removal attempts failed.'
            }
        } -Description "remove exclude rule from '$dependentCollectionName' to '$targetCollectionName'"

        if (-not $DryRun) {
            Write-LogEvent -Level 'SUCCESS' -Scope 'Dependencies' -Action 'Success' -Detail ("Removed exclude dependency from '{0}' to '{1}'." -f $dependentCollectionName, $targetCollectionName)
        }

        return $true
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not remove exclude dependency from '{0}' to '{1}': {2}" -f $dependentCollectionName, $targetCollectionName, $_.Exception.Message)
        return $false
    }
}

<#
.SYNOPSIS
    Reassigns a collection to a new limiting collection.

.DESCRIPTION
    Used when a delete target is currently used as a limiting collection by other
    collections. Reassignment removes structural blockers before delete.
#>
function Set-CollectionLimitingDependency {
    param(
        [Parameter(Mandatory = $true)]
        $DependentCollection,

        [Parameter(Mandatory = $true)]
        [string]$NewLimitingCollectionName
    )

    $dependentCollectionId = [string](Get-ObjectPropertyValue -InputObject $DependentCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $dependentCollectionName = [string](Get-ObjectPropertyValue -InputObject $DependentCollection -PropertyNames @('Name', 'CollectionName'))

    $setCommand = Get-CachedCommand -Name 'Set-CMCollection'
    if (-not $setCommand) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Cannot reassign limiting collection for '{0}' because Set-CMCollection is unavailable." -f $dependentCollectionName)
        return $false
    }

    $fallbackCollection = Get-CachedCmCollectionByName -CollectionName $NewLimitingCollectionName

    $fallbackCollectionId = $null
    if ($fallbackCollection) {
        $fallbackCollectionId = [string](Get-ObjectPropertyValue -InputObject $fallbackCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    }

    if ([string]::IsNullOrWhiteSpace($fallbackCollectionId) -and [string]::IsNullOrWhiteSpace($NewLimitingCollectionName)) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Cannot reassign limiting collection for '{0}' because fallback target is not available." -f $dependentCollectionName)
        return $false
    }

    $attempts = @()
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionId) -and -not [string]::IsNullOrWhiteSpace($fallbackCollectionId)) {
        $attempts += { Set-CMCollection -CollectionId $dependentCollectionId -LimitingCollectionId $fallbackCollectionId -ErrorAction Stop | Out-Null }
    }
    if (-not [string]::IsNullOrWhiteSpace($dependentCollectionName) -and -not [string]::IsNullOrWhiteSpace($fallbackCollectionId)) {
        $attempts += { Set-CMCollection -Name $dependentCollectionName -LimitingCollectionId $fallbackCollectionId -ErrorAction Stop | Out-Null }
    }
    if ($fallbackCollection) {
        $attempts += { Set-CMCollection -InputObject $DependentCollection -LimitingCollection $fallbackCollection -ErrorAction Stop | Out-Null }
    }
    if (-not [string]::IsNullOrWhiteSpace($NewLimitingCollectionName)) {
        $attempts += { Set-CMCollection -InputObject $DependentCollection -LimitingCollectionName $NewLimitingCollectionName -ErrorAction Stop | Out-Null }
    }

    if ($attempts.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not build limiting collection reassignment call for '{0}'." -f $dependentCollectionName)
        return $false
    }

    try {
        Invoke-DryRunAction -Action {
            $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Set-CMCollection (limiting reassignment)'
            if (-not $result.Success) {
                throw 'All limiting collection reassignment attempts failed.'
            }
        } -Description "reassign limiting collection for '$dependentCollectionName' to '$NewLimitingCollectionName'"

        if (-not $DryRun) {
            Write-LogEvent -Level 'SUCCESS' -Scope 'Dependencies' -Action 'Success' -Detail ("Reassigned limiting collection for '{0}' to '{1}'." -f $dependentCollectionName, $NewLimitingCollectionName)
        }

        return $true
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Dependencies' -Action 'Warning' -Detail ("Could not reassign limiting collection for '{0}' to '{1}': {2}" -f $dependentCollectionName, $NewLimitingCollectionName, $_.Exception.Message)
        return $false
    }
}

function Resolve-CollectionDeleteDependencies {
    <#
    .SYNOPSIS
        Resolves known collection-reference blockers before delete attempts.

    .DESCRIPTION
        Includes optional include/exclude rule cleanup and optional limiting
        collection reassignment. Any unresolved references are returned as explicit
        reasons and included in delete failure output.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TargetCollection
    )

    $targetCollectionId = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $targetCollectionName = [string](Get-ObjectPropertyValue -InputObject $TargetCollection -PropertyNames @('Name', 'CollectionName'))

    $initialSnapshot = Get-CollectionDependencySnapshot -TargetCollection $TargetCollection
    Write-CollectionDependencyLog -TargetCollection $TargetCollection -DependencySnapshot $initialSnapshot

    $changesMade = $false

    if ($CleanupCollectionMembershipDependencies) {
        # Remove include rules that point to the target collection so SCCM does
        # not reject deletion due to membership-rule references.
        foreach ($includeDependent in @($initialSnapshot.IncludeDependents)) {
            $dependentCollection = Get-CachedDeviceCollectionById -CollectionId ([string]$includeDependent.CollectionID)
            if ($dependentCollection) {
                if (Remove-CollectionIncludeDependencyRule -DependentCollection $dependentCollection -TargetCollection $TargetCollection) {
                    $changesMade = $true
                }
            }
        }

        # Remove exclude rules for the same reason as include rules above.
        foreach ($excludeDependent in @($initialSnapshot.ExcludeDependents)) {
            $dependentCollection = Get-CachedDeviceCollectionById -CollectionId ([string]$excludeDependent.CollectionID)
            if ($dependentCollection) {
                if (Remove-CollectionExcludeDependencyRule -DependentCollection $dependentCollection -TargetCollection $TargetCollection) {
                    $changesMade = $true
                }
            }
        }
    }
    elseif ($initialSnapshot.IncludeDependents.Count -gt 0 -or $initialSnapshot.ExcludeDependents.Count -gt 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Collection membership dependency cleanup is disabled. Include/exclude references to '{0}' will only be logged." -f $targetCollectionName)
    }

    if ($initialSnapshot.LimitingDependents.Count -gt 0) {
        if ($ReassignLimitingCollectionDependencies) {
            # Reassign dependent collections away from the target as limiting
            # collection to remove structural delete blockers.
            foreach ($limitingDependent in @($initialSnapshot.LimitingDependents)) {
                $dependentCollection = Get-CachedDeviceCollectionById -CollectionId ([string]$limitingDependent.CollectionID)
                if ($dependentCollection) {
                    if (Set-CollectionLimitingDependency -DependentCollection $dependentCollection -NewLimitingCollectionName $FallbackLimitingCollectionName) {
                        $changesMade = $true
                    }
                }
            }
        }
        else {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Limiting collection reassignment is disabled. Collections limited by '{0}' will remain blockers until -ReassignLimitingCollectionDependencies is used." -f $targetCollectionName)
        }
    }

    if ($changesMade -and -not $DryRun) {
        $script:CollectionDependencyIndexCache = $null
        Start-Sleep -Seconds 3
    }

    $remainingSnapshot = $initialSnapshot
    if (-not $DryRun) {
        $remainingSnapshot = Get-CollectionDependencySnapshot -TargetCollection $TargetCollection -RefreshIndex
    }

    $remainingReasons = New-Object System.Collections.Generic.List[string]
    foreach ($includeDependent in @($remainingSnapshot.IncludeDependents)) {
        [void]$remainingReasons.Add(("Include rule remains on '{0}' ({1})" -f $includeDependent.Name, $includeDependent.CollectionID))
    }
    foreach ($excludeDependent in @($remainingSnapshot.ExcludeDependents)) {
        [void]$remainingReasons.Add(("Exclude rule remains on '{0}' ({1})" -f $excludeDependent.Name, $excludeDependent.CollectionID))
    }
    foreach ($limitingDependent in @($remainingSnapshot.LimitingDependents)) {
        [void]$remainingReasons.Add(("Still used as limiting collection by '{0}' ({1})" -f $limitingDependent.Name, $limitingDependent.CollectionID))
    }

    if ($remainingReasons.Count -gt 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Collection '{0}' ({1}) still has {2} unresolved collection dependency reference(s)." -f $targetCollectionName, $targetCollectionId, $remainingReasons.Count)
    }

    return [pscustomobject]@{
        ChangesMade      = $changesMade
        RemainingReasons = @($remainingReasons)
    }
}

# ------------------------------------------------------------
# ROBUST COLLECTION REMOVAL
# ------------------------------------------------------------

function Remove-Collection-Robust {
    <#
    .SYNOPSIS
        Performs multi-strategy collection deletion with dependency-aware fallback.

    .DESCRIPTION
        The function resolves dependencies, removes linked deployments, tries
        several delete cmdlet variants, and finally attempts WMI provider delete.
        This design improves resilience across SCCM module/version differences.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Collection
    )

    # Normalize to a single object; callers may pass a 1-item array from cache helpers.
    $collectionObject = @($Collection) | Select-Object -First 1

    $collectionId = [string](Get-ObjectPropertyValue -InputObject $collectionObject -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $collectionName = [string](Get-ObjectPropertyValue -InputObject $collectionObject -PropertyNames @('Name', 'CollectionName'))

    # DryRun fast-path: skip all real SCCM work (dependency resolution,
    # deployment removal, deletion). Prevents the 8-minute index build and
    # false 'Argument types do not match' errors during preview runs.
    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Would execute action' -Detail ("delete device collection '{0}' (id '{1}')" -f ($collectionName -as [string]), ($collectionId -as [string]))
        return
    }

    try {
        $dependencyReasons = @()
        
        # PHASE 1: Attempt direct membership rule cleanup (optional; may fail in some SCCM versions).
        # Skip if Get-CMCollectionMembershipRule is unavailable or fails.
        try {
            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Attempting membership rule cleanup for collection '{0}' ({1})." -f ($collectionName -as [string]), ($collectionId -as [string]))
            
            if (-not [string]::IsNullOrWhiteSpace(($collectionId -as [string]))) {
                # Try to query the collection object itself for include/exclude rules stored in its RuleType property.
                # This avoids the problematic Get-CMCollectionMembershipRule cmdlet.
                try {
                    $collectionObj = Get-CachedDeviceCollectionById -CollectionId $collectionId
                    if ($collectionObj) {
                        # Get the collection's own rules via WMI query (safer than cmdlet)
                        $wmiCollection = Get-WmiObject -Namespace "root\SMS\site_$SiteCode" -Class SMS_Collection -Filter "CollectionID='$collectionId'" -ErrorAction SilentlyContinue
                        if ($wmiCollection) {
                            # Try to refresh/clear collection rules if WMI interface supports it
                            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Found WMI collection object for '{0}' ({1}), attempting rule enumeration." -f ($collectionName -as [string]), ($collectionId -as [string]))
                        }
                    }
                }
                catch {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Skipped membership rule query for '{0}' ({1}): {2}" -f ($collectionName -as [string]), ($collectionId -as [string]), $_.Exception.Message)
                }
            }
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Membership rule cleanup phase skipped for '{0}' ({1}): {2}" -f ($collectionName -as [string]), ($collectionId -as [string]), $_.Exception.Message)
        }
        
        # PHASE 2: Run the original dependency resolution (more reliable; handles include/exclude cleanup).
        try {
            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Running dependency resolution for collection '{0}' ({1})." -f ($collectionName -as [string]), ($collectionId -as [string]))
            
            $dependencyResolution = Resolve-CollectionDeleteDependencies -TargetCollection $collectionObject
            if ($dependencyResolution -and $dependencyResolution.RemainingReasons) {
                $dependencyReasons = @($dependencyResolution.RemainingReasons)
            }
        }
        catch {
            $dependencyErrorMessage = [string]$_.Exception.Message
            $dependencyLogLevel = 'WARN'
            $dependencyAction = 'Warning'

            # In some SCCM environments dependency cmdlets throw type-mismatch for
            # valid collections; direct deletion still succeeds. Keep this as DEBUG
            # to reduce no-op noise while preserving troubleshooting data.
            if ($dependencyErrorMessage -match 'Argument types do not match') {
                $dependencyLogLevel = 'DEBUG'
                $dependencyAction = 'Debug'
            }

            Write-LogEvent -Level $dependencyLogLevel -Scope 'Dependencies' -Action $dependencyAction -Detail (
                "Dependency resolution failed for collection '{0}' ({1}), continuing with direct delete attempts: {2}" -f
                ($collectionName -as [string]),
                ($collectionId -as [string]),
                $dependencyErrorMessage
            )
        }

        # Ensure dependent deployments targeting this collection are removed first.
        $deploymentCandidates = @()

        if (-not [string]::IsNullOrWhiteSpace(($collectionName -as [string]))) {
            $deploymentCandidates += @(Get-CachedDeploymentsForCollectionName -CollectionName ([string]$collectionName))
        }

        if (-not [string]::IsNullOrWhiteSpace(($collectionId -as [string]))) {
            $allDeployments = Get-CachedAllDeployments
            if ($allDeployments.Count -gt 0) {
                $byTargetId = @($allDeployments | Where-Object {
                    $targetCollectionId = Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('TargetCollectionID', 'CollectionID', 'CollectionId')
                    [string]$targetCollectionId -eq [string]$collectionId
                })

                if ($byTargetId.Count -gt 0) {
                    $deploymentCandidates += $byTargetId
                }
            }
        }

        if ($deploymentCandidates.Count -gt 0) {
            $uniqueDeployments = @{}
            foreach ($deploymentCandidate in $deploymentCandidates) {
                # Build a stable unique key so duplicate deployments found from
                # multiple lookup strategies are removed only once.
                if (-not $deploymentCandidate) { continue }

                $deploymentKey = Get-ObjectPropertyValue -InputObject $deploymentCandidate -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id')
                if ([string]::IsNullOrWhiteSpace(($deploymentKey -as [string]))) {
                    $depCollectionName = Get-ObjectPropertyValue -InputObject $deploymentCandidate -PropertyNames @('CollectionName', 'TargetCollectionName')
                    $depAppName = Get-ObjectPropertyValue -InputObject $deploymentCandidate -PropertyNames @('ApplicationName', 'SoftwareName', 'Name')
                    $deploymentKey = "{0}|{1}" -f ($depCollectionName -as [string]), ($depAppName -as [string])
                }

                if (-not $uniqueDeployments.ContainsKey([string]$deploymentKey)) {
                    $uniqueDeployments[[string]$deploymentKey] = $deploymentCandidate
                }
            }

            if ($uniqueDeployments.Count -gt 0) {
                Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Removing {0} deployment(s) before deleting collection '{1}' ({2})." -f $uniqueDeployments.Count, ($collectionName -as [string]), ($collectionId -as [string]))
                foreach ($deploymentToRemove in $uniqueDeployments.Values) {
                    # Delete dependent deployments first; SCCM often blocks
                    # collection deletion while active deployments exist.
                    Remove-Deployment-Robust -Deployment $deploymentToRemove
                }
                # SCCM needs a moment to propagate deployment removal before the collection can be deleted.
                Start-Sleep -Seconds 5
            }
        }

        $attempts = @()

        if ($collectionObject) {
            # Prefer InputObject first; some SCCM environments are stricter with
            # Id/Name parameter sets and can throw type mismatch errors.
            $attempts += { Remove-CMDeviceCollection -InputObject $collectionObject -Force -Confirm:$false -ErrorAction Stop }
            $attempts += { Remove-CMCollection -InputObject $collectionObject -Force -Confirm:$false -ErrorAction Stop }
        }

        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            # Explicit string cast to prevent "Argument types do not match" errors
            $collectionIdStr = [string]$collectionId
            
            # Attempt with fresh fetch - sometimes cached objects have type issues
            $attempts += { 
                $freshCollection = Get-CMDeviceCollection -CollectionId $collectionIdStr -ErrorAction Stop
                if ($freshCollection) {
                    Remove-CMDeviceCollection -InputObject $freshCollection -Force -Confirm:$false -ErrorAction Stop
                }
            }
            
            $attempts += { Remove-CMDeviceCollection -CollectionId $collectionIdStr -Force -Confirm:$false -ErrorAction Stop }
            $attempts += { Remove-CMCollection -CollectionId $collectionIdStr -Force -Confirm:$false -ErrorAction Stop }
        }

        if (-not [string]::IsNullOrWhiteSpace($collectionName)) {
            # Explicit string cast to prevent "Argument types do not match" errors
            $collectionNameStr = [string]$collectionName
            
            # Attempt with fresh fetch - sometimes cached objects have type issues
            $attempts += { 
                $freshCollection = Get-CMDeviceCollection -Name $collectionNameStr -ErrorAction Stop
                if ($freshCollection) {
                    Remove-CMDeviceCollection -InputObject $freshCollection -Force -Confirm:$false -ErrorAction Stop
                }
            }
            
            $attempts += { Remove-CMDeviceCollection -Name $collectionNameStr -Force -Confirm:$false -ErrorAction Stop }
            $attempts += { Remove-CMCollection -Name $collectionNameStr -Force -Confirm:$false -ErrorAction Stop }
        }

        if ($attempts.Count -eq 0) {
            throw "No valid collection identifier found for deletion."
        }

        Invoke-DryRunAction -Action {
            $removed = $false
            $attemptErrors = New-Object System.Collections.Generic.List[string]

            foreach ($dependencyReason in $dependencyReasons) {
                if (-not [string]::IsNullOrWhiteSpace($dependencyReason)) {
                    [void]$attemptErrors.Add($dependencyReason)
                }
            }

            # Try provider WMI deletion first to bypass SCCM cmdlet parameter binding issues.
            if (-not $removed -and -not [string]::IsNullOrWhiteSpace($collectionId)) {
                try {
                    $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
                    $collectionIdStr = [string]$collectionId

                    $wmiCollection = Get-WmiObject -Namespace $siteNamespace -Class SMS_DeviceCollection -Filter ("CollectionID='{0}'" -f $collectionIdStr) -ErrorAction SilentlyContinue
                    if (-not $wmiCollection) {
                        $wmiCollection = Get-WmiObject -Namespace $siteNamespace -Class SMS_Collection -Filter ("CollectionID='{0}'" -f $collectionIdStr) -ErrorAction SilentlyContinue
                    }

                    if ($wmiCollection) {
                        $wmiTarget = @($wmiCollection) | Select-Object -First 1
                        try {
                            [void]($wmiTarget.Delete())
                            $removed = $true
                        }
                        catch {
                            try {
                                [void](Invoke-WmiMethod -InputObject $wmiTarget -Name Delete -ErrorAction Stop)
                                $removed = $true
                            }
                            catch {
                                [void]$attemptErrors.Add(("WMI direct delete failed: {0}" -f $_.Exception.Message))
                            }
                        }
                    }
                    else {
                        [void]$attemptErrors.Add('WMI lookup returned no collection object (tried both DeviceCollection and Collection classes).')
                    }
                }
                catch {
                    [void]$attemptErrors.Add(("WMI provider attempt failed: {0}" -f $_.Exception.Message))
                }
            }

            foreach ($attempt in $attempts) {
                # Try known cmdlet variants in sequence because parameter support
                # differs between SCCM module versions and environments.
                try {
                    & $attempt
                    $removed = $true
                    break
                }
                catch {
                    $msg = $_.Exception.Message
                    if (-not [string]::IsNullOrWhiteSpace($msg)) {
                        [void]$attemptErrors.Add($msg)
                    }
                }
            }

            # Final fallback for stubborn collections: call provider WMI delete directly by CollectionID.
            if (-not $removed -and -not [string]::IsNullOrWhiteSpace($collectionId)) {
                try {
                    $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
                    $collectionIdStr = [string]$collectionId
                    
                    # Try SMS_DeviceCollection first
                    $wmiCollection = Get-WmiObject -Namespace $siteNamespace -Class SMS_DeviceCollection -Filter ("CollectionID='{0}'" -f $collectionIdStr) -ErrorAction SilentlyContinue

                    # Fallback to generic SMS_Collection if DeviceCollection not found
                    if (-not $wmiCollection) {
                        $wmiCollection = Get-WmiObject -Namespace $siteNamespace -Class SMS_Collection -Filter ("CollectionID='{0}'" -f $collectionIdStr) -ErrorAction SilentlyContinue
                    }

                    if ($wmiCollection) {
                        $wmiTarget = @($wmiCollection) | Select-Object -First 1

                        try {
                            [void]($wmiTarget.Delete())
                            $removed = $true
                        }
                        catch {
                            try {
                                [void](Invoke-WmiMethod -InputObject $wmiTarget -Name Delete -ErrorAction Stop)
                                $removed = $true
                            }
                            catch {
                                Remove-WmiObject -InputObject $wmiTarget -ErrorAction Stop
                                $removed = $true
                            }
                        }
                    }
                    else {
                        [void]$attemptErrors.Add('WMI lookup returned no collection object (tried both DeviceCollection and Collection classes).')
                    }
                }
                catch {
                    [void]$attemptErrors.Add(("WMI fallback failed: {0}" -f $_.Exception.Message))
                }
            }

            if (-not $removed) {
                $distinctErrors = @($attemptErrors | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
                if ($distinctErrors.Count -gt 0) {
                    $shortErrors = @($distinctErrors | Select-Object -First 6)
                    throw ("All collection removal attempts failed. Reasons: {0}" -f ($shortErrors -join ' | '))
                }

                throw "All collection removal attempts failed."
            }
        } -Description "delete device collection '$($collectionName -as [string])' (id '$($collectionId -as [string])')"

        if (-not $DryRun) {
            Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Deleted collection: {0} ({1})" -f ($collectionName -as [string]), ($collectionId -as [string]))
        }
    }
    catch {
        Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not delete collection '{0}' ({1}): {2}" -f ($collectionName -as [string]), ($collectionId -as [string]), $_.Exception.Message)

        [void]$failedCollections.Add(
            [pscustomobject]@{
                Name         = $collectionName
                CollectionID = $collectionId
                Error        = $_.Exception.Message
            }
        )
    }
}

<#
.SYNOPSIS
    Determines whether an application delete error is non-retryable.

.DESCRIPTION
    Detects dependency-reference failures (for example, task sequence references)
    so retries can skip permanent blockers.
#>
function Is-PermanentAppDeletionError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    if ([string]::IsNullOrWhiteSpace($ErrorMessage)) {
        return $false
    }

    if ($ErrorMessage -match 'dependent task sequences:\s*[1-9]\d*') {
        return $true
    }

    if ($ErrorMessage -match 'cannot delete this application because other applications or task sequences reference it') {
        return $true
    }

    return $false
}

# ------------------------------------------------------------
# REMOVE EMPTY FOLDERS UNDER APPLICATION DEPLOYMENT
# ------------------------------------------------------------

<#
.SYNOPSIS
    Removes empty folders under Application Deployment.

.DESCRIPTION
    Traverses folder hierarchy from deepest to shallowest to safely remove empty
    child folders before parent folders.
#>
function Remove-EmptyApplicationDeploymentFolders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $false)]
        [string[]]$PreserveFolderPaths = @()
    )

    $rootPath = "{0}:\DeviceCollection\Application Deployment" -f $SiteCode
    $rootPathNoDrive = "DeviceCollection\Application Deployment"
    $rootPathNoDriveWithSlash = "\DeviceCollection\Application Deployment"

    $normalizeCmFolderPath = {
        param(
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [string]$Path
        )

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return ''
        }

        $normalized = [string]$Path
        $normalized = $normalized.Trim()
        $normalized = $normalized -replace '/', '\\'
        $normalized = $normalized -replace '\\\\+', '\\'

        # Accept both provider styles:
        #   P03:\DeviceCollection\...
        #   P03:DeviceCollection\...
        $normalized = $normalized -replace '^[^:]+:\\?', ''
        $normalized = $normalized.TrimStart('\\').TrimEnd('\\')

        return $normalized
    }

    $resolveFolderPath = {
        param(
            [Parameter(Mandatory = $true)]
            $FolderObject
        )

        # Prefer SCCM container-style paths over WMI ObjectPath strings.
        $candidates = @(
            [string](Get-ObjectPropertyValue -InputObject $FolderObject -PropertyNames @('FolderPath')),
            [string](Get-ObjectPropertyValue -InputObject $FolderObject -PropertyNames @('Path')),
            [string](Get-ObjectPropertyValue -InputObject $FolderObject -PropertyNames @('ContainerNodePath')),
            [string](Get-ObjectPropertyValue -InputObject $FolderObject -PropertyNames @('ObjectPath'))
        )

        foreach ($candidate in $candidates) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return [string]$candidate
            }
        }

        return ''
    }

    $normalizedPreservePaths = @($PreserveFolderPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        ([string](& $normalizeCmFolderPath ([string]$_))).ToLowerInvariant()
    } | Sort-Object -Unique)

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Scanning for empty folders under: {0}" -f $rootPath)
    if ($normalizedPreservePaths.Count -gt 0) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Preserving {0} folder path(s) from cleanup: {1}" -f $normalizedPreservePaths.Count, ($normalizedPreservePaths -join ', '))
    }

    $allFolders = @()

    # Collect folders using multiple path/query variants because SCCM folder cmdlets
    # return different FolderPath formats across environments. Prioritize versions
    # without -Recurse (which may not be supported in all SCCM versions).
    $folderQueryAttempts = @(
        { @(Get-CMFolder -FolderPath $rootPath -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -FolderPath $rootPathNoDrive -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -FolderPath $rootPathNoDriveWithSlash -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -Recurse -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -Name '*' -ErrorAction SilentlyContinue) }
    )

    foreach ($queryAttempt in $folderQueryAttempts) {
        try {
            $result = @(& $queryAttempt)
            if ($result -and $result.Count -gt 0) {
                $allFolders += $result
                Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Folder query returned {0} folder(s)." -f $result.Count)
            }
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Folder query attempt failed: {0}" -f $_.Exception.Message)
        }
    }

    if (-not $allFolders -or $allFolders.Count -eq 0) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail "No folders found under Application Deployment root. Attempting manual recursive discovery..."
        
        # Manual recursive folder discovery by querying each folder path level
        try {
            $queue = @($rootPath)
            $discoveredFolders = @()
            
            while ($queue.Count -gt 0) {
                $currentPath = $queue[0]
                if ($queue.Count -gt 1) {
                    $queue = @($queue[1..($queue.Count - 1)])
                }
                else {
                    $queue = @()
                }
                
                Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Querying children of: {0}" -f $currentPath)
                
                try {
                    $childFolders = @(Get-CMFolder -FolderPath $currentPath -ErrorAction Stop)
                    if ($childFolders -and $childFolders.Count -gt 0) {
                        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Found {0} child folder(s) under {1}" -f $childFolders.Count, $currentPath)
                        $discoveredFolders += $childFolders
                        
                        # Add child folders to queue for recursive discovery
                        foreach ($child in $childFolders) {
                            $childFolderPath = [string](& $resolveFolderPath $child)
                            if (-not [string]::IsNullOrWhiteSpace($childFolderPath)) {
                                $queue += $childFolderPath
                            }
                        }
                    }
                }
                catch {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Could not query children of {0}: {1}" -f $currentPath, $_.Exception.Message)
                }
            }
            
            $allFolders = @($discoveredFolders)
        }
        catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Manual recursive discovery failed: {0}" -f $_.Exception.Message)
        }
    }

    if (-not $allFolders -or $allFolders.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail 'No folders found via any discovery method.'
        return
    }

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Enumerated {0} folder object(s) for cleanup analysis." -f $allFolders.Count)

    # Normalize and keep only child folders under Application Deployment.
    $uniqueFoldersByPath = @{}

    foreach ($folder in @($allFolders)) {
        if (-not $folder) {
            continue
        }

        $rawPath = [string](& $resolveFolderPath $folder)
        if ([string]::IsNullOrWhiteSpace($rawPath)) {
            continue
        }

        $normalizedPath = [string](& $normalizeCmFolderPath $rawPath)
        $rootIndex = $normalizedPath.ToLowerInvariant().IndexOf($rootPathNoDrive.ToLowerInvariant())
        if ($rootIndex -ge 0) {
            $normalizedPath = $normalizedPath.Substring($rootIndex)
        }

        if (-not $normalizedPath.ToLowerInvariant().StartsWith($rootPathNoDrive.ToLowerInvariant())) {
            continue
        }

        # Skip the root itself; cleanup should target only child folders.
        if ($normalizedPath.TrimEnd('\').ToLowerInvariant() -eq $rootPathNoDrive.ToLowerInvariant()) {
            continue
        }

        $normalizedPathKey = $normalizedPath.TrimEnd('\').ToLowerInvariant()
        if ($normalizedPreservePaths -contains $normalizedPathKey) {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Preserving folder from cleanup: {0}" -f $rawPath)
            continue
        }

        if (-not $uniqueFoldersByPath.ContainsKey($normalizedPathKey)) {
            $uniqueFoldersByPath[$normalizedPathKey] = [pscustomobject]@{
                FolderObject = $folder
                RawPath      = $rawPath
            }
        }
    }

    $allSubfolders = @($uniqueFoldersByPath.Values)

    if ($allSubfolders.Count -eq 0) {
        $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
        $wmiCandidates = @()

        try {
            $allContainerNodes = @(Get-WmiObject -Namespace $siteNamespace -Class SMS_ObjectContainerNode -ErrorAction Stop)
            $emptyContainerNodes = @($allContainerNodes | Where-Object { [int]($_.IsEmpty) -eq 1 })

            if ($emptyContainerNodes.Count -gt 0) {
                $nodesByKey = @{}
                foreach ($node in $allContainerNodes) {
                    if (-not $node) {
                        continue
                    }

                    $nodeTypeName = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ObjectTypeName'))
                    $nodeId = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
                    if ([string]::IsNullOrWhiteSpace($nodeId)) {
                        continue
                    }

                    $nodeKey = ("{0}|{1}" -f $nodeTypeName, $nodeId)
                    if (-not $nodesByKey.ContainsKey($nodeKey)) {
                        $nodesByKey[$nodeKey] = $node
                    }
                }

                foreach ($node in $emptyContainerNodes) {
                    if (-not $node) {
                        continue
                    }

                    $nodeTypeName = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ObjectTypeName'))
                    $nodeId = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
                    $parentNodeId = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ParentContainerNodeId', 'ParentContainerNodeID'))
                    $nameChain = New-Object System.Collections.Generic.List[string]
                    $visitedKeys = New-Object System.Collections.Generic.HashSet[string]
                    $currentNode = $node
                    $currentNodeId = $nodeId

                    while ($currentNode -and -not [string]::IsNullOrWhiteSpace($currentNodeId)) {
                        $currentName = [string](Get-ObjectPropertyValue -InputObject $currentNode -PropertyNames @('Name'))
                        if (-not [string]::IsNullOrWhiteSpace($currentName)) {
                            [void]$nameChain.Add($currentName)
                        }

                        $currentKey = ("{0}|{1}" -f $nodeTypeName, $currentNodeId)
                        if (-not $visitedKeys.Add($currentKey)) {
                            break
                        }

                        $currentParentId = [string](Get-ObjectPropertyValue -InputObject $currentNode -PropertyNames @('ParentContainerNodeId', 'ParentContainerNodeID'))
                        if ([string]::IsNullOrWhiteSpace($currentParentId) -or $currentParentId -eq '0') {
                            break
                        }

                        $parentKey = ("{0}|{1}" -f $nodeTypeName, $currentParentId)
                        if (-not $nodesByKey.ContainsKey($parentKey)) {
                            break
                        }

                        $currentNode = $nodesByKey[$parentKey]
                        $currentNodeId = $currentParentId
                    }

                    if ($nameChain.Count -eq 0) {
                        continue
                    }

                    [array]::Reverse($nameChain.ToArray()) | Out-Null
                    $orderedNames = @($nameChain.ToArray())
                    [array]::Reverse($orderedNames)

                    $appDeploymentIndex = -1
                    for ($i = 0; $i -lt $orderedNames.Count; $i++) {
                        if ($orderedNames[$i] -eq 'Application Deployment') {
                            $appDeploymentIndex = $i
                            break
                        }
                    }

                    if ($appDeploymentIndex -lt 0) {
                        continue
                    }

                    if ($orderedNames.Count -le ($appDeploymentIndex + 1)) {
                        continue
                    }

                    $relativeNames = @($orderedNames[$appDeploymentIndex..($orderedNames.Count - 1)])
                    $relativePath = "DeviceCollection\{0}" -f ($relativeNames -join '\')
                    $normalizedPathKey = ([string](& $normalizeCmFolderPath $relativePath)).ToLowerInvariant()

                    if ($normalizedPreservePaths -contains $normalizedPathKey) {
                        continue
                    }

                    $wmiCandidates += [pscustomobject]@{
                        Node              = $node
                        RawPath           = $relativePath
                        NormalizedPathKey = $normalizedPathKey
                        ObjectTypeName    = $nodeTypeName
                        ContainerNodeId   = $nodeId
                        ParentNodeId      = $parentNodeId
                    }
                }
            }
        }
        catch {
            Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("WMI fallback query for SMS_ObjectContainerNode failed: {0}" -f $_.Exception.Message)
        }

        if ($wmiCandidates.Count -gt 0) {
            $allSubfolders = @($wmiCandidates | Sort-Object -Property NormalizedPathKey -Unique)
            Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("WMI fallback discovered {0} empty folder candidate(s) under Application Deployment." -f $allSubfolders.Count)
        }
    }

    if ($allSubfolders.Count -eq 0) {
        $samplePaths = @($allFolders | ForEach-Object { [string](& $resolveFolderPath $_) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 5)
        Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("No child folders discovered for cleanup after filtering {0} enumerated folder object(s)." -f $allFolders.Count)
        if ($samplePaths.Count -gt 0) {
            Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Sample enumerated folder paths: {0}" -f ($samplePaths -join '; '))
        }

        $sampleFolder = @($allFolders | Select-Object -First 1)[0]
        if ($sampleFolder) {
            $propertyNames = @($sampleFolder.PSObject.Properties.Name | Sort-Object -Unique)
            if ($propertyNames.Count -gt 0) {
                Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Sample folder object properties: {0}" -f ($propertyNames -join ', '))
            }

            $sampleValues = @()
            foreach ($propName in @('Name','FolderPath','Path','ContainerNodePath','ObjectPath','InstanceKey','ParentContainerNodeId','ContainerNodeId','ObjectTypeName')) {
                try {
                    $prop = $sampleFolder.PSObject.Properties[$propName]
                    if ($prop) {
                        $value = [string]$prop.Value
                        if (-not [string]::IsNullOrWhiteSpace($value)) {
                            $sampleValues += ("{0}={1}" -f $propName, $value)
                        }
                    }
                }
                catch {
                }
            }

            if ($sampleValues.Count -gt 0) {
                Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Sample folder object values: {0}" -f ($sampleValues -join '; '))
            }
        }

        return
    }

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Discovered {0} candidate folder(s) under Application Deployment." -f $allSubfolders.Count)

    # Sort deepest path first so child folders are removed before parents.
    $sortedFolders = $allSubfolders | Sort-Object {
        ([string](& $normalizeCmFolderPath $_.RawPath)).Split('\\').Count
    } -Descending

    foreach ($folderEntry in $sortedFolders) {
        if (-not $folderEntry) {
            continue
        }

        $folderPath = [string]$folderEntry.RawPath
        if ([string]::IsNullOrWhiteSpace($folderPath)) {
            continue
        }

        try {
            if ($folderEntry.PSObject.Properties['Node']) {
                Invoke-DryRunAction -Action {
                    $folderEntry.Node | Remove-WmiObject -ErrorAction Stop
                } -Description "delete empty folder '$folderPath' via WMI"
            }
            else {
                Invoke-DryRunAction -Action {
                    Remove-CMFolder -FolderPath $folderPath -Force -ErrorAction Stop
                } -Description "delete empty folder '$folderPath'"
            }
            if (-not $DryRun) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Deleted empty folder: {0}" -f $folderPath)
            }
        }
        catch {
            # Expected for non-empty folders; keep as DEBUG to avoid noisy logs.
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Skipping non-empty/protected folder '{0}': {1}" -f $folderPath, $_.Exception.Message)
        }
    }
}

# ------------------------------------------------------------
# PLAN AND EXECUTE CLEANUP
# ------------------------------------------------------------

function Plan-And-Execute-Cleanup {
    <#
    .SYNOPSIS
        Plans and executes cleanup for deployments, applications and collections.

    .DESCRIPTION
        Cleanup keeps the two newest app versions plus Task Sequence referenced
        versions, migrates collection deployments to latest app when possible, then
        performs deletion in a dependency-aware order.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName,

        [Parameter(Mandatory = $true)]
        $Masters,

        [Parameter(Mandatory = $true)]
        $AllCollections,

        [Parameter(Mandatory = $false)]
        [switch]$DeleteOldCollections
    )

    $cleanupStage = 'initialization'

    try {
        if (-not $DeleteOldCollections) {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Skipped' -Detail 'DeleteOldCollections not specified.'
            return
        }

        $cleanupStage = 'validate software name'
        $normalizedSoftwareName = ($SoftwareName -as [string]).Trim()
        if ([string]::IsNullOrWhiteSpace($normalizedSoftwareName) -or $normalizedSoftwareName.Length -lt 3) {
            Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Skipped' -Detail ("SoftwareName '{0}' is too short for safe scope." -f $SoftwareName)
            return
        }

        Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Plan start'

        $cleanupStage = 'resolve master collection names'
        $masterNames = @()
        if ($Masters) {
            if ($Masters.InstallAvailable -and $Masters.InstallAvailable.Name) { $masterNames += $Masters.InstallAvailable.Name }
            if ($Masters.InstallRequired -and $Masters.InstallRequired.Name) { $masterNames += $Masters.InstallRequired.Name }
            if ($Masters.Uninstall -and $Masters.Uninstall.Name) { $masterNames += $Masters.Uninstall.Name }
        }

        # Build deployment cleanup set for non-master collections.
        $cleanupStage = 'build deployment cleanup candidate set'
        $deploymentsToDelete = @()
        $latestAppForMigration = Get-LatestVersionedApplication -SoftwareName $normalizedSoftwareName

        if ($latestAppForMigration) {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Migration target selected' -Detail $latestAppForMigration.LocalizedDisplayName
        }
        else {
            Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Migration target missing' -Detail ("Could not identify latest version app for '{0}'." -f $normalizedSoftwareName)
        }

        foreach ($col in $AllCollections) {
            # Only non-master collections are cleanup candidates.
            if (-not $col) { continue }
            if ($masterNames -contains $col.Name) {
                continue
            }

            $deps = @(Get-CachedDeploymentsForCollectionName -CollectionName ([string]$col.Name))
            if ($deps.Count -gt 0) {
                $deploymentsToDelete += $deps
            }
        }

        # Build versioned app set for keep/delete decisions.
        $cleanupStage = 'build versioned app set'
        $appsSorted = @(Get-VersionedApplicationsForSoftwareName -SoftwareName $normalizedSoftwareName)

        # Keep policy: two newest versions plus anything referenced by task sequences.
        $coreKeep = @($appsSorted | Select-Object -First 2)

        $tsReferenced = @()

        $cleanupStage = 'evaluate task sequence references'
        foreach ($entry in $appsSorted) {
            # Keep any app version referenced by at least one task sequence to avoid
            # breaking deployment task sequences during cleanup.
            if (-not $entry) { continue }

            $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
            if (-not $entryApp) { continue }

            $appId        = Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID','CIId','ModelID','ModelId')
            $appModelName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('ModelName', 'ModelId'))
            $tsRefs = @(Find-TaskSequencesReferencingApp -AppCI_ID $appId -AppModelName $appModelName)

            if ($tsRefs.Count -gt 0) {
                $tsReferenced += $entry
            }
        }

        $cleanupStage = 'build keep set'
        $appsToKeep = New-Object System.Collections.Generic.List[object]
        $keepIdsSet = New-Object System.Collections.Generic.HashSet[string]

        foreach ($entry in @($coreKeep + $tsReferenced)) {
            if (-not $entry) { continue }

            $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
            if (-not $entryApp) { continue }

            $keepId = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID','CIId','ModelID','ModelId'))
            if ([string]::IsNullOrWhiteSpace($keepId)) { continue }

            if ($keepIdsSet.Add($keepId)) {
                [void]$appsToKeep.Add($entry)
            }
        }

        $keepIds = @($keepIdsSet)

        $cleanupStage = 'classify old apps'
        $oldApps = @($appsSorted | Where-Object {
            if (-not $_) { return $false }
            $candidateApp = Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('App')
            if (-not $candidateApp) { return $false }
            $candidateId = [string](Get-ObjectPropertyValue -InputObject $candidateApp -PropertyNames @('CI_ID','CIId','ModelID','ModelId'))
            -not [string]::IsNullOrWhiteSpace($candidateId) -and ($keepIds -notcontains $candidateId)
        })

        $cleanupStage = 'log app keep/delete plan'
        $appsToKeepList = @()
        if ($appsToKeep) {
            if ($appsToKeep -is [System.Collections.Generic.List[object]]) {
                $appsToKeepList = @($appsToKeep.ToArray())
            }
            else {
                $appsToKeepList = Convert-ToSafeArray -InputObject $appsToKeep
            }
        }

        $oldAppsList = @()
        if ($oldApps) {
            $oldAppsList = Convert-ToSafeArray -InputObject $oldApps
        }

        $appsToKeepNames = @(
            foreach ($entry in $appsToKeepList) {
                if (-not $entry) { continue }
                $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
                if (-not $entryApp) { continue }
                $displayName = ''
                try { $displayName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName','Name')) } catch {}
                if (-not [string]::IsNullOrWhiteSpace($displayName)) { $displayName }
            }
        )

        $oldAppNames = @(
            foreach ($entry in $oldAppsList) {
                if (-not $entry) { continue }
                $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
                if (-not $entryApp) { continue }
                $displayName = ''
                try { $displayName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName','Name')) } catch {}
                if (-not [string]::IsNullOrWhiteSpace($displayName)) { $displayName }
            }
        )

        $keepDetail = 'None'
        if ($appsToKeepNames -and @($appsToKeepNames).Count -gt 0) {
            $keepDetail = [string]::Join(', ', @($appsToKeepNames | Where-Object { -not [string]::IsNullOrWhiteSpace(($_ -as [string])) }))
        }

        $deleteDetail = 'None'
        if ($oldAppNames -and @($oldAppNames).Count -gt 0) {
            $deleteDetail = [string]::Join(', ', @($oldAppNames | Where-Object { -not [string]::IsNullOrWhiteSpace(($_ -as [string])) }))
        }

        try { Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Applications to keep' -Detail $keepDetail } catch { Write-Log -Level 'INFO' -Message ("[CLEANUP] Applications to keep: {0}" -f $keepDetail) }
        try { Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Applications to delete' -Detail $deleteDetail } catch { Write-Log -Level 'INFO' -Message ("[CLEANUP] Applications to delete: {0}" -f $deleteDetail) }

        # Determine which non-master collections are eligible for deletion.
        $cleanupStage = 'build collection delete plan'
        $oldCollections = @()

        if ($DeleteOldCollections) {
            foreach ($col in $AllCollections) {
                if (-not $col) { continue }
                if ($masterNames -notcontains $col.Name) {
                    $oldCollections += $col
                }
            }

        # Sort collections by version in DESCENDING order (newest to oldest).
        # This respects the include hierarchy: delete parent collections before
        # child collections to avoid "include" dependency errors.
            $oldCollectionsWithVersion = @()
            foreach ($col in $oldCollections) {
                $version = Extract-VersionFromName -Name ($col.Name -as [string])
                $oldCollectionsWithVersion += [pscustomobject]@{
                    Collection = $col
                    VersionString = ($version -as [string])
                    Version = if ([version]::TryParse(($version -as [string]), [ref]$null)) { [version]$version } else { [version]'0.0.0' }
                }
            }

            $oldCollections = @($oldCollectionsWithVersion |
                Sort-Object -Property @(
                    @{ Expression = { $_.Version }; Descending = $true },
                    @{ Expression = { [string]$_.Collection.Name }; Descending = $true }
                ) |
                ForEach-Object { $_.Collection })

            if ($oldCollections.Count -gt 0) {
                Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Collections deletion order' -Detail ("Will delete {0} legacy collections in descending version order (newest first) to respect include hierarchy." -f $oldCollections.Count)
                foreach ($col in $oldCollections) {
                    $colVersion = Extract-VersionFromName -Name ($col.Name -as [string])
                    Write-LogEvent -Level 'DEBUG' -Scope 'Cleanup' -Action 'Deletion queue' -Detail ("  {0} (version: {1})" -f $col.Name, ($colVersion -as [string]))
                }
            }
        }

        $cleanupStage = 'confirm cleanup plan'
        if (($deploymentsToDelete.Count -eq 0) -and ($oldApps.Count -eq 0) -and ($oldCollections.Count -eq 0)) {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'No-op' -Detail 'No legacy deployments, applications, or collections require cleanup.'
        }

        if (-not $AutoApprove) {
        Write-Host ""
        Write-Host "Planned cleanup actions:" -ForegroundColor Cyan
        Write-Host (" - Deployments to delete: {0}" -f $deploymentsToDelete.Count)
        Write-Host (" - Applications to delete: {0}" -f $oldApps.Count)
        Write-Host (" - Collections to delete:  {0}" -f $oldCollections.Count)
        Write-Host ""
        $answer = Read-Host "Proceed with cleanup? (Y/N)"
        if ($answer -notin @('Y','y','Yes','yes')) {
            Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Aborted' -Detail 'User declined confirmation prompt.'
            return
        }
        }
        else {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Confirmed' -Detail 'AutoApprove enabled. Running without additional prompts.'
        }

        $cleanupStage = 'migrate and delete deployments'
        $migratedCollections = New-Object System.Collections.Generic.HashSet[string]

        foreach ($d in $deploymentsToDelete) {
        # For each source deployment, ensure the target collection first has a
        # deployment to the latest app version, then remove the legacy deployment.
        if (-not $d) { continue }
        
        if ($latestAppForMigration) {
            $dCollectionName = [string](Get-ObjectPropertyValue -InputObject $d -PropertyNames @('CollectionName', 'TargetCollectionName'))

            if (-not $migratedCollections.Contains($dCollectionName)) {
                $migrated = Ensure-LatestDeploymentForCollection -Deployment $d -LatestApp $latestAppForMigration
                if (-not $migrated) {
                    Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Deployment delete skipped' -Detail ("Migration to latest app failed for collection '{0}'." -f $dCollectionName)
                    continue
                }
                [void]$migratedCollections.Add($dCollectionName)
            }
        }

            Remove-Deployment-Robust -Deployment $d
        }

        $cleanupStage = 'delete old apps'
        foreach ($a in $oldApps) {
        # App deletion is skipped when task sequence references are detected.
        # This ensures cleanup never breaks operational task sequences.

        if (-not $a) { continue }

        $entryApp = Get-ObjectPropertyValue -InputObject $a -PropertyNames @('App')
        if (-not $entryApp) { continue }

        $appName      = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName','Name'))
        $appId        = Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID','CIId','ModelID','ModelId')
        $appModelName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('ModelName', 'ModelId'))

        $tsRefs = Find-TaskSequencesReferencingApp -AppCI_ID $appId -AppModelName $appModelName

        if ($tsRefs.Count -gt 0) {
            Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Application delete skipped' -Detail (("'{0}' (CI_ID: {1}) is referenced by {2} task sequence(s).") -f $appName, $appId, $tsRefs.Count)

            foreach ($r in $tsRefs) {
                Write-Host (" - Task Sequence: {0} (PackageId: {1})" -f $r.TaskSequenceName, $r.PackageId)
            }

            continue
        }

        try {
            Invoke-DryRunAction -Action {
                Remove-CMApplication -Name $appName -Force -Confirm:$false -ErrorAction Stop
            } -Description "delete software application '$appName'"
            if (-not $DryRun) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Cleanup' -Action 'Application deleted' -Detail $appName
            }
        }
        catch {
            Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Application delete failed' -Detail (("'{0}' | {1}") -f $appName, $_.Exception.Message)

            if (Is-PermanentAppDeletionError -ErrorMessage $_.Exception.Message) {
                Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Retry skipped' -Detail (("'{0}' blocked by dependency references.") -f $appName)
                continue
            }

            [void]$failedApps.Add(
                [pscustomobject]@{
                    Name  = $appName
                    CI_ID = $appId
                    Error = $_.Exception.Message
                }
            )
        }
        }

        $cleanupStage = 'refresh caches before collection cleanup'
        Reset-SccmRuntimeCaches

        $cleanupStage = 'delete old collections'
        foreach ($col in $oldCollections) {
        # Collection deletion runs after app/deployment cleanup to minimize
        # dependency conflicts and failed delete retries.
            if (-not $col) { continue }
            Remove-Collection-Robust -Collection $col
        }

        Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Finished'

        $cleanupStage = 'cleanup empty folders'
        Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Folder cleanup start' -Detail 'Application Deployment root.'
        $preserveFolders = @()
        if (-not [string]::IsNullOrWhiteSpace(($TargetFolder -as [string]))) {
            $preserveFolders += @(Get-TargetFolderPath -SiteCode $SiteCode -TargetFolder $TargetFolder)
        }

        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Folder cleanup simulation' -Detail 'Enumerating empty folder delete candidates under Application Deployment root.'
        }

        Remove-EmptyApplicationDeploymentFolders -SiteCode $SiteCode -PreserveFolderPaths $preserveFolders
    }
    catch {
        $cleanupErrorMessage = [string]$_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($cleanupErrorMessage)) {
            $cleanupErrorMessage = '[No exception message available]'
        }

        Write-Log -Level 'ERROR' -Message ("[CLEANUP] Failed: Plan-And-Execute-Cleanup failed during stage '{0}': {1}" -f $cleanupStage, $cleanupErrorMessage)
        if ($_.ScriptStackTrace) {
            Write-Log -Level 'DEBUG' -Message ("[CLEANUP] Debug: Stack: {0}" -f $_.ScriptStackTrace)
        }

        # Also emit the structured event when possible for consistency.
        Write-LogEvent -Level 'ERROR' -Scope 'Cleanup' -Action 'Failed' -Detail ("Plan-And-Execute-Cleanup failed during stage '{0}': {1}" -f $cleanupStage, $cleanupErrorMessage)
        throw
    }
}

# ------------------------------------------------------------
# EXPORT FAILED OBJECTS
# ------------------------------------------------------------

<#
.SYNOPSIS
    Exports failed operations and migration audit data to CSV files.

.DESCRIPTION
    Creates timestamped output files for failed apps, collections, deployments,
    and deployment migration audit records.
#>
function Export-FailedObjectsToCsv {
    param(
        [Parameter(Mandatory = $false)]
        [string]$BasePath = "C:\Temp\SCCMCleanupResults"
    )

    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')

    if (-not (Test-Path $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
    }

    if ($failedApps.Count -gt 0) {
        $path = Join-Path $BasePath ("FailedApps_{0}.csv" -f $timestamp)
        $failedApps | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-LogEvent -Level 'INFO' -Scope 'Reporting' -Action 'Status' -Detail ("Exported failed applications to {0}" -f $path)
    }

    if ($failedCollections.Count -gt 0) {
        $path = Join-Path $BasePath ("FailedCollections_{0}.csv" -f $timestamp)
        $failedCollections | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-LogEvent -Level 'INFO' -Scope 'Reporting' -Action 'Status' -Detail ("Exported failed collections to {0}" -f $path)
    }

    if ($failedDeployments.Count -gt 0) {
        $path = Join-Path $BasePath ("FailedDeployments_{0}.csv" -f $timestamp)
        $failedDeployments | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-LogEvent -Level 'INFO' -Scope 'Reporting' -Action 'Status' -Detail ("Exported failed deployments to {0}" -f $path)
    }

    if ($deploymentMigrationAudit.Count -gt 0) {
        $path = Join-Path $BasePath ("DeploymentMigration_{0}.csv" -f $timestamp)
        $deploymentMigrationAudit | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-LogEvent -Level 'INFO' -Scope 'Reporting' -Action 'Status' -Detail ("Exported deployment migration audit to {0}" -f $path)
    }
}

# ------------------------------------------------------------
# RETRY FAILED DELETIONS
# ------------------------------------------------------------

function Retry-FailedDeletions {
    <#
    .SYNOPSIS
        Retries previously failed deletions for deployments, apps and collections.

    .DESCRIPTION
        Some SCCM operations fail transiently while provider state converges.
        Retries are separated by delay and use fresh caches per round.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 1,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 30
    )

    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Skipped' -Detail 'DryRun is active.'
        return
    }

    for ($round = 1; $round -le $RetryCount; $round++) {

        Reset-SccmRuntimeCaches

        Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Round start' -Detail ("{0} of {1}" -f $round, $RetryCount)

        if ($failedDeployments.Count -gt 0) {

            $toRetry = $failedDeployments.ToArray()
            $failedDeployments.Clear()

            foreach ($d in $toRetry) {
                # Retry each failed deployment by ID from fresh cache snapshots.
                try {
                    $depObj = Get-CachedDeploymentById -DeploymentId ([string]$d.DeploymentID)

                    if ($depObj) {
                        Remove-Deployment-Robust -Deployment $depObj
                    }
                    else {
                        Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Deployment not found' -Detail $d.DeploymentID
                        [void]$failedDeployments.Add($d)
                    }
                }
                catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Deployment retry failed' -Detail (("{0} | {1}") -f $d.DeploymentID, $_.Exception.Message)

                    [void]$failedDeployments.Add(
                        [pscustomobject]@{
                            DeploymentID   = $d.DeploymentID
                            CollectionName = $d.CollectionName
                            Error          = $_.Exception.Message
                        }
                    )
                }
            }
        }

        if ($failedApps.Count -gt 0) {

            $toRetry = $failedApps.ToArray()
            $failedApps.Clear()

            foreach ($a in $toRetry) {
                # Retry application deletions that previously failed due to
                # transient provider state or timing.
                try {
                    Remove-CMApplication -Name $a.Name -Force -Confirm:$false -ErrorAction Stop
                    Write-LogEvent -Level 'SUCCESS' -Scope 'Retry' -Action 'Application deleted' -Detail $a.Name
                }
                catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Application retry failed' -Detail (("'{0}' | {1}") -f $a.Name, $_.Exception.Message)

                    if (Is-PermanentAppDeletionError -ErrorMessage $_.Exception.Message) {
                        Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Application retry skipped' -Detail (("'{0}' blocked by dependency references.") -f $a.Name)
                        continue
                    }

                    [void]$failedApps.Add(
                        [pscustomobject]@{
                            Name  = $a.Name
                            CI_ID = $a.CI_ID
                            Error = $_.Exception.Message
                        }
                    )
                }
            }
        }

        if ($failedCollections.Count -gt 0) {

            $toRetry = $failedCollections.ToArray()
            $failedCollections.Clear()

            foreach ($c in $toRetry) {
                # Retry collection deletion after dependencies and deployments may
                # have changed in previous rounds.
                try {
                    $colObj = Get-CachedDeviceCollectionById -CollectionId ([string]$c.CollectionID)

                    if ($colObj) {
                        Remove-Collection-Robust -Collection $colObj
                    }
                    else {
                        Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Collection not found' -Detail $c.CollectionID
                        [void]$failedCollections.Add($c)
                    }
                }
                catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Collection retry failed' -Detail (("'{0}' | {1}") -f $c.Name, $_.Exception.Message)

                    [void]$failedCollections.Add(
                        [pscustomobject]@{
                            Name         = $c.Name
                            CollectionID = $c.CollectionID
                            Error        = $_.Exception.Message
                        }
                    )
                }
            }
        }

        if ($round -lt $RetryCount) {
            Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Wait before next round' -Detail ("{0} seconds" -f $RetryDelaySeconds)
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Completed all rounds'
}

# ------------------------------------------------------------
# MAIN FLOW
# ------------------------------------------------------------

$__OldConfirmPreference  = $ConfirmPreference
$__OldProgressPreference = $ProgressPreference

$ConfirmPreference  = 'None'
$ProgressPreference = 'SilentlyContinue'

try {
    # Phase 0: initialize and report execution context.
    Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Start consolidation' -Detail ("Software='{0}', SiteCode='{1}', DryRun={2}" -f $SoftwareName, $SiteCode, $DryRun.IsPresent)

    $scriptIdentity = Get-ScriptIdentity
    $shortHash = [string]$scriptIdentity.Sha256
    if (-not [string]::IsNullOrWhiteSpace($shortHash) -and $shortHash.Length -gt 12) {
        $shortHash = $shortHash.Substring(0, 12)
    }

    Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Script identity' -Detail (
        "BuildId='{0}', Host='{1}', Path='{2}', LastWrite='{3}', SHA256='{4}'" -f
        ([string]$scriptIdentity.BuildId),
        ([string]$scriptIdentity.Computer),
        ([string]$scriptIdentity.ScriptPath),
        ([string]$scriptIdentity.LastWrite),
        $shortHash
    )

    # ------------------------------------------------------------
    # CONNECT TO SCCM SITE
    # ------------------------------------------------------------
    # Phase 1: establish SCCM provider context for all subsequent operations.
    Connect-SccmSite -SiteCode $SiteCode

    # ------------------------------------------------------------
    # RETRIEVE ALL COLLECTIONS MATCHING USER INPUT
    # ------------------------------------------------------------
    # Phase 2: identify all candidate collections in scope for this software.
    $allCollections = Convert-ToSafeArray -InputObject (Get-SoftwareCollections -SoftwareName $SoftwareName)

    if (-not $allCollections -or $allCollections.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Discovery' -Action 'No matching collections' -Detail $SoftwareName
    }
    else {

        # ------------------------------------------------------------
        # AUTO-DETECT ACTUAL SOFTWARE NAME USED IN SCCM
        # (WITH FILTERING, DEBUG LOGGING, AND FALLBACK PROMPT)
        # ------------------------------------------------------------

        # Phase 3: derive the best software-family name from existing collection names.
        $matchingCollections = Convert-ToSafeArray -InputObject ($allCollections | Where-Object {
            $_.Name -like ("*" + $SoftwareName + "*")
        })

        if ($matchingCollections.Count -gt 0) {

            $requestedSoftwareName = $SoftwareName

            $softwareNameCandidatesRaw = @()
            $softwareNameCandidates = @()
            $debugFiltered = @()

            foreach ($col in $matchingCollections) {
                # Extract a software-family candidate from each matching
                # collection name by trimming version suffixes.
                $originalName = $col.Name
                $name = $originalName.Trim()

                # Remove deployment intent suffixes so candidate extraction works
                # with names like "Product - Install (Available)".
                $nameForCandidate = $name
                $nameForCandidate = $nameForCandidate -replace '\s*-\s*Install\s*(\((Available|Required)\))?\s*$', ''
                $nameForCandidate = $nameForCandidate -replace '\s*-\s*Uninstall\s*$', ''

                # Split on first numeric sequence (version)
                $split = $nameForCandidate -split "\d", 2

                if ($split.Count -gt 0) {
                    $candidate = $split[0].Trim()
                    $candidate = $candidate.TrimEnd('-', ' ')

                    if (
                        -not [string]::IsNullOrWhiteSpace($candidate) -and
                        $candidate -match "[A-Za-z]" -and
                        $candidate.Length -ge 3 -and
                        ($candidate -split "\s+").Count -ge 2
                    ) {

                        $softwareNameCandidatesRaw += $candidate
                    }
                    else {
                        $debugFiltered += [PSCustomObject]@{
                            CollectionName = $originalName
                            Extracted      = $candidate
                            Reason         = "Empty or invalid candidate"
                        }
                    }
                }
                else {
                    $debugFiltered += [PSCustomObject]@{
                        CollectionName = $originalName
                        Extracted      = ""
                        Reason         = "Split failed"
                    }
                }
            }

            # Keep a unique list for interactive display while preserving the
            # raw list for frequency-based auto-selection logic.
            $softwareNameCandidates = @($softwareNameCandidatesRaw | Sort-Object -Unique)

            # Final cleanup: ensure no empty or invalid candidates remain
            $softwareNameCandidates = @($softwareNameCandidates |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -match "[A-Za-z]" })

            # Debug logging
            if ($debugFiltered.Count -gt 0) {
                Write-LogEvent -Level 'DEBUG' -Scope 'Discovery' -Action 'Filtered invalid candidates' -Detail "Candidate extraction quality details follow."
                foreach ($item in $debugFiltered) {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Discovery' -Action 'Candidate filtered out' -Detail (
                        " - Collection: '{0}', Extracted: '{1}', Reason: {2}" `
                        -f $item.CollectionName, $item.Extracted, $item.Reason
                    )
                }
            }

            # ------------------------------------------------------------
            # HANDLE CANDIDATE SELECTION LOGIC
            # ------------------------------------------------------------

            $skipPrompt = $false

            if ($softwareNameCandidates.Count -eq 1) {
                # Only one valid candidate -> auto-select.
                $candidate = [string]($softwareNameCandidates | Select-Object -First 1)
                if (-not [string]::IsNullOrWhiteSpace($candidate) -and $candidate.Trim().Length -ge 3) {
                    $SoftwareName = $candidate.Trim()
                }
                else {
                    Write-LogEvent -Level 'WARN' -Scope 'Discovery' -Action 'Candidate rejected' -Detail ("Auto-detected candidate '{0}' is too short. Keeping requested software name '{1}'." -f $candidate, $requestedSoftwareName)
                    $SoftwareName = $requestedSoftwareName
                }
                Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Auto-selected software name' -Detail $SoftwareName
                $skipPrompt = $true
            }
            elseif ($softwareNameCandidates.Count -gt 1 -and $AutoApprove) {
                # AutoApprove -> pick the most common candidate.
                $SoftwareName = ($softwareNameCandidatesRaw |
                    Group-Object |
                    Sort-Object Count -Descending |
                    Select-Object -First 1).Name

                Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Auto-selected software name' -Detail ("Multiple candidates detected; selected '{0}'." -f $SoftwareName)
                $skipPrompt = $true
            }

            if (-not $skipPrompt -and $softwareNameCandidates.Count -gt 1) {

                Write-Host ""
                Write-Host "Multiple software name candidates found:" -ForegroundColor Yellow

                # Build stats for display
                $candidateStats = foreach ($candidate in $softwareNameCandidates) {
                    [PSCustomObject]@{
                        Name  = $candidate
                        Count = ($matchingCollections | Where-Object { $_.Name -like ("*" + $candidate + "*") }).Count
                    }
                }

                for ($i = 0; $i -lt $candidateStats.Count; $i++) {
                    Write-Host ("[{0}] {1}  (matches: {2})" `
                        -f ($i+1), $candidateStats[$i].Name, $candidateStats[$i].Count)
                }

                $selection = Read-Host "Enter the number of the correct software name"

                if ($selection -match '^\d+$' -and
                    $selection -ge 1 -and
                    $selection -le $candidateStats.Count) {

                    $SoftwareName = $candidateStats[$selection - 1].Name
                    Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'User-selected software name' -Detail $SoftwareName
                }
                else {
                    Write-LogEvent -Level 'ERROR' -Scope 'Discovery' -Action 'Invalid user selection' -Detail 'Aborting run.'
                    return
                }
            }
        }

        # ------------------------------------------------------------
        # RESOLVE CANONICAL NAME (AFTER AUTO-DETECTION)
        # ------------------------------------------------------------
        # Phase 4: resolve canonical naming used for master objects and reporting.
        $canonicalName = Get-CanonicalName -SoftwareName $SoftwareName

        Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Collections in scope' -Detail (("{0} for '{1}'") -f $allCollections.Count, $canonicalName)


        # ------------------------------------------------------------
        # ENSURE MASTER COLLECTIONS EXIST
        # ------------------------------------------------------------
        # Phase 5: create/locate master collections and place them in target folder.
        $masters = Ensure-MasterCollections `
            -CanonicalName $canonicalName `
            -TargetFolder $TargetFolder

        # ------------------------------------------------------------
        # POPULATE MASTER COLLECTIONS
        # ------------------------------------------------------------
        Write-LogEvent -Level 'DEBUG' -Scope 'Run' -Action 'Population input' -Detail ("SoftwareName: {0}" -f $SoftwareName)
        Write-LogEvent -Level 'DEBUG' -Scope 'Run' -Action 'Population input' -Detail ("CanonicalName: {0}" -f $canonicalName)
        Write-LogEvent -Level 'DEBUG' -Scope 'Run' -Action 'Population input' -Detail ("AllCollections count: {0}" -f ($allCollections.Count))
        # Phase 6: compute member sets and ensure deployment intent on masters.
        if ($allCollections -and $allCollections.Count -gt 0) {
            Populate-MasterCollections `
                -CanonicalName $canonicalName `
                -RequestedSoftwareName $requestedSoftwareName `
                -Masters $masters `
                -AllCollections $allCollections
        } else {
            Write-LogEvent -Level 'ERROR' -Scope 'Run' -Action 'Populate master collections skipped' -Detail 'AllCollections is null or empty.'
        }

        # ------------------------------------------------------------
        # APPLY SUPERSEDENCE AND DEPLOYMENTS
        # ------------------------------------------------------------
        # Phase 7: apply optional supersedence chain for version progression.
        Apply-SupersedenceAndDeployments `
            -SoftwareName $canonicalName `
            -ManageSupersedence:$ManageSupersedence

        # Supersedence creates new app revisions in SCCM, invalidating any
        # cached WMI proxy objects fetched before the operation. Force a fresh
        # fetch for the cleanup phase so property access doesn't hit stale refs.
        Reset-SccmRuntimeCaches -IncludeAppCaches

        # ------------------------------------------------------------
        # CLEANUP OLD COLLECTIONS
        # ------------------------------------------------------------
        # Phase 8: migrate/delete legacy artifacts in dependency-safe order.
        Plan-And-Execute-Cleanup `
            -SoftwareName $canonicalName `
            -Masters $masters `
            -AllCollections $allCollections `
            -DeleteOldCollections:$DeleteOldCollections

        # Phase 9: retry transient failures after provider state has settled.
        Retry-FailedDeletions `
            -RetryCount $RetryCount `
            -RetryDelaySeconds $RetryDelaySeconds

        # Phase 10: persist failures/audit data for post-run review.
        Export-FailedObjectsToCsv -BasePath "C:\Temp\SCCMCleanupResults"
    }

    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Completed in DryRun mode' -Detail 'No changes were performed.'
    }
    else {
        Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Completed'
    }

    # End-of-run summary
    $summaryLines = @()
    $summaryLines += ("  Collections processed : {0}" -f @($allCollections).Count)
    $summaryLines += ("  Deployment migrations : {0}" -f ($deploymentMigrationAudit | Where-Object { $_.Status -in @('Created','Planned') }).Count)
    $summaryLines += ("  Failed apps           : {0}" -f $failedApps.Count)
    $summaryLines += ("  Failed collections    : {0}" -f $failedCollections.Count)
    $summaryLines += ("  Failed deployments    : {0}" -f $failedDeployments.Count)
    Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Summary'
    foreach ($line in $summaryLines) { Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Summary line' -Detail $line.Trim() }
}
finally {
    $ConfirmPreference  = $__OldConfirmPreference
    $ProgressPreference = $__OldProgressPreference

    try { Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Restored session preferences' -Detail 'ConfirmPreference and ProgressPreference.' } catch {}
}
