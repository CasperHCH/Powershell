<#
.SYNOPSIS
Performs read-only analysis of SCCM device collections for consolidation and delete safety.

.DESCRIPTION
This script inspects device collections and reports potential consolidation groups
and safe-to-delete status without changing any SCCM data.

Analysis modes:
- Consolidation analysis: groups collections by parsed software identity,
  suffix, and version to find version-sprawl candidates.
- Safe-to-delete analysis: evaluates deployments, membership rules,
  include/exclude dependencies, limiting collection dependencies, and optional
  deep query references.

Safety model:
- Read-only reporting only (no mutation cmdlets are used).
- Optional filtering lets you scope analysis to a software family or folder path.
- Optional cap limits maximum number of collections analyzed for faster previews.

.PARAMETER SiteCode
SCCM site code. If omitted, the script attempts auto-detection from
SMS_ProviderLocation.

.PARAMETER SoftwareNameContains
Optional wildcard-like substring filter applied to collection names before
analysis.

.PARAMETER FolderPathContains
Optional wildcard-like substring filter applied to resolved folder paths before
analysis.

.PARAMETER ExcludeCollectionNamePattern
Optional wildcard pattern used to exclude collections by collection name after
include filters are applied.

.PARAMETER ExcludeFolderPathPattern
Optional wildcard pattern used to exclude collections by folder path after
include filters are applied.

.PARAMETER MaxCollectionsToAnalyze
Optional hard limit on how many scoped collections to analyze.
Use 0 for no limit.

.PARAMETER ProgressInterval
Controls progress-log cadence for long loops.
- 0 disables progress logs.
- N (>0) logs every N processed scoped collections.

.PARAMETER AnalyzeConsolidation
Runs consolidation analysis only.

.PARAMETER ConsolidationCanonicalPerVersion
When used with AnalyzeConsolidation, emits one canonical row per software
version (prefers install over uninstall) so install/uninstall pairs do not
produce duplicate rows.

.PARAMETER AnalyzeSafeToDelete
Runs safe-to-delete analysis only.

.PARAMETER AnalyzeAll
Runs both consolidation and safe-to-delete analyses.

.PARAMETER Mode
Controls safe-to-delete detail depth.
- Standard: focused checks and concise output.
- Deep: includes query-reference deep scan.

.PARAMETER Quiet
Suppresses INFO phase logs while keeping WARN/SUCCESS phase logs and primary
result lines.

.PARAMETER IncludeMasterCollections
Includes master collections in analysis output.
Default behavior excludes master collections to reduce output noise.

.PARAMETER OutputCsv
Optional CSV output path.
- Empty value means no export.
- Non-empty value means export to the provided path.
- Relative paths are resolved under the script directory.

.PARAMETER JsonSummaryPath
Optional JSON summary output path.
- Empty value means no JSON summary export.
- Non-empty value means export run summary JSON to the provided path.

.PARAMETER EnableParallelRuleScan
Attempts to parallelize include/exclude dependency rule scans using ThreadJob
when available. Falls back to sequential mode automatically when unsupported.

.PARAMETER ParallelThrottleLimit
Maximum number of concurrent jobs when EnableParallelRuleScan is active.

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeAll -Mode Deep

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeSafeToDelete -Quiet -OutputCsv .\SafeToDeleteReport.csv

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeConsolidation -SoftwareNameContains Adobe -FolderPathContains "Application Deployment" -MaxCollectionsToAnalyze 250

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeConsolidation -ConsolidationCanonicalPerVersion -FolderPathContains "Application Deployment"

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeAll -IncludeMasterCollections

.EXAMPLE
.\SCCM-CollectionAnalyse.ps1 -SiteCode P03 -AnalyzeAll -ProgressInterval 250 -JsonSummaryPath .\Summary.json
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$SiteCode,

    [AllowEmptyString()]
    [string]$SoftwareNameContains = "",

    [AllowEmptyString()]
    [string]$FolderPathContains = "",

    [AllowEmptyString()]
    [string]$ExcludeCollectionNamePattern = "",

    [AllowEmptyString()]
    [string]$ExcludeFolderPathPattern = "",

    [ValidateRange(0, 1000000)]
    [int]$MaxCollectionsToAnalyze = 0,

    [ValidateRange(0, 1000000)]
    [int]$ProgressInterval = 100,

    [switch]$AnalyzeConsolidation,
    [switch]$AnalyzeSafeToDelete,
    [switch]$AnalyzeAll,

    [switch]$ConsolidationCanonicalPerVersion,

    [ValidateSet('Standard','Deep')]
    [string]$Mode = 'Standard',

    [switch]$Quiet,

    [switch]$IncludeMasterCollections,

    [AllowEmptyString()]
    [string]$OutputCsv = "",

    [AllowEmptyString()]
    [string]$JsonSummaryPath = "",

    [switch]$EnableParallelRuleScan,

    [ValidateRange(1, 128)]
    [int]$ParallelThrottleLimit = 8

)

<#
.SYNOPSIS
Writes timestamped phase logs with optional INFO suppression.

.DESCRIPTION
Central logging helper for analysis progress. When Quiet is enabled,
INFO-level phase logs are suppressed while WARN and SUCCESS remain visible.

.PARAMETER Message
Log message text.

.PARAMETER Level
Log severity level. Allowed values: INFO, WARN, SUCCESS.
#>
function Write-PhaseLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO','WARN','SUCCESS')]
        [string]$Level = 'INFO'
    )

    if ($Quiet -and $Level -eq 'INFO') {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host ("{0} [{1}] {2}" -f $timestamp, $Level, $Message)
}

<#
.SYNOPSIS
Returns whether progress should be emitted at a given iteration.

.DESCRIPTION
Uses ProgressInterval to decide if periodic progress logging should occur.

.PARAMETER ProcessedCount
Current processed item count.

.OUTPUTS
System.Boolean
#>
function Should-EmitProgress {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessedCount
    )

    if ($ProgressInterval -le 0) {
        return $false
    }

    return (($ProcessedCount % $ProgressInterval) -eq 0)
}

<#
.SYNOPSIS
Validates and resolves an output file path.

.DESCRIPTION
Ensures an output path has valid syntax, points to a file (not a directory),
and that the parent folder exists. Relative paths are resolved under ScriptDir.

.PARAMETER Path
Raw output path from an output parameter.

.PARAMETER ScriptDir
Script directory used to resolve relative paths.

.OUTPUTS
System.String
#>
function Resolve-ValidatedOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ScriptDir
    )

    $trimmedPath = [string]$Path
    if ([string]::IsNullOrWhiteSpace($trimmedPath)) {
        throw 'Output path is empty.'
    }

    $trimmedPath = $trimmedPath.Trim()

    # Reject obvious invalid path characters early.
    if ($trimmedPath.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) {
        throw ("Output path contains invalid characters: '{0}'" -f $trimmedPath)
    }

    $resolvedPath = $trimmedPath
    if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
        $resolvedPath = Join-Path $ScriptDir $resolvedPath
    }

    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($resolvedPath)
    }
    catch {
        throw ("Output path is not valid: '{0}' | {1}" -f $trimmedPath, $_.Exception.Message)
    }

    if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
        throw ("Output path must be a file path, but a directory was provided: '{0}'" -f $resolvedPath)
    }

    $parentDir = Split-Path -Path $resolvedPath -Parent
    if ([string]::IsNullOrWhiteSpace($parentDir) -or -not (Test-Path -LiteralPath $parentDir -PathType Container)) {
        throw ("Output path parent directory does not exist: '{0}'" -f $parentDir)
    }

    return $resolvedPath
}

$scriptStart = Get-Date
$script:DeploymentCacheByCollectionId = @{}
$script:ApplicationAssignmentsCacheByCollectionId = @{}
$script:MembershipRulesCacheByCollectionId = @{}
$script:QueryRulesCacheByCollectionId = @{}
$script:AnalysisWarningCounts = @{
    DeploymentQueryFailures = 0
    ApplicationAssignmentQueryFailures = 0
    MembershipRuleFailures = 0
    QueryRuleFailures = 0
    DeepReferenceHeuristicMatches = 0
}

# ---------------------------------------------------------
# STARTUP AND SITE CONTEXT RESOLUTION
# ---------------------------------------------------------

if (-not $AnalyzeConsolidation -and -not $AnalyzeSafeToDelete -and -not $AnalyzeAll) {
    Write-Host "No analysis mode selected. Defaulting to AnalyzeConsolidation." -ForegroundColor Yellow
    $AnalyzeConsolidation = $true
    
}

if ($AnalyzeAll) {
    $AnalyzeConsolidation = $true
    $AnalyzeSafeToDelete  = $true
}

if (-not $SiteCode) {
    Write-PhaseLog -Message 'SiteCode not provided. Attempting auto-detection from SMS provider.'
    try {
        $provider = Get-CimInstance -Namespace "root\SMS" -ClassName SMS_ProviderLocation | Select-Object -First 1
        $SiteCode = $provider.SiteCode
        Write-PhaseLog -Message ("Auto-detected SiteCode: {0}" -f $SiteCode) -Level 'SUCCESS'
    }
    catch {
        Write-PhaseLog -Message 'Could not auto-detect SiteCode.' -Level 'WARN'
        return
    }
}

Write-Host "=== SCCM Collection Analyse (SiteCode: $SiteCode, Mode: $Mode) ===" -ForegroundColor Cyan
Write-PhaseLog -Message ("Analysis start: SiteCode={0}; Mode={1}; Consolidation={2}; SafeToDelete={3}; DeepMode={4}; IncludeMasterCollections={5}" -f $SiteCode, $Mode, $AnalyzeConsolidation.IsPresent, $AnalyzeSafeToDelete.IsPresent, ($Mode -eq 'Deep'), $IncludeMasterCollections.IsPresent)
Write-PhaseLog -Message ("Filters: SoftwareNameContains='{0}', FolderPathContains='{1}', ExcludeCollectionNamePattern='{2}', ExcludeFolderPathPattern='{3}', MaxCollectionsToAnalyze={4}, ProgressInterval={5}" -f $SoftwareNameContains, $FolderPathContains, $ExcludeCollectionNamePattern, $ExcludeFolderPathPattern, $MaxCollectionsToAnalyze, $ProgressInterval)

$uiPath = $env:SMS_ADMIN_UI_PATH
if (-not $uiPath) { throw "SMS_ADMIN_UI_PATH not found." }

$cmModule = Join-Path (Split-Path $uiPath -Parent) "ConfigurationManager.psd1"
Write-PhaseLog -Message ("Importing module: {0}" -f $cmModule)
Import-Module $cmModule -ErrorAction Stop

Set-Location "$SiteCode`:"
Write-PhaseLog -Message ("Connected to SCCM drive: {0}:" -f $SiteCode) -Level 'SUCCESS'

# ---------------------------------------------------------
# WMI / CIM
# ---------------------------------------------------------

$namespace = "root\SMS\site_$SiteCode"
Write-PhaseLog -Message ("Loading metadata from namespace {0}..." -f $namespace)

$folders = Get-CimInstance -Namespace $namespace -ClassName SMS_ObjectContainerNode |
           Where-Object { $_.ObjectType -eq 5000 } |
           Sort-Object Name

$items   = Get-CimInstance -Namespace $namespace -ClassName SMS_ObjectContainerItem |
           Where-Object { $_.ObjectType -eq 5000 }

$allCollections = @(Get-CMDeviceCollection -ErrorAction SilentlyContinue)
Write-PhaseLog -Message ("Metadata loaded: Folders={0}; ContainerItems={1}; Collections={2}" -f @($folders).Count, @($items).Count, @($allCollections).Count) -Level 'SUCCESS'

$collectionById = @{}
foreach ($c in $allCollections) {
    $collectionById[$c.CollectionID] = $c
}

$folderByNodeId = @{}
foreach ($folder in @($folders)) {
    if (-not $folder) { continue }

    $nodeId = $null
    try { $nodeId = [uint32]$folder.ContainerNodeID } catch { $nodeId = $null }
    if ($null -eq $nodeId) { continue }

    if (-not $folderByNodeId.ContainsKey($nodeId)) {
        $folderByNodeId[$nodeId] = $folder
    }
}

# ---------------------------------------------------------
# FOLDER PATH
# ---------------------------------------------------------

<#
.SYNOPSIS
Resolves a full folder path from a ContainerNodeID.

.DESCRIPTION
Builds a Device Collections path by walking parent links in the pre-built
folderByNodeId index. Returns a ROOT placeholder when the node is not found.

.PARAMETER ContainerNodeID
Container node identifier from SCCM folder metadata.

.OUTPUTS
System.String
#>
function Get-FolderPath {
    param([uint32]$ContainerNodeID)

    $pathParts = @()
    $current = $null
    if ($folderByNodeId.ContainsKey($ContainerNodeID)) {
        $current = $folderByNodeId[$ContainerNodeID]
    }

    while ($current) {
        $pathParts += $current.Name

        $parentNodeId = $null
        try { $parentNodeId = [uint32]$current.ParentContainerNodeID } catch { $parentNodeId = $null }

        if ($null -eq $parentNodeId -or -not $folderByNodeId.ContainsKey($parentNodeId)) {
            $current = $null
        }
        else {
            $current = $folderByNodeId[$parentNodeId]
        }
    }

    if ($pathParts.Count -eq 0) {
        return "Device Collections\<ROOT>"
    }

    return ("Device Collections\" + ($pathParts[-1..0] -join "\"))
}

<#
.SYNOPSIS
Evaluates whether a collection matches active scope filters.

.DESCRIPTION
Applies optional SoftwareNameContains and FolderPathContains filters to decide
whether a candidate collection should be included in the analysis scope.

.PARAMETER CollectionName
Collection display name.

.PARAMETER FolderPath
Resolved collection folder path.

.OUTPUTS
System.Boolean
#>
function Test-CollectionInScope {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName,

        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    if (-not [string]::IsNullOrWhiteSpace($SoftwareNameContains)) {
        if ($CollectionName -notlike ("*{0}*" -f $SoftwareNameContains)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($FolderPathContains)) {
        if ($FolderPath -notlike ("*{0}*" -f $FolderPathContains)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExcludeCollectionNamePattern)) {
        if ($CollectionName -like $ExcludeCollectionNamePattern) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExcludeFolderPathPattern)) {
        if ($FolderPath -like $ExcludeFolderPathPattern) {
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS
Determines whether a collection name matches master-collection naming.

.DESCRIPTION
Identifies canonical master collections used by consolidation workflows:
<Software> - Install (Available), <Software> - Install (Required),
and <Software> - Uninstall.

.PARAMETER CollectionName
Collection display name to evaluate.

.OUTPUTS
System.Boolean
#>
function Test-IsMasterCollectionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionName
    )

    if ([string]::IsNullOrWhiteSpace($CollectionName)) {
        return $false
    }

    return ($CollectionName -match ' - Install \(Available\)$' -or
            $CollectionName -match ' - Install \(Required\)$'  -or
            $CollectionName -match ' - Uninstall$')
}

# ---------------------------------------------------------
# PREPARE SCOPED ANALYSIS CANDIDATES
# ---------------------------------------------------------
# Build one filtered candidate list used by all analysis modes.
# This avoids duplicated filtering logic and keeps counts consistent.

$scopedItems = New-Object System.Collections.Generic.List[object]
$masterCollectionsExcluded = 0
foreach ($ci in @($items)) {
    if (-not $ci) { continue }

    $colId = [string]$ci.InstanceKey
    if ([string]::IsNullOrWhiteSpace($colId)) { continue }
    if (-not $collectionById.ContainsKey($colId)) { continue }

    $colObj = $collectionById[$colId]
    if (-not $colObj) { continue }

    $collectionName = [string]$colObj.Name
    $folderPath = Get-FolderPath -ContainerNodeID $ci.ContainerNodeID

    if (-not $IncludeMasterCollections -and (Test-IsMasterCollectionName -CollectionName $collectionName)) {
        $masterCollectionsExcluded++
        continue
    }

    if (-not (Test-CollectionInScope -CollectionName $collectionName -FolderPath $folderPath)) {
        continue
    }

    [void]$scopedItems.Add([pscustomobject]@{
        ContainerItem = $ci
        CollectionID  = $colId
        Collection    = $colObj
        CollectionName = $collectionName
        FolderPath    = $folderPath
    })

    if ($MaxCollectionsToAnalyze -gt 0 -and $scopedItems.Count -ge $MaxCollectionsToAnalyze) {
        break
    }
}

Write-PhaseLog -Message (
    "Scope filtering complete: Candidates={0}; Filters: SoftwareNameContains='{1}', FolderPathContains='{2}', MaxCollectionsToAnalyze={3}" -f
    $scopedItems.Count, $SoftwareNameContains, $FolderPathContains, $MaxCollectionsToAnalyze
)

if (-not $IncludeMasterCollections) {
    Write-PhaseLog -Message ("Master collections excluded from output: {0} (use -IncludeMasterCollections to include them)." -f $masterCollectionsExcluded)
}

if ($scopedItems.Count -eq 0) {
    Write-PhaseLog -Message 'No collections match current scope filters. Exiting.' -Level 'WARN'
    Write-Host ""
    Write-Host "=== Analysis complete - no SCCM changes were made ===" -ForegroundColor Cyan
    return
}

# ---------------------------------------------------------
# VERSIONDETEKTION (Model D – aggressiv)
# ---------------------------------------------------------

<#
.SYNOPSIS
Extracts a version token from free-form text.

.DESCRIPTION
Uses a regex pattern that supports leading v and 1-5 numeric parts,
including optional suffix components.

.PARAMETER Text
Input text to parse.

.OUTPUTS
System.String
#>
function Get-Version {
    param([string]$Text)

    if (-not $Text) { return $null }

    # Only treat tokens as versions when they are delimited and have at least
    # one dot, a leading v-prefix, or multiple numeric parts. This avoids
    # stripping product names like 7-zip down to zip.
    $versionPattern = '(?<![A-Za-z0-9])((?:v\d+(?:\.\d+){1,4})|(?:\d+\.\d+(?:\.\d+){0,3})(?:-[A-Za-z0-9]+)?)\b'

    $m = [regex]::Match($Text, $versionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        return $m.Groups[1].Value.Trim()
    }

    return $null
}

# ---------------------------------------------------------
# SUFFIXDETEKTION (Model D)
# ---------------------------------------------------------

<#
.SYNOPSIS
Extracts environment or functional suffix text from a name.

.DESCRIPTION
Supports dash style suffixes, parenthesis suffixes, and known trailing words
such as Pilot, Production, Test, and similar labels.

.PARAMETER Text
Input text to parse.

.OUTPUTS
System.String
#>
function Get-Suffix {
    param([string]$Text)

    if (-not $Text) { return "" }

    if ($Text -match '(?i)(?:^|[\s\-_])(install|uninstall|repair|cleanup)\b') {
        return $matches[1].ToLowerInvariant()
    }

    if ($Text -match '–\s*(.+)$') {
        return $matches[1].Trim()
    }

    if ($Text -match '\(([^)]+)\)$') {
        return $matches[1].Trim()
    }

    $knownSuffix = @(
        "Installed","Not Installed","Pilot","Production","Test","Dev","Stable","Beta","Canary"
    )

    foreach ($s in $knownSuffix) {
        if ($Text -like "* $s") {
            return $s
        }
    }

    return ""
}

# ---------------------------------------------------------
# SOFTWARENAVN
# ---------------------------------------------------------

<#
.SYNOPSIS
Normalizes software name text by removing version and suffix parts.

.DESCRIPTION
Strips parsed version/suffix fragments and normalizes separators and spacing
to produce a stable software-name key for grouping.

.PARAMETER Text
Original collection or folder name.

.PARAMETER Version
Previously parsed version token to remove.

.PARAMETER Suffix
Previously parsed suffix token to remove.

.OUTPUTS
System.String
#>
function Get-SoftwareName {
    param(
        [string]$Text,
        [string]$Version,
        [string]$Suffix
    )

    $name = $Text

    if ($Version) {
        $name = $name -replace [regex]::Escape($Version), ""
    }

    if ($Suffix) {
        $name = $name -replace [regex]::Escape($Suffix), ""
    }

    # Remove residual deployment markers commonly used in SCCM collection names.
    $name = $name -replace '(?i)\(\s*(device|user)\s*\)', ' '
    $name = $name -replace '(?i)\b(required|available|install|uninstall|repair|cleanup)\b', ' '

    $name = $name -replace '[\(\)

\[\]

–\-]', ' '
    $name = ($name -replace '\s+', ' ').Trim()
    $name = $name -replace '(?i)\s+(device|user)$', ''
    $name = ($name -replace '\s+', ' ').Trim()

    return $name
}

function ConvertTo-SoftwareKey {
    param([string]$SoftwareName)

    if ([string]::IsNullOrWhiteSpace($SoftwareName)) {
        return $null
    }

    $normalizedName = [string]$SoftwareName
    $normalizedName = $normalizedName -replace '(?i)\b(required|available|install|uninstall|repair|cleanup)\b', ' '
    $normalizedName = ($normalizedName -replace '\s+', ' ').Trim().ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($normalizedName)) {
        return $null
    }

    return $normalizedName
}

# ---------------------------------------------------------
# PARSER
# ---------------------------------------------------------

<#
.SYNOPSIS
Parses software identity fields from collection and folder names.

.DESCRIPTION
Builds a normalized identity object with Software, Version, and Suffix by
combining collection-name and folder-name parsing heuristics.

.PARAMETER CollectionName
SCCM collection name.

.PARAMETER FolderName
Leaf folder name where the collection resides.

.OUTPUTS
PSCustomObject
#>
function Parse-CollectionIdentity {
    param(
        [string]$CollectionName,
        [string]$FolderName
    )

    $colVersion = Get-Version $CollectionName
    $folderVersion = Get-Version $FolderName

    $version = $colVersion
    if (-not $version) { $version = $folderVersion }

    $suffix = Get-Suffix $CollectionName
    if (-not $suffix) { $suffix = Get-Suffix $FolderName }

    $software = Get-SoftwareName -Text $CollectionName -Version $version -Suffix $suffix

    return [PSCustomObject]@{
        Software = $software
        Version  = $version
        Suffix   = $suffix
    }
}

$analysisCollectionNameById = @{}
$analysisInstallCollectionIdsBySoftware = @{}

foreach ($containerItem in @($items)) {
    if (-not $containerItem) { continue }

    $analysisCollectionId = [string]$containerItem.InstanceKey
    if ([string]::IsNullOrWhiteSpace($analysisCollectionId)) { continue }
    if (-not $collectionById.ContainsKey($analysisCollectionId)) { continue }

    $analysisCollection = $collectionById[$analysisCollectionId]
    if (-not $analysisCollection) { continue }

    $analysisCollectionName = [string]$analysisCollection.Name
    $analysisFolderPath = Get-FolderPath -ContainerNodeID $containerItem.ContainerNodeID
    $analysisFolderLeaf = Split-Path -Path $analysisFolderPath -Leaf
    $analysisIdentity = Parse-CollectionIdentity -CollectionName $analysisCollectionName -FolderName $analysisFolderLeaf

    $analysisCollectionNameById[$analysisCollectionId] = $analysisCollectionName

    if ([string]$analysisIdentity.Suffix -ieq 'install' -and -not [string]::IsNullOrWhiteSpace([string]$analysisIdentity.Software)) {
        $softwareKey = ConvertTo-SoftwareKey -SoftwareName ([string]$analysisIdentity.Software)
        if ([string]::IsNullOrWhiteSpace($softwareKey)) { continue }
        if (-not $analysisInstallCollectionIdsBySoftware.ContainsKey($softwareKey)) {
            $analysisInstallCollectionIdsBySoftware[$softwareKey] = New-Object System.Collections.Generic.List[string]
        }

        [void]$analysisInstallCollectionIdsBySoftware[$softwareKey].Add($analysisCollectionId)
    }
}

<#
.SYNOPSIS
Converts version-like text into a sortable System.Version value.

.DESCRIPTION
Normalizes version text for semantic sorting and returns 0.0.0.0 when parsing
fails to avoid exceptions in report processing.

.PARAMETER VersionText
Version text to convert.

.OUTPUTS
System.Version
#>
function Convert-ToSortableVersion {
    param([string]$VersionText)

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return [version]'0.0.0.0'
    }

    $clean = [string]$VersionText
    $clean = $clean -replace '^[vV]', ''

    $match = [regex]::Match($clean, '\d+(\.\d+){0,3}')
    if (-not $match.Success) {
        return [version]'0.0.0.0'
    }

    $parts = @($match.Value.Split('.'))
    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    try {
        return [version]($parts[0..3] -join '.')
    }
    catch {
        return [version]'0.0.0.0'
    }
}

function Get-ConsolidationRowPriority {
    param(
        [string]$Suffix,
        [string]$CollectionName
    )

    $suffixValue = [string]$Suffix
    if ($suffixValue -ieq 'install') { return 0 }
    if ($suffixValue -ieq 'uninstall') { return 1 }
    if ($suffixValue -ieq 'repair') { return 2 }
    if ($suffixValue -ieq 'cleanup') { return 3 }

    if ([string]$CollectionName -match '(?i)\binstall\b') { return 4 }
    if ([string]$CollectionName -match '(?i)\buninstall\b') { return 5 }

    return 9
}
# ---------------------------------------------------------
# KONSOLIDERING
# ---------------------------------------------------------

$results = @()

# ---------------------------------------------------------
# MAIN ANALYSIS EXECUTION
# ---------------------------------------------------------

if ($AnalyzeConsolidation) {

    Write-Host ""
    Write-Host "=== Consolidation analysis (global, version + suffix based) ===" -ForegroundColor Cyan
    Write-PhaseLog -Message 'Consolidation analysis started.'
    if ($ConsolidationCanonicalPerVersion) {
        Write-PhaseLog -Message 'Canonical consolidation mode enabled: one representative row per software-version.'
    }

    $parsedList = @()
    $processedConsolidationItems = 0

    foreach ($entry in $scopedItems) {
        $processedConsolidationItems++
        if (Should-EmitProgress -ProcessedCount $processedConsolidationItems) {
            Write-PhaseLog -Message ("Consolidation scan progress: {0}/{1} scoped collections processed." -f $processedConsolidationItems, $scopedItems.Count)
        }

        if (-not $entry) { continue }

        $colId = [string]$entry.CollectionID
        $colObj = $entry.Collection
        $folderPath = [string]$entry.FolderPath
        $folderName = Split-Path $folderPath -Leaf

        $parsed = Parse-CollectionIdentity -CollectionName $colObj.Name -FolderName $folderName

        $parsedList += [PSCustomObject]@{
            CollectionID   = $colObj.CollectionID
            CollectionName = $colObj.Name
            FolderPath     = $folderPath
            Software       = $parsed.Software
            Version        = $parsed.Version
            Suffix         = $parsed.Suffix
        }
    }

    Write-PhaseLog -Message ("Consolidation parsing complete: {0} candidate entries." -f @($parsedList).Count)

# Functional suffixes should remain separate grouping tracks.
$functionalSuffixes = @("install", "uninstall", "repair", "cleanup")

# Add GroupKey for deterministic grouping.
$parsedList = $parsedList | ForEach-Object {
    $suffixLower = $_.Suffix.ToLower()

    if ($ConsolidationCanonicalPerVersion) {
        # Merge install/uninstall into one software-level track.
        $groupKey = "$($_.Software)|<canonical>"
    }
    elseif ($functionalSuffixes -contains $suffixLower) {
        # Install/uninstall remain separate groups.
        $groupKey = "$($_.Software)|$suffixLower"
    }
    else {
        # Environment suffixes collapse into one track.
        $groupKey = "$($_.Software)|<env>"
    }

    $_ | Add-Member -NotePropertyName GroupKey -NotePropertyValue $groupKey -Force
    $_
}

# Group by GroupKey and sort by software name for deterministic log/output order.
$groups = @($parsedList | Group-Object -Property GroupKey | Sort-Object {
    [string]$_.Group[0].Software
})
    Write-PhaseLog -Message ("Consolidation grouping complete: {0} groups." -f @($groups).Count)


    foreach ($g in $groups) {

        $software = $g.Group[0].Software
        $suffix   = $g.Group[0].Suffix

        $versions = @($g.Group | Where-Object { $_.Version } | Sort-Object -Property @(
            @{ Expression = { Convert-ToSortableVersion -VersionText $_.Version }; Descending = $false },
            @{ Expression = { [string]$_.Version }; Descending = $false },
            @{ Expression = { Get-ConsolidationRowPriority -Suffix $_.Suffix -CollectionName $_.CollectionName }; Descending = $false },
            @{ Expression = { [string]$_.CollectionName }; Descending = $false }
        ))

        if ($ConsolidationCanonicalPerVersion) {
            $canonicalRows = @()
            foreach ($versionGroup in @($versions | Group-Object -Property Version)) {
                if (-not $versionGroup) { continue }

                $candidates = @($versionGroup.Group | Sort-Object -Property @(
                    @{ Expression = { Get-ConsolidationRowPriority -Suffix $_.Suffix -CollectionName $_.CollectionName }; Descending = $false },
                    @{ Expression = { [string]$_.CollectionName }; Descending = $false }
                ))

                if (@($candidates).Count -gt 0) {
                    $canonicalRows += $candidates[0]
                }
            }

            $versions = @($canonicalRows | Sort-Object -Property @(
                @{ Expression = { Convert-ToSortableVersion -VersionText $_.Version }; Descending = $false },
                @{ Expression = { [string]$_.Version }; Descending = $false }
            ))
        }

# Skip when only one unique version exists but multiple function suffixes exist.
$uniqueVersions = ($g.Group.Version | Where-Object { $_ } | Select-Object -Unique)
$uniqueSuffixes = ($g.Group.Suffix  | Where-Object { $_ } | Select-Object -Unique)

# If only one version but multiple suffixes, skip as non-consolidation signal.
if ($uniqueVersions.Count -eq 1 -and $uniqueSuffixes.Count -gt 1) {
    continue
}

        if ($versions.Count -le 1) { continue }

        Write-Host ""
        Write-Host ("Software: {0}" -f $software) -ForegroundColor Magenta

        $displaySuffix = if ($ConsolidationCanonicalPerVersion) {
            '<canonical>'
        }
        elseif ($suffix -ne "") {
            $suffix
        }
        else {
            "<none>"
        }
        Write-Host ("Suffix:   {0}" -f $displaySuffix) -ForegroundColor DarkGray

        Write-Host ("Found versions: {0}" -f ($versions.Version -join ", ")) -ForegroundColor Cyan

        foreach ($item in $versions) {
            Write-Host ("  - {0} (ID: {1}) [{2}]" -f $item.CollectionName, $item.CollectionID, $item.FolderPath)

            $results += [PSCustomObject]@{
                Type           = 'Consolidation'
                FolderPath     = $item.FolderPath
                Software       = $item.Software
                CollectionName = $item.CollectionName
                Version        = $item.Version
                CollectionID   = $item.CollectionID
                Status         = 'VersionGroup'
                Reason         = "Multiple versions detected for same software + suffix"
                DataQuality    = 'Complete'
                AnalysisConfidence = 'High'
            }
        }
    }

    $consolidationResultCount = @($results | Where-Object { $_.Type -eq 'Consolidation' }).Count
    Write-PhaseLog -Message ("Consolidation analysis finished: {0} report rows." -f $consolidationResultCount) -Level 'SUCCESS'
}

# ---------------------------------------------------------
# SAFE‑TO‑DELETE
# ---------------------------------------------------------

<#
.SYNOPSIS
Returns deployments targeting a collection.

.DESCRIPTION
Wraps Get-CMDeployment in array-safe handling so single-item returns do not
break downstream Count-based logic.

.PARAMETER CollectionID
Collection identifier to query.

.OUTPUTS
System.Object[]
#>
function Get-CollectionDeployments {
    param([string]$CollectionID)

    $cacheKey = [string]$CollectionID
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return @()
    }

    if ($script:DeploymentCacheByCollectionId.ContainsKey($cacheKey)) {
        return @($script:DeploymentCacheByCollectionId[$cacheKey])
    }

    try {
        $deployments = @(Get-CMDeployment -CollectionId $CollectionID -ErrorAction SilentlyContinue)
        $script:DeploymentCacheByCollectionId[$cacheKey] = @($deployments)
        return @($deployments)
    }
    catch {
        $script:AnalysisWarningCounts.DeploymentQueryFailures++
        $script:DeploymentCacheByCollectionId[$cacheKey] = @()
        return @()
    }
}

function Get-CollectionApplicationAssignments {
    param([string]$CollectionID)

    $cacheKey = [string]$CollectionID
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return @()
    }

    if ($script:ApplicationAssignmentsCacheByCollectionId.ContainsKey($cacheKey)) {
        return @($script:ApplicationAssignmentsCacheByCollectionId[$cacheKey])
    }

    try {
        $escapedCollectionId = $cacheKey.Replace("'", "''")
        $assignments = @(Get-CimInstance -Namespace $namespace -ClassName SMS_ApplicationAssignment -Filter ("TargetCollectionID = '{0}'" -f $escapedCollectionId) -ErrorAction Stop)
        $script:ApplicationAssignmentsCacheByCollectionId[$cacheKey] = @($assignments)
        return @($assignments)
    }
    catch {
        $script:AnalysisWarningCounts.ApplicationAssignmentQueryFailures++
        $script:ApplicationAssignmentsCacheByCollectionId[$cacheKey] = @()
        return @()
    }
}

function Resolve-ApplicationAssignmentPurpose {
    param([Parameter(Mandatory = $false)][AllowNull()]$Assignment)

    if ($null -eq $Assignment) { return 'Unknown' }

    $offerTypeId = $null
    try { $offerTypeId = $Assignment.OfferTypeID } catch { $offerTypeId = $null }
    if ($null -ne $offerTypeId) {
        switch ([int]$offerTypeId) {
            0 { return 'Required' }
            2 { return 'Available' }
        }
    }

    return 'Unknown'
}

function Resolve-ApplicationAssignmentAction {
    param([Parameter(Mandatory = $false)][AllowNull()]$Assignment)

    if ($null -eq $Assignment) { return 'Unknown' }

    $desiredConfigType = $null
    try { $desiredConfigType = $Assignment.DesiredConfigType } catch { $desiredConfigType = $null }
    if ($null -ne $desiredConfigType) {
        switch ([string]$desiredConfigType) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    $assignmentAction = $null
    try { $assignmentAction = $Assignment.AssignmentAction } catch { $assignmentAction = $null }
    if ($null -ne $assignmentAction) {
        switch ([string]$assignmentAction) {
            '1' { return 'Install' }
            '2' { return 'Uninstall' }
        }
    }

    return 'Unknown'
}

function Test-ImplicitUninstallEnabled {
    param([Parameter(Mandatory = $false)][AllowNull()]$Assignment)

    if ($null -eq $Assignment) {
        return $false
    }

    $offerFlags = $null
    try { $offerFlags = $Assignment.OfferFlags } catch { $offerFlags = $null }
    if ($null -ne $offerFlags) {
        try {
            if (([uint32]$offerFlags -band 64) -eq 64) {
                return $true
            }
        }
        catch {
        }
    }

    $additionalProperties = $null
    try { $additionalProperties = [string]$Assignment.AdditionalProperties } catch { $additionalProperties = $null }
    if ([string]::IsNullOrWhiteSpace($additionalProperties)) {
        return $false
    }

    try {
        [xml]$xml = $additionalProperties
        $implicitNode = $xml.SelectSingleNode('/Properties/ImplicitUninstallEnabled')
        if ($null -ne $implicitNode) {
            return ([string]$implicitNode.InnerText -match '^(?i:true|1)$')
        }
    }
    catch {
    }

    return $false
}

function Get-CollectionDeploymentSignal {
    param([string]$CollectionID)

    $deployments = @(Get-CollectionDeployments -CollectionID $CollectionID)
    $assignments = @(Get-CollectionApplicationAssignments -CollectionID $CollectionID)

    $requiredInstallAssignments = @($assignments | Where-Object {
        (Resolve-ApplicationAssignmentAction -Assignment $_) -eq 'Install' -and
        (Resolve-ApplicationAssignmentPurpose -Assignment $_) -eq 'Required'
    })

    $requiredUninstallAssignments = @($assignments | Where-Object {
        (Resolve-ApplicationAssignmentAction -Assignment $_) -eq 'Uninstall' -and
        (Resolve-ApplicationAssignmentPurpose -Assignment $_) -eq 'Required'
    })

    $implicitInstallAssignments = @($requiredInstallAssignments | Where-Object { Test-ImplicitUninstallEnabled -Assignment $_ })

    return [pscustomobject]@{
        HasDeployments                    = ($deployments.Count -gt 0 -or $assignments.Count -gt 0)
        GenericDeploymentCount            = $deployments.Count
        ApplicationAssignmentCount        = $assignments.Count
        RequiredInstallAssignmentCount    = $requiredInstallAssignments.Count
        RequiredUninstallAssignmentCount  = $requiredUninstallAssignments.Count
        HasRequiredUninstallDeployment    = ($requiredUninstallAssignments.Count -gt 0)
        HasImplicitUninstallEnabledInstall = ($implicitInstallAssignments.Count -gt 0)
    }
}

function Get-PairedImplicitInstallCoverage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentCollectionId,

        [Parameter(Mandatory = $true)]
        [string]$SoftwareName
    )

    if ([string]::IsNullOrWhiteSpace($SoftwareName)) {
        return $null
    }

    $softwareKey = ConvertTo-SoftwareKey -SoftwareName $SoftwareName
    if ([string]::IsNullOrWhiteSpace($softwareKey)) {
        return $null
    }
    if (-not $analysisInstallCollectionIdsBySoftware.ContainsKey($softwareKey)) {
        return $null
    }

    $candidateIds = @($analysisInstallCollectionIdsBySoftware[$softwareKey].ToArray() | Where-Object { $_ -ne $CurrentCollectionId })
    if ($candidateIds.Count -eq 0) {
        return $null
    }

    $orderedCandidateIds = @(
        $candidateIds | Sort-Object -Property @(
            @{ Expression = {
                $candidateCollectionName = ''
                if ($analysisCollectionNameById.ContainsKey([string]$_)) {
                    $candidateCollectionName = [string]$analysisCollectionNameById[[string]$_]
                }
                if ($candidateCollectionName -match '\(Required\)$') { 0 } else { 1 }
            }; Descending = $false },
            @{ Expression = { [string]$_ }; Descending = $false }
        )
    )

    foreach ($candidateId in $orderedCandidateIds) {
        $candidateSignal = Get-CollectionDeploymentSignal -CollectionID $candidateId
        if (-not $candidateSignal.HasImplicitUninstallEnabledInstall) {
            continue
        }

        return [pscustomobject]@{
            CollectionId   = [string]$candidateId
            CollectionName = if ($analysisCollectionNameById.ContainsKey([string]$candidateId)) { [string]$analysisCollectionNameById[[string]$candidateId] } else { [string]$candidateId }
        }
    }

    return $null
}

<#
.SYNOPSIS
Returns direct/query/include/exclude membership rules for a collection.

.DESCRIPTION
Collects all relevant membership rule types with resilient query wrappers,
returning empty arrays when rule queries are unavailable.

.PARAMETER CollectionID
Collection identifier to query.

.OUTPUTS
PSCustomObject
#>
function Get-CollectionMembershipRules {
    param([string]$CollectionID)

    $cacheKey = [string]$CollectionID
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return [PSCustomObject]@{
            Direct  = @()
            Query   = @()
            Include = @()
            Exclude = @()
            DataQuality = 'Partial'
        }
    }

    if ($script:MembershipRulesCacheByCollectionId.ContainsKey($cacheKey)) {
        return $script:MembershipRulesCacheByCollectionId[$cacheKey]
    }

    $direct  = @()
    $query   = @()
    $include = @()
    $exclude = @()
    $hadFailure = $false

    try { $direct  = @(Get-CMDeviceCollectionDirectMembershipRule  -CollectionId $CollectionID -ErrorAction SilentlyContinue) } catch { $hadFailure = $true }
    try { $query   = @(Get-CMDeviceCollectionQueryMembershipRule   -CollectionId $CollectionID -ErrorAction SilentlyContinue) } catch { $hadFailure = $true }
    try { $include = @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $CollectionID -ErrorAction SilentlyContinue) } catch { $hadFailure = $true }
    try { $exclude = @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $CollectionID -ErrorAction SilentlyContinue) } catch { $hadFailure = $true }

    if ($hadFailure) {
        $script:AnalysisWarningCounts.MembershipRuleFailures++
    }

    $result = [PSCustomObject]@{
        Direct  = $direct
        Query   = $query
        Include = $include
        Exclude = $exclude
        DataQuality = if ($hadFailure) { 'Partial' } else { 'Complete' }
    }

    $script:MembershipRulesCacheByCollectionId[$cacheKey] = $result

    if (-not $script:QueryRulesCacheByCollectionId.ContainsKey($cacheKey)) {
        $script:QueryRulesCacheByCollectionId[$cacheKey] = @($query)
    }

    return $result
}

function Get-CachedQueryMembershipRules {
    param([string]$CollectionID)

    $cacheKey = [string]$CollectionID
    if ([string]::IsNullOrWhiteSpace($cacheKey)) {
        return @()
    }

    if ($script:QueryRulesCacheByCollectionId.ContainsKey($cacheKey)) {
        return @($script:QueryRulesCacheByCollectionId[$cacheKey])
    }

    try {
        $rules = @(Get-CMDeviceCollectionQueryMembershipRule -CollectionId $CollectionID -ErrorAction SilentlyContinue)
        $script:QueryRulesCacheByCollectionId[$cacheKey] = @($rules)
        return @($rules)
    }
    catch {
        $script:AnalysisWarningCounts.QueryRuleFailures++
        $script:QueryRulesCacheByCollectionId[$cacheKey] = @()
        return @()
    }
}

<#
.SYNOPSIS
Finds collections that use the specified collection as limiting collection.

.DESCRIPTION
Searches the loaded allCollections snapshot for LimitingCollectionID matches.

.PARAMETER CollectionID
Collection identifier potentially used as a limiting collection.

.OUTPUTS
System.Object[]
#>
function Get-LimitingCollectionDependents {
    param([string]$CollectionID)
    return @($allCollections | Where-Object { $_.LimitingCollectionID -eq $CollectionID })
}

<#
.SYNOPSIS
Adds a dependency entry to a target-keyed dependency bucket.

.DESCRIPTION
Maintains a unique list of dependent collections per target collection id.
Used while constructing include/exclude dependency indexes.

.PARAMETER Bucket
Hashtable keyed by target collection id.

.PARAMETER TargetCollectionId
Target collection identifier referenced by a dependency rule.

.PARAMETER Dependent
Dependent collection identity object.
#>
function Add-DependencyReference {
    param(
        [hashtable]$Bucket,
        [string]$TargetCollectionId,
        [pscustomobject]$Dependent
    )

    if ([string]::IsNullOrWhiteSpace($TargetCollectionId) -or -not $Dependent) {
        return
    }

    if (-not $Bucket.ContainsKey($TargetCollectionId)) {
        $Bucket[$TargetCollectionId] = New-Object System.Collections.Generic.List[object]
    }

    $existing = @($Bucket[$TargetCollectionId] | Where-Object { $_.CollectionID -eq $Dependent.CollectionID } | Select-Object -First 1)
    if ($existing.Count -eq 0) {
        [void]$Bucket[$TargetCollectionId].Add($Dependent)
    }
}

<#
.SYNOPSIS
Builds incoming include/exclude dependency indexes for collections.

.DESCRIPTION
Traverses candidate collections, inspects include and exclude rules, and
produces dictionaries keyed by target collection id for fast dependency lookup.

.PARAMETER Collections
Collections to inspect while building the index.

.OUTPUTS
PSCustomObject
#>
function Get-CollectionDependencyIndex {
    param([array]$Collections)

    $index = @{
        IncludeByTargetId = @{}
        ExcludeByTargetId = @{}
    }

    $canUseParallelRuleScan = $EnableParallelRuleScan -and (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)
    if ($EnableParallelRuleScan -and -not $canUseParallelRuleScan) {
        Write-PhaseLog -Level 'WARN' -Message 'Parallel rule scan requested but Start-ThreadJob is unavailable. Falling back to sequential scan.'
    }

    if ($canUseParallelRuleScan) {
        $jobs = @()
        $jobResults = New-Object System.Collections.Generic.List[object]

        foreach ($candidate in @($Collections)) {
            if (-not $candidate) { continue }
            $dependentCollectionId = [string]$candidate.CollectionID
            $dependentCollectionName = [string]$candidate.Name
            if ([string]::IsNullOrWhiteSpace($dependentCollectionId)) { continue }

            while (@($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ParallelThrottleLimit) {
                Start-Sleep -Milliseconds 100
            }

            $jobs += Start-ThreadJob -ArgumentList $dependentCollectionId, $dependentCollectionName -ScriptBlock {
                param($CollectionId, $CollectionName)

                $includeRows = @()
                $excludeRows = @()
                $errorText = $null

                try {
                    $includeRules = @(Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue)
                    foreach ($rule in $includeRules) {
                        $targetId = [string]$rule.IncludeCollectionID
                        if ([string]::IsNullOrWhiteSpace($targetId)) { $targetId = [string]$rule.IncludeCollectionId }
                        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
                            $includeRows += [pscustomobject]@{ TargetId = $targetId; DependentId = $CollectionId; DependentName = $CollectionName }
                        }
                    }

                    $excludeRules = @(Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $CollectionId -ErrorAction SilentlyContinue)
                    foreach ($rule in $excludeRules) {
                        $targetId = [string]$rule.ExcludeCollectionID
                        if ([string]::IsNullOrWhiteSpace($targetId)) { $targetId = [string]$rule.ExcludeCollectionId }
                        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
                            $excludeRows += [pscustomobject]@{ TargetId = $targetId; DependentId = $CollectionId; DependentName = $CollectionName }
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }

                return [pscustomobject]@{
                    IncludeRows = $includeRows
                    ExcludeRows = $excludeRows
                    Error = $errorText
                }
            }
        }

        foreach ($job in $jobs) {
            $jobOutput = Receive-Job -Job $job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue
            foreach ($row in @($jobOutput)) {
                if (-not $row) { continue }
                [void]$jobResults.Add($row)
            }
        }

        $successfulRows = 0
        foreach ($row in @($jobResults)) {
            if ($row.Error) {
                $script:AnalysisWarningCounts.MembershipRuleFailures++
                continue
            }

            $successfulRows++

            foreach ($includeRow in @($row.IncludeRows)) {
                Add-DependencyReference -Bucket $index.IncludeByTargetId -TargetCollectionId $includeRow.TargetId -Dependent ([pscustomobject]@{ CollectionID = $includeRow.DependentId; CollectionName = $includeRow.DependentName })
            }

            foreach ($excludeRow in @($row.ExcludeRows)) {
                Add-DependencyReference -Bucket $index.ExcludeByTargetId -TargetCollectionId $excludeRow.TargetId -Dependent ([pscustomobject]@{ CollectionID = $excludeRow.DependentId; CollectionName = $excludeRow.DependentName })
            }
        }

        if ($successfulRows -gt 0) {
            return [pscustomobject]$index
        }

        Write-PhaseLog -Level 'WARN' -Message 'Parallel dependency scan returned no successful rows. Falling back to sequential scan.'
    }

    foreach ($candidate in @($Collections)) {
        if (-not $candidate) { continue }

        $dependentCollectionId = [string]$candidate.CollectionID
        $dependentCollectionName = [string]$candidate.Name
        if ([string]::IsNullOrWhiteSpace($dependentCollectionId)) { continue }

        $dependentEntry = [pscustomobject]@{
            CollectionID = $dependentCollectionId
            CollectionName = $dependentCollectionName
        }

        $rules = Get-CollectionMembershipRules -CollectionID $dependentCollectionId
        $includeRules = @($rules.Include)
        $excludeRules = @($rules.Exclude)

        foreach ($rule in $includeRules) {
            if (-not $rule) { continue }
            $targetId = [string]$rule.IncludeCollectionID
            if ([string]::IsNullOrWhiteSpace($targetId)) {
                $targetId = [string]$rule.IncludeCollectionId
            }
            Add-DependencyReference -Bucket $index.IncludeByTargetId -TargetCollectionId $targetId -Dependent $dependentEntry
        }

        foreach ($rule in $excludeRules) {
            if (-not $rule) { continue }
            $targetId = [string]$rule.ExcludeCollectionID
            if ([string]::IsNullOrWhiteSpace($targetId)) {
                $targetId = [string]$rule.ExcludeCollectionId
            }
            Add-DependencyReference -Bucket $index.ExcludeByTargetId -TargetCollectionId $targetId -Dependent $dependentEntry
        }
    }

    return [pscustomobject]$index
}

<#
.SYNOPSIS
Detects deep query-expression references to a collection.

.DESCRIPTION
Scans query membership expressions in peer collections for explicit references
to the input collection id and returns discovered reference entries.

.PARAMETER CollectionID
Collection identifier being analyzed.

.PARAMETER Collections
Collections to inspect for query-expression references.

.OUTPUTS
System.Object[]
#>
function Get-DeepReferences {
    param(
        [string]$CollectionID,
        [array]$Collections
    )

    $references = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($CollectionID)) {
           return $references.ToArray()
    }

    $targetCollection = @($Collections | Where-Object { ([string]$_.CollectionID) -eq $CollectionID } | Select-Object -First 1)
    $targetCollectionName = ''
    if ($targetCollection.Count -gt 0) {
        $targetCollectionName = [string]$targetCollection[0].Name
    }

    $collectionIdPattern = [regex]::Escape($CollectionID)
    $quotedIdPattern = ('CollectionID\s*=\s*[''"\[]?{0}[''"\]]?' -f $collectionIdPattern)
    $inClausePattern = ('CollectionID\s+IN\s*\([^\)]*{0}[^\)]*\)' -f $collectionIdPattern)
    $collectionNamePattern = if (-not [string]::IsNullOrWhiteSpace($targetCollectionName)) { [regex]::Escape($targetCollectionName) } else { $null }

    foreach ($candidate in @($Collections)) {
        if (-not $candidate) { continue }

        $candidateId = [string]$candidate.CollectionID
        $candidateName = [string]$candidate.Name

        if ([string]::IsNullOrWhiteSpace($candidateId) -or $candidateId -eq $CollectionID) {
            continue
        }

        $queryRules = @(Get-CachedQueryMembershipRules -CollectionID $candidateId)

        foreach ($rule in $queryRules) {
            if (-not $rule) { continue }

            $queryExpression = [string]$rule.QueryExpression
            if ([string]::IsNullOrWhiteSpace($queryExpression)) { continue }

            $matchType = $null
            $confidence = 'Low'

            if ($queryExpression -match $quotedIdPattern) {
                $matchType = 'ExactIdPredicate'
                $confidence = 'High'
            }
            elseif ($queryExpression -match $inClausePattern) {
                $matchType = 'IdInClause'
                $confidence = 'High'
            }
            elseif ($queryExpression -match $collectionIdPattern) {
                $matchType = 'HeuristicIdTextMatch'
                $confidence = 'Medium'
                $script:AnalysisWarningCounts.DeepReferenceHeuristicMatches++
            }
            elseif ($collectionNamePattern -and $queryExpression -match $collectionNamePattern) {
                $matchType = 'HeuristicNameTextMatch'
                $confidence = 'Low'
                $script:AnalysisWarningCounts.DeepReferenceHeuristicMatches++
            }

            if ($matchType) {
                [void]$references.Add([pscustomobject]@{
                    Type = 'QueryExpression'
                    CollectionID = $candidateId
                    CollectionName = $candidateName
                    Detail = ("Query rule reference detected via {0}." -f $matchType)
                    Confidence = $confidence
                    MatchType = $matchType
                })
                break
            }
        }
    }

    return $references.ToArray()
}

# Deep-mode matching, JSON summary export, and configurable progress interval
# are implemented in this script revision.

if ($AnalyzeSafeToDelete) {

    Write-Host ""
    Write-Host "=== Safe-to-delete analysis ===" -ForegroundColor Cyan
    Write-PhaseLog -Message 'Safe-to-delete analysis started.'

    Write-PhaseLog -Message 'Building dependency index for incoming include/exclude references...'
    $dependencyIndex = Get-CollectionDependencyIndex -Collections $allCollections
    Write-PhaseLog -Message ("Dependency index ready: IncludeTargets={0}; ExcludeTargets={1}" -f @($dependencyIndex.IncludeByTargetId.Keys).Count, @($dependencyIndex.ExcludeByTargetId.Keys).Count) -Level 'SUCCESS'

    $processedSafeItems = 0

    foreach ($entry in $scopedItems) {
        $processedSafeItems++
        if (Should-EmitProgress -ProcessedCount $processedSafeItems) {
            Write-PhaseLog -Message ("Safe-to-delete progress: {0}/{1} scoped collections processed." -f $processedSafeItems, $scopedItems.Count)
        }

        if (-not $entry) { continue }

        $colId = [string]$entry.CollectionID
        $colObj = $entry.Collection
        $colName = [string]$entry.CollectionName
        $folderPath = [string]$entry.FolderPath
        $folderLeaf = Split-Path -Path $folderPath -Leaf
        $safeIdentity = Parse-CollectionIdentity -CollectionName $colName -FolderName $folderLeaf
        $safeSoftwareName = [string]$safeIdentity.Software

        $reasons = @()
        $blockingCategories = New-Object System.Collections.Generic.List[string]
        $status  = 'Safe'
        $dataQuality = 'Complete'
        $analysisConfidence = 'High'
        $lifecycleSignal = ''
        $pairedImplicitInstallCollection = ''

        $deploymentSignal = Get-CollectionDeploymentSignal -CollectionID $colId
        if ($deploymentSignal.HasDeployments) {
            $status = 'NotSafe'
            $reasons += "Has deployments"
            [void]$blockingCategories.Add('Deployments')
        }

        $rules = Get-CollectionMembershipRules -CollectionID $colId
        if ($rules.DataQuality -ne 'Complete') {
            $dataQuality = 'PartialRuleData'
            $analysisConfidence = 'Medium'
        }

        if ($rules.Direct.Count  -gt 0) { $status = 'NotSafe'; $reasons += "Has direct members"; [void]$blockingCategories.Add('DirectMembers') }
        if ($rules.Query.Count   -gt 0) { $status = 'NotSafe'; $reasons += "Has query membership"; [void]$blockingCategories.Add('QueryMembership') }
        $incomingInclude = @()
        $incomingExclude = @()

        if ($dependencyIndex -and $dependencyIndex.IncludeByTargetId.ContainsKey($colId)) {
            $incomingInclude = $dependencyIndex.IncludeByTargetId[$colId].ToArray()
        }
        if ($dependencyIndex -and $dependencyIndex.ExcludeByTargetId.ContainsKey($colId)) {
            $incomingExclude = $dependencyIndex.ExcludeByTargetId[$colId].ToArray()
        }

        if ($incomingInclude.Count -gt 0) {
            $status = 'NotSafe'
            [void]$blockingCategories.Add('IncludedByCollections')
            $includeNames = @($incomingInclude | ForEach-Object { $_.CollectionName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($includeNames.Count -gt 0) {
                $reasons += ("Included by collections: " + ($includeNames -join ', '))
            }
            else {
                $reasons += "Included by other collections"
            }
        }

        if ($incomingExclude.Count -gt 0) {
            $status = 'NotSafe'
            [void]$blockingCategories.Add('ExcludedByCollections')
            $excludeNames = @($incomingExclude | ForEach-Object { $_.CollectionName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($excludeNames.Count -gt 0) {
                $reasons += ("Excluded by collections: " + ($excludeNames -join ', '))
            }
            else {
                $reasons += "Excluded by other collections"
            }
        }

        $limitingUsedBy = @(Get-LimitingCollectionDependents -CollectionID $colId)
        if ($limitingUsedBy.Count -gt 0) {
            $status = 'NotSafe'
            [void]$blockingCategories.Add('LimitingCollection')
            $reasons += ("Is limiting collection for: " + (($limitingUsedBy | Select-Object -ExpandProperty Name) -join ', '))
        }

        if ($Mode -eq 'Deep') {
            $deepRefs = @(Get-DeepReferences -CollectionID $colId -Collections $allCollections)
            if ($deepRefs.Count -gt 0) {
                $status = 'NotSafe'
                [void]$blockingCategories.Add('DeepReferences')
                $deepRefNames = @($deepRefs | ForEach-Object { $_.CollectionName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
                $deepConfidences = @($deepRefs | ForEach-Object { [string]$_.Confidence })
                if ($deepConfidences -contains 'High') {
                    $analysisConfidence = 'High'
                }
                elseif ($deepConfidences -contains 'Medium') {
                    if ($analysisConfidence -ne 'High') { $analysisConfidence = 'Medium' }
                }
                else {
                    $analysisConfidence = 'Low'
                }
                if ($deepRefNames.Count -gt 0) {
                    $reasons += ("Referenced by collection query rules: " + ($deepRefNames -join ', '))
                }
                else {
                    $reasons += "Referenced by other objects (Deep mode)"
                }
            }
        }

        if ([string]$safeIdentity.Suffix -ieq 'uninstall' -and -not [string]::IsNullOrWhiteSpace($safeSoftwareName)) {
            $pairedImplicitCoverage = Get-PairedImplicitInstallCoverage -CurrentCollectionId $colId -SoftwareName $safeSoftwareName
            if ($null -ne $pairedImplicitCoverage) {
                $pairedImplicitInstallCollection = [string]$pairedImplicitCoverage.CollectionName

                if ($blockingCategories.Count -eq 1 -and $blockingCategories.Contains('Deployments') -and $deploymentSignal.HasRequiredUninstallDeployment) {
                    $status = 'Safe'
                    $analysisConfidence = 'Medium'
                    $lifecycleSignal = 'RedundantUninstallCollection'
                    $reasons = @(
                        ("Redundant explicit uninstall: paired install collection [{0}] has Required install deployment with implicit uninstall enabled." -f $pairedImplicitInstallCollection)
                    )
                }
                else {
                    $lifecycleSignal = 'ImplicitUninstallCoverageAvailable'
                    $reasons += ("Paired install collection [{0}] has implicit uninstall enabled; explicit uninstall collection may be redundant once other blockers are removed." -f $pairedImplicitInstallCollection)
                    if ($analysisConfidence -eq 'High') {
                        $analysisConfidence = 'Medium'
                    }
                }
            }
        }

        if ($Mode -eq 'Standard') {
            if ($status -eq 'Safe') {
                Write-Host ("[SAFE] {0} (ID: {1}) - {2}" -f $colName, $colId, $folderPath) -ForegroundColor Green

                $results += [PSCustomObject]@{
                    Type           = 'SafeToDelete'
                    FolderPath     = $folderPath
                    Software       = $safeSoftwareName
                    CollectionName = $colName
                    Version        = ''
                    CollectionID   = $colId
                    Status         = $status
                    Reason         = ''
                    DataQuality    = $dataQuality
                    AnalysisConfidence = $analysisConfidence
                    LifecycleSignal = $lifecycleSignal
                    PairedImplicitInstallCollection = $pairedImplicitInstallCollection
                }
            }
        }
        else {
            if ($status -eq 'Safe') {
                Write-Host ("[SAFE] {0} (ID: {1}) - {2}" -f $colName, $colId, $folderPath) -ForegroundColor Green
            }
            else {
                Write-Host ("[NOT SAFE] {0} (ID: {1}) - {2}" -f $colName, $colId, $folderPath) -ForegroundColor Yellow
                Write-Host ("  Reasons: {0}" -f ($reasons -join '; ')) -ForegroundColor DarkYellow
            }

            $results += [PSCustomObject]@{
                Type           = 'SafeToDelete'
                FolderPath     = $folderPath
                Software       = $safeSoftwareName
                CollectionName = $colName
                Version        = ''
                CollectionID   = $colId
                Status         = $status
                Reason         = ($reasons -join '; ')
                DataQuality    = $dataQuality
                AnalysisConfidence = $analysisConfidence
                LifecycleSignal = $lifecycleSignal
                PairedImplicitInstallCollection = $pairedImplicitInstallCollection
            }
        }
    }

    $safeRows = @($results | Where-Object { $_.Type -eq 'SafeToDelete' })
    $safeCount = @($safeRows | Where-Object { $_.Status -eq 'Safe' }).Count
    $notSafeCount = @($safeRows | Where-Object { $_.Status -eq 'NotSafe' }).Count
    Write-PhaseLog -Message ("Safe-to-delete analysis finished: Rows={0}; Safe={1}; NotSafe={2}" -f $safeRows.Count, $safeCount, $notSafeCount) -Level 'SUCCESS'
}

# ---------------------------------------------------------
# SORTERING + CSV
# ---------------------------------------------------------

$results = @($results | Sort-Object -Property @(
    @{ Expression = { [string]$_.Software }; Descending = $false },
    @{ Expression = { [string]$_.CollectionName }; Descending = $false },
    @{ Expression = { [string]$_.FolderPath }; Descending = $false }
))

if (-not [string]::IsNullOrWhiteSpace($OutputCsv)) {
    Write-PhaseLog -Message 'CSV export requested. Preparing output path.'

    # Brug scriptets mappe hvis der ikke er angivet fuld sti
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

    try {
        $OutputCsv = Resolve-ValidatedOutputPath -Path $OutputCsv -ScriptDir $scriptDir
    }
    catch {
        Write-PhaseLog -Message $_.Exception.Message -Level 'WARN'
        throw
    }

    if ($results.Count -gt 0) {
        $results |
            Select-Object Type, FolderPath, Software, CollectionName, Version, CollectionID, Status, Reason, DataQuality, AnalysisConfidence, LifecycleSignal, PairedImplicitInstallCollection |
            Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

        Write-Host ""
        Write-Host ("CSV report saved as: {0}" -f $OutputCsv) -ForegroundColor Green
        Write-PhaseLog -Message ("CSV export completed: {0}" -f $OutputCsv) -Level 'SUCCESS'
    }
    else {
        Write-Host ""
        Write-Host "No results to save to CSV." -ForegroundColor Yellow
        Write-PhaseLog -Message 'CSV export skipped because there are no result rows.' -Level 'WARN'
    }
}
else {
    Write-PhaseLog -Message 'CSV export skipped because OutputCsv is empty.'
}

if (-not [string]::IsNullOrWhiteSpace($JsonSummaryPath)) {
    Write-PhaseLog -Message 'JSON summary export requested. Preparing output path.'

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    try {
        $JsonSummaryPath = Resolve-ValidatedOutputPath -Path $JsonSummaryPath -ScriptDir $scriptDir
    }
    catch {
        Write-PhaseLog -Message $_.Exception.Message -Level 'WARN'
        throw
    }

    $summaryObject = [pscustomobject]@{
        SiteCode = $SiteCode
        Mode = $Mode
        AnalyzeConsolidation = $AnalyzeConsolidation.IsPresent
        AnalyzeSafeToDelete = $AnalyzeSafeToDelete.IsPresent
        IncludeMasterCollections = $IncludeMasterCollections.IsPresent
        Filters = [pscustomobject]@{
            SoftwareNameContains = $SoftwareNameContains
            FolderPathContains = $FolderPathContains
            ExcludeCollectionNamePattern = $ExcludeCollectionNamePattern
            ExcludeFolderPathPattern = $ExcludeFolderPathPattern
            MaxCollectionsToAnalyze = $MaxCollectionsToAnalyze
        }
        ProgressInterval = $ProgressInterval
        OutputCsv = $OutputCsv
        Totals = [pscustomobject]@{
            ScopedCandidates = $scopedItems.Count
            MasterCollectionsExcluded = $masterCollectionsExcluded
            ResultRows = $results.Count
            ConsolidationRows = @($results | Where-Object { $_.Type -eq 'Consolidation' }).Count
            SafeToDeleteRows = @($results | Where-Object { $_.Type -eq 'SafeToDelete' }).Count
            SafeRows = @($results | Where-Object { $_.Type -eq 'SafeToDelete' -and $_.Status -eq 'Safe' }).Count
            NotSafeRows = @($results | Where-Object { $_.Type -eq 'SafeToDelete' -and $_.Status -eq 'NotSafe' }).Count
        }
        WarningCounts = [pscustomobject]$script:AnalysisWarningCounts
        GeneratedAt = (Get-Date).ToString('o')
    }

    $summaryObject | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonSummaryPath -Encoding UTF8
    Write-PhaseLog -Message ("JSON summary export completed: {0}" -f $JsonSummaryPath) -Level 'SUCCESS'
}
else {
    Write-PhaseLog -Message 'JSON summary export skipped because JsonSummaryPath is empty.'
}

Write-Host ""
Write-Host "=== Analysis complete - no SCCM changes were made ===" -ForegroundColor Cyan
$duration = New-TimeSpan -Start $scriptStart -End (Get-Date)
Write-PhaseLog -Message ("Analysis completed in {0:hh\:mm\:ss}. Total rows={1}" -f $duration, $results.Count) -Level 'SUCCESS'
