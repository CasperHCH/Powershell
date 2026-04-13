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
    - Place master collections in the resolved Application Deployment root:
        <SiteCode>:\<DeviceCollection root>\<Deployment root>\<TargetFolder>
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
    - Clean up empty folders under the resolved Application Deployment root.

.PARAMETER SiteCode
    SCCM site code, for example "P03".

.PARAMETER SoftwareName
    Name or partial name of the software to consolidate,
    for example "Firefox".

.PARAMETER TargetFolder
    Name of the subfolder under the resolved Application Deployment root:
        <SiteCode>:\<DeviceCollection root>\<Deployment root>\<TargetFolder>
    where master collections should be placed.
    Example: "Mozilla Firefox"

.PARAMETER ApplicationDeploymentRootPath
    Optional explicit root path override under the SCCM device collection tree.
    Use this when auto-discovery is ambiguous in a given environment.
    Examples:
        DeviceCollections\Application Deployment Devices
        DeviceCollection\Application Deployment

.PARAMETER ManageSupersedence
    Defaults to $true and builds a linear supersedence chain between
    applications related to SoftwareName. Pass -ManageSupersedence $false
    to disable.

.PARAMETER DeleteOldCollections
    Defaults to $true and deletes old version-specific collections after
    consolidation. Pass -DeleteOldCollections $false to disable.

.PARAMETER AutoApprove
    If specified, perform cleanup without interactive confirmation.

.PARAMETER NonInteractive
    If specified, never prompt for input. Operations that require manual
    confirmation or candidate selection will abort with an explicit warning.

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

.PARAMETER StrictApplicationDeploymentRootDiscovery
    If specified, fail the run when the application deployment root cannot be
    discovered deterministically from explicit override, existing target-folder
    evidence, or provider evidence. This prevents silent fallback behavior.

.PARAMETER ScriptBuildId
    Optional build identifier for cross-machine verification.
    Example: "2026.03.20-rc2" or a CI run id.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteCode,

    [Parameter(Mandatory = $true)]
    [string]$SoftwareName,

    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $false)]
    [bool]$ManageSupersedence = $true,

    [Parameter(Mandatory = $false)]
    [bool]$DeleteOldCollections = $true,

    [Parameter(Mandatory = $false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive,

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
    [string]$ApplicationDeploymentRootPath = '',

    [Parameter(Mandatory = $false)]
    [switch]$StrictApplicationDeploymentRootDiscovery,

    [Parameter(Mandatory = $false)]
    [string]$ScriptBuildId = ''
)

# Backward compatibility and standardization:
# -WhatIf implies dry-run execution in this legacy workflow.
if ($WhatIfPreference -and -not $DryRun) {
    $DryRun = $true
}
if ($DryRun -and -not $WhatIfPreference) {
    $WhatIfPreference = $true
}

$script:DebugLoggingEnabled = $EnableDebugLog.IsPresent
$script:CleanupMembershipDependenciesEnabled = [bool]$CleanupCollectionMembershipDependencies
$script:ReassignLimitingDependencyEnabled = $ReassignLimitingCollectionDependencies.IsPresent
$script:FallbackLimitingCollection = $FallbackLimitingCollectionName
$script:ApplicationDeploymentRootOverride = $ApplicationDeploymentRootPath
$script:StrictRootDiscoveryEnabled = $StrictApplicationDeploymentRootDiscovery.IsPresent
$script:ExecutionBuildId = $ScriptBuildId

function Write-SectionHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Information '' -InformationAction Continue
    Write-Information $Message -InformationAction Continue
}

function Write-ResultLine {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    Write-Information $Message -InformationAction Continue
}

# ------------------------------------------------------------
# GLOBAL STATE
# ------------------------------------------------------------

$failedApps = New-Object System.Collections.Generic.List[object]
$failedCollections = New-Object System.Collections.Generic.List[object]
$failedDeployments = New-Object System.Collections.Generic.List[object]
$deploymentMigrationAudit = New-Object System.Collections.Generic.List[object]
$script:ProtectedLegacyCollectionIds = New-Object System.Collections.Generic.HashSet[string]
$script:ProtectedLegacyCollectionNames = New-Object System.Collections.Generic.HashSet[string]

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
$script:CanonicalMappingInventoryCache = $null
$script:ResolvedApplicationDeploymentRoot = $null
$script:GetCmFolderSupportsPath = $null
$script:GetCmFolderSupportsRecurse = $null
$script:RemoveCmFolderSupportsPath = $null

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
function Write-ScriptLog {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Level -eq 'DEBUG' -and -not $script:DebugLoggingEnabled) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Information ("{0} [{1}] {2}" -f $timestamp, $Level, $Message) -InformationAction Continue
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
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
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
    } catch {
        $normalizedScope = 'GENERAL'
    }

    try {
        $actionValue = [string]$Action
        if (-not [string]::IsNullOrWhiteSpace($actionValue)) {
            $normalizedAction = $actionValue.Trim()
        }
    } catch {
        $normalizedAction = 'Event'
    }

    try {
        $detailText = [string]$Detail
    } catch {
        $detailText = '[Detail conversion failed]'
    }

    $prefix = ("[{0}] {1}" -f $normalizedScope, $normalizedAction)

    try {
        if ([string]::IsNullOrWhiteSpace($detailText)) {
            Write-ScriptLog -Level $Level -Message $prefix
        } else {
            Write-ScriptLog -Level $Level -Message ("{0}: {1}" -f $prefix, $detailText)
        }
    } catch {
        # Last-resort logging path; never let logging failures crash the workflow.
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Information ("{0} [ERROR] [LOGGING] Write-LogEvent fallback | Level={1}; Scope={2}; Action={3}; Detail={4}; Error={5}" -f $timestamp, $Level, $normalizedScope, $normalizedAction, $detailText, $_.Exception.Message) -InformationAction Continue
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
        } catch {
            $hash = 'HashError'
        }

        try {
            $lastWrite = (Get-Item -LiteralPath $scriptPath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        } catch {
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

function Get-SmsProviderInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Namespace,

        [Parameter(Mandatory = $true)]
        [string]$ClassName,

        [Parameter(Mandatory = $false)]
        [string]$Filter = ''
    )

    $previousWhatIfPreference = $WhatIfPreference

    try {
        # Importing CimCmdlets lazily under a script-wide WhatIf preference can
        # emit noisy alias-creation messages. Suppress WhatIf only for the local
        # provider query so DryRun logs stay readable.
        $WhatIfPreference = $false
        Import-Module CimCmdlets -ErrorAction SilentlyContinue | Out-Null

        $cimParams = @{
            Namespace   = $Namespace
            ClassName   = $ClassName
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $cimParams.Filter = $Filter
        }

        return @(Get-CimInstance @cimParams)
    } finally {
        $WhatIfPreference = $previousWhatIfPreference
    }
}

function Invoke-SmsProviderDelete {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    $previousWhatIfPreference = $WhatIfPreference

    try {
        $WhatIfPreference = $false
        Import-Module CimCmdlets -ErrorAction SilentlyContinue | Out-Null

        try {
            [void](Invoke-CimMethod -InputObject $InputObject -MethodName Delete -ErrorAction Stop)
            return
        } catch {
            Remove-CimInstance -InputObject $InputObject -ErrorAction Stop
        }
    } finally {
        $WhatIfPreference = $previousWhatIfPreference
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
    } else {
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
        [Parameter(Mandatory = $true)]
        [scriptblock[]]$Attempts,
        [Parameter(Mandatory = $false)]
        [string]$ActionName = 'command'
    )

    foreach ($attempt in $Attempts) {
        try {
            # Execute each attempt under a temporary Stop preference so non-terminating
            # command errors are promoted without passing unsupported args to scriptblocks.
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            $result = & $attempt
            return @{ Success = $true; Result = $result }
        } catch {
            # Sanitize error to avoid information disclosure
            $sanitizedMsg = $_.Exception.Message -replace '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]'
            Write-LogEvent -Level 'DEBUG' -Scope 'Operations' -Action 'Debug' -Detail ("Fallback {0} attempt failed: {1}" -f $ActionName, $sanitizedMsg)
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
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
        } catch {
            Write-Verbose ("Failed to inspect property [{0}] on input object." -f $propertyName)
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

function Test-CmFolderPathParameterSupport {
    <#
    .SYNOPSIS
        Returns whether Get-CMFolder supports the -Path parameter.

    .DESCRIPTION
        SCCM module parameter sets vary by environment. This helper avoids
        runtime binding failures by detecting support once per run.
    #>
    if ($null -ne $script:GetCmFolderSupportsPath) {
        return [bool]$script:GetCmFolderSupportsPath
    }

    $supportsPath = $false
    try {
        $getCmFolderCommand = Get-CachedCommand -Name 'Get-CMFolder'
        if ($getCmFolderCommand -and $getCmFolderCommand.Parameters -and $getCmFolderCommand.Parameters.ContainsKey('Path')) {
            $supportsPath = $true
        }
    } catch {
        $supportsPath = $false
    }

    $script:GetCmFolderSupportsPath = $supportsPath
    return [bool]$script:GetCmFolderSupportsPath
}

function Test-CmFolderRecurseParameterSupport {
    <#
    .SYNOPSIS
        Returns whether Get-CMFolder supports the -Recurse parameter.

    .DESCRIPTION
        SCCM module parameter sets vary by environment. This helper avoids
        runtime binding failures by detecting support once per run.
    #>
    if ($null -ne $script:GetCmFolderSupportsRecurse) {
        return [bool]$script:GetCmFolderSupportsRecurse
    }

    $supportsRecurse = $false
    try {
        $getCmFolderCommand = Get-CachedCommand -Name 'Get-CMFolder'
        if ($getCmFolderCommand -and $getCmFolderCommand.Parameters -and $getCmFolderCommand.Parameters.ContainsKey('Recurse')) {
            $supportsRecurse = $true
        }
    } catch {
        $supportsRecurse = $false
    }

    $script:GetCmFolderSupportsRecurse = $supportsRecurse
    return [bool]$script:GetCmFolderSupportsRecurse
}

function Test-RemoveCmFolderPathParameterSupport {
    <#
    .SYNOPSIS
        Returns whether Remove-CMFolder supports the -Path parameter.

    .DESCRIPTION
        SCCM module parameter sets vary by environment. This helper avoids
        runtime binding failures by detecting support once per run.
    #>
    if ($null -ne $script:RemoveCmFolderSupportsPath) {
        return [bool]$script:RemoveCmFolderSupportsPath
    }

    $supportsPath = $false
    try {
        $removeCmFolderCommand = Get-CachedCommand -Name 'Remove-CMFolder'
        if ($removeCmFolderCommand -and $removeCmFolderCommand.Parameters -and $removeCmFolderCommand.Parameters.ContainsKey('Path')) {
            $supportsPath = $true
        }
    } catch {
        $supportsPath = $false
    }

    $script:RemoveCmFolderSupportsPath = $supportsPath
    return [bool]$script:RemoveCmFolderSupportsPath
}

function Get-ApplicationDeploymentDiscoveryFingerprint {
    <#
    .SYNOPSIS
        Returns a capability fingerprint for root discovery cache safety.

    .DESCRIPTION
        Captures site and cmdlet capability shape so cached root resolution is
        reused only when execution context appears equivalent.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode
    )

    $getCmFolderSupportsPath = Test-CmFolderPathParameterSupport
    $getCmFolderSupportsRecurse = Test-CmFolderRecurseParameterSupport
    $removeCmFolderSupportsPath = Test-RemoveCmFolderPathParameterSupport

    $getCmFolderParameterKey = ''
    try {
        $getCmFolderCommand = Get-CachedCommand -Name 'Get-CMFolder'
        if ($getCmFolderCommand -and $getCmFolderCommand.Parameters) {
            $getCmFolderParameterKey = (@($getCmFolderCommand.Parameters.Keys | Sort-Object) -join ',')
        }
    } catch {
        $getCmFolderParameterKey = ''
    }

    return ('{0}|GP:{1}|GR:{2}|RP:{3}|K:{4}' -f $SiteCode, [int]$getCmFolderSupportsPath, [int]$getCmFolderSupportsRecurse, [int]$removeCmFolderSupportsPath, $getCmFolderParameterKey)
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
        } catch {
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
        } catch {
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
        } else {
            $collection = $null
        }
    } catch {
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
        IncludeByTargetId    = @{}
        IncludeByTargetName  = @{}
        ExcludeByTargetId    = @{}
        ExcludeByTargetName  = @{}
        LimitingByTargetId   = @{}
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
            } catch {
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
            } catch {
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
            } catch {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal cache reset helper. Confirmation and DryRun behavior are coordinated by the top-level script workflow.')]
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
    $searchTerms = New-Object System.Collections.Generic.List[string]
    $searchTerms.Add($SoftwareName.Trim())

    # Fallback for names entered with a trailing version token, such as
    # "Oracle Java 8" when app names are "Oracle Java <version>".
    $withoutTrailingVersion = (($SoftwareName -as [string]).Trim() -replace '(?i)\s+v?\d+(?:\.\d+){0,3}\s*$', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($withoutTrailingVersion) -and ($withoutTrailingVersion -ne $SoftwareName.Trim())) {
        $searchTerms.Add($withoutTrailingVersion)
    }

    $allTerms = @($searchTerms | Sort-Object -Unique)
    $appsByKey = @{}

    foreach ($term in $allTerms) {
        try {
            # Use provider-side filtering first to avoid a full application scan.
            $applicationMatches = @(Get-CMApplication -Name ("*{0}*" -f $term) -ErrorAction Stop)
            Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Found {0} apps matching pattern '*{1}*'" -f $applicationMatches.Count, $term)

            foreach ($app in $applicationMatches) {
                $appKey = [string](Get-ObjectPropertyValue -InputObject $app -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId', 'LocalizedDisplayName', 'ApplicationName', 'Name'))
                if (-not [string]::IsNullOrWhiteSpace($appKey)) {
                    $appsByKey[$appKey.ToLowerInvariant()] = $app
                }
            }
        } catch {
            if ($_.Exception.Message -like '*Not found*') {
                Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("No apps found matching pattern '*{0}*'" -f $term)
                continue
            }

            Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Filtered CMApplication query failed for '{0}': {1}" -f $term, $_.Exception.Message)
        }
    }

    $apps = @($appsByKey.Values)

    if ($apps.Count -eq 0) {
        # Last-resort full scan to cover environments where -Name filtering differs.
        Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail 'No matches from provider-side filters; falling back to full application scan.'
        try {
            $allApps = @(Get-CMApplication -ErrorAction SilentlyContinue)
            $apps = @($allApps | Where-Object {
                    $displayName = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
                    foreach ($term in $allTerms) {
                        if ($displayName -like ("*{0}*" -f $term)) {
                            return $true
                        }
                    }

                    return $false
                })
        } catch {
            Write-LogEvent -Level 'WARN' -Scope 'Applications' -Action 'Warning' -Detail ("Could not query applications for '{0}': {1}" -f $SoftwareName, $_.Exception.Message)
            $apps = @()
        }
    }

    Write-LogEvent -Level 'INFO' -Scope 'Applications' -Action 'Status' -Detail ("Found {0} matching applications after fallback discovery." -f @($apps).Count)

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
            } elseif ($deploymentSet.Scope -eq 'ByCollection') {
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
    Prefers version text from the application display name and falls back to
    SoftwareVersion only when the name does not contain a parseable version.
#>
function Get-AppVersionNormalized {
    param(
        [Parameter(Mandatory = $true)]
        $App
    )

    if (-not $App) { return $null }

    # Prefer the version embedded in the display name when present. In SCCM,
    # SoftwareVersion can contain vendor-specific product numbering that does not
    # reflect the deployable application version shown to operators.
    $displayName = [string](Get-ObjectPropertyValue -InputObject $App -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
    if (-not [string]::IsNullOrWhiteSpace($displayName)) {
        $norm = Get-VersionFromName -Name $displayName
        if ($norm) { return $norm }
    }

    $softwareVersion = [string](Get-ObjectPropertyValue -InputObject $App -PropertyNames @('SoftwareVersion'))
    if (-not [string]::IsNullOrWhiteSpace($softwareVersion)) {
        $norm = ConvertTo-NormalizedVersion -VersionString $softwareVersion
        if ($norm) { return $norm }
    }

    return $null
}

<#
.SYNOPSIS
    Formats an application name with version when the name does not include one.

.DESCRIPTION
    Produces stable operator-facing labels so logs show the resolved application
    version even when SCCM stores a short display name such as 'Brave'.
#>
function Get-VersionAwareDisplayName {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$VersionRaw
    )

    $resolvedName = ($Name -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($resolvedName)) {
        $resolvedName = '[Unnamed application]'
    }

    $resolvedVersion = ($VersionRaw -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
        return $resolvedName
    }

    if (Get-VersionFromName -Name $resolvedName) {
        return $resolvedName
    }

    return ('{0} {1}' -f $resolvedName, $resolvedVersion)
}

<#
.SYNOPSIS
    Returns a log-friendly application display name.

.DESCRIPTION
    Resolves display name aliases from a CM application object and appends the
    normalized version only when the base name does not already contain one.
#>
function Get-ApplicationDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        $App
    )

    if (-not $App) {
        return '[Unnamed application]'
    }

    $name = [string](Get-ObjectPropertyValue -InputObject $App -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
    $version = [string](Get-AppVersionNormalized -App $App)
    return Get-VersionAwareDisplayName -Name $name -VersionRaw $version
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
        $appCiId = [string](Get-ObjectPropertyValue -InputObject $app -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId'))
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
            @{ Expression = { [string](Get-ObjectPropertyValue -InputObject $_.App -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId')) }; Descending = $true },
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

    $selection = Get-LatestApplicationSelection -SoftwareName $SoftwareName
    return $selection.App
}

<#
.SYNOPSIS
    Returns latest-application selection metadata for a software family.

.DESCRIPTION
    Distinguishes between a version-confirmed latest application and an inferred
    fallback based on modification timestamps when version parsing is unavailable.
#>
function Get-LatestApplicationSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    $versioned = Convert-ToSafeArray -InputObject (Get-VersionedApplicationsForSoftwareName -SoftwareName $SoftwareName)
    if ($versioned.Count -gt 0) {
        return [pscustomobject]@{
            App                = $versioned[0].App
            IsVersionConfirmed = $true
            SelectionMode      = 'VersionConfirmed'
            WarningDetail      = ''
        }
    }

    $apps = Convert-ToSafeArray -InputObject (Get-ApplicationsForSoftwareName -SoftwareName $SoftwareName)
    if ($apps.Count -eq 0) {
        return [pscustomobject]@{
            App                = $null
            IsVersionConfirmed = $false
            SelectionMode      = 'NotFound'
            WarningDetail      = ''
        }
    }

    $latestFallback = @($apps | Sort-Object -Property @(
            @{ Expression     = {
                    $candidate = Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('DateLastModified', 'LastModified', 'DateCreated', 'CreatedDate')
                    if ($candidate -is [datetime]) {
                        return $candidate
                    }

                    try {
                        return [datetime]$candidate
                    } catch {
                        return [datetime]::MinValue
                    }
                }; Descending = $true
            },
            @{ Expression = { [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId')) }; Descending = $true },
            @{ Expression = { [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name')) }; Descending = $false }
        ) | Select-Object -First 1)

    if ($latestFallback.Count -gt 0) {
        $fallbackDisplayName = Get-ApplicationDisplayName -App $latestFallback[0]
        $warningDetail = "Version parsing unavailable for '{0}'. Latest target is inferred from newest matching application metadata: '{1}'." -f $SoftwareName, $fallbackDisplayName
        Write-LogEvent -Level 'WARN' -Scope 'Applications' -Action 'Fallback latest selection' -Detail $warningDetail
        return [pscustomobject]@{
            App                = $latestFallback[0]
            IsVersionConfirmed = $false
            SelectionMode      = 'InferredLatestModified'
            WarningDetail      = $warningDetail
        }
    }

    return [pscustomobject]@{
        App                = $null
        IsVersionConfirmed = $false
        SelectionMode      = 'NotFound'
        WarningDetail      = ''
    }
}

<#!
.SYNOPSIS
    Resolves the application object used for master-collection deployments.

.DESCRIPTION
    Uses the same latest-selection logic as cleanup so master deployments target
    the same application version. An exact canonical-name app is only preferred
    when no version-confirmed latest application can be resolved.
#>
function Get-MasterDeploymentApplicationSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        [Parameter(Mandatory = $false)]
        [string]$RequestedSoftwareName = ''
    )

    $exactCanonicalApp = $null
    $canonicalApps = Convert-ToSafeArray -InputObject (Get-ApplicationsForSoftwareName -SoftwareName $CanonicalName)
    $exactCanonicalMatch = @($canonicalApps | Where-Object {
            [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name')) -eq $CanonicalName
        } | Select-Object -First 1)
    if ($exactCanonicalMatch.Count -gt 0) {
        $exactCanonicalApp = $exactCanonicalMatch[0]
    }

    $selection = $null
    if (-not [string]::IsNullOrWhiteSpace($RequestedSoftwareName) -and $RequestedSoftwareName -ne $CanonicalName) {
        $selection = Get-LatestApplicationSelection -SoftwareName $RequestedSoftwareName
    }

    if (-not $selection -or -not $selection.App) {
        $selection = Get-LatestApplicationSelection -SoftwareName $CanonicalName
    }

    if ($selection -and $selection.App) {
        return [pscustomobject]@{
            App                        = $selection.App
            IsVersionConfirmed         = $selection.IsVersionConfirmed
            SelectionMode              = $selection.SelectionMode
            WarningDetail              = $selection.WarningDetail
            ExactCanonicalApp          = $exactCanonicalApp
            ExactCanonicalWasPreferred = $false
        }
    }

    if ($exactCanonicalApp) {
        return [pscustomobject]@{
            App                        = $exactCanonicalApp
            IsVersionConfirmed         = $false
            SelectionMode              = 'ExactCanonicalFallback'
            WarningDetail              = ''
            ExactCanonicalApp          = $exactCanonicalApp
            ExactCanonicalWasPreferred = $true
        }
    }

    return [pscustomobject]@{
        App                        = $null
        IsVersionConfirmed         = $false
        SelectionMode              = 'NotFound'
        WarningDetail              = ''
        ExactCanonicalApp          = $exactCanonicalApp
        ExactCanonicalWasPreferred = $false
    }
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
function Set-LatestDeploymentForCollection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal deployment migration helper. Confirmation is controlled by the script entry point and DryRun wrapper.')]
    param(
        [Parameter(Mandatory = $true)]
        $Deployment,

        [Parameter(Mandatory = $true)]
        $LatestApp
    )

    $collectionName = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('CollectionName', 'TargetCollectionName')
    $deploymentId = Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('DeploymentID', 'DeploymentId', 'AssignmentID', 'AssignmentId', 'Id')
    $latestAppName = [string](Get-ObjectPropertyValue -InputObject $LatestApp -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
    $latestAppDisplayName = Get-ApplicationDisplayName -App $LatestApp

    if ([string]::IsNullOrWhiteSpace(($collectionName -as [string]))) {
        $audit = [pscustomobject]@{
            Timestamp        = (Get-Date).ToString('o')
            SourceDeployment = $deploymentId
            CollectionName   = $collectionName
            SourceAppName    = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName    = $latestAppDisplayName
            Status           = 'Skipped'
            Notes            = 'Missing collection name on source deployment.'
        }
        [void]$deploymentMigrationAudit.Add($audit)
        return $false
    }

    $existing = Find-ExistingApplicationDeployment -CollectionName $collectionName -Application $LatestApp
    if ($existing) {
        $audit = [pscustomobject]@{
            Timestamp        = (Get-Date).ToString('o')
            SourceDeployment = $deploymentId
            CollectionName   = $collectionName
            SourceAppName    = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName    = $latestAppDisplayName
            Status           = 'AlreadyExists'
            Notes            = 'Latest deployment already present for target collection.'
        }
        [void]$deploymentMigrationAudit.Add($audit)
        return $true
    }

    $intent = Get-DeploymentIntent -Deployment $Deployment

    if ($DryRun) {
        $audit = [pscustomobject]@{
            Timestamp        = (Get-Date).ToString('o')
            SourceDeployment = $deploymentId
            CollectionName   = $collectionName
            SourceAppName    = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName    = $latestAppDisplayName
            Status           = 'Planned'
            Notes            = ("[DryRun] Would migrate deployment with Action={0}; Purpose={1}" -f $intent.DeployAction, $intent.DeployPurpose)
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'INFO' -Scope 'Deployments' -Action 'Status' -Detail ("[DryRun] Would migrate deployment for collection '{0}' to latest app '{1}' ({2}/{3})." -f $collectionName, $latestAppDisplayName, $intent.DeployAction, $intent.DeployPurpose)
        return $true
    }

    try {
        $deployAttempts = @()
        if ($intent.DeployPurpose) {
            $deployAttempts += {
                New-CMApplicationDeployment -CollectionName $collectionName -Name $latestAppName -DeployAction $intent.DeployAction -DeployPurpose $intent.DeployPurpose -ErrorAction Stop | Out-Null
            }
        }
        $deployAttempts += {
            New-CMApplicationDeployment -CollectionName $collectionName -Name $latestAppName -DeployAction $intent.DeployAction -ErrorAction Stop | Out-Null
        }

        $result = Invoke-CmCommandWithFallback -Attempts $deployAttempts -ActionName 'New-CMApplicationDeployment (migrate)'
        if (-not $result.Success) {
            throw 'All deployment creation attempts failed.'
        }

        $audit = [pscustomobject]@{
            Timestamp        = (Get-Date).ToString('o')
            SourceDeployment = $deploymentId
            CollectionName   = $collectionName
            SourceAppName    = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName    = $latestAppDisplayName
            Status           = 'Created'
            Notes            = ("Action={0}; Purpose={1}" -f $intent.DeployAction, $intent.DeployPurpose)
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'SUCCESS' -Scope 'Deployments' -Action 'Success' -Detail ("Migrated deployment for collection '{0}' to latest app '{1}' ({2}/{3})." -f $collectionName, $latestAppDisplayName, $intent.DeployAction, $intent.DeployPurpose)
        return $true
    } catch {
        $audit = [pscustomobject]@{
            Timestamp        = (Get-Date).ToString('o')
            SourceDeployment = $deploymentId
            CollectionName   = $collectionName
            SourceAppName    = (Get-ObjectPropertyValue -InputObject $Deployment -PropertyNames @('ApplicationName', 'SoftwareName', 'Name'))
            TargetAppName    = $latestAppDisplayName
            Status           = 'Failed'
            Notes            = $_.Exception.Message
        }
        [void]$deploymentMigrationAudit.Add($audit)

        Write-LogEvent -Level 'WARN' -Scope 'Deployments' -Action 'Warning' -Detail ("Could not migrate deployment for collection '{0}' to latest app '{1}': {2}" -f $collectionName, $latestAppDisplayName, $_.Exception.Message)
        return $false
    }
}

<#
.SYNOPSIS
    Deletes an application using the safest available SCCM identifier.

.DESCRIPTION
    Prefers object, id, and model-name based removal before falling back to the
    application display name. This reduces the risk of deleting the wrong app
    when multiple SCCM objects share a visible name.
#>
function Remove-Application-Robust {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal delete helper. Confirmation is controlled by the script entry point and DryRun wrapper.')]
    param(
        [Parameter(Mandatory = $true)]
        $Application
    )

    $resolvedApplication = $Application
    $applicationName = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
    $applicationId = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('CI_ID', 'CIId', 'Id', 'ModelID', 'ModelId'))
    $applicationModelName = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('ModelName', 'ModelId'))

    if ([string]::IsNullOrWhiteSpace($applicationName) -and
        [string]::IsNullOrWhiteSpace($applicationId) -and
        [string]::IsNullOrWhiteSpace($applicationModelName)) {
        throw 'Application removal requires at least one identifier (InputObject, Id, ModelName, or Name).'
    }

    $getApplicationCommand = Get-CachedCommand -Name 'Get-CMApplication'
    if ($getApplicationCommand) {
        $getApplicationParameterNames = @($getApplicationCommand.Parameters.Keys)
        $resolveAttempts = @()

        if (($getApplicationParameterNames -contains 'Id') -and -not [string]::IsNullOrWhiteSpace($applicationId)) {
            $applicationIdValue = $applicationId
            $resolveAttempts += [pscustomobject]@{
                Label  = 'Get-CMApplication -Id'
                Action = { @(Get-CMApplication -Id $applicationIdValue -ErrorAction Stop | Select-Object -First 1) }
            }
        }

        if (($getApplicationParameterNames -contains 'ModelName') -and -not [string]::IsNullOrWhiteSpace($applicationModelName)) {
            $applicationModelNameValue = $applicationModelName
            $resolveAttempts += [pscustomobject]@{
                Label  = 'Get-CMApplication -ModelName'
                Action = { @(Get-CMApplication -ModelName $applicationModelNameValue -ErrorAction Stop | Select-Object -First 1) }
            }
        }

        if (($getApplicationParameterNames -contains 'Name') -and -not [string]::IsNullOrWhiteSpace($applicationName)) {
            $applicationNameValue = $applicationName
            $resolveAttempts += [pscustomobject]@{
                Label  = 'Get-CMApplication -Name'
                Action = { @(Get-CMApplication -Name $applicationNameValue -ErrorAction Stop | Select-Object -First 1) }
            }
        }

        foreach ($resolveAttempt in $resolveAttempts) {
            try {
                $candidate = @(& $resolveAttempt.Action)
                if ($candidate.Count -gt 0 -and $candidate[0]) {
                    $resolvedApplication = $candidate[0]
                    break
                }
            } catch {
                Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Application rehydrate attempt failed with {0}: {1}" -f $resolveAttempt.Label, $_.Exception.Message)
            }
        }

        $applicationName = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
        $applicationId = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('CI_ID', 'CIId', 'Id', 'ModelID', 'ModelId'))
        $applicationModelName = [string](Get-ObjectPropertyValue -InputObject $resolvedApplication -PropertyNames @('ModelName', 'ModelId'))
    }

    $applicationDisplayName = $applicationName
    try {
        $applicationDisplayName = [string](Get-ApplicationDisplayName -App $resolvedApplication)
    } catch {
        $applicationDisplayName = $applicationName
    }

    $removeApplicationCommand = Get-CachedCommand -Name 'Remove-CMApplication'
    if (-not $removeApplicationCommand) {
        throw 'Remove-CMApplication command is not available in current session.'
    }

    $commandParameters = $null
    try { $commandParameters = $removeApplicationCommand.Parameters } catch { $commandParameters = $null }
    if ($null -eq $commandParameters) {
        $removeApplicationCommand = Get-Command 'Remove-CMApplication' -ErrorAction SilentlyContinue
        $script:CommandMetadataCache['Remove-CMApplication'] = $removeApplicationCommand
        try { $commandParameters = $removeApplicationCommand.Parameters } catch { $commandParameters = $null }
    }

    $commandParameterNames = if ($null -ne $commandParameters) { @($commandParameters.Keys) } else { @() }
    $attempts = @()

    if (($commandParameterNames -contains 'InputObject') -and $resolvedApplication) {
        $applicationInputObject = $resolvedApplication
        $attempts += [pscustomobject]@{
            Label  = 'InputObject'
            Action = { Remove-CMApplication -InputObject $applicationInputObject -Force -Confirm:$false -ErrorAction Stop }
        }
    }

    if (($commandParameterNames -contains 'Id') -and -not [string]::IsNullOrWhiteSpace($applicationId)) {
        $applicationIdValue = $applicationId
        $attempts += [pscustomobject]@{
            Label  = 'Id'
            Action = { Remove-CMApplication -Id $applicationIdValue -Force -Confirm:$false -ErrorAction Stop }
        }
    }

    if (($commandParameterNames -contains 'ModelName') -and -not [string]::IsNullOrWhiteSpace($applicationModelName)) {
        $applicationModelNameValue = $applicationModelName
        $attempts += [pscustomobject]@{
            Label  = 'ModelName'
            Action = { Remove-CMApplication -ModelName $applicationModelNameValue -Force -Confirm:$false -ErrorAction Stop }
        }
    }

    if (($commandParameterNames -contains 'Name') -and -not [string]::IsNullOrWhiteSpace($applicationName)) {
        $applicationNameValue = $applicationName
        $attempts += [pscustomobject]@{
            Label  = 'Name'
            Action = { Remove-CMApplication -Name $applicationNameValue -Force -Confirm:$false -ErrorAction Stop }
        }
    }

    if ($attempts.Count -eq 0) {
        throw ("No valid non-interactive Remove-CMApplication call could be built. Available params: {0}" -f ($commandParameterNames -join ', '))
    }

    $attemptErrors = New-Object System.Collections.Generic.List[string]

    foreach ($attempt in $attempts) {
        try {
            & $attempt.Action
            return $true
        } catch {
            $attemptError = [string]$_.Exception.Message
            if ([string]::IsNullOrWhiteSpace($attemptError)) {
                $attemptError = '[No exception message available]'
            }

            Write-LogEvent -Level 'DEBUG' -Scope 'Applications' -Action 'Debug' -Detail ("Remove-CMApplication attempt failed for '{0}' using {1}: {2}" -f $applicationDisplayName, $attempt.Label, $attemptError)
            [void]$attemptErrors.Add(("{0}: {1}" -f $attempt.Label, $attemptError))
        }
    }

    throw ("All Remove-CMApplication fallback attempts failed for '{0}'. Attempt errors: {1}" -f $applicationDisplayName, ([string]::Join(' | ', $attemptErrors)))
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
            } catch {
                Write-LogEvent -Level 'WARN' -Scope 'Connect' -Action 'Warning' -Detail ("Could not create PSDrive with AdminUI.PS.Provider.CMSite: {0}" -f $_.Exception.Message)
                $provider = Get-PSProvider | Where-Object { $_.Name -match 'CMSite' } | Select-Object -First 1
                if ($provider) {
                    try {
                        New-PSDrive -Name $SiteCode -PSProvider $provider.Name -Root $env:COMPUTERNAME -ErrorAction Stop | Out-Null
                    } catch {
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
    } catch {
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
function ConvertTo-NormalizedVersion {
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
function Get-VersionFromName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pattern = '\d+(\.\d+){1,3}'
    $match = [System.Text.RegularExpressions.Regex]::Match($Name, $pattern)
    if ($match.Success) {
        return ConvertTo-NormalizedVersion -VersionString $match.Value
    }

    return $null
}

<#
.SYNOPSIS
    Extracts a software-family candidate from a collection name.

.DESCRIPTION
    Removes deployment intent suffixes plus trailing version and locale tokens
    so names like 'Brave Software Inc Brave 146.1.88.138 en-US-install (device)'
    normalize to a family name candidate instead of a version-specific label.
#>
function Get-SoftwareFamilyCandidateFromCollectionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    $candidate = ($CollectionName -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    $candidate = $candidate -replace '[_]+', ' '
    $candidate = $candidate -replace '(?i)\s*-\s*(install|uninstall)\s*\((available|required|device|user)\)\s*$', ''
    $candidate = $candidate -replace '(?i)\s*-\s*(install|uninstall)\s*(\((available|required)\))?\s*$', ''
    $candidate = $candidate -replace '(?i)\s*\((device|user)\)\s*$', ''
    $candidate = $candidate -replace '(?i)(?:[\s_-]+)v?\d+(?:[._-]\d+){1,}(?:\s+[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})+)?\s*$', ''
    $candidate = $candidate -replace '(?i)\s+[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})+\s*$', ''
    $candidate = ($candidate -replace '\s+', ' ').Trim().TrimEnd('-', ' ')

    $tokens = @($candidate -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($tokens.Count -gt 1) {
        $dedupedTokens = New-Object System.Collections.Generic.List[string]
        $previousToken = ''

        foreach ($token in $tokens) {
            if (-not [string]::IsNullOrWhiteSpace($previousToken) -and $token.Equals($previousToken, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            [void]$dedupedTokens.Add($token)
            $previousToken = $token
        }

        $candidate = (@($dedupedTokens) -join ' ').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    return $candidate
}

<#
.SYNOPSIS
    Validates an auto-detected software-name candidate.

.DESCRIPTION
    Allows single-word product families while rejecting obvious action-only or
    malformed values that should never become the canonical family name.
#>
function Test-SoftwareNameCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Candidate
    )

    $trimmedCandidate = [string]$Candidate
    if ($null -eq $trimmedCandidate) {
        $trimmedCandidate = ''
    }
    $trimmedCandidate = $trimmedCandidate.Trim()

    if ([string]::IsNullOrWhiteSpace($trimmedCandidate)) {
        return $false
    }

    if ($trimmedCandidate.Length -lt 3 -or $trimmedCandidate -notmatch '[A-Za-z]') {
        return $false
    }

    $invalidNames = @('install', 'uninstall', 'available', 'required', 'device', 'user')
    return $invalidNames -notcontains $trimmedCandidate.ToLowerInvariant()
}

# ------------------------------------------------------------
# TARGET FOLDER PATH HELPER
# ------------------------------------------------------------

<#
.SYNOPSIS
    Returns known SCCM application deployment root layouts.

.DESCRIPTION
    These are last-resort fallback layouts used when provider-based discovery
    cannot determine the correct root automatically.
#>
function Get-ApplicationDeploymentRootDefinition {
    return @(
        [pscustomobject]@{
            DeviceRootName     = 'DeviceCollection'
            DeploymentRootName = 'Application Deployment'
        },
        [pscustomobject]@{
            DeviceRootName     = 'DeviceCollections'
            DeploymentRootName = 'Application Deployment Devices'
        }
    )
}

function Get-NormalizedCmFolderPath {
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
    $normalized = $normalized -replace '^[^:]+:\\?', ''
    $normalized = $normalized.TrimStart('\\').TrimEnd('\\')
    return $normalized
}

function Get-ApplicationDeploymentRootInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$DeviceRootName,

        [Parameter(Mandatory = $true)]
        [string]$DeploymentRootPath,

        [Parameter(Mandatory = $false)]
        [string]$Source = 'Unknown',

        [Parameter(Mandatory = $false)]
        [int]$Score = 0,

        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = '',

        [Parameter(Mandatory = $false)]
        [string]$ContainerNodeId = '',

        [Parameter(Mandatory = $false)]
        $FolderObject = $null,

        [Parameter(Mandatory = $false)]
        [string]$OverridePath = ''
    )

    $normalizedDeviceRootName = (Get-NormalizedCmFolderPath -Path $DeviceRootName).Trim('\')
    $normalizedDeploymentRootPath = (Get-NormalizedCmFolderPath -Path $DeploymentRootPath).Trim('\')
    if ([string]::IsNullOrWhiteSpace($normalizedDeviceRootName) -or [string]::IsNullOrWhiteSpace($normalizedDeploymentRootPath)) {
        return $null
    }

    $deploymentRootName = @($normalizedDeploymentRootPath -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)[0]
    $rootPathNoDrive = ('{0}\{1}' -f $normalizedDeviceRootName, $normalizedDeploymentRootPath)

    return [pscustomobject]@{
        SiteCode                   = [string]$SiteCode
        DeviceRootName             = [string]$normalizedDeviceRootName
        DeploymentRootName         = [string]$deploymentRootName
        DeploymentRootRelativePath = [string]$normalizedDeploymentRootPath
        DeviceRootNoDrive          = [string]$normalizedDeviceRootName
        DeviceRootPath             = ('{0}:\{1}' -f $SiteCode, $normalizedDeviceRootName)
        RootPathNoDrive            = [string]$rootPathNoDrive
        RootPath                   = ('{0}:\{1}' -f $SiteCode, $rootPathNoDrive)
        RootPathWithSlash          = ('\{0}' -f $rootPathNoDrive)
        Source                     = [string]$Source
        Score                      = [int]$Score
        TargetFolder               = [string]$TargetFolder
        ContainerNodeId            = [string]$ContainerNodeId
        FolderObject               = $FolderObject
        OverridePath               = [string]$OverridePath
        DiscoveryFingerprint       = ''
    }
}

<#
.SYNOPSIS
    Resolves the active application deployment root for the current site.

.DESCRIPTION
    Resolution order is:
    1. Explicit ApplicationDeploymentRootPath override
    2. Existing folder inference from TargetFolder
    3. Provider-based discovery of a top-level device collection folder
    4. Known fallback layouts

    The selected root is cached for the rest of the run so all later folder and
    cleanup operations use the same path consistently.
#>
function Resolve-ApplicationDeploymentRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = ''
    )

    $normalizedOverridePath = Get-NormalizedCmFolderPath -Path $script:ApplicationDeploymentRootOverride
    $discoveryFingerprint = Get-ApplicationDeploymentDiscoveryFingerprint -SiteCode $SiteCode
    $cachedRootInfo = $script:ResolvedApplicationDeploymentRoot
    if ($cachedRootInfo -and
        [string]$cachedRootInfo.SiteCode -eq [string]$SiteCode -and
        [string]$cachedRootInfo.OverridePath -eq [string]$normalizedOverridePath -and
        [string]$cachedRootInfo.DiscoveryFingerprint -eq [string]$discoveryFingerprint) {

        $cacheCanBeReused = $true
        if (-not [string]::IsNullOrWhiteSpace($TargetFolder) -and
            [string]::IsNullOrWhiteSpace([string]$cachedRootInfo.TargetFolder) -and
            [string]$cachedRootInfo.Source -eq 'FallbackKnownLayout') {
            $cacheCanBeReused = $false
        }

        if ($cacheCanBeReused) {
            return $cachedRootInfo
        }
    }

    $rootDefinitions = @(Get-ApplicationDeploymentRootDefinition)
    $knownDeviceRootNames = @($rootDefinitions | ForEach-Object { [string]$_.DeviceRootName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $knownRootLookup = @{}
    foreach ($rootDefinition in $rootDefinitions) {
        $knownRootLookup[(('{0}\{1}' -f $rootDefinition.DeviceRootName, $rootDefinition.DeploymentRootName).ToLowerInvariant())] = $true
    }

    $getCmFolderSupportsPath = Test-CmFolderPathParameterSupport

    $resolveRootFolderObject = {
        param(
            [Parameter(Mandatory = $true)]
            $RootInfo
        )

        $candidatePaths = @(
            [string]$RootInfo.RootPath,
            [string]$RootInfo.RootPathNoDrive,
            [string]$RootInfo.RootPathWithSlash
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

        foreach ($candidatePath in $candidatePaths) {
            $folderResult = @(Get-CMFolder -FolderPath $candidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
            if ($folderResult) {
                return $folderResult
            }

            if ($getCmFolderSupportsPath) {
                $folderResult = @(Get-CMFolder -Path $candidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
                if ($folderResult) {
                    return $folderResult
                }
            }
        }

        $folderResult = @(
            Get-CMFolder -Name ([string]$RootInfo.DeploymentRootName) -ErrorAction SilentlyContinue |
            Where-Object {
                (Get-NormalizedCmFolderPath -Path ([string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('FolderPath', 'Path', 'ContainerNodePath')))).ToLowerInvariant() -eq ([string]$RootInfo.RootPathNoDrive).ToLowerInvariant()
            }
        ) | Select-Object -First 1

        return $folderResult
    }

    $testChildFolderExists = {
        param(
            [Parameter(Mandatory = $true)]
            $RootInfo,

            [Parameter(Mandatory = $true)]
            [string]$ChildFolderName
        )

        $childFolderLeaf = [string](@($ChildFolderName) | Select-Object -First 1)
        $childFolderLeaf = $childFolderLeaf.Trim()
        if ([string]::IsNullOrWhiteSpace($childFolderLeaf)) {
            return $false
        }

        $rootPathValue = [string](Get-ObjectPropertyValue -InputObject $RootInfo -PropertyNames @('RootPath'))
        $rootPathNoDriveValue = [string](Get-ObjectPropertyValue -InputObject $RootInfo -PropertyNames @('RootPathNoDrive'))

        try {
            $candidatePaths = @(
                ('{0}\{1}' -f $rootPathValue.TrimEnd('\'), $childFolderLeaf),
                ('{0}\{1}' -f $rootPathNoDriveValue.TrimEnd('\'), $childFolderLeaf),
                ('\{0}\{1}' -f $rootPathNoDriveValue.TrimStart('\').TrimEnd('\'), $childFolderLeaf)
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
        } catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail (
                "Could not build child folder probe paths for root '{0}' and child '{1}': {2}" -f
                [string](Get-ObjectPropertyValue -InputObject $RootInfo -PropertyNames @('RootPathNoDrive')),
                $childFolderLeaf,
                $_.Exception.Message
            )
            return $false
        }

        foreach ($candidatePath in $candidatePaths) {
            $folderResult = @(Get-CMFolder -FolderPath $candidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
            if ($folderResult) {
                return $true
            }

            if ($getCmFolderSupportsPath) {
                $folderResult = @(Get-CMFolder -Path $candidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
                if ($folderResult) {
                    return $true
                }
            }
        }

        return $false
    }

    $cacheResolvedRoot = {
        param(
            [Parameter(Mandatory = $true)]
            $RootInfo
        )

        $RootInfo.DiscoveryFingerprint = [string]$discoveryFingerprint
        $script:ResolvedApplicationDeploymentRoot = $RootInfo
        Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Resolved application deployment root' -Detail (
            "{0} (source: {1})" -f [string]$RootInfo.RootPathNoDrive, [string]$RootInfo.Source
        )
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail (
            "Resolved Application Deployment root via {0}: {1}" -f [string]$RootInfo.Source, [string]$RootInfo.RootPathNoDrive
        )
        return $RootInfo
    }

    if (-not [string]::IsNullOrWhiteSpace($normalizedOverridePath)) {
        $overrideSegments = @($normalizedOverridePath -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($overrideSegments.Count -lt 2) {
            Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail (
                "ApplicationDeploymentRootPath '{0}' is invalid. Expected a path like 'DeviceCollections\\Application Deployment Devices'." -f $script:ApplicationDeploymentRootOverride
            )
        } else {
            $overrideDeviceRootName = [string]$overrideSegments[0]
            $overrideDeploymentRootPath = [string]::Join('\\', @($overrideSegments[1..($overrideSegments.Count - 1)]))
            $overrideRootInfo = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName $overrideDeviceRootName -DeploymentRootPath $overrideDeploymentRootPath -Source 'ExplicitOverride' -Score 10000 -TargetFolder $TargetFolder -OverridePath $normalizedOverridePath
            if ($overrideRootInfo) {
                $overrideRootInfo.FolderObject = & $resolveRootFolderObject $overrideRootInfo
                if (-not $overrideRootInfo.FolderObject) {
                    Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail (
                        "ApplicationDeploymentRootPath '{0}' did not resolve to an existing folder. The script will still use it as the root path override." -f $script:ApplicationDeploymentRootOverride
                    )
                }
                return & $cacheResolvedRoot $overrideRootInfo
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetFolder)) {
        try {
            $targetFolderRootsByPath = @{}
            $existingTargetFolders = @(Get-CMFolder -Name $TargetFolder -ErrorAction SilentlyContinue)
            foreach ($existingTargetFolder in $existingTargetFolders) {
                if (-not $existingTargetFolder) {
                    continue
                }

                $pathCandidates = @(
                    [string](Get-ObjectPropertyValue -InputObject $existingTargetFolder -PropertyNames @('FolderPath')),
                    [string](Get-ObjectPropertyValue -InputObject $existingTargetFolder -PropertyNames @('Path')),
                    [string](Get-ObjectPropertyValue -InputObject $existingTargetFolder -PropertyNames @('ContainerNodePath'))
                ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

                foreach ($pathCandidate in $pathCandidates) {
                    $normalizedPathCandidate = Get-NormalizedCmFolderPath -Path $pathCandidate
                    if ([string]::IsNullOrWhiteSpace($normalizedPathCandidate)) {
                        continue
                    }

                    $segments = @($normalizedPathCandidate -split '\\' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                    if ($segments.Count -lt 3) {
                        continue
                    }

                    if ($segments[-1].ToLowerInvariant() -ne $TargetFolder.Trim().ToLowerInvariant()) {
                        continue
                    }

                    $deploymentRootPath = [string]::Join('\\', @($segments[1..($segments.Count - 2)]))
                    if ([string]::IsNullOrWhiteSpace($deploymentRootPath)) {
                        continue
                    }

                    $rootInfo = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName ([string]$segments[0]) -DeploymentRootPath $deploymentRootPath -Source 'ExistingTargetFolder' -Score 5000 -TargetFolder $TargetFolder -FolderObject $existingTargetFolder -OverridePath $normalizedOverridePath
                    if (-not $rootInfo) {
                        continue
                    }

                    $targetFolderRootsByPath[$rootInfo.RootPathNoDrive.ToLowerInvariant()] = $rootInfo
                }
            }

            if ($targetFolderRootsByPath.Count -eq 1) {
                return & $cacheResolvedRoot @($targetFolderRootsByPath.Values)[0]
            }

            if ($targetFolderRootsByPath.Count -gt 1) {
                $ambiguousRoots = ((Convert-ToSafeArray -InputObject $targetFolderRootsByPath.Values) | ForEach-Object { $_.RootPathNoDrive }) -join ', '
                Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail (
                    "Target folder '{0}' exists under multiple possible roots: {1}. Auto-discovery will continue with provider-based scoring. Use -ApplicationDeploymentRootPath to force one." -f
                    $TargetFolder,
                    $ambiguousRoots
                )

                if ($script:StrictRootDiscoveryEnabled) {
                    throw ("StrictApplicationDeploymentRootDiscovery is enabled and target-folder inference is ambiguous. Candidates: {0}" -f $ambiguousRoots)
                }
            }
        } catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail (
                "Target-folder-based root inference failed for '{0}': {1}" -f $TargetFolder, $_.Exception.Message
            )
        }
    }

    $providerCandidatesByPath = @{}
    $providerDiscoveryError = ''
    try {
        $siteNamespace = 'root\SMS\site_{0}' -f $SiteCode
        $containerNodes = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_ObjectContainerNode')
        $topLevelNodes = @($containerNodes | Where-Object {
                $parentNodeId = [string](Get-ObjectPropertyValue -InputObject $_ -PropertyNames @('ParentContainerNodeId', 'ParentContainerNodeID'))
                [string]::IsNullOrWhiteSpace($parentNodeId) -or $parentNodeId -eq '0'
            })

        foreach ($topLevelNode in $topLevelNodes) {
            if (-not $topLevelNode) {
                continue
            }

            $nodeName = [string](Get-ObjectPropertyValue -InputObject $topLevelNode -PropertyNames @('Name'))
            if ([string]::IsNullOrWhiteSpace($nodeName)) {
                continue
            }

            $nodeTypeName = [string](Get-ObjectPropertyValue -InputObject $topLevelNode -PropertyNames @('ObjectTypeName'))
            $containerNodeId = [string](Get-ObjectPropertyValue -InputObject $topLevelNode -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
            $isEmptyValue = Get-ObjectPropertyValue -InputObject $topLevelNode -PropertyNames @('IsEmpty')

            # Deterministic fast-path for environments that expose the root as
            # a top-level SMS_Collection_Device node named "Application Deployment Devices".
            if ($nodeTypeName -match 'Collection_Device' -and $nodeName.Trim().ToLowerInvariant() -eq 'application deployment devices') {
                $directRoot = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName 'DeviceCollections' -DeploymentRootPath $nodeName -Source 'ProviderDiscovery-DirectDeviceCollections' -Score 9999 -TargetFolder $TargetFolder -ContainerNodeId $containerNodeId -OverridePath $normalizedOverridePath
                if ($directRoot) {
                    $directRoot.FolderObject = & $resolveRootFolderObject $directRoot
                    return & $cacheResolvedRoot $directRoot
                }
            }

            # Prefer root-name candidates that match provider object type. Device
            # collection folders commonly surface as SMS_Collection_Device.
            $deviceRootCandidates = @($knownDeviceRootNames)
            if ($nodeTypeName -match 'Collection_Device') {
                $deviceRootCandidates = @('DeviceCollections', 'DeviceCollection')
            }

            foreach ($deviceRootName in $deviceRootCandidates) {
                $candidateRootInfo = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName $deviceRootName -DeploymentRootPath $nodeName -Source 'ProviderDiscovery' -TargetFolder $TargetFolder -ContainerNodeId $containerNodeId -OverridePath $normalizedOverridePath
                if (-not $candidateRootInfo) {
                    continue
                }

                $candidateRootInfo.FolderObject = & $resolveRootFolderObject $candidateRootInfo

                $candidateScore = 100
                $candidateRootPathKey = ([string]$candidateRootInfo.RootPathNoDrive).ToLowerInvariant()
                if ($knownRootLookup.ContainsKey($candidateRootPathKey)) {
                    $candidateScore += 50
                }

                if ($candidateRootInfo.FolderObject) {
                    $candidateScore += 40
                }

                if ($nodeTypeName -match 'Collection_Device') {
                    if ($deviceRootName -eq 'DeviceCollections') {
                        $candidateScore += 120
                    } elseif ($deviceRootName -eq 'DeviceCollection') {
                        $candidateScore -= 30
                    }
                }

                $nodeNameLower = $nodeName.ToLowerInvariant()
                if ($nodeNameLower -match 'application') {
                    $candidateScore += 20
                }
                if ($nodeNameLower -match 'deployment') {
                    $candidateScore += 20
                }
                if ($nodeNameLower -match 'device') {
                    $candidateScore += 5
                }

                try {
                    if ($null -ne $isEmptyValue -and [int]$isEmptyValue -eq 0) {
                        $candidateScore += 5
                    }
                } catch {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail (
                        "Could not evaluate IsEmpty for provider node '{0}': {1}" -f $nodeName, $_.Exception.Message
                    )
                }

                $targetFolderLeaf = [string](@($TargetFolder) | Select-Object -First 1)
                if (-not [string]::IsNullOrWhiteSpace($targetFolderLeaf) -and (& $testChildFolderExists -RootInfo $candidateRootInfo -ChildFolderName $targetFolderLeaf)) {
                    $candidateScore += 200
                }

                $candidateRootInfo.Score = $candidateScore

                if (-not $providerCandidatesByPath.ContainsKey($candidateRootPathKey) -or [int]$providerCandidatesByPath[$candidateRootPathKey].Score -lt $candidateScore) {
                    $providerCandidatesByPath[$candidateRootPathKey] = $candidateRootInfo
                }
            }
        }
    } catch {
        $providerDiscoveryError = [string]$_.Exception.Message
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail (
            "Provider-based Application Deployment root discovery failed: {0}" -f $providerDiscoveryError
        )
    }

    if ($providerCandidatesByPath.Count -gt 0) {
        $rankedProviderCandidates = @($providerCandidatesByPath.Values | Sort-Object -Property @{ Expression = { [int]$_.Score }; Descending = $true }, @{ Expression = { [string]$_.RootPathNoDrive }; Descending = $false })
        $bestScore = [int]$rankedProviderCandidates[0].Score
        $bestCandidates = @($rankedProviderCandidates | Where-Object { [int]$_.Score -eq $bestScore })

        if ($bestCandidates.Count -eq 1) {
            return & $cacheResolvedRoot $bestCandidates[0]
        }

        Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail (
            "Multiple Application Deployment roots scored equally in provider discovery: {0}. Falling back to known layouts unless -ApplicationDeploymentRootPath is specified." -f
            (($bestCandidates | ForEach-Object { $_.RootPathNoDrive }) -join ', ')
        )

        if ($script:StrictRootDiscoveryEnabled) {
            throw ("StrictApplicationDeploymentRootDiscovery is enabled and provider discovery is ambiguous. Candidates: {0}" -f (($bestCandidates | ForEach-Object { $_.RootPathNoDrive }) -join ', '))
        }

        $knownBestCandidate = @($bestCandidates | Where-Object { $knownRootLookup.ContainsKey(([string]$_.RootPathNoDrive).ToLowerInvariant()) } | Select-Object -First 1)[0]
        if ($knownBestCandidate) {
            return & $cacheResolvedRoot $knownBestCandidate
        }
    }

    foreach ($rootDefinition in $rootDefinitions) {
        $fallbackRootInfo = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName ([string]$rootDefinition.DeviceRootName) -DeploymentRootPath ([string]$rootDefinition.DeploymentRootName) -Source 'FallbackKnownLayout' -TargetFolder $TargetFolder -OverridePath $normalizedOverridePath
        if (-not $fallbackRootInfo) {
            continue
        }

        $fallbackRootInfo.FolderObject = & $resolveRootFolderObject $fallbackRootInfo
        if ($fallbackRootInfo.FolderObject) {
            Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Fallback root selected' -Detail (
                "Using known layout fallback '{0}' because deterministic provider resolution did not produce a unique candidate. Provider error: {1}" -f
                [string]$fallbackRootInfo.RootPathNoDrive,
                ([string]$providerDiscoveryError)
            )
            if ($script:StrictRootDiscoveryEnabled) {
                throw ("StrictApplicationDeploymentRootDiscovery is enabled and fallback root '{0}' would be required." -f [string]$fallbackRootInfo.RootPathNoDrive)
            }
            return & $cacheResolvedRoot $fallbackRootInfo
        }
    }

    $fallback = @($rootDefinitions | Select-Object -First 1)[0]
    $fallbackRootInfo = Get-ApplicationDeploymentRootInfo -SiteCode $SiteCode -DeviceRootName ([string]$fallback.DeviceRootName) -DeploymentRootPath ([string]$fallback.DeploymentRootName) -Source 'FallbackKnownLayout' -TargetFolder $TargetFolder -OverridePath $normalizedOverridePath
    Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail (
        "Could not auto-discover an existing Application Deployment root. Defaulting to '{0}'. Use -ApplicationDeploymentRootPath if this environment uses a different root." -f [string]$fallbackRootInfo.RootPathNoDrive
    )
    Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Fallback root selected' -Detail (
        "Default fallback used because no known layout root was discoverable. Provider error: {0}" -f ([string]$providerDiscoveryError)
    )
    if ($script:StrictRootDiscoveryEnabled) {
        throw ("StrictApplicationDeploymentRootDiscovery is enabled and no deterministic Application Deployment root was discoverable.")
    }
    return & $cacheResolvedRoot $fallbackRootInfo
}

function Test-ApplicationDeploymentRootPrerequisites {
    <#
    .SYNOPSIS
        Performs root-resolution preflight checks and logs environment shape.

    .DESCRIPTION
        Captures cmdlet capability flags and validates that provider/root
        discovery can produce a usable application deployment root.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = ''
    )

    $getCmFolderSupportsPath = Test-CmFolderPathParameterSupport
    $getCmFolderSupportsRecurse = Test-CmFolderRecurseParameterSupport
    $removeCmFolderSupportsPath = Test-RemoveCmFolderPathParameterSupport

    Write-LogEvent -Level 'INFO' -Scope 'Preflight' -Action 'CMFolder capabilities' -Detail (
        "Get-CMFolder: Path={0}, Recurse={1}; Remove-CMFolder: Path={2}" -f [int]$getCmFolderSupportsPath, [int]$getCmFolderSupportsRecurse, [int]$removeCmFolderSupportsPath
    )

    try {
        $siteNamespace = 'root\SMS\site_{0}' -f $SiteCode
        $sampleNode = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_ObjectContainerNode' | Select-Object -First 1)
        if ($sampleNode.Count -gt 0) {
            Write-LogEvent -Level 'INFO' -Scope 'Preflight' -Action 'Provider connectivity' -Detail ("SMS_ObjectContainerNode query succeeded for {0}." -f $siteNamespace)
        } else {
            Write-LogEvent -Level 'WARN' -Scope 'Preflight' -Action 'Provider connectivity' -Detail ("SMS_ObjectContainerNode query returned no rows for {0}." -f $siteNamespace)
        }
    } catch {
        Write-LogEvent -Level 'WARN' -Scope 'Preflight' -Action 'Provider connectivity failed' -Detail $_.Exception.Message
    }

    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode -TargetFolder $TargetFolder
    if (-not $rootInfo -or [string]::IsNullOrWhiteSpace([string]$rootInfo.RootPathNoDrive)) {
        throw 'Application deployment root preflight failed: no root path was resolved.'
    }

    return $rootInfo
}

<#
.SYNOPSIS
    Builds the SCCM folder path for master collection placement.

.DESCRIPTION
    Combines SiteCode and TargetFolder into the resolved Application Deployment
    root path for the current SCCM environment.
#>
function Get-TargetFolderPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode -TargetFolder $TargetFolder
    $basePath = [string]$rootInfo.RootPath
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
function Set-CollectionFolder {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal folder helper. Mutating calls are gated by the script entry point and DryRun wrapper.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $targetFolderLeaf = ($TargetFolder -as [string]).Trim()
    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode -TargetFolder $TargetFolder
    $fullFolderPath = Join-Path -Path ([string]$rootInfo.RootPath) -ChildPath $targetFolderLeaf
    $siteDeviceCollectionPath = [string]$rootInfo.DeviceRootPath
    $siteBaseFolderPath = [string]$rootInfo.RootPath

    $normalizedCandidates = @()
    $normalizedCandidates += $fullFolderPath
    $normalizedCandidates += $fullFolderPath -replace '^[^:]+:\\', ''
    $normalizedCandidates += $fullFolderPath -replace '^[^:]+:', ''
    $normalizedCandidates += ('{0}\{1}' -f $rootInfo.RootPathNoDrive, $targetFolderLeaf)
    $normalizedCandidates += ('\{0}\{1}' -f $rootInfo.RootPathNoDrive, $targetFolderLeaf)
    $normalizedCandidates = @($normalizedCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    $baseFolderCandidates = @(
        $siteBaseFolderPath,
        [string]$rootInfo.RootPathNoDrive,
        [string]$rootInfo.RootPathWithSlash
    )

    try {
        $getCmFolderSupportsPath = Test-CmFolderPathParameterSupport
        $getCmFolderSupportsRecurse = Test-CmFolderRecurseParameterSupport
        $folder = $null
        foreach ($candidate in $normalizedCandidates) {
            if ($folder) { break }

            $queries = @(
                { Get-CMFolder -FolderPath $candidate -ErrorAction SilentlyContinue },
                { Get-CMFolder -Name $TargetFolder -ErrorAction SilentlyContinue | Where-Object { $_.FolderPath -eq $candidate } }
            )
            if ($getCmFolderSupportsPath) {
                $queries += { Get-CMFolder -Path $candidate -ErrorAction SilentlyContinue }
            }
            if ($getCmFolderSupportsRecurse) {
                $queries += { Get-CMFolder -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FolderPath -eq $candidate } }
            }

            foreach ($q in $queries) {
                try {
                    $result = & $q
                    if ($result) {
                        $folder = $result
                        break
                    }
                } catch {
                    Write-Verbose 'Failed to resolve collection folder via one provider query attempt.'
                }
            }
        }

        if (-not $folder) {
            if ($DryRun) {
                Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("[DryRun] Would create folder: {0}" -f $fullFolderPath)
                return $fullFolderPath
            } else {
                $resolveFolderByPath = {
                    param(
                        [Parameter(Mandatory = $true)]
                        [string]$CandidatePath,

                        [Parameter(Mandatory = $false)]
                        [string]$NameHint
                    )

                    $folderResult = @(Get-CMFolder -FolderPath $CandidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
                    if ($folderResult) {
                        return $folderResult
                    }

                    if ($getCmFolderSupportsPath) {
                        $folderResult = @(Get-CMFolder -Path $CandidatePath -ErrorAction SilentlyContinue) | Select-Object -First 1
                        if ($folderResult) {
                            return $folderResult
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($NameHint)) {
                        $folderResult = @(Get-CMFolder -Name $NameHint -ErrorAction SilentlyContinue | Where-Object { $_.FolderPath -eq $CandidatePath }) | Select-Object -First 1
                        if ($folderResult) {
                            return $folderResult
                        }
                    }

                    return $null
                }

                $baseFolder = $null
                foreach ($baseCandidate in $baseFolderCandidates) {
                    $baseFolder = & $resolveFolderByPath $baseCandidate ([string]$rootInfo.DeploymentRootName)
                    if ($baseFolder) {
                        break
                    }
                }

                if (-not $baseFolder) {
                    $baseCreateErrors = New-Object System.Collections.Generic.List[string]
                    $baseCreateAttempts = @(
                        { New-CMFolder -Name ([string]$rootInfo.DeploymentRootName) -ParentFolderPath $siteDeviceCollectionPath -ErrorAction Stop | Out-Null },
                        { New-CMFolder -Name ([string]$rootInfo.DeploymentRootName) -ParentFolderPath ([string]$rootInfo.DeviceRootNoDrive) -ErrorAction Stop | Out-Null },
                        { New-Item -Path $siteDeviceCollectionPath -Name ([string]$rootInfo.DeploymentRootName) -ItemType Directory -ErrorAction Stop | Out-Null },
                        { New-Item -Path ([string]$rootInfo.DeviceRootNoDrive) -Name ([string]$rootInfo.DeploymentRootName) -ItemType Directory -ErrorAction Stop | Out-Null }
                    )

                    foreach ($baseCreateAttempt in $baseCreateAttempts) {
                        try {
                            & $baseCreateAttempt
                            break
                        } catch {
                            $baseErr = [string]$_.Exception.Message
                            if (-not [string]::IsNullOrWhiteSpace($baseErr)) {
                                [void]$baseCreateErrors.Add($baseErr)
                            }
                            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Base folder create attempt failed for '{0}': {1}" -f $siteBaseFolderPath, $baseErr)
                        }
                    }

                    foreach ($baseCandidate in $baseFolderCandidates) {
                        $baseFolder = & $resolveFolderByPath $baseCandidate ([string]$rootInfo.DeploymentRootName)
                        if ($baseFolder) {
                            break
                        }
                    }
                }

                $resolvedBaseFolderPath = $siteBaseFolderPath
                if ($baseFolder -and -not [string]::IsNullOrWhiteSpace(($baseFolder.FolderPath -as [string]))) {
                    $resolvedBaseFolderPath = [string]$baseFolder.FolderPath
                }

                $createAttemptErrors = New-Object System.Collections.Generic.List[string]
                $createAttempts = @(
                    { New-CMFolder -Name $targetFolderLeaf -ParentFolderPath $resolvedBaseFolderPath -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $targetFolderLeaf -ParentFolderPath $siteBaseFolderPath -ErrorAction Stop | Out-Null },
                    { New-CMFolder -Name $targetFolderLeaf -ParentFolderPath ([string]$rootInfo.RootPathNoDrive) -ErrorAction Stop | Out-Null }
                )

                foreach ($attempt in $createAttempts) {
                    try {
                        & $attempt
                        $createdFolder = $null
                        foreach ($candidate in $normalizedCandidates) {
                            $createdFolder = & $resolveFolderByPath $candidate $targetFolderLeaf
                            if ($createdFolder) {
                                break
                            }
                        }

                        if ($createdFolder -and -not [string]::IsNullOrWhiteSpace(($createdFolder.FolderPath -as [string]))) {
                            Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Created folder: {0}" -f $createdFolder.FolderPath)
                            return ([string]$createdFolder.FolderPath)
                        }

                        Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Created folder: {0}" -f $fullFolderPath)
                        return $fullFolderPath
                    } catch {
                        $msg = [string]$_.Exception.Message
                        if ([string]::IsNullOrWhiteSpace($msg)) {
                            $msg = '[No exception message available]'
                        }
                        [void]$createAttemptErrors.Add($msg)
                        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("New-CMFolder attempt failed for '{0}': {1}" -f $fullFolderPath, $msg)
                    }
                }

                $providerAttemptErrors = New-Object System.Collections.Generic.List[string]
                $providerCreateAttempts = @(
                    { New-Item -Path $resolvedBaseFolderPath -Name $targetFolderLeaf -ItemType Directory -ErrorAction Stop | Out-Null },
                    { New-Item -Path $siteBaseFolderPath -Name $targetFolderLeaf -ItemType Directory -ErrorAction Stop | Out-Null },
                    { New-Item -Path ([string]$rootInfo.RootPathWithSlash) -Name $targetFolderLeaf -ItemType Directory -ErrorAction Stop | Out-Null }
                )

                foreach ($attempt in $providerCreateAttempts) {
                    try {
                        & $attempt
                        Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Created folder via provider path: {0}" -f $fullFolderPath)
                        return $fullFolderPath
                    } catch {
                        $msg = [string]$_.Exception.Message
                        if ([string]::IsNullOrWhiteSpace($msg)) {
                            $msg = '[No exception message available]'
                        }
                        [void]$providerAttemptErrors.Add($msg)
                        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Provider New-Item attempt failed for '{0}': {1}" -f $fullFolderPath, $msg)
                    }
                }

                $distinctCreateErrors = @($createAttemptErrors | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
                $distinctProviderErrors = @($providerAttemptErrors | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
                $errorDetailParts = New-Object System.Collections.Generic.List[string]
                if ($distinctCreateErrors.Count -gt 0) {
                    [void]$errorDetailParts.Add(("New-CMFolder errors: {0}" -f ([string]::Join(' | ', $distinctCreateErrors))))
                }
                if ($distinctProviderErrors.Count -gt 0) {
                    [void]$errorDetailParts.Add(("Provider New-Item errors: {0}" -f ([string]::Join(' | ', $distinctProviderErrors))))
                }

                $errorDetailText = ''
                if ($errorDetailParts.Count -gt 0) {
                    $errorDetailText = [string]::Join(' || ', @($errorDetailParts))
                }

                Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("Could not create folder '{0}': no supported parameters succeeded. Ensure parent folder '{1}' exists. {2}" -f $fullFolderPath, ([string]$rootInfo.RootPathNoDrive), $errorDetailText)
                return $fullFolderPath
            }
        } else {
            $resolvedPath = $folder.FolderPath
            if (-not $resolvedPath) {
                $resolvedPath = $fullFolderPath
            }
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Found existing folder: {0}" -f $resolvedPath)
            return $resolvedPath
        }
    } catch {
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

    if (-not $Collection -or [string]::IsNullOrWhiteSpace($FolderPath)) {
        return $false
    }

    $collectionId = [string](Get-ObjectPropertyValue -InputObject $Collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $collectionName = [string](Get-ObjectPropertyValue -InputObject $Collection -PropertyNames @('Name', 'CollectionName'))

    $folderPathCandidates = @(
        $FolderPath,
        ($FolderPath -replace '^[^:]+:\\', ''),
        ($FolderPath -replace '^[^:]+:', ''),
        ('\' + ($FolderPath -replace '^[^:]+:\\', ''))
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique

    $attempts = @()
    foreach ($candidatePath in $folderPathCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
            $attempts += { Move-CMObject -ObjectId $collectionId -FolderPath $candidatePath -ErrorAction Stop }
            $attempts += { Move-CMObject -ObjectId $collectionId -InputObject $Collection -FolderPath $candidatePath -ErrorAction Stop }
        }

        $attempts += { Move-CMObject -InputObject $Collection -FolderPath $candidatePath -ErrorAction Stop }
        $attempts += { Move-CMObject -InputObject $Collection -Path $candidatePath -ErrorAction Stop }
        $attempts += { Move-CMObject -InputObject $Collection -DestinationPath $candidatePath -ErrorAction Stop }
        $attempts += { Move-CMObject -InputObject $Collection -Destination $candidatePath -ErrorAction Stop }
        $attempts += { Move-CMObject -InputObject $Collection -TargetPath $candidatePath -ErrorAction Stop }
    }

    if (Get-CachedCommand -Name 'Move-CMDeviceCollection') {
        foreach ($candidatePath in $folderPathCandidates) {
            if (-not [string]::IsNullOrWhiteSpace($collectionId)) {
                $attempts += { Move-CMDeviceCollection -CollectionId $collectionId -FolderPath $candidatePath -ErrorAction Stop }
                $attempts += { Move-CMDeviceCollection -CollectionId $collectionId -Path $candidatePath -ErrorAction Stop }
                $attempts += { Move-CMDeviceCollection -CollectionId $collectionId -DestinationPath $candidatePath -ErrorAction Stop }
                $attempts += { Move-CMDeviceCollection -CollectionId $collectionId -Destination $candidatePath -ErrorAction Stop }
                $attempts += { Move-CMDeviceCollection -CollectionId $collectionId -TargetPath $candidatePath -ErrorAction Stop }
            }

            if (-not [string]::IsNullOrWhiteSpace($collectionName)) {
                $attempts += { Move-CMDeviceCollection -CollectionName $collectionName -FolderPath $candidatePath -ErrorAction Stop }
            }
        }
    }

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

    $normalizedInput = ($SoftwareName -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedInput)) {
        return @()
    }

    $searchTerms = New-Object System.Collections.Generic.List[string]
    $searchTerms.Add($normalizedInput)

    # Fallback for names entered with a trailing version token, such as
    # "Oracle Java 8" when collections are named "Oracle Java - Install (...)".
    $withoutTrailingVersion = ($normalizedInput -replace '(?i)\s+v?\d+(?:\.\d+){0,3}\s*$', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($withoutTrailingVersion) -and ($withoutTrailingVersion -ne $normalizedInput)) {
        $searchTerms.Add($withoutTrailingVersion)
    }

    $collectionsById = @{}
    $collectionsByName = @{}

    foreach ($term in ($searchTerms | Sort-Object -Unique)) {
        $namePattern = ("*{0}*" -f $term)

        try {
            $collectionMatches = @(Get-CMDeviceCollection -Name $namePattern -ErrorAction Stop)
            Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("Found {0} collections matching pattern '{1}'" -f $collectionMatches.Count, $namePattern)

            foreach ($candidate in $collectionMatches) {
                $identity = Get-CollectionIdentity -InputObject $candidate
                if ($identity.IsValid -and -not [string]::IsNullOrWhiteSpace($identity.Id)) {
                    $collectionsById[$identity.Id.ToLowerInvariant()] = $candidate
                } elseif ($identity.IsValid -and -not [string]::IsNullOrWhiteSpace($identity.Name)) {
                    $collectionsByName[$identity.Name.Trim().ToLowerInvariant()] = $candidate
                }
            }
        } catch {
            if ($_.Exception.Message -like '*Not found*') {
                Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail ("No collections found matching pattern '{0}'" -f $namePattern)
                continue
            }
            throw
        }
    }

    $results = @()
    if ($collectionsById.Count -gt 0) {
        $results += @($collectionsById.Values)
    }
    if ($collectionsByName.Count -gt 0) {
        $results += @($collectionsByName.Values)
    }

    if ($results.Count -eq 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No collections found matching '{0}'." -f $SoftwareName)
        return @()
    }

    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Found {0} matching collections after fallback discovery." -f $results.Count)
    return @($results)
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

function Protect-LegacyCollectionFromDeletion {
    <#
    .SYNOPSIS
        Marks a legacy collection as protected from delete cleanup.

    .DESCRIPTION
        Used when query membership rules could not be copied to a master
        collection. Protected collections are excluded from delete plans.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Collection,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    $identity = Get-CollectionIdentity -InputObject $Collection
    if (-not $identity.IsValid) {
        return
    }

    $id = [string]$identity.Id
    $name = [string]$identity.Name

    if (-not [string]::IsNullOrWhiteSpace($id)) {
        [void]$script:ProtectedLegacyCollectionIds.Add($id.ToLowerInvariant())
    }

    if (-not [string]::IsNullOrWhiteSpace($name)) {
        [void]$script:ProtectedLegacyCollectionNames.Add($name.Trim().ToLowerInvariant())
    }

    Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Protected from cleanup delete' -Detail ("'{0}' | Reason: {1}" -f $name, $Reason)
}

function Test-LegacyCollectionProtectedFromDeletion {
    <#
    .SYNOPSIS
        Checks whether a collection is currently protected from deletion.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Collection
    )

    $identity = Get-CollectionIdentity -InputObject $Collection
    if (-not $identity.IsValid) {
        return $false
    }

    $id = [string]$identity.Id
    $name = [string]$identity.Name

    if (-not [string]::IsNullOrWhiteSpace($id) -and $script:ProtectedLegacyCollectionIds.Contains($id.ToLowerInvariant())) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($name) -and $script:ProtectedLegacyCollectionNames.Contains($name.Trim().ToLowerInvariant())) {
        return $true
    }

    return $false
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
    } catch {
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
function Set-MasterCollectionDeployment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal deployment helper. Confirmation is coordinated by the top-level workflow.')]
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
    $appName = [string](Get-ObjectPropertyValue -InputObject $Application -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name'))
    $appDisplayName = Get-ApplicationDisplayName -App $Application

    # Check if deployment already exists
    $collectionDeployments = Get-CollectionDeployments -CollectionName $collectionName
    $existingDeployment = Find-ExistingApplicationDeployment -CollectionName $collectionName -Application $Application

    if ($existingDeployment -or $collectionDeployments.Count -gt 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appDisplayName, $collectionName)
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
            Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Deployed '{0}' as '{1}' to collection '{2}'" -f $appDisplayName, $DeploymentPurpose, $collectionName)
        } -Description "deploy '$appDisplayName' as $DeploymentPurpose to collection '$collectionName'"
    } catch {
        if ($_.Exception.Message -match 'already been deployed') {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appDisplayName, $collectionName)
        } else {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not deploy '{0}' as '{1}' to collection '{2}': {3}" -f $appDisplayName, $DeploymentPurpose, $collectionName, $_.Exception.Message)
        }
    }
}

function Get-CollectionQueryMembershipRules {
    <#
    .SYNOPSIS
        Returns query membership rules for a collection.

    .DESCRIPTION
        Uses compatible parameter fallbacks because SCCM cmdlet parameter sets
        differ between environments.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Collection
    )

    $queryRuleGetCmd = Get-CachedCommand -Name 'Get-CMDeviceCollectionQueryMembershipRule'
    if (-not $queryRuleGetCmd) {
        return @()
    }

    $identity = Get-CollectionIdentity -InputObject $Collection
    if (-not $identity.IsValid) {
        return @()
    }

    $attempts = @()
    $paramNames = @($queryRuleGetCmd.Parameters.Keys)

    if (($paramNames -contains 'CollectionId') -and -not [string]::IsNullOrWhiteSpace($identity.Id)) {
        $collectionId = [string]$identity.Id
        $attempts += { Get-CMDeviceCollectionQueryMembershipRule -CollectionId $collectionId -ErrorAction Stop }
    }

    if (($paramNames -contains 'CollectionName') -and -not [string]::IsNullOrWhiteSpace($identity.Name)) {
        $collectionName = [string]$identity.Name
        $attempts += { Get-CMDeviceCollectionQueryMembershipRule -CollectionName $collectionName -ErrorAction Stop }
    }

    if ($paramNames -contains 'InputObject') {
        $collectionObject = $Collection
        $attempts += { Get-CMDeviceCollectionQueryMembershipRule -InputObject $collectionObject -ErrorAction Stop }
    }

    if ($attempts.Count -eq 0) {
        return @()
    }

    $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Get collection query membership rules'
    if (-not $result.Success) {
        return @()
    }

    return Convert-ToSafeArray -InputObject $result.Result
}

function Add-CollectionQueryMembershipRuleIfMissing {
    <#
    .SYNOPSIS
        Adds a query membership rule to a target collection when missing.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TargetCollection,

        [Parameter(Mandatory = $true)]
        [string]$RuleName,

        [Parameter(Mandatory = $true)]
        [string]$QueryExpression
    )

    $normalizedQuery = ($QueryExpression -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedQuery)) {
        return $false
    }

    $targetIdentity = Get-CollectionIdentity -InputObject $TargetCollection
    if (-not $targetIdentity.IsValid) {
        return $false
    }

    $existingRules = Get-CollectionQueryMembershipRules -Collection $TargetCollection
    foreach ($existingRule in $existingRules) {
        if (-not $existingRule) { continue }

        $existingName = [string](Get-ObjectPropertyValue -InputObject $existingRule -PropertyNames @('RuleName', 'Name'))
        $existingQuery = [string](Get-ObjectPropertyValue -InputObject $existingRule -PropertyNames @('QueryExpression', 'Query'))

        if ((-not [string]::IsNullOrWhiteSpace($existingName) -and $existingName -eq $RuleName) -or
            (-not [string]::IsNullOrWhiteSpace($existingQuery) -and $existingQuery.Trim() -eq $normalizedQuery)) {
            return $true
        }
    }

    $addRuleCmd = Get-CachedCommand -Name 'Add-CMDeviceCollectionQueryMembershipRule'
    if (-not $addRuleCmd) {
        return $false
    }

    $paramNames = @($addRuleCmd.Parameters.Keys)
    $attempts = @()

    if (($paramNames -contains 'CollectionId') -and ($paramNames -contains 'RuleName') -and ($paramNames -contains 'QueryExpression') -and -not [string]::IsNullOrWhiteSpace($targetIdentity.Id)) {
        $targetCollectionId = [string]$targetIdentity.Id
        $targetRuleName = $RuleName
        $targetQueryExpression = $normalizedQuery
        $attempts += { Add-CMDeviceCollectionQueryMembershipRule -CollectionId $targetCollectionId -RuleName $targetRuleName -QueryExpression $targetQueryExpression -ErrorAction Stop | Out-Null }
    }

    if (($paramNames -contains 'CollectionName') -and ($paramNames -contains 'RuleName') -and ($paramNames -contains 'QueryExpression') -and -not [string]::IsNullOrWhiteSpace($targetIdentity.Name)) {
        $targetCollectionName = [string]$targetIdentity.Name
        $targetRuleName = $RuleName
        $targetQueryExpression = $normalizedQuery
        $attempts += { Add-CMDeviceCollectionQueryMembershipRule -CollectionName $targetCollectionName -RuleName $targetRuleName -QueryExpression $targetQueryExpression -ErrorAction Stop | Out-Null }
    }

    if (($paramNames -contains 'InputObject') -and ($paramNames -contains 'RuleName') -and ($paramNames -contains 'QueryExpression')) {
        $targetCollectionObject = $TargetCollection
        $targetRuleName = $RuleName
        $targetQueryExpression = $normalizedQuery
        $attempts += { Add-CMDeviceCollectionQueryMembershipRule -InputObject $targetCollectionObject -RuleName $targetRuleName -QueryExpression $targetQueryExpression -ErrorAction Stop | Out-Null }
    }

    if ($attempts.Count -eq 0) {
        return $false
    }

    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Would copy query rule' -Detail ("Target='{0}', Rule='{1}'" -f $targetIdentity.Name, $RuleName)
        return $true
    }

    $result = Invoke-CmCommandWithFallback -Attempts $attempts -ActionName 'Add collection query membership rule'
    return $result.Success
}

function Copy-QueryMembershipRulesToMaster {
    <#
    .SYNOPSIS
        Copies query membership rules from legacy collections to a master.

    .DESCRIPTION
        If query rules cannot be copied, marks the source collection as protected
        from cleanup deletion to prevent membership-loss regressions.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $LegacyCollections,

        [Parameter(Mandatory = $true)]
        $MasterCollection,

        [Parameter(Mandatory = $true)]
        [string]$MasterRole
    )

    if (-not $MasterCollection) {
        return
    }

    $masterIdentity = Get-CollectionIdentity -InputObject $MasterCollection
    if (-not $masterIdentity.IsValid) {
        return
    }

    $legacyList = Convert-ToSafeArray -InputObject $LegacyCollections
    if ($legacyList.Count -eq 0) {
        return
    }

    $getRuleCmd = Get-CachedCommand -Name 'Get-CMDeviceCollectionQueryMembershipRule'
    $addRuleCmd = Get-CachedCommand -Name 'Add-CMDeviceCollectionQueryMembershipRule'

    if (-not $getRuleCmd -or -not $addRuleCmd) {
        foreach ($legacy in $legacyList) {
            if (-not $legacy) { continue }
            Protect-LegacyCollectionFromDeletion -Collection $legacy -Reason 'Query-rule copy command unavailable in this SCCM environment.'
        }
        return
    }

    foreach ($legacy in $legacyList) {
        if (-not $legacy) { continue }

        $legacyIdentity = Get-CollectionIdentity -InputObject $legacy
        if (-not $legacyIdentity.IsValid) { continue }

        $queryRules = Get-CollectionQueryMembershipRules -Collection $legacy
        if (-not $queryRules -or $queryRules.Count -eq 0) {
            continue
        }

        $allCopied = $true
        foreach ($queryRule in $queryRules) {
            if (-not $queryRule) { continue }

            $sourceRuleName = [string](Get-ObjectPropertyValue -InputObject $queryRule -PropertyNames @('RuleName', 'Name'))
            $sourceQuery = [string](Get-ObjectPropertyValue -InputObject $queryRule -PropertyNames @('QueryExpression', 'Query'))

            if ([string]::IsNullOrWhiteSpace($sourceQuery)) {
                $allCopied = $false
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Query rule skipped' -Detail ("Source='{0}', Rule='{1}' has empty query expression." -f $legacyIdentity.Name, $sourceRuleName)
                continue
            }

            $effectiveRuleName = $sourceRuleName
            if ([string]::IsNullOrWhiteSpace($effectiveRuleName)) {
                $effectiveRuleName = ("MigratedQuery-{0}-{1}" -f $MasterRole, ([Guid]::NewGuid().ToString('N').Substring(0, 8)))
            }

            $copied = Add-CollectionQueryMembershipRuleIfMissing -TargetCollection $MasterCollection -RuleName $effectiveRuleName -QueryExpression $sourceQuery
            if ($copied) {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Query rule copied' -Detail ("Source='{0}', Target='{1}', Rule='{2}'" -f $legacyIdentity.Name, $masterIdentity.Name, $effectiveRuleName)
            } else {
                $allCopied = $false
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Query rule copy failed' -Detail ("Source='{0}', Target='{1}', Rule='{2}'" -f $legacyIdentity.Name, $masterIdentity.Name, $effectiveRuleName)
            }
        }

        if (-not $allCopied) {
            Protect-LegacyCollectionFromDeletion -Collection $legacy -Reason ("Could not fully copy query membership rules to master '{0}'." -f $masterIdentity.Name)
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
    Loads the external canonical-name inventory used by consolidation.

.DESCRIPTION
    Reads the repository-scoped mapping file so canonical names can be updated
    without editing the script. Prefers a private local inventory file, then a
    tracked generic template, and finally falls back to an embedded inventory
    when neither external file is available or valid.
#>
function Get-CanonicalMappingInventory {
    if ($script:CanonicalMappingInventoryCache) {
        return $script:CanonicalMappingInventoryCache
    }

    $fallbackInventory = @{
        CanonicalMappings = @{
            'Firefox'         = 'Mozilla Firefox'
            'Mozilla Firefox' = 'Mozilla Firefox'
            'Chrome'          = 'Google Chrome'
            'Google Chrome'   = 'Google Chrome'
            'Notepad'         = 'Notepad++'
            'Notepad Notepad' = 'Notepad++'
            'Notepad++'       = 'Notepad++'
        }
    }

    $privateInventoryPath = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $PSScriptRoot -ChildPath '..\..\data\SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1')
    )
    $templateInventoryPath = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $PSScriptRoot -ChildPath '..\..\data\SCCMSoftwareCollectionConsolidation.CanonicalMap.template.psd1')
    )
    $inventoryCandidates = @(
        [pscustomobject]@{ Path = $privateInventoryPath; Type = 'private local inventory' },
        [pscustomobject]@{ Path = $templateInventoryPath; Type = 'tracked template inventory' }
    )

    foreach ($inventoryCandidate in $inventoryCandidates) {
        if (-not (Test-Path -LiteralPath $inventoryCandidate.Path)) {
            continue
        }

        try {
            $inventory = Import-PowerShellDataFile -Path $inventoryCandidate.Path -ErrorAction Stop
            $mappingCount = 0
            if ($inventory -and $inventory.ContainsKey('CanonicalMappings') -and $inventory.CanonicalMappings) {
                $mappingCount = @($inventory.CanonicalMappings.Keys).Count
                Write-LogEvent -Level 'DEBUG' -Scope 'Collections' -Action 'Debug' -Detail (
                    "Loaded {0} from '{1}' with {2} mapping entries." -f $inventoryCandidate.Type, $inventoryCandidate.Path, $mappingCount
                )
                $script:CanonicalMappingInventoryCache = $inventory
                return $script:CanonicalMappingInventoryCache
            }

            throw 'CanonicalMappings key is missing or empty.'
        } catch {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Canonical inventory fallback' -Detail (
                "Could not load {0} from '{1}': {2}" -f $inventoryCandidate.Type, $inventoryCandidate.Path, $_.Exception.Message
            )
        }
    }

    Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Canonical inventory fallback' -Detail (
        "No valid private or template canonical inventory was available. Using embedded fallback mappings."
    )
    $script:CanonicalMappingInventoryCache = $fallbackInventory
    return $script:CanonicalMappingInventoryCache
}

<#
.SYNOPSIS
    Returns normalized lookup candidates for canonical software resolution.

.DESCRIPTION
    Strips common deployment-role suffixes such as Available and Required so
    canonical resolution does not need explicit inventory keys for each role
    variant.
#>
function Get-CanonicalLookupCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    $trimmedName = ($SoftwareName -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedName)) {
        return [pscustomobject]@{
            Candidates     = @()
            NormalizedName = ''
        }
    }

    $candidateList = New-Object System.Collections.Generic.List[string]
    $candidateList.Add($trimmedName)

    $withoutRoleVariant = ($trimmedName -replace '(?i)\s+(available|required)\s*$', '').Trim()
    if (-not [string]::IsNullOrWhiteSpace($withoutRoleVariant) -and $withoutRoleVariant -ne $trimmedName) {
        $candidateList.Add($withoutRoleVariant)
    }

    $uniqueCandidates = @($candidateList | Select-Object -Unique)
    $normalizedName = $trimmedName
    if (-not [string]::IsNullOrWhiteSpace($withoutRoleVariant)) {
        $normalizedName = $withoutRoleVariant
    }

    return [pscustomobject]@{
        Candidates     = $uniqueCandidates
        NormalizedName = $normalizedName
    }
}

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

    $inventory = Get-CanonicalMappingInventory
    $map = @{}
    if ($inventory -and $inventory.ContainsKey('CanonicalMappings') -and $inventory.CanonicalMappings) {
        $map = $inventory.CanonicalMappings
    }

    if ($map.Count -eq 0) {
        return $SoftwareName
    }

    $lookupCandidates = Get-CanonicalLookupCandidates -SoftwareName $SoftwareName
    if (-not $lookupCandidates.Candidates -or $lookupCandidates.Candidates.Count -eq 0) {
        return $SoftwareName
    }

    $normalizedInputs = @($lookupCandidates.Candidates | ForEach-Object { ($_ -as [string]).Trim().ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($normalizedInputs.Count -eq 0) {
        return $lookupCandidates.NormalizedName
    }

    # First: try exact (case-insensitive) match
    foreach ($key in $map.Keys) {
        $normalizedKey = $key.ToLower()
        foreach ($normalizedInput in $normalizedInputs) {
            if ($normalizedKey -eq $normalizedInput) {
                return $map[$key]
            }
        }
    }

    # Second: try partial match (e.g. "notepad" matches "notepad notepad")
    foreach ($key in $map.Keys) {
        $normalizedKey = $key.ToLower()
        foreach ($normalizedInput in $normalizedInputs) {
            if ($normalizedKey.Contains($normalizedInput)) {
                return $map[$key]
            }
        }
    }

    # Third: try reverse partial match (e.g. "notepad notepad" matches "notepad")
    foreach ($key in $map.Keys) {
        $normalizedKey = $key.ToLower()
        foreach ($normalizedInput in $normalizedInputs) {
            if ($normalizedInput.Contains($normalizedKey)) {
                return $map[$key]
            }
        }
    }

    return $lookupCandidates.NormalizedName
}

<#
.SYNOPSIS
    Creates a master device collection with fallback parameter sets.

.DESCRIPTION
    Wraps New-CMDeviceCollection with environment-compatible attempts and returns
    the created object when successful.
#>
function New-MasterDeviceCollection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal collection creation helper. Confirmation is coordinated by the top-level workflow.')]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Comment,
        [Parameter(Mandatory = $true)][string]$LimitingCollectionName,
        [Parameter(Mandatory = $true)][string]$FolderPath
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or
        [string]::IsNullOrWhiteSpace($Comment) -or
        [string]::IsNullOrWhiteSpace($LimitingCollectionName) -or
        [string]::IsNullOrWhiteSpace($FolderPath)) {
        return $null
    }

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
function Set-MasterCollections {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal orchestration helper. Confirmation is controlled by the top-level script and DryRun behavior.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CanonicalName,

        [Parameter(Mandatory = $true)]
        [string]$TargetFolder
    )

    $fullFolderPath = Set-CollectionFolder -SiteCode $SiteCode -TargetFolder $TargetFolder

    $installAvailName = "{0} - Install (Available)" -f $CanonicalName
    $installReqName = "{0} - Install (Required)" -f $CanonicalName
    $uninstallName = "{0} - Uninstall" -f $CanonicalName

    # Use targeted per-name queries here instead of going through the full-scan
    # cache. The all-collections fetch takes 2+ minutes in large environments and
    # is only needed for dependency resolution, which happens later in the run.
    $installAvailCol = @(Get-CMDeviceCollection -Name $installAvailName -ErrorAction SilentlyContinue) | Select-Object -First 1
    $installReqCol = @(Get-CMDeviceCollection -Name $installReqName   -ErrorAction SilentlyContinue) | Select-Object -First 1
    $uninstallCol = @(Get-CMDeviceCollection -Name $uninstallName    -ErrorAction SilentlyContinue) | Select-Object -First 1

    if (-not $installAvailCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $installAvailName)
            $installAvailCol = [pscustomobject]@{ Name = $installAvailName; CollectionID = 0 }
        } else {
            $installAvailCol = New-MasterDeviceCollection -Name $installAvailName -LimitingCollectionName "All Systems" -Comment ("Master available install collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($installAvailCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $installAvailName)
            } else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not create master collection: {0}" -f $installAvailName)
            }
        }
    }

    if (-not $installReqCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $installReqName)
            $installReqCol = [pscustomobject]@{ Name = $installReqName; CollectionID = 0 }
        } else {
            $installReqCol = New-MasterDeviceCollection -Name $installReqName -LimitingCollectionName "All Systems" -Comment ("Master required install collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($installReqCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $installReqName)
            } else {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not create master collection: {0}" -f $installReqName)
            }
        }
    }

    if (-not $uninstallCol) {
        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would create collection: {0}" -f $uninstallName)
            $uninstallCol = [pscustomobject]@{ Name = $uninstallName; CollectionID = 0 }
        } else {
            $uninstallCol = New-MasterDeviceCollection -Name $uninstallName -LimitingCollectionName "All Systems" -Comment ("Master uninstall collection for {0}" -f $CanonicalName) -FolderPath $fullFolderPath
            if ($uninstallCol) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Created collection: {0}" -f $uninstallName)
            } else {
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
            } else {
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
        return , $ids
    }

    try {
        $rules = Get-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionID -ErrorAction SilentlyContinue
        foreach ($rule in $rules) {
            if ($rule.ResourceID) { [void]$ids.Add($rule.ResourceID) }
        }
    } catch {
        Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not read direct membership rules for collection '{0}': {1}" -f ($Collection.Name -as [string]), $_.Exception.Message)
    }

    return , $ids
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
            } catch {
                # Relationship may already exist from concurrent operations; ignore duplicate errors.
                Write-Verbose ("Direct membership rule may already exist for resource [{0}] in collection [{1}]." -f $id, $Collection.CollectionID)
            }
        } -Description "add device ($id) to collection $($Collection.CollectionID)"
    }
}

# ------------------------------------------------------------
# GET MEMBERS FROM A SET OF COLLECTIONS
# ------------------------------------------------------------

<#
.SYNOPSIS
    Returns effective collection member ResourceIDs for a collection.

.DESCRIPTION
    Prefers evaluated collection membership (query/include/direct results) and
    falls back to direct membership rules when evaluated membership is not
    available in the current SCCM cmdlet set.
#>
function Get-CollectionEffectiveResourceIds {
    param(
        [Parameter(Mandatory = $true)]
        $Collection
    )

    $ids = New-Object System.Collections.Generic.HashSet[int]

    if (-not $Collection) {
        return , $ids
    }

    $collectionId = [string](Get-ObjectPropertyValue -InputObject $Collection -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
    $collectionName = [string](Get-ObjectPropertyValue -InputObject $Collection -PropertyNames @('Name', 'CollectionName'))

    $memberCmd = Get-CachedCommand -Name 'Get-CMCollectionMember'
    if ($memberCmd) {
        $memberCmdParamNames = @($memberCmd.Parameters.Keys)
        $memberAttempts = @()

        if (($memberCmdParamNames -contains 'CollectionId') -and -not [string]::IsNullOrWhiteSpace($collectionId)) {
            $memberAttempts += { Get-CMCollectionMember -CollectionId $collectionId -ErrorAction Stop }
        }
        if (($memberCmdParamNames -contains 'CollectionName') -and -not [string]::IsNullOrWhiteSpace($collectionName)) {
            $memberAttempts += { Get-CMCollectionMember -CollectionName $collectionName -ErrorAction Stop }
        }
        if (($memberCmdParamNames -contains 'InputObject')) {
            $memberAttempts += { Get-CMCollectionMember -InputObject $Collection -ErrorAction Stop }
        }

        if ($memberAttempts.Count -gt 0) {
            $memberResult = Invoke-CmCommandWithFallback -Attempts $memberAttempts -ActionName 'Get-CMCollectionMember'
            if ($memberResult.Success) {
                $members = Convert-ToSafeArray -InputObject $memberResult.Result
                foreach ($member in $members) {
                    if (-not $member) { continue }

                    $resourceId = Get-ObjectPropertyValue -InputObject $member -PropertyNames @('ResourceID', 'ResourceId', 'SMSID', 'SMSId', 'Id')
                    $resourceIdInt = 0
                    if ([int]::TryParse([string]$resourceId, [ref]$resourceIdInt) -and $resourceIdInt -gt 0) {
                        [void]$ids.Add($resourceIdInt)
                    }
                }

                if ($ids.Count -gt 0) {
                    return , $ids
                }
            }
        }
    }

    # Compatibility fallback for environments where evaluated membership query is
    # unavailable or empty.
    return Get-DirectMembershipResourceIds -Collection $Collection
}

<#
.SYNOPSIS
    Aggregates effective members from multiple collections.

.DESCRIPTION
    Collects evaluated member ResourceIDs (with direct-rule fallback) across
    source collections into a de-duplicated set used for master composition.
#>
function Get-DeviceMembersFromCollections {
    param(
        $Collections
    )

    $ids = New-Object System.Collections.Generic.HashSet[int]

    if (-not $Collections) {
        return , $ids
    }

    $collectionList = @($Collections)
    if ($collectionList.Count -eq 0) {
        return , $ids
    }

    foreach ($col in $collectionList) {
        if (-not $col) {
            continue
        }

        try {
            $sourceIds = Get-CollectionEffectiveResourceIds -Collection $col
            if (-not $sourceIds -or $sourceIds.Count -eq 0) {
                continue
            }

            foreach ($sourceId in $sourceIds) {
                if (-not $sourceId) { continue }
                [void]$ids.Add($sourceId)
            }
        } catch {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail ("Could not get members from collection '{0}': {1}" -f ($col.Name -as [string]), $_.Exception.Message)
        }
    }

    return , $ids
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
function Update-MasterCollections {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal orchestration helper. State changes remain gated by underlying DryRun-aware operations.')]
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
            Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Update-MasterCollections aborted: CanonicalName is missing."
            return
        }

        if (-not $Masters -or -not $Masters.InstallAvailable -or -not $Masters.InstallRequired -or -not $Masters.Uninstall) {
            Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Update-MasterCollections aborted: Master collection objects are missing or invalid."
            return
        }

        $populationStage = 'normalize inputs'
        $masterInstallAvailableName = "{0} - Install (Available)" -f $CanonicalName
        $masterInstallRequiredName = "{0} - Install (Required)" -f $CanonicalName
        $masterUninstallName = "{0} - Uninstall" -f $CanonicalName

        $masterInstallAvailable = $Masters.InstallAvailable
        $masterInstallRequired = $Masters.InstallRequired
        $masterUninstall = $Masters.Uninstall

        $all = Convert-ToSafeArray -InputObject $AllCollections
        if ($all.Count -eq 0) {
            Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Warning' -Detail "Update-MasterCollections: AllCollections is empty. No members to calculate."
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
        $appSelection = Get-MasterDeploymentApplicationSelection -CanonicalName $CanonicalName -RequestedSoftwareName $RequestedSoftwareName
        $appForMasterDeploy = $appSelection.App
        if ($appForMasterDeploy) {
            $appForMasterDeployDisplayName = Get-ApplicationDisplayName -App $appForMasterDeploy
            if ($appSelection.ExactCanonicalWasPreferred) {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Exact canonical fallback' -Detail (
                    "No version-confirmed latest app was found for '{0}'. Falling back to exact canonical app '{1}' for master deployments." -f $CanonicalName, $appForMasterDeployDisplayName
                )
            } elseif (-not $appSelection.IsVersionConfirmed) {
                Write-LogEvent -Level 'WARN' -Scope 'Collections' -Action 'Inferred deployment target' -Detail (
                    "No version-confirmed app was found for '{0}'. Using inferred latest app '{1}' for master deployments." -f $CanonicalName, $appForMasterDeployDisplayName
                )
            } else {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail (
                    "Using latest version-confirmed app '{0}' for master deployments targeting '{1}'." -f $appForMasterDeployDisplayName, $CanonicalName
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
                        $appDisplayName = Get-ApplicationDisplayName -App $app

                        if ($existingDeployment -or $collectionDeployments.Count -gt 0) {
                            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appDisplayName, $masterInstallAvailableNameResolved)
                        } else {
                            try {
                                Invoke-DryRunAction -Action {
                                    New-CMApplicationDeployment -CollectionName $masterInstallAvailableNameResolved -Name $app.LocalizedDisplayName -DeployAction Install -DeployPurpose Available -ErrorAction Stop | Out-Null
                                    Write-LogEvent -Level 'SUCCESS' -Scope 'Collections' -Action 'Success' -Detail ("Deployed '{0}' as 'Available' to collection '{1}'" -f $appDisplayName, $masterInstallAvailableNameResolved)
                                } -Description "deploy '$appDisplayName' as Available to collection '$masterInstallAvailableNameResolved'"
                            } catch {
                                if ($_.Exception.Message -match 'already been deployed') {
                                    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("Deployment already exists for '{0}' to collection '{1}'" -f $appDisplayName, $masterInstallAvailableNameResolved)
                                } else {
                                    throw
                                }
                            }
                        }
                    } else {
                        Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No deployable application found for '{0}'. Deployment to master Available collection skipped." -f $CanonicalName)
                    }
                } else {
                    $dryRunAppName = $CanonicalName
                    if ($appForMasterDeploy) {
                        $dryRunAppName = [string](Get-ApplicationDisplayName -App $appForMasterDeploy)
                    }
                    Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("[DryRun] Would deploy '{0}' as 'Available' to collection '{1}'" -f $dryRunAppName, $masterInstallAvailableNameResolved)
                }
            } else {
                Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail "Master 'Available' collection does not exist or has no name."
            }
        }

        $populationStage = 'calculate memberships'
        $populationStage = 'copy query rules to masters'
        Copy-QueryMembershipRulesToMaster -LegacyCollections $legacyInstallAvailableCollections -MasterCollection $masterInstallAvailable -MasterRole 'InstallAvailable'
        Copy-QueryMembershipRulesToMaster -LegacyCollections $legacyInstallRequiredCollections -MasterCollection $masterInstallRequired -MasterRole 'InstallRequired'
        Copy-QueryMembershipRulesToMaster -LegacyCollections $legacyUninstallCollections -MasterCollection $masterUninstall -MasterRole 'Uninstall'

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
                Set-MasterCollectionDeployment -Application $app -MasterCollection $masterInstallAvailable -DeploymentPurpose 'Available'
                Set-MasterCollectionDeployment -Application $app -MasterCollection $masterInstallRequired -DeploymentPurpose 'Required'
                Set-MasterCollectionDeployment -Application $app -MasterCollection $masterUninstall -DeploymentPurpose 'Uninstall' -DeploymentAction 'Uninstall'
            } else {
                Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail ("No deployable application found for '{0}'. Skipping master collection deployment creation." -f $CanonicalName)
            }
        } else {
            Write-LogEvent -Level 'INFO' -Scope 'Collections' -Action 'Status' -Detail '[DryRun] Would populate master collections with calculated members.'
        }
    } catch {
        Write-LogEvent -Level 'ERROR' -Scope 'Collections' -Action 'Error' -Detail ("Update-MasterCollections failed during stage '{0}': {1}" -f $populationStage, $_.Exception.Message)
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
            } catch {
                try {
                    $taskSequences = @(Get-CMTaskSequence -ErrorAction SilentlyContinue)
                } catch {
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
                    } catch {
                        Write-Verbose 'Failed to parse task sequence XML while building application reference cache.'
                    }
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
    } catch {
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
function Set-ApplicationSupersedenceLink {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal supersedence helper. Confirmation is coordinated by the script entry point.')]
    param(
        [Parameter(Mandatory = $true)]
        $OlderApp,
        [Parameter(Mandatory = $true)]
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

            if (-not $App) {
                return $null
            }

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
                } catch {
                    Write-Verbose 'A deployment type resolution attempt failed; continuing with fallback parameter sets.'
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
                Label  = 'InputObject+SupersededApplicationId+CurrentDeploymentTypeId+OldDeploymentTypeId'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentTypeId $newerDtId -OldDeploymentTypeId $olderDtId -Force -ErrorAction Stop }
            }
        }
        if (($paramNames -contains 'CurrentDeploymentTypeName') -and ($paramNames -contains 'OldDeploymentTypeName') -and $newerDtName -and $olderDtName) {
            $attempts += [pscustomobject]@{
                Label  = 'InputObject+SupersededApplicationId+CurrentDeploymentTypeName+OldDeploymentTypeName'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentTypeName $newerDtName -OldDeploymentTypeName $olderDtName -Force -ErrorAction Stop }
            }
        }
        if (($paramNames -contains 'CurrentDeploymentType') -and ($paramNames -contains 'OldDeploymentType') -and $newerDt -and $olderDt) {
            $attempts += [pscustomobject]@{
                Label  = 'InputObject+SupersededApplicationId+CurrentDeploymentType+OldDeploymentType'
                Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -CurrentDeploymentType $newerDt -OldDeploymentType $olderDt -Force -ErrorAction Stop }
            }
        }
    }

    # Fallback sets (for environments that do not require deployment type arguments).
    if (($paramNames -contains 'InputObject') -and ($paramNames -contains 'SupersededApplicationId')) {
        $attempts += [pscustomobject]@{
            Label  = 'InputObject+SupersededApplicationId'
            Action = { & $cmd -InputObject $NewerApp -SupersededApplicationId $OlderApp.CI_ID -Force -ErrorAction Stop }
        }
    }
    if (($paramNames -contains 'Id') -and ($paramNames -contains 'SupersededApplicationId')) {
        $attempts += [pscustomobject]@{
            Label  = 'Id+SupersededApplicationId'
            Action = { & $cmd -Id $NewerApp.CI_ID -SupersededApplicationId $OlderApp.CI_ID -Force -ErrorAction Stop }
        }
    }
    if (($paramNames -contains 'Name') -and ($paramNames -contains 'SupersededApplicationName')) {
        $attempts += [pscustomobject]@{
            Label  = 'Name+SupersededApplicationName'
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
        } catch {
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
function Set-SupersedenceAndDeployments {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal orchestration helper. Confirmation is coordinated by the top-level workflow.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SoftwareName,

        [Parameter(Mandatory = $false)]
        [bool]$ManageSupersedence = $true
    )

    if (-not $ManageSupersedence) {
        Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Skipped' -Detail 'ManageSupersedence is disabled.'
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

        $entryName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName', 'Name'))
        if ([string]::IsNullOrWhiteSpace($entryName)) {
            $entryName = '[Unnamed application]'
        }

        $entryVersionRaw = [string](Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('Version'))
        if ([string]::IsNullOrWhiteSpace($entryVersionRaw)) {
            $entryVersionRaw = [string](Get-VersionFromName -Name $entryName)
        }

        $entryVersion = [version]'0.0.0'
        if (-not [string]::IsNullOrWhiteSpace($entryVersionRaw)) {
            try { $entryVersion = [version]$entryVersionRaw } catch { $entryVersion = $null }
        }

        $chainEntries += [pscustomobject]@{
            App         = $entryApp
            Name        = $entryName
            Version     = $entryVersion
            VersionRaw  = $entryVersionRaw
            DisplayName = (Get-VersionAwareDisplayName -Name $entryName -VersionRaw $entryVersionRaw)
        }
    }

    $chainEntries = @($chainEntries | Sort-Object -Property Version)

    if ($chainEntries.Count -lt 2) {
        Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Skipped' -Detail 'Not enough valid applications to build a chain after normalization.'
        return
    }

    $chainDisplay = [string]::Join(' -> ', @($chainEntries | ForEach-Object { $_.DisplayName }))
    Write-LogEvent -Level 'INFO' -Scope 'Supersedence' -Action 'Build chain' -Detail $chainDisplay

    for ($i = 0; $i -lt $chainEntries.Count - 1; $i++) {
        # Create adjacent pairs (older -> newer) to form a linear supersedence
        # chain that is easy to reason about and troubleshoot.
        $olderEntry = $chainEntries[$i]
        $newerEntry = $chainEntries[$i + 1]
        $older = $olderEntry.App
        $newer = $newerEntry.App

        try {
            if (-not $DryRun) {
                $ok = Set-ApplicationSupersedenceLink -OlderApp $older -NewerApp $newer
                if (-not $ok) {
                    throw "Set-CMApplicationSupersedence command not supported with detected parameter set."
                }

                Write-LogEvent -Level 'SUCCESS' -Scope 'Supersedence' -Action 'Linked' -Detail (("'{0}' supersedes '{1}'") -f $newerEntry.DisplayName, $olderEntry.DisplayName)
            } else {
                Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Would link supersedence' -Detail (("'{0}' supersedes '{1}'") -f $newerEntry.DisplayName, $olderEntry.DisplayName)
            }
        } catch {
            Write-LogEvent -Level 'WARN' -Scope 'Supersedence' -Action 'Link failed' -Detail (("'{0}' -> '{1}' | {2}") -f $olderEntry.DisplayName, $newerEntry.DisplayName, $_.Exception.Message)
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal delete helper. Confirmation is controlled by the script entry point and DryRun wrapper.')]
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
        try { $commandParameters = $removeDeploymentCommand.Parameters } catch { $commandParameters = $null }
        if ($null -eq $commandParameters) {
            $removeDeploymentCommand = Get-Command 'Remove-CMDeployment' -ErrorAction SilentlyContinue
            $script:CommandMetadataCache['Remove-CMDeployment'] = $removeDeploymentCommand
            try { $commandParameters = $removeDeploymentCommand.Parameters } catch { $commandParameters = $null }
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
                } else {
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
    } catch {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal dependency cleanup helper. Confirmation is coordinated by the top-level workflow.')]
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
    } catch {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal dependency cleanup helper. Confirmation is coordinated by the top-level workflow.')]
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
    } catch {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal dependency reassignment helper. Confirmation is coordinated by the top-level workflow.')]
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
    } catch {
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
    } elseif ($initialSnapshot.IncludeDependents.Count -gt 0 -or $initialSnapshot.ExcludeDependents.Count -gt 0) {
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
        } else {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal delete helper. Confirmation is controlled by the script entry point and DryRun wrapper.')]
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
                        # Get the collection's own rules via provider query without relying on the problematic cmdlet.
                        $providerCollection = @(Get-SmsProviderInstance -Namespace ("root\SMS\site_{0}" -f $SiteCode) -ClassName 'SMS_Collection' -Filter ("CollectionID='{0}'" -f $collectionId) | Select-Object -First 1)
                        if ($providerCollection.Count -gt 0) {
                            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Found provider collection object for '{0}' ({1}), attempting rule enumeration." -f ($collectionName -as [string]), ($collectionId -as [string]))
                        }
                    }
                } catch {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Skipped membership rule query for '{0}' ({1}): {2}" -f ($collectionName -as [string]), ($collectionId -as [string]), $_.Exception.Message)
                }
            }
        } catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Membership rule cleanup phase skipped for '{0}' ({1}): {2}" -f ($collectionName -as [string]), ($collectionId -as [string]), $_.Exception.Message)
        }

        # PHASE 2: Run the original dependency resolution (more reliable; handles include/exclude cleanup).
        try {
            Write-LogEvent -Level 'DEBUG' -Scope 'Dependencies' -Action 'Debug' -Detail ("Running dependency resolution for collection '{0}' ({1})." -f ($collectionName -as [string]), ($collectionId -as [string]))

            $dependencyResolution = Resolve-CollectionDeleteDependencies -TargetCollection $collectionObject
            if ($dependencyResolution -and $dependencyResolution.RemainingReasons) {
                $dependencyReasons = @($dependencyResolution.RemainingReasons)
            }
        } catch {
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

                    $providerCollection = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_DeviceCollection' -Filter ("CollectionID='{0}'" -f $collectionIdStr) | Select-Object -First 1)
                    if ($providerCollection.Count -eq 0) {
                        $providerCollection = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_Collection' -Filter ("CollectionID='{0}'" -f $collectionIdStr) | Select-Object -First 1)
                    }

                    if ($providerCollection.Count -gt 0) {
                        $providerTarget = $providerCollection[0]
                        try {
                            Invoke-SmsProviderDelete -InputObject $providerTarget
                            $removed = $true
                        } catch {
                            [void]$attemptErrors.Add(("Provider direct delete failed: {0}" -f $_.Exception.Message))
                        }
                    } else {
                        [void]$attemptErrors.Add('Provider lookup returned no collection object (tried both DeviceCollection and Collection classes).')
                    }
                } catch {
                    [void]$attemptErrors.Add(("Provider delete attempt failed: {0}" -f $_.Exception.Message))
                }
            }

            foreach ($attempt in $attempts) {
                # Try known cmdlet variants in sequence because parameter support
                # differs between SCCM module versions and environments.
                try {
                    & $attempt
                    $removed = $true
                    break
                } catch {
                    $msg = $_.Exception.Message
                    if (-not [string]::IsNullOrWhiteSpace($msg)) {
                        [void]$attemptErrors.Add($msg)
                    }
                }
            }

            # Final fallback for stubborn collections: call provider delete directly by CollectionID.
            if (-not $removed -and -not [string]::IsNullOrWhiteSpace($collectionId)) {
                try {
                    $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
                    $collectionIdStr = [string]$collectionId

                    $providerCollection = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_DeviceCollection' -Filter ("CollectionID='{0}'" -f $collectionIdStr) | Select-Object -First 1)

                    if ($providerCollection.Count -eq 0) {
                        $providerCollection = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_Collection' -Filter ("CollectionID='{0}'" -f $collectionIdStr) | Select-Object -First 1)
                    }

                    if ($providerCollection.Count -gt 0) {
                        $providerTarget = $providerCollection[0]

                        try {
                            Invoke-SmsProviderDelete -InputObject $providerTarget
                            $removed = $true
                        } catch {
                            [void]$attemptErrors.Add(("Provider fallback delete failed: {0}" -f $_.Exception.Message))
                        }
                    } else {
                        [void]$attemptErrors.Add('Provider lookup returned no collection object (tried both DeviceCollection and Collection classes).')
                    }
                } catch {
                    [void]$attemptErrors.Add(("Provider fallback failed: {0}" -f $_.Exception.Message))
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
    } catch {
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
function Test-PermanentAppDeletionError {
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

    if ($ErrorMessage -match 'referenced by other applications') {
        return $true
    }

    if ($ErrorMessage -match 'supersed') {
        return $true
    }

    if ($ErrorMessage -match 'dependent application') {
        return $true
    }

    return $false
}

# ------------------------------------------------------------
# REMOVE EMPTY FOLDERS UNDER APPLICATION DEPLOYMENT
# ------------------------------------------------------------

<#!
.SYNOPSIS
    Resolves deterministic Application Deployment folder cleanup candidates.

.DESCRIPTION
    Uses collection metadata plus SMS_ObjectContainer mappings to determine
    folder paths tied to collections that are scheduled for deletion.
#>
function Get-CollectionFolderCleanupCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object[]]$Collections
    )

    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode
    $rootPathCandidates = @([string]$rootInfo.RootPathNoDrive)
    $results = New-Object System.Collections.Generic.HashSet[string]

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
        $normalized = $normalized -replace '^[^:]+:\\?', ''
        $normalized = $normalized.TrimStart('\\').TrimEnd('\\')
        return $normalized
    }

    $addCandidatePath = {
        param(
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [string]$Path
        )

        $normalized = [string](& $normalizeCmFolderPath $Path)
        if ([string]::IsNullOrWhiteSpace($normalized)) {
            return
        }

        $normalizedLower = $normalized.ToLowerInvariant()
        $matchedRoot = $null
        foreach ($rootCandidate in $rootPathCandidates) {
            if ($normalizedLower.IndexOf($rootCandidate.ToLowerInvariant()) -ge 0) {
                $matchedRoot = [string]$rootCandidate
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($matchedRoot)) {
            return
        }

        $rootIndex = $normalizedLower.IndexOf($matchedRoot.ToLowerInvariant())
        $relative = $normalized.Substring($rootIndex).TrimEnd('\\')
        if ($relative.ToLowerInvariant() -eq $matchedRoot.ToLowerInvariant()) {
            return
        }

        [void]$results.Add($relative)
    }

    foreach ($collection in @($Collections)) {
        if (-not $collection) {
            continue
        }

        $collectionPathCandidates = @(
            [string](Get-ObjectPropertyValue -InputObject $collection -PropertyNames @('FolderPath', 'Path', 'ContainerNodePath', 'ObjectPath'))
        )

        foreach ($candidatePath in $collectionPathCandidates) {
            & $addCandidatePath $candidatePath
        }
    }

    try {
        $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
        $containerNodes = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_ObjectContainerNode')
        $nodesById = @{}

        foreach ($node in $containerNodes) {
            if (-not $node) { continue }
            $nodeId = [string](Get-ObjectPropertyValue -InputObject $node -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
            if ([string]::IsNullOrWhiteSpace($nodeId)) { continue }
            if (-not $nodesById.ContainsKey($nodeId)) {
                $nodesById[$nodeId] = $node
            }
        }

        foreach ($collection in @($Collections)) {
            if (-not $collection) { continue }

            $identity = Get-CollectionIdentity -InputObject $collection
            $collectionId = [string]$identity.Id
            if ([string]::IsNullOrWhiteSpace($collectionId)) {
                continue
            }

            $escapedCollectionId = $collectionId.Replace("'", "''")
            $containerItems = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_ObjectContainerItem' -Filter ("ObjectType = 5000 AND InstanceKey = '{0}'" -f $escapedCollectionId))

            foreach ($item in $containerItems) {
                if (-not $item) { continue }

                $nodeId = [string](Get-ObjectPropertyValue -InputObject $item -PropertyNames @('ContainerNodeID', 'ContainerNodeId', 'ObjectContainerNodeID', 'ObjectContainerNodeId'))
                if ([string]::IsNullOrWhiteSpace($nodeId)) {
                    continue
                }

                if (-not $nodesById.ContainsKey($nodeId)) {
                    continue
                }

                $nameChain = New-Object System.Collections.Generic.List[string]
                $visited = New-Object System.Collections.Generic.HashSet[string]
                $current = $nodesById[$nodeId]

                while ($current) {
                    $currentId = [string](Get-ObjectPropertyValue -InputObject $current -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
                    if ([string]::IsNullOrWhiteSpace($currentId)) { break }
                    if (-not $visited.Add($currentId)) { break }

                    $currentName = [string](Get-ObjectPropertyValue -InputObject $current -PropertyNames @('Name'))
                    if (-not [string]::IsNullOrWhiteSpace($currentName)) {
                        [void]$nameChain.Add($currentName)
                    }

                    $parentId = [string](Get-ObjectPropertyValue -InputObject $current -PropertyNames @('ParentContainerNodeId', 'ParentContainerNodeID'))
                    if ([string]::IsNullOrWhiteSpace($parentId) -or $parentId -eq '0') {
                        break
                    }

                    if (-not $nodesById.ContainsKey($parentId)) {
                        break
                    }

                    $current = $nodesById[$parentId]
                }

                if ($nameChain.Count -eq 0) {
                    continue
                }

                $orderedNames = @($nameChain)
                [array]::Reverse($orderedNames)
                $candidatePath = ('{0}\{1}' -f ([string]$rootInfo.DeviceRootName), ($orderedNames -join '\\'))
                & $addCandidatePath $candidatePath
            }
        }
    } catch {
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Could not resolve provider-based collection folder cleanup candidates: {0}" -f $_.Exception.Message)
    }

    return @(@($results) | Sort-Object -Unique)
}

<#!
.SYNOPSIS
    Removes deterministic folder cleanup candidates and parent chain paths.

.DESCRIPTION
    Deletes known candidate folders first, then attempts parent folders up to the
    Application Deployment root while honoring preserve paths.
#>
function Remove-KnownApplicationDeploymentFolders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal cleanup helper. Confirmation is coordinated by the top-level workflow and DryRun wrapper.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [string[]]$FolderPaths,

        [Parameter(Mandatory = $false)]
        [string[]]$PreserveFolderPaths = @()
    )
    $removeCmFolderSupportsPath = Test-RemoveCmFolderPathParameterSupport
    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode
    $rootPathCandidates = @([string]$rootInfo.RootPathNoDrive)

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
        $normalized = $normalized -replace '^[^:]+:\\?', ''
        $normalized = $normalized.TrimStart('\\').TrimEnd('\\')
        return $normalized
    }

    $normalizedPreservePaths = @($PreserveFolderPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            ([string](& $normalizeCmFolderPath ([string]$_))).ToLowerInvariant()
        } | Sort-Object -Unique)

    $plannedPaths = New-Object System.Collections.Generic.HashSet[string]

    foreach ($folderPath in @($FolderPaths)) {
        $normalizedPath = [string](& $normalizeCmFolderPath $folderPath)
        if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
            continue
        }

        $normalizedLower = $normalizedPath.ToLowerInvariant()
        $matchedRoot = $null
        foreach ($rootCandidate in $rootPathCandidates) {
            if ($normalizedLower.IndexOf($rootCandidate.ToLowerInvariant()) -ge 0) {
                $matchedRoot = [string]$rootCandidate
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($matchedRoot)) {
            continue
        }

        $rootIndex = $normalizedLower.IndexOf($matchedRoot.ToLowerInvariant())
        $relativePath = $normalizedPath.Substring($rootIndex).TrimEnd('\\')
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        if ($relativePath.ToLowerInvariant() -eq $matchedRoot.ToLowerInvariant()) {
            continue
        }

        $currentPath = $relativePath
        while (-not [string]::IsNullOrWhiteSpace($currentPath)) {
            if ($currentPath.ToLowerInvariant() -eq $matchedRoot.ToLowerInvariant()) {
                break
            }

            [void]$plannedPaths.Add($currentPath)
            $lastSlash = $currentPath.LastIndexOf('\\')
            if ($lastSlash -le 0) {
                break
            }

            $currentPath = $currentPath.Substring(0, $lastSlash)
        }
    }

    $sortedCleanupPaths = @(@($plannedPaths) | Sort-Object {
            $_.Split('\\').Count
        } -Descending)

    if ($sortedCleanupPaths.Count -eq 0) {
        Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail 'No deterministic folder cleanup candidates were generated from collection delete plan.'
        return
    }

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Deterministic folder cleanup candidates: {0}" -f $sortedCleanupPaths.Count)

    foreach ($pathNoDrive in $sortedCleanupPaths) {
        if ([string]::IsNullOrWhiteSpace($pathNoDrive)) {
            continue
        }

        $pathKey = $pathNoDrive.ToLowerInvariant()
        if ($normalizedPreservePaths -contains $pathKey) {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Skipping preserved folder from deterministic cleanup: {0}" -f $pathNoDrive)
            continue
        }

        $siteQualifiedPath = ("{0}:\{1}" -f $SiteCode, $pathNoDrive)
        $leadingSlashPath = ("\{0}" -f $pathNoDrive)

        $removeAttempts = @(
            { Remove-CMFolder -FolderPath $siteQualifiedPath -Force -ErrorAction Stop | Out-Null },
            { Remove-CMFolder -FolderPath $pathNoDrive -Force -ErrorAction Stop | Out-Null },
            { Remove-CMFolder -FolderPath $leadingSlashPath -Force -ErrorAction Stop | Out-Null }
        )
        if ($removeCmFolderSupportsPath) {
            $removeAttempts += { Remove-CMFolder -Path $siteQualifiedPath -Force -ErrorAction Stop | Out-Null }
            $removeAttempts += { Remove-CMFolder -Path $pathNoDrive -Force -ErrorAction Stop | Out-Null }
            $removeAttempts += { Remove-CMFolder -Path $leadingSlashPath -Force -ErrorAction Stop | Out-Null }
        }

        try {
            Invoke-DryRunAction -Action {
                $result = Invoke-CmCommandWithFallback -Attempts $removeAttempts -ActionName 'Remove-CMFolder (deterministic cleanup)'
                if (-not $result.Success) {
                    throw ("No supported Remove-CMFolder argument set succeeded for deterministic path '{0}'." -f $pathNoDrive)
                }
            } -Description ("delete deterministic empty folder '{0}'" -f $siteQualifiedPath)

            if (-not $DryRun) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Deleted deterministic folder candidate: {0}" -f $siteQualifiedPath)
            }
        } catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Deterministic folder cleanup skipped for '{0}': {1}" -f $siteQualifiedPath, $_.Exception.Message)
        }
    }
}

<#
.SYNOPSIS
    Removes empty folders under Application Deployment.

.DESCRIPTION
    Traverses folder hierarchy from deepest to shallowest to safely remove empty
    child folders before parent folders.
#>
function Remove-EmptyApplicationDeploymentFolders {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal cleanup helper. Confirmation is coordinated by the top-level workflow and DryRun wrapper.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteCode,

        [Parameter(Mandatory = $false)]
        [string[]]$PreserveFolderPaths = @()
    )

    $removeCmFolderSupportsPath = Test-RemoveCmFolderPathParameterSupport
    $rootInfo = Resolve-ApplicationDeploymentRoot -SiteCode $SiteCode
    $rootPath = [string]$rootInfo.RootPath
    $rootPathNoDrive = [string]$rootInfo.RootPathNoDrive
    $rootPathNoDriveWithSlash = [string]$rootInfo.RootPathWithSlash

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

    $folderNodesById = @{}

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

        $folderNodeId = [string](Get-ObjectPropertyValue -InputObject $FolderObject -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
        if ([string]::IsNullOrWhiteSpace($folderNodeId)) {
            return ''
        }

        $nameChain = New-Object System.Collections.Generic.List[string]
        $visitedNodeIds = New-Object System.Collections.Generic.HashSet[string]
        $currentNode = $FolderObject

        while ($currentNode) {
            $currentNodeId = [string](Get-ObjectPropertyValue -InputObject $currentNode -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
            if ([string]::IsNullOrWhiteSpace($currentNodeId)) {
                break
            }

            if (-not $visitedNodeIds.Add($currentNodeId)) {
                break
            }

            $currentName = [string](Get-ObjectPropertyValue -InputObject $currentNode -PropertyNames @('Name'))
            if (-not [string]::IsNullOrWhiteSpace($currentName)) {
                [void]$nameChain.Add($currentName)
            }

            $parentNodeId = [string](Get-ObjectPropertyValue -InputObject $currentNode -PropertyNames @('ParentContainerNodeId', 'ParentContainerNodeID'))
            if ([string]::IsNullOrWhiteSpace($parentNodeId) -or $parentNodeId -eq '0') {
                break
            }

            if (-not $folderNodesById.ContainsKey($parentNodeId)) {
                break
            }

            $currentNode = $folderNodesById[$parentNodeId]
        }

        if ($nameChain.Count -eq 0) {
            return ''
        }

        $orderedNames = @($nameChain)
        [array]::Reverse($orderedNames)
        return ('{0}\{1}' -f ([string]$rootInfo.DeviceRootName), ($orderedNames -join '\'))

        return ''
    }

    $normalizedPreservePaths = @($PreserveFolderPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            ([string](& $normalizeCmFolderPath ([string]$_))).ToLowerInvariant()
        } | Sort-Object -Unique)

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Scanning for empty folders under: {0}" -f $rootPath)
    if ($normalizedPreservePaths.Count -gt 0) {
        Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Preserving {0} folder path(s) from cleanup: {1}" -f $normalizedPreservePaths.Count, ($normalizedPreservePaths -join ', '))
    }

    $getCmFolderSupportsRecurse = Test-CmFolderRecurseParameterSupport
    $allFolders = @()

    # Collect folders using multiple path/query variants because SCCM folder cmdlets
    # return different FolderPath formats across environments. Prioritize versions
    # without -Recurse (which may not be supported in all SCCM versions).
    $folderQueryAttempts = @(
        { @(Get-CMFolder -FolderPath $rootPath -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -FolderPath $rootPathNoDrive -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -FolderPath $rootPathNoDriveWithSlash -ErrorAction SilentlyContinue) },
        { @(Get-CMFolder -Name '*' -ErrorAction SilentlyContinue) }
    )
    if ($getCmFolderSupportsRecurse) {
        $folderQueryAttempts += { @(Get-CMFolder -Recurse -ErrorAction SilentlyContinue) }
    }

    foreach ($queryAttempt in $folderQueryAttempts) {
        try {
            $result = @(& $queryAttempt)
            if ($result -and $result.Count -gt 0) {
                $allFolders += $result
                Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Folder query returned {0} folder(s)." -f $result.Count)
            }
        } catch {
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
                } else {
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
                } catch {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Could not query children of {0}: {1}" -f $currentPath, $_.Exception.Message)
                }
            }

            $allFolders = @($discoveredFolders)
        } catch {
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Manual recursive discovery failed: {0}" -f $_.Exception.Message)
        }
    }

    if (-not $allFolders -or $allFolders.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail 'No folders found via any discovery method.'
        return
    }

    Write-LogEvent -Level 'INFO' -Scope 'Folders' -Action 'Status' -Detail ("Enumerated {0} folder object(s) for cleanup analysis." -f $allFolders.Count)

    foreach ($folderNode in @($allFolders)) {
        if (-not $folderNode) {
            continue
        }

        $folderNodeId = [string](Get-ObjectPropertyValue -InputObject $folderNode -PropertyNames @('ContainerNodeId', 'ContainerNodeID'))
        if ([string]::IsNullOrWhiteSpace($folderNodeId)) {
            continue
        }

        if (-not $folderNodesById.ContainsKey($folderNodeId)) {
            $folderNodesById[$folderNodeId] = $folderNode
        }
    }

    # Normalize and keep only child folders under Application Deployment.
    $uniqueFoldersByPath = @{}

    foreach ($folder in @($allFolders)) {
        if (-not $folder) {
            continue
        }

        $isEmptyValue = Get-ObjectPropertyValue -InputObject $folder -PropertyNames @('IsEmpty')
        $isEmptyResolved = $null
        if ($null -ne $isEmptyValue -and -not [string]::IsNullOrWhiteSpace(($isEmptyValue -as [string]))) {
            try {
                $isEmptyInt = 0
                if ([int]::TryParse([string]$isEmptyValue, [ref]$isEmptyInt)) {
                    $isEmptyResolved = ($isEmptyInt -eq 1)
                } else {
                    $isEmptyResolved = [bool]$isEmptyValue
                }
            } catch {
                $isEmptyResolved = $null
            }
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
                IsEmptyKnown = ($null -ne $isEmptyResolved)
                IsEmpty      = $isEmptyResolved
            }
        }
    }

    $allSubfolders = @($uniqueFoldersByPath.Values)

    if ($allSubfolders.Count -eq 0) {
        $siteNamespace = "root\SMS\site_{0}" -f $SiteCode
        $wmiCandidates = @()

        try {
            $allContainerNodes = @(Get-SmsProviderInstance -Namespace $siteNamespace -ClassName 'SMS_ObjectContainerNode')
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

                    $orderedNames = @($nameChain)
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
                    $relativePath = "{0}\{1}" -f ([string]$rootInfo.DeviceRootName), ($relativeNames -join '\')
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
        } catch {
            Write-LogEvent -Level 'WARN' -Scope 'Folders' -Action 'Warning' -Detail ("Provider fallback query for SMS_ObjectContainerNode failed: {0}" -f $_.Exception.Message)
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
            foreach ($propName in @('Name', 'FolderPath', 'Path', 'ContainerNodePath', 'ObjectPath', 'InstanceKey', 'ParentContainerNodeId', 'ContainerNodeId', 'ObjectTypeName')) {
                try {
                    $prop = $sampleFolder.PSObject.Properties[$propName]
                    if ($prop) {
                        $value = [string]$prop.Value
                        if (-not [string]::IsNullOrWhiteSpace($value)) {
                            $sampleValues += ("{0}={1}" -f $propName, $value)
                        }
                    }
                } catch {
                    Write-Verbose ("Failed to sample folder object property [{0}]." -f $propName)
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
    $sortedFolders = $allSubfolders | Sort-Object -Property @(
        @{ Expression     = {
                $isKnownEmpty = $false
                try {
                    if ($_.PSObject.Properties['IsEmpty']) {
                        $isKnownEmpty = ($_.IsEmpty -eq $true)
                    }
                } catch {
                    $isKnownEmpty = $false
                }

                if ($isKnownEmpty) { 0 } else { 1 }
            }; Descending = $false
        },
        @{ Expression     = {
                ([string](& $normalizeCmFolderPath $_.RawPath)).Split('\\').Count
            }; Descending = $true
        }
    )

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
                    Invoke-SmsProviderDelete -InputObject $folderEntry.Node
                } -Description "delete empty folder '$folderPath' via provider"
            } else {
                $normalizedFolderPath = [string](& $normalizeCmFolderPath $folderPath)
                $folderPathWithoutDrive = $normalizedFolderPath -replace '^[^:]+:\\', ''
                $folderPathWithoutDrive = $folderPathWithoutDrive -replace '^[\\]+', ''

                $removeAttempts = @(
                    { Remove-CMFolder -FolderPath $folderPath -Force -ErrorAction Stop | Out-Null },
                    { Remove-CMFolder -FolderPath $normalizedFolderPath -Force -ErrorAction Stop | Out-Null }
                )
                if ($removeCmFolderSupportsPath) {
                    $removeAttempts += { Remove-CMFolder -Path $folderPath -Force -ErrorAction Stop | Out-Null }
                    $removeAttempts += { Remove-CMFolder -Path $normalizedFolderPath -Force -ErrorAction Stop | Out-Null }
                }

                if (-not [string]::IsNullOrWhiteSpace($folderPathWithoutDrive)) {
                    $removeAttempts += {
                        Remove-CMFolder -FolderPath $folderPathWithoutDrive -Force -ErrorAction Stop | Out-Null
                    }
                    if ($removeCmFolderSupportsPath) {
                        $removeAttempts += {
                            Remove-CMFolder -Path $folderPathWithoutDrive -Force -ErrorAction Stop | Out-Null
                        }
                    }
                }

                if ($folderEntry.PSObject.Properties['FolderObject'] -and $folderEntry.FolderObject) {
                    $folderInputObject = $folderEntry.FolderObject
                    $removeAttempts += {
                        Remove-CMFolder -InputObject $folderInputObject -Force -ErrorAction Stop | Out-Null
                    }
                }

                Invoke-DryRunAction -Action {
                    $removeResult = Invoke-CmCommandWithFallback -Attempts $removeAttempts -ActionName 'Remove-CMFolder (empty cleanup)'
                    if (-not $removeResult.Success) {
                        throw ("No supported Remove-CMFolder argument set succeeded for path '{0}'." -f $folderPath)
                    }
                } -Description "delete empty folder '$folderPath'"
            }
            if (-not $DryRun) {
                Write-LogEvent -Level 'SUCCESS' -Scope 'Folders' -Action 'Success' -Detail ("Deleted empty folder: {0}" -f $folderPath)
            }
        } catch {
            # Expected for non-empty folders; keep as DEBUG to avoid noisy logs.
            Write-LogEvent -Level 'DEBUG' -Scope 'Folders' -Action 'Debug' -Detail ("Skipping non-empty/protected folder '{0}': {1}" -f $folderPath, $_.Exception.Message)
        }
    }
}

# ------------------------------------------------------------
# PLAN AND EXECUTE CLEANUP
# ------------------------------------------------------------

function Invoke-CleanupPlan {
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
        [bool]$DeleteOldCollections = $true
    )

    $cleanupStage = 'initialization'

    try {
        if (-not $DeleteOldCollections) {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Skipped' -Detail 'DeleteOldCollections is disabled.'
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
        $latestAppSelection = Get-LatestApplicationSelection -SoftwareName $normalizedSoftwareName
        $latestAppForMigration = $latestAppSelection.App

        if ($latestAppForMigration) {
            $migrationTargetDisplayName = Get-ApplicationDisplayName -App $latestAppForMigration
            if ($latestAppSelection -and -not $latestAppSelection.IsVersionConfirmed) {
                Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Migration target inferred' -Detail ("Target '{0}' is inferred from application metadata and is not version-confirmed. Review before allowing deployment migration and cleanup deletes." -f $migrationTargetDisplayName)
            }
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Migration target selected' -Detail $migrationTargetDisplayName
        } else {
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

            $appId = Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId')
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

            $keepId = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId'))
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
                $candidateId = [string](Get-ObjectPropertyValue -InputObject $candidateApp -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId'))
                -not [string]::IsNullOrWhiteSpace($candidateId) -and ($keepIds -notcontains $candidateId)
            })

        $cleanupStage = 'log app keep/delete plan'
        $appsToKeepList = @()
        if ($appsToKeep) {
            if ($appsToKeep -is [System.Collections.Generic.List[object]]) {
                $appsToKeepList = @($appsToKeep)
            } else {
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
                try { $displayName = [string](Get-ApplicationDisplayName -App $entryApp) } catch { $displayName = [string]$entryAppName }
                if (-not [string]::IsNullOrWhiteSpace($displayName)) { $displayName }
            }
        )

        $oldAppNames = @(
            foreach ($entry in $oldAppsList) {
                if (-not $entry) { continue }
                $entryApp = Get-ObjectPropertyValue -InputObject $entry -PropertyNames @('App')
                if (-not $entryApp) { continue }
                $displayName = ''
                try { $displayName = [string](Get-ApplicationDisplayName -App $entryApp) } catch { $displayName = [string]$entryAppName }
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

        try { Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Applications to keep' -Detail $keepDetail } catch { Write-ScriptLog -Level 'INFO' -Message ("[CLEANUP] Applications to keep: {0}" -f $keepDetail) }
        try { Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Applications to delete' -Detail $deleteDetail } catch { Write-ScriptLog -Level 'INFO' -Message ("[CLEANUP] Applications to delete: {0}" -f $deleteDetail) }

        # Determine which non-master collections are eligible for deletion.
        $cleanupStage = 'build collection delete plan'
        $oldCollections = @()
        $knownFolderCleanupCandidates = @()

        if ($DeleteOldCollections) {
            foreach ($col in $AllCollections) {
                if (-not $col) { continue }
                if ($masterNames -notcontains $col.Name) {
                    if (Test-LegacyCollectionProtectedFromDeletion -Collection $col) {
                        Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Collection delete skipped (protected)' -Detail ([string](Get-ObjectPropertyValue -InputObject $col -PropertyNames @('Name', 'CollectionName')))
                        continue
                    }

                    $oldCollections += $col
                }
            }

            # Sort collections by version in DESCENDING order (newest to oldest).
            # This respects the include hierarchy: delete parent collections before
            # child collections to avoid "include" dependency errors.
            $oldCollectionsWithVersion = @()
            foreach ($col in $oldCollections) {
                $version = Get-VersionFromName -Name ($col.Name -as [string])
                $oldCollectionsWithVersion += [pscustomobject]@{
                    Collection    = $col
                    VersionString = ($version -as [string])
                    Version       = if ([version]::TryParse(($version -as [string]), [ref]$null)) { [version]$version } else { [version]'0.0.0' }
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
                    $colVersion = Get-VersionFromName -Name ($col.Name -as [string])
                    Write-LogEvent -Level 'DEBUG' -Scope 'Cleanup' -Action 'Deletion queue' -Detail ("  {0} (version: {1})" -f $col.Name, ($colVersion -as [string]))
                }

                $knownFolderCleanupCandidates = @(Get-CollectionFolderCleanupCandidates -SiteCode $SiteCode -Collections $oldCollections)
                if ($knownFolderCleanupCandidates.Count -gt 0) {
                    Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Folder cleanup plan' -Detail ("Resolved {0} deterministic folder candidate(s) from collection delete plan." -f $knownFolderCleanupCandidates.Count)
                } else {
                    Write-LogEvent -Level 'DEBUG' -Scope 'Cleanup' -Action 'Debug' -Detail 'No deterministic folder candidates resolved from collection delete plan. Generic empty-folder discovery will still run.'
                }
            }
        }

        $cleanupStage = 'confirm cleanup plan'
        $hasObjectCleanupActions = (($deploymentsToDelete.Count -gt 0) -or ($oldApps.Count -gt 0) -or ($oldCollections.Count -gt 0))

        if ($hasObjectCleanupActions) {
            if ($DryRun) {
                Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Confirmation skipped' -Detail 'DryRun is active. Continuing with simulated cleanup actions without prompting.'
            } elseif (-not $AutoApprove) {
                if ($NonInteractive) {
                    Write-LogEvent -Level 'ERROR' -Scope 'Cleanup' -Action 'Aborted' -Detail 'Cleanup confirmation is required, but NonInteractive is set. Re-run with -AutoApprove to proceed without prompts.'
                    return
                }
                Write-SectionHeader -Message 'Planned cleanup actions:'
                Write-ResultLine -Message (" - Deployments to delete: {0}" -f $deploymentsToDelete.Count)
                Write-ResultLine -Message (" - Applications to delete: {0}" -f $oldApps.Count)
                Write-ResultLine -Message (" - Collections to delete:  {0}" -f $oldCollections.Count)
                Write-ResultLine -Message ''
                $answer = Read-Host "Proceed with cleanup? (Y/N)"
                if ($answer -notin @('Y', 'y', 'Yes', 'yes')) {
                    Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Aborted' -Detail 'User declined confirmation prompt.'
                    return
                }
            } else {
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
                        $migrated = Set-LatestDeploymentForCollection -Deployment $d -LatestApp $latestAppForMigration
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

                $appName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('LocalizedDisplayName', 'Name'))
                $appDisplayName = Get-ApplicationDisplayName -App $entryApp
                $appId = Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('CI_ID', 'CIId', 'ModelID', 'ModelId')
                $appModelName = [string](Get-ObjectPropertyValue -InputObject $entryApp -PropertyNames @('ModelName', 'ModelId'))

                $tsRefs = Find-TaskSequencesReferencingApp -AppCI_ID $appId -AppModelName $appModelName

                if ($tsRefs.Count -gt 0) {
                    Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Application delete skipped' -Detail (("'{0}' (CI_ID: {1}) is referenced by {2} task sequence(s).") -f $appDisplayName, $appId, $tsRefs.Count)

                    foreach ($r in $tsRefs) {
                        Write-ResultLine -Message (" - Task Sequence: {0} (PackageId: {1})" -f $r.TaskSequenceName, $r.PackageId)
                    }

                    continue
                }

                try {
                    Invoke-DryRunAction -Action {
                        [void](Remove-Application-Robust -Application $entryApp)
                    } -Description "delete software application '$appDisplayName'"
                    if (-not $DryRun) {
                        Write-LogEvent -Level 'SUCCESS' -Scope 'Cleanup' -Action 'Application deleted' -Detail $appDisplayName
                    }
                } catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Cleanup' -Action 'Application delete failed' -Detail (("'{0}' | {1}") -f $appDisplayName, $_.Exception.Message)

                    if (Test-PermanentAppDeletionError -ErrorMessage $_.Exception.Message) {
                        Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Retry skipped' -Detail (("'{0}' blocked by dependency references.") -f $appDisplayName)
                        continue
                    }

                    [void]$failedApps.Add(
                        [pscustomobject]@{
                            Name      = $appName
                            CI_ID     = $appId
                            ModelName = $appModelName
                            Error     = $_.Exception.Message
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
        } else {
            Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'No-op' -Detail 'No legacy deployments, applications, or collections require cleanup. Continuing to folder cleanup for leftovers from previous runs.'
        }

        $cleanupStage = 'cleanup empty folders'
        Write-LogEvent -Level 'INFO' -Scope 'Cleanup' -Action 'Folder cleanup start' -Detail 'Application Deployment root.'
        $preserveFolders = @()
        if (-not [string]::IsNullOrWhiteSpace(($TargetFolder -as [string]))) {
            $preserveFolders += @(Get-TargetFolderPath -SiteCode $SiteCode -TargetFolder $TargetFolder)
        }

        if ($DryRun) {
            Write-LogEvent -Level 'INFO' -Scope 'DryRun' -Action 'Folder cleanup simulation' -Detail 'Enumerating empty folder delete candidates under Application Deployment root.'
        }

        if ($knownFolderCleanupCandidates.Count -gt 0) {
            $cleanupStage = 'deterministic folder cleanup'
            Remove-KnownApplicationDeploymentFolders -SiteCode $SiteCode -FolderPaths $knownFolderCleanupCandidates -PreserveFolderPaths $preserveFolders
        }

        $cleanupStage = 'generic empty folder cleanup'

        Remove-EmptyApplicationDeploymentFolders -SiteCode $SiteCode -PreserveFolderPaths $preserveFolders
    } catch {
        $cleanupErrorMessage = [string]$_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($cleanupErrorMessage)) {
            $cleanupErrorMessage = '[No exception message available]'
        }

        Write-ScriptLog -Level 'ERROR' -Message ("[CLEANUP] Failed: Invoke-CleanupPlan failed during stage '{0}': {1}" -f $cleanupStage, $cleanupErrorMessage)
        if ($_.ScriptStackTrace) {
            Write-ScriptLog -Level 'DEBUG' -Message ("[CLEANUP] Debug: Stack: {0}" -f $_.ScriptStackTrace)
        }

        # Also emit the structured event when possible for consistency.
        Write-LogEvent -Level 'ERROR' -Scope 'Cleanup' -Action 'Failed' -Detail ("Invoke-CleanupPlan failed during stage '{0}': {1}" -f $cleanupStage, $cleanupErrorMessage)
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

function Invoke-FailedDeletionRetry {
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
                    } else {
                        Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Deployment not found' -Detail $d.DeploymentID
                        [void]$failedDeployments.Add($d)
                    }
                } catch {
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
                    [void](Remove-Application-Robust -Application $a)
                    Write-LogEvent -Level 'SUCCESS' -Scope 'Retry' -Action 'Application deleted' -Detail (Get-ApplicationDisplayName -App $a)
                } catch {
                    Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Application retry failed' -Detail (("'{0}' | {1}") -f $a.Name, $_.Exception.Message)

                    if (Test-PermanentAppDeletionError -ErrorMessage $_.Exception.Message) {
                        Write-LogEvent -Level 'INFO' -Scope 'Retry' -Action 'Application retry skipped' -Detail (("'{0}' blocked by dependency references.") -f (Get-ApplicationDisplayName -App $a))
                        continue
                    }

                    [void]$failedApps.Add(
                        [pscustomobject]@{
                            Name      = $a.Name
                            CI_ID     = $a.CI_ID
                            ModelName = $a.ModelName
                            Error     = $_.Exception.Message
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
                    } else {
                        Write-LogEvent -Level 'WARN' -Scope 'Retry' -Action 'Collection not found' -Detail $c.CollectionID
                        [void]$failedCollections.Add($c)
                    }
                } catch {
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

$__OldConfirmPreference = $ConfirmPreference
$__OldProgressPreference = $ProgressPreference

$ConfirmPreference = 'None'
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

    # Preflight: validate cmdlet/provider capabilities and resolve a stable
    # application deployment root before creating/moving any collections.
    [void](Test-ApplicationDeploymentRootPrerequisites -SiteCode $SiteCode -TargetFolder $TargetFolder)

    # ------------------------------------------------------------
    # RETRIEVE ALL COLLECTIONS MATCHING USER INPUT
    # ------------------------------------------------------------
    # Phase 2: identify all candidate collections in scope for this software.
    $allCollections = Convert-ToSafeArray -InputObject (Get-SoftwareCollections -SoftwareName $SoftwareName)

    if (-not $allCollections -or $allCollections.Count -eq 0) {
        Write-LogEvent -Level 'WARN' -Scope 'Discovery' -Action 'No matching collections' -Detail $SoftwareName
    } else {

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
                $candidate = Get-SoftwareFamilyCandidateFromCollectionName -CollectionName $originalName

                if (
                    -not [string]::IsNullOrWhiteSpace($candidate) -and
                    (Test-SoftwareNameCandidate -Candidate $candidate)
                ) {

                    $softwareNameCandidatesRaw += $candidate
                } else {
                    $debugFiltered += [PSCustomObject]@{
                        CollectionName = $originalName
                        Extracted      = $candidate
                        Reason         = "Empty or invalid candidate"
                    }
                }
            }

            # Keep a unique list for interactive display while preserving the
            # raw list for frequency-based auto-selection logic.
            $softwareNameCandidates = @($softwareNameCandidatesRaw | Sort-Object -Unique)

            # Final cleanup: ensure no empty or invalid candidates remain
            $softwareNameCandidates = @($softwareNameCandidates |
                Where-Object { Test-SoftwareNameCandidate -Candidate $_ })

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
            $requestedSoftwareNameNormalized = ($requestedSoftwareName -as [string]).Trim().ToLowerInvariant()
            $requestedSoftwareCandidate = @($softwareNameCandidates | Where-Object {
                    $_.Trim().ToLowerInvariant() -eq $requestedSoftwareNameNormalized
                } | Select-Object -First 1)

            if ($requestedSoftwareCandidate.Count -gt 0) {
                $SoftwareName = $requestedSoftwareCandidate[0].Trim()
                Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Auto-selected software name' -Detail ("Requested software name matched discovered candidate '{0}'." -f $SoftwareName)
                $skipPrompt = $true
            } elseif ($softwareNameCandidates.Count -eq 1) {
                # Only one valid candidate -> auto-select.
                $candidate = [string]($softwareNameCandidates | Select-Object -First 1)
                if (Test-SoftwareNameCandidate -Candidate $candidate) {
                    $SoftwareName = $candidate.Trim()
                } else {
                    Write-LogEvent -Level 'WARN' -Scope 'Discovery' -Action 'Candidate rejected' -Detail ("Auto-detected candidate '{0}' is too short. Keeping requested software name '{1}'." -f $candidate, $requestedSoftwareName)
                    $SoftwareName = $requestedSoftwareName
                }
                Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Auto-selected software name' -Detail $SoftwareName
                $skipPrompt = $true
            } elseif ($softwareNameCandidates.Count -gt 1 -and $AutoApprove) {
                # AutoApprove -> pick the most common candidate.
                $SoftwareName = ($softwareNameCandidatesRaw |
                    Group-Object |
                    Sort-Object -Property @(
                        @{ Expression     = {
                                if ($requestedSoftwareNameNormalized -and $_.Name.Trim().ToLowerInvariant() -eq $requestedSoftwareNameNormalized) { 1 } else { 0 }
                            }; Descending = $true
                        },
                        @{ Expression     = {
                                if ($requestedSoftwareNameNormalized -and $_.Name.Trim().ToLowerInvariant().Contains($requestedSoftwareNameNormalized)) { 1 } else { 0 }
                            }; Descending = $true
                        },
                        @{ Expression = { $_.Count }; Descending = $true },
                        @{ Expression = { $_.Name.Length }; Descending = $false }
                    ) |
                    Select-Object -First 1).Name

                Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Auto-selected software name' -Detail ("Multiple candidates detected; selected '{0}'." -f $SoftwareName)
                $skipPrompt = $true
            }

            if (-not $skipPrompt -and $softwareNameCandidates.Count -gt 1) {

                if ($NonInteractive) {
                    Write-LogEvent -Level 'ERROR' -Scope 'Discovery' -Action 'Ambiguous software name' -Detail ("Multiple candidates require input, but NonInteractive is set. Candidates: {0}" -f ($softwareNameCandidates -join ', '))
                    return
                }

                Write-SectionHeader -Message 'Multiple software name candidates found:'

                # Build stats for display
                $candidateStats = foreach ($candidate in $softwareNameCandidates) {
                    [PSCustomObject]@{
                        Name  = $candidate
                        Count = ($matchingCollections | Where-Object { $_.Name -like ("*" + $candidate + "*") }).Count
                    }
                }

                for ($i = 0; $i -lt $candidateStats.Count; $i++) {
                    Write-ResultLine -Message (("[{0}] {1}  (matches: {2})" `
                                -f ($i + 1), $candidateStats[$i].Name, $candidateStats[$i].Count))
                }

                $selection = Read-Host "Enter the number of the correct software name"

                if ($selection -match '^\d+$' -and
                    $selection -ge 1 -and
                    $selection -le $candidateStats.Count) {

                    $SoftwareName = $candidateStats[$selection - 1].Name
                    Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'User-selected software name' -Detail $SoftwareName
                } else {
                    Write-LogEvent -Level 'ERROR' -Scope 'Discovery' -Action 'Invalid user selection' -Detail 'Aborting run.'
                    return
                }
            }
        }

        # ------------------------------------------------------------
        # RESOLVE CANONICAL NAME (AFTER AUTO-DETECTION)
        # ------------------------------------------------------------
        # Phase 4: resolve canonical naming used for master objects and reporting.
        $resolvedSoftwareName = $SoftwareName
        $canonicalName = Get-CanonicalName -SoftwareName $SoftwareName

        Write-LogEvent -Level 'INFO' -Scope 'Discovery' -Action 'Collections in scope' -Detail (("{0} for '{1}'") -f $allCollections.Count, $canonicalName)


        # ------------------------------------------------------------
        # ENSURE MASTER COLLECTIONS EXIST
        # ------------------------------------------------------------
        # Phase 5: create/locate master collections and place them in target folder.
        $masters = Set-MasterCollections `
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
            Update-MasterCollections `
                -CanonicalName $canonicalName `
                -RequestedSoftwareName $resolvedSoftwareName `
                -Masters $masters `
                -AllCollections $allCollections
        } else {
            Write-LogEvent -Level 'ERROR' -Scope 'Run' -Action 'Populate master collections skipped' -Detail 'AllCollections is null or empty.'
        }

        # ------------------------------------------------------------
        # APPLY SUPERSEDENCE AND DEPLOYMENTS
        # ------------------------------------------------------------
        # Phase 7: apply optional supersedence chain for version progression.
        Set-SupersedenceAndDeployments `
            -SoftwareName $resolvedSoftwareName `
            -ManageSupersedence:$ManageSupersedence

        # Supersedence creates new app revisions in SCCM, invalidating any
        # cached WMI proxy objects fetched before the operation. Force a fresh
        # fetch for the cleanup phase so property access doesn't hit stale refs.
        Reset-SccmRuntimeCaches -IncludeAppCaches

        # ------------------------------------------------------------
        # CLEANUP OLD COLLECTIONS
        # ------------------------------------------------------------
        # Phase 8: migrate/delete legacy artifacts in dependency-safe order.
        Invoke-CleanupPlan `
            -SoftwareName $resolvedSoftwareName `
            -Masters $masters `
            -AllCollections $allCollections `
            -DeleteOldCollections:$DeleteOldCollections

        # Phase 9: retry transient failures after provider state has settled.
        Invoke-FailedDeletionRetry `
            -RetryCount $RetryCount `
            -RetryDelaySeconds $RetryDelaySeconds

        # Phase 10: persist failures/audit data for post-run review.
        Export-FailedObjectsToCsv -BasePath "C:\Temp\SCCMCleanupResults"
    }

    if ($DryRun) {
        Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Completed in DryRun mode' -Detail 'No changes were performed.'
    } else {
        Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Completed'
    }

    # End-of-run summary
    $summaryLines = @()
    $summaryLines += ("  Collections processed : {0}" -f @($allCollections).Count)
    $summaryLines += ("  Deployment migrations : {0}" -f ($deploymentMigrationAudit | Where-Object { $_.Status -in @('Created', 'Planned') }).Count)
    $summaryLines += ("  Failed apps           : {0}" -f $failedApps.Count)
    $summaryLines += ("  Failed collections    : {0}" -f $failedCollections.Count)
    $summaryLines += ("  Failed deployments    : {0}" -f $failedDeployments.Count)
    Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Summary'
    foreach ($line in $summaryLines) { Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Summary line' -Detail $line.Trim() }
} finally {
    $ConfirmPreference = $__OldConfirmPreference
    $ProgressPreference = $__OldProgressPreference

    try { Write-LogEvent -Level 'INFO' -Scope 'Run' -Action 'Restored session preferences' -Detail 'ConfirmPreference and ProgressPreference.' } catch { Write-Verbose 'Failed to record session preference restoration.' }
}
