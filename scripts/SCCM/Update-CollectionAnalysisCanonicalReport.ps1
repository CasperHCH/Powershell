<#
.SYNOPSIS
    Rebuilds SCCM canonical-name gap reports from collection analysis data.

.DESCRIPTION
    This utility reads the collection analysis CSV together with the local
    SCCM canonical mapping inventory and regenerates three operator-facing
    outputs:

    - Unmapped software inventory markdown
    - Unmapped software inventory CSV
    - Canonical map proposal markdown
    - Control/exclusion review markdown

    The script excludes known control or exclusion collection names from the
    unresolved software totals and writes them to a separate review file so the
    canonical mapping work stays focused on real software-family aliases.

.PARAMETER CsvPath
    Path to the source collection analysis CSV file.

.PARAMETER CanonicalMapPath
    Path to the private canonical map PSD1 file used for alias resolution.

.PARAMETER UnmappedMarkdownPath
    Output path for the unresolved software markdown report.

.PARAMETER UnmappedCsvPath
    Output path for the unresolved software CSV report.

.PARAMETER ProposalMarkdownPath
    Output path for the canonical map proposal markdown file.

.PARAMETER ControlReviewMarkdownPath
    Output path for the control and exclusion review markdown file.

.EXAMPLE
    .\Update-CollectionAnalysisCanonicalReport.ps1

    Rebuilds the standard P03 report set using the default input and output
    paths under scripts\SCCM\output.

.EXAMPLE
    .\Update-CollectionAnalysisCanonicalReport.ps1 -CsvPath '.\output\CollectionAnalyse-p99.csv'

    Rebuilds the report set from an alternate analysis CSV while keeping the
    remaining default paths.

.OUTPUTS
    System.String

    Writes summary status lines such as REPORT_OK, UNMAPPED, BASE, ROLE, and
    CONTROL_EXCLUDED for automation-friendly terminal use.

.NOTES
    Intended as a repeatable admin helper after new Software Central content,
    new SCCM collections, or canonical-map updates are introduced.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = (Join-Path $PSScriptRoot 'output\CollectionAnalyse-p03.csv'),

    [Parameter(Mandatory = $false)]
    [string]$CanonicalMapPath = (Join-Path $PSScriptRoot '..\..\data\SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1'),

    [Parameter(Mandatory = $false)]
    [string]$UnmappedMarkdownPath = (Join-Path $PSScriptRoot 'output\CollectionAnalyse-p03.UnmappedSoftware.md'),

    [Parameter(Mandatory = $false)]
    [string]$UnmappedCsvPath = (Join-Path $PSScriptRoot 'output\CollectionAnalyse-p03.UnmappedSoftware.csv'),

    [Parameter(Mandatory = $false)]
    [string]$ProposalMarkdownPath = (Join-Path $PSScriptRoot 'output\CollectionAnalyse-p03.CanonicalMapProposal.md'),

    [Parameter(Mandatory = $false)]
    [string]$ControlReviewMarkdownPath = (Join-Path $PSScriptRoot 'output\CollectionAnalyse-p03.ControlNamesReview.md')
)

function ConvertTo-RoleVariant {
    param([string]$Name)

    return (($Name -as [string]).Trim() -replace '(?i)\s+(available|required)\s*$', '').Trim()
}

function Get-ProposalGroup {
    param([string]$Software)

    $name = ($Software -as [string]).Trim()
    if ($name -match '^(?i)Adobe\b') { return 'Adobe' }
    if ($name -match '^(?i)Apple\b') { return 'Apple' }
    if ($name -match '^(?i)Broadcom\b') { return 'Broadcom' }
    if ($name -match '^(?i)Brother\b') { return 'Brother' }
    if ($name -match '^(?i)Citrix\b') { return 'Citrix' }
    if ($name -match '^(?i)Microsoft\b') { return 'Microsoft' }
    return 'Other'
}

function Test-ControlOrExclusionName {
    param([string]$Software)

    $trimmedName = ($Software -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedName)) {
        return $false
    }

    $explicitControlNames = @(
        'Broadcom Symantec Endpoint Protection Client Exclude List',
        'Broadcom Symantec Endpoint Protection Server Exclude List',
        'Exclude'
    )

    if ($explicitControlNames -contains $trimmedName) {
        return $true
    }

    return $trimmedName -match '(?i)exclude list$'
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV input not found: $CsvPath"
}

if (-not (Test-Path -LiteralPath $CanonicalMapPath)) {
    throw "Canonical map not found: $CanonicalMapPath"
}

$inventory = Import-PowerShellDataFile -Path $CanonicalMapPath -ErrorAction Stop
$map = @{}
if ($inventory -and $inventory.ContainsKey('CanonicalMappings')) {
    $map = $inventory.CanonicalMappings
}

$rows = Import-Csv -Path $CsvPath
$appRows = @($rows | Where-Object {
    $_.FolderPath -like 'Device Collections\Application Deployment*' -and
    -not [string]::IsNullOrWhiteSpace($_.Software)
})
$groups = @($appRows | Group-Object -Property Software | Sort-Object Name)

$unresolvedResults = New-Object System.Collections.Generic.List[object]
$controlResults = New-Object System.Collections.Generic.List[object]

foreach ($group in $groups) {
    $software = [string]$group.Name
    $normalized = ConvertTo-RoleVariant -Name $software
    $softwareKey = $software.Trim().ToLowerInvariant()
    $normalizedKey = $normalized.Trim().ToLowerInvariant()

    $explicitCovered = $false
    $normalizedCovered = $false
    foreach ($key in $map.Keys) {
        $mapKey = ([string]$key).Trim().ToLowerInvariant()
        if ($mapKey -eq $softwareKey) {
            $explicitCovered = $true
        }
        if ($mapKey -eq $normalizedKey) {
            $normalizedCovered = $true
        }
        if ($explicitCovered -and $normalizedCovered) {
            break
        }
    }

    if ($explicitCovered -or $normalizedCovered) {
        continue
    }

    $sampleCollections = @($group.Group | Select-Object -ExpandProperty CollectionName -Unique | Select-Object -First 3)
    $sampleFolders = @($group.Group | Select-Object -ExpandProperty FolderPath -Unique | Select-Object -First 3)
    $result = [pscustomobject]@{
        Category = if ($normalized -ne $software) { 'DeploymentRoleVariant' } else { 'BaseOrAliasName' }
        Software = $software
        NormalizedSoftware = $normalized
        Rows = @($group.Group).Count
        SampleCollections = ($sampleCollections -join ' || ')
        SampleFolders = ($sampleFolders -join ' || ')
    }

    if (Test-ControlOrExclusionName -Software $software) {
        $controlResult = [pscustomobject]@{
            Name = $software
            SampleCollection = (@($sampleCollections)[0] -as [string])
            SampleFolder = (@($sampleFolders)[0] -as [string])
            Recommendation = 'Keep out of canonical map; treat as exclusion or control collection metadata.'
        }
        [void]$controlResults.Add($controlResult)
        continue
    }

    [void]$unresolvedResults.Add($result)
}

$base = @($unresolvedResults | Where-Object Category -eq 'BaseOrAliasName' | Sort-Object Software)
$role = @($unresolvedResults | Where-Object Category -eq 'DeploymentRoleVariant' | Sort-Object Software)
$controls = @($controlResults | Sort-Object Name)

$mdLines = New-Object System.Collections.Generic.List[string]
$null = $mdLines.Add('# Unmapped Software Inventory Report')
$null = $mdLines.Add('')
$null = $mdLines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$null = $mdLines.Add(('Source CSV: {0}' -f $CsvPath))
$null = $mdLines.Add(('Inventory: {0}' -f $CanonicalMapPath))
$null = $mdLines.Add(('Application-deployment software groups reviewed: {0}' -f $groups.Count))
$null = $mdLines.Add(('Groups without explicit inventory key or normalized key: {0}' -f $unresolvedResults.Count))
$null = $mdLines.Add(('Base or alias names still missing: {0}' -f $base.Count))
$null = $mdLines.Add(('Deployment role variants still missing after normalization: {0}' -f $role.Count))
$null = $mdLines.Add(('Excluded control/exclusion names tracked separately: {0}' -f $controls.Count))

foreach ($section in @(
    @{ Title = 'Base Or Alias Names Missing From Inventory'; Items = $base },
    @{ Title = 'Deployment Role Variants Still Missing After Normalization'; Items = $role }
)) {
    $null = $mdLines.Add('')
    $null = $mdLines.Add(('## {0}' -f $section.Title))
    $null = $mdLines.Add('')
    $null = $mdLines.Add('| Software | Normalized | Rows | Sample Collections |')
    $null = $mdLines.Add('| --- | --- | ---: | --- |')
    foreach ($item in $section.Items) {
        $escapedCollections = (($item.SampleCollections -replace '\|', '\\|') -replace '\r?\n', ' ')
        $null = $mdLines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Software, $item.NormalizedSoftware, $item.Rows, $escapedCollections))
    }
}

if ($controls.Count -gt 0) {
    $null = $mdLines.Add('')
    $null = $mdLines.Add(('Control and exclusion collection names are documented separately in {0} and are not counted as unresolved software aliases.' -f $ControlReviewMarkdownPath))
}

Set-Content -Path $UnmappedMarkdownPath -Value $mdLines -Encoding UTF8
$unresolvedResults | Export-Csv -Path $UnmappedCsvPath -NoTypeInformation -Encoding UTF8

$proposalGroups = @($base | Group-Object { Get-ProposalGroup -Software $_.Software } | Sort-Object Name)
$proposalLines = New-Object System.Collections.Generic.List[string]
$null = $proposalLines.Add('# Canonical Map Proposal')
$null = $proposalLines.Add('')
$null = $proposalLines.Add('This file lists remaining unmapped base or alias names after the safe expansion pass and automatic Available/Required normalization. These should be reviewed before adding to the canonical inventory.')
foreach ($proposalGroup in $proposalGroups) {
    $null = $proposalLines.Add('')
    $null = $proposalLines.Add(('## {0}' -f $proposalGroup.Name))
    $null = $proposalLines.Add('')
    $null = $proposalLines.Add('| Software | Normalized | Rows | Sample Collections |')
    $null = $proposalLines.Add('| --- | --- | ---: | --- |')
    foreach ($item in @($proposalGroup.Group | Sort-Object Software)) {
        $escapedCollections = (($item.SampleCollections -replace '\|', '\\|') -replace '\r?\n', ' ')
        $null = $proposalLines.Add(('| {0} | {1} | {2} | {3} |' -f $item.Software, $item.NormalizedSoftware, $item.Rows, $escapedCollections))
    }
}
Set-Content -Path $ProposalMarkdownPath -Value $proposalLines -Encoding UTF8

$controlLines = New-Object System.Collections.Generic.List[string]
$null = $controlLines.Add('# Control And Exclusion Name Review')
$null = $controlLines.Add('')
$null = $controlLines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd')))
$null = $controlLines.Add(('Source CSV: {0}' -f $CsvPath))
$null = $controlLines.Add('')
$null = $controlLines.Add('These names were intentionally kept out of the canonical software mapping inventory.')
$null = $controlLines.Add('They appear to be collection-control or exclusion constructs rather than deployable')
$null = $controlLines.Add('software families.')
$null = $controlLines.Add('')
$null = $controlLines.Add('| Name | Sample Collection | Sample Folder | Recommendation |')
$null = $controlLines.Add('| --- | --- | --- | --- |')
foreach ($control in $controls) {
    $null = $controlLines.Add(('| {0} | {1} | {2} | {3} |' -f $control.Name, $control.SampleCollection, $control.SampleFolder, $control.Recommendation))
}
$null = $controlLines.Add('')
$null = $controlLines.Add('## Follow-Up Options')
$null = $controlLines.Add('')
$null = $controlLines.Add('1. Leave these names in a dedicated review list and exclude them from canonical expansion work.')
$null = $controlLines.Add('2. Add more explicit control-name patterns here if new exclusion collections appear in future analysis runs.')
Set-Content -Path $ControlReviewMarkdownPath -Value $controlLines -Encoding UTF8

Write-Output ('REPORT_OK')
Write-Output ('REVIEWED={0}' -f $groups.Count)
Write-Output ('UNMAPPED={0}' -f $unresolvedResults.Count)
Write-Output ('BASE={0}' -f $base.Count)
Write-Output ('ROLE={0}' -f $role.Count)
Write-Output ('CONTROL_EXCLUDED={0}' -f $controls.Count)