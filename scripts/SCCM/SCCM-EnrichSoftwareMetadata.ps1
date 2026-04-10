<#
.SYNOPSIS
    Enriches missing SCCM application metadata fields using existing software data.

.DESCRIPTION
    Scans SCCM applications and fills missing metadata where a safe inference exists.
    Current enrichment targets:
    - Publisher (vendor)
    - SoftwareVersion

    Inference strategy:
    - Publisher: most common publisher found within the same normalized software family.
    - SoftwareVersion: parsed from the application display name when missing.

    Optional vendor mappings can be supplied via JSON to improve publisher inference.
    The script supports WhatIf, Confirm, and DryRun behavior and exports a CSV report.

.PARAMETER SiteCode
    SCCM site code, for example P03.

.PARAMETER SoftwareName
    Software filter (partial name). Recommended for focused runs.

.PARAMETER IncludeAllApplications
    Explicitly allows scanning all applications when SoftwareName is not provided.

.PARAMETER VendorMapPath
    Optional path to a JSON file mapping software keywords to vendor names.
    Example JSON:
    {
      "firefox": "Mozilla",
      "chrome": "Google"
    }

.PARAMETER DryRun
    Logs planned updates without changing SCCM application metadata.

.PARAMETER ReportPath
    Optional output CSV path. Defaults to a timestamped file next to this script.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$SoftwareName,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllApplications,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$VendorMapPath,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

# Backward compatibility: keep -DryRun working while standardizing on -WhatIf.
if ($DryRun -and -not $WhatIfPreference) {
    $WhatIfPreference = $true
}

$script:SessionId = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
$script:LogFile = Join-Path -Path $PSScriptRoot -ChildPath 'SCCM-EnrichSoftwareMetadata.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG', 'AUDIT')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    if ($Level -eq 'DEBUG' -and -not $EnableDebugLog) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = ('[{0}] [{1}] [{2}] {3}' -f $timestamp, $script:SessionId, $Level, $Message)

    if (-not $Sensitive) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'AUDIT' { 'Cyan' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        Write-Host $entry -ForegroundColor $color
    }

    try {
        Add-Content -Path $script:LogFile -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Host ('[{0}] [WARN] [LOGGING] Could not write log file: {1}' -f $timestamp, $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    $auditObject = @{
        Timestamp = (Get-Date).ToString('o')
        SessionId = $script:SessionId
        User = $env:USERNAME
        Action = $Action
        Target = $Target
        ComputerName = $env:COMPUTERNAME
        AdditionalData = $AdditionalData
    }

    $auditJson = $auditObject | ConvertTo-Json -Compress -Depth 5
    Write-Log -Level 'AUDIT' -Message $auditJson -Sensitive
}

function Convert-ToSafeArray {
    param(
        [Parameter(Mandatory = $false)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    return @($InputObject)
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        try {
            $property = $InputObject.PSObject.Properties[$propertyName]
            if ($null -ne $property) {
                $value = $property.Value
                if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                    return [string]$value
                }
            }
        }
        catch {
            $null = $_
        }
    }

    return $null
}

function ConvertTo-NormalizedVersion {
    param(
        [Parameter(Mandatory = $false)]
        [string]$VersionString
    )

    if ([string]::IsNullOrWhiteSpace($VersionString)) {
        return $null
    }

    $clean = $VersionString.Trim()
    if (-not ($clean -match '^\d+(\.\d+){0,3}$')) {
        return $null
    }

    $parts = $clean.Split('.')
    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    return ($parts[0..3] -join '.')
}

function Get-VersionFromName {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    $regex = [regex]'\b\d+(?:\.\d+){1,3}\b'
    $match = $regex.Match($Name)
    if (-not $match.Success) {
        return $null
    }

    return ConvertTo-NormalizedVersion -VersionString $match.Value
}

function Get-SoftwareFamilyKey {
    param(
        [Parameter(Mandatory = $false)]
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        return 'unknown'
    }

    $key = $DisplayName.ToLowerInvariant()
    $key = [regex]::Replace($key, '\b\d+(?:\.\d+){1,3}\b', ' ')
    $key = [regex]::Replace($key, '\b(x64|x86|64-bit|32-bit|install|uninstall|update|hotfix|patch|msi|exe)\b', ' ')
    $key = [regex]::Replace($key, '[^a-z0-9]+', ' ')
    $key = [regex]::Replace($key, '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($key)) {
        return $DisplayName.Trim().ToLowerInvariant()
    }

    return $key
}

function Add-Count {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Table,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return
    }

    if ($Table.ContainsKey($Key)) {
        $Table[$Key] = [int]$Table[$Key] + 1
    }
    else {
        $Table[$Key] = 1
    }
}

function Get-TopValueFromCountTable {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Table
    )

    if ($Table.Count -eq 0) {
        return $null
    }

    return @($Table.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1)[0].Key
}

function Get-VendorMap {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @{}
    }

    try {
        # PowerShell 2.0/early 3.0 compatibility: avoid -Raw which is not always available.
        $raw = (Get-Content -Path $Path -ErrorAction Stop | Out-String)

        if (Get-Command -Name 'ConvertFrom-Json' -ErrorAction SilentlyContinue) {
            $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        }
        else {
            Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
            $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $parsed = $serializer.DeserializeObject($raw)
        }
        $map = @{}

        if ($parsed -is [System.Collections.IDictionary]) {
            foreach ($key in $parsed.Keys) {
                $k = [string]$key
                $v = [string]$parsed[$key]
                if (-not [string]::IsNullOrWhiteSpace($k) -and -not [string]::IsNullOrWhiteSpace($v)) {
                    $map[$k.Trim().ToLowerInvariant()] = $v.Trim()
                }
            }
        }
        else {
            foreach ($property in $parsed.PSObject.Properties) {
                $k = [string]$property.Name
                $v = [string]$property.Value
                if (-not [string]::IsNullOrWhiteSpace($k) -and -not [string]::IsNullOrWhiteSpace($v)) {
                    $map[$k.Trim().ToLowerInvariant()] = $v.Trim()
                }
            }
        }

        Write-Log -Level 'INFO' -Message ('Loaded vendor map entries: {0}' -f $map.Count)
        return $map
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Could not parse vendor map file {0}: {1}' -f $Path, $_.Exception.Message)
        return @{}
    }
}

function Get-MappedVendor {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VendorMap,

        [Parameter(Mandatory = $false)]
        [string]$FamilyKey,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName
    )

    if ($VendorMap.Count -eq 0) {
        return $null
    }

    $haystack = ('{0} {1}' -f $FamilyKey, $DisplayName).ToLowerInvariant()
    $bestMatch = $null
    $bestLength = -1

    foreach ($entry in $VendorMap.GetEnumerator()) {
        $keyword = [string]$entry.Key
        if ([string]::IsNullOrWhiteSpace($keyword)) {
            continue
        }

        if ($haystack.Contains($keyword) -and $keyword.Length -gt $bestLength) {
            $bestLength = $keyword.Length
            $bestMatch = [string]$entry.Value
        }
    }

    return $bestMatch
}

function Get-SccmApplications {
    param(
        [Parameter(Mandatory = $false)]
        [string]$NameFilter,

        [Parameter(Mandatory = $false)]
        [switch]$AllApps
    )

    if ($AllApps) {
        try {
            return @(Get-CMApplication -ErrorAction Stop)
        }
        catch {
            throw ('Failed to retrieve applications: {0}' -f $_.Exception.Message)
        }
    }

    if ([string]::IsNullOrWhiteSpace($NameFilter)) {
        return @()
    }

    try {
        return @(Get-CMApplication -Name ('*{0}*' -f $NameFilter) -ErrorAction Stop)
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Name-filter query failed; using fallback query: {0}' -f $_.Exception.Message)
        return @(Get-CMApplication -ErrorAction SilentlyContinue | Where-Object {
            [string]$_.LocalizedDisplayName -like ('*{0}*' -f $NameFilter)
        })
    }
}

function Invoke-UpdateApplicationMetadata {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        $Application,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Changes,

        [Parameter(Mandatory = $true)]
        $SetCommand
    )

    if ($Changes.Count -eq 0) {
        return [pscustomobject]@{ Success = $true; Status = 'NoChange'; Error = $null }
    }

    if ($DryRun) {
        return [pscustomobject]@{ Success = $true; Status = 'Planned'; Error = $null }
    }

    if (-not $PSCmdlet.ShouldProcess($ApplicationName, 'Update application metadata fields')) {
        return [pscustomobject]@{ Success = $true; Status = 'SkippedByConfirmation'; Error = $null }
    }

    $paramNames = @($SetCommand.Parameters.Keys)
    $attempts = @()

    if ($paramNames -contains 'InputObject') {
        $attempts += 'InputObject'
    }
    if ($paramNames -contains 'Name') {
        $attempts += 'Name'
    }
    if ($paramNames -contains 'Id') {
        $attempts += 'Id'
    }

    if ($attempts.Count -eq 0) {
        return [pscustomobject]@{ Success = $false; Status = 'Failed'; Error = 'Set-CMApplication exposes no supported identity parameter (InputObject, Name, Id).' }
    }

    $lastError = $null
    foreach ($attempt in $attempts) {
        try {
            $splat = @{ ErrorAction = 'Stop' }

            if ($attempt -eq 'InputObject') {
                $splat['InputObject'] = $Application
            }
            elseif ($attempt -eq 'Name') {
                $splat['Name'] = $ApplicationName
            }
            elseif ($attempt -eq 'Id') {
                $idValue = Get-ObjectPropertyValue -InputObject $Application -PropertyNames @('CI_ID', 'CIId', 'Id')
                if ([string]::IsNullOrWhiteSpace($idValue)) {
                    continue
                }
                $splat['Id'] = $idValue
            }

            if ($Changes.ContainsKey('Publisher') -and ($paramNames -contains 'Publisher')) {
                $splat['Publisher'] = [string]$Changes['Publisher']
            }

            if ($Changes.ContainsKey('SoftwareVersion') -and ($paramNames -contains 'SoftwareVersion')) {
                $splat['SoftwareVersion'] = [string]$Changes['SoftwareVersion']
            }

            if (($splat.Keys.Count -le 2) -and $splat.ContainsKey('ErrorAction')) {
                continue
            }

            & $SetCommand @splat | Out-Null
            return [pscustomobject]@{ Success = $true; Status = 'Updated'; Error = $null }
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Log -Level 'DEBUG' -Message ('Set-CMApplication attempt {0} failed for {1}: {2}' -f $attempt, $ApplicationName, $lastError)
        }
    }

    return [pscustomobject]@{ Success = $false; Status = 'Failed'; Error = $lastError }
}

try {
    if ([string]::IsNullOrWhiteSpace($SoftwareName) -and -not $IncludeAllApplications) {
        throw 'Provide SoftwareName for a scoped run, or use IncludeAllApplications to process everything.'
    }

    if (-not [string]::IsNullOrWhiteSpace($SoftwareName) -and $SoftwareName.Trim().Length -lt 3) {
        throw ('SoftwareName ''{0}'' is too short for safe scope. Minimum length is 3.' -f $SoftwareName)
    }

    Import-Module ConfigurationManager -ErrorAction Stop
    Set-Location -Path ('{0}:' -f $SiteCode) -ErrorAction Stop

    $setCommand = Get-Command -Name 'Set-CMApplication' -ErrorAction SilentlyContinue
    if ($null -eq $setCommand) {
        throw 'Set-CMApplication is unavailable in this SCCM environment.'
    }

    $vendorMap = Get-VendorMap -Path $VendorMapPath

    $applications = Convert-ToSafeArray -InputObject (Get-SccmApplications -NameFilter $SoftwareName -AllApps:$IncludeAllApplications)
    if ($applications.Count -eq 0) {
        Write-Log -Level 'INFO' -Message 'No applications matched the requested scope.'
        return
    }

    Write-Log -Level 'INFO' -Message ('Applications in scope: {0}' -f $applications.Count)

    $familyProfiles = @{}
    $appRows = @()

    foreach ($app in $applications) {
        $displayName = Get-ObjectPropertyValue -InputObject $app -PropertyNames @('LocalizedDisplayName', 'ApplicationName', 'Name')
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = '<unknown>'
        }

        $familyKey = Get-SoftwareFamilyKey -DisplayName $displayName
        $publisher = Get-ObjectPropertyValue -InputObject $app -PropertyNames @('Publisher', 'Manufacturer', 'Vendor')
        $versionRaw = Get-ObjectPropertyValue -InputObject $app -PropertyNames @('SoftwareVersion', 'Version')
        $version = ConvertTo-NormalizedVersion -VersionString $versionRaw
        $extractedVersion = Get-VersionFromName -Name $displayName

        if (-not $familyProfiles.ContainsKey($familyKey)) {
            $familyProfiles[$familyKey] = @{
                PublisherCounts = @{}
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($publisher)) {
            Add-Count -Table $familyProfiles[$familyKey].PublisherCounts -Key $publisher.Trim()
        }

        $appRows += [pscustomobject]@{
            App = $app
            DisplayName = $displayName
            FamilyKey = $familyKey
            CurrentPublisher = $publisher
            CurrentVersion = $version
            ExtractedVersion = $extractedVersion
        }
    }

    $reportRows = @()
    $updatedCount = 0
    $plannedCount = 0
    $noChangeCount = 0
    $failedCount = 0

    foreach ($row in $appRows) {
        $app = $row.App
        $displayName = [string]$row.DisplayName
        $familyKey = [string]$row.FamilyKey
        $currentPublisher = [string]$row.CurrentPublisher
        $currentVersion = [string]$row.CurrentVersion
        $extractedVersion = [string]$row.ExtractedVersion

        $candidatePublisher = $null
        if ([string]::IsNullOrWhiteSpace($currentPublisher)) {
            $candidatePublisher = Get-TopValueFromCountTable -Table $familyProfiles[$familyKey].PublisherCounts
            if ([string]::IsNullOrWhiteSpace($candidatePublisher)) {
                $candidatePublisher = Get-MappedVendor -VendorMap $vendorMap -FamilyKey $familyKey -DisplayName $displayName
            }
        }

        $candidateVersion = $null
        if ([string]::IsNullOrWhiteSpace($currentVersion) -and -not [string]::IsNullOrWhiteSpace($extractedVersion)) {
            $candidateVersion = $extractedVersion
        }

        $changes = @{}
        if (-not [string]::IsNullOrWhiteSpace($candidatePublisher)) {
            $changes['Publisher'] = $candidatePublisher
        }
        if (-not [string]::IsNullOrWhiteSpace($candidateVersion)) {
            $changes['SoftwareVersion'] = $candidateVersion
        }

        $updateResult = Invoke-UpdateApplicationMetadata -Application $app -ApplicationName $displayName -Changes $changes -SetCommand $setCommand

        switch ($updateResult.Status) {
            'Updated' { $updatedCount++ }
            'Planned' { $plannedCount++ }
            'NoChange' { $noChangeCount++ }
            'SkippedByConfirmation' { $noChangeCount++ }
            default { if (-not $updateResult.Success) { $failedCount++ } else { $noChangeCount++ } }
        }

        if ($updateResult.Status -eq 'Updated' -or $updateResult.Status -eq 'Planned') {
            $changeSummary = @()
            if ($changes.ContainsKey('Publisher')) {
                $changeSummary += ('Publisher={0}' -f $changes['Publisher'])
            }
            if ($changes.ContainsKey('SoftwareVersion')) {
                $changeSummary += ('SoftwareVersion={0}' -f $changes['SoftwareVersion'])
            }
            $changeText = if ($changeSummary.Count -gt 0) { $changeSummary -join '; ' } else { 'None' }
            Write-Log -Level ($(if ($updateResult.Status -eq 'Updated') { 'SUCCESS' } else { 'INFO' })) -Message ('{0}: {1} -> {2}' -f $updateResult.Status, $displayName, $changeText)

            Write-AuditLog -Action ('APP_METADATA_{0}' -f $updateResult.Status.ToUpperInvariant()) -Target $displayName -AdditionalData @{
                FamilyKey = $familyKey
                Changes = $changes
            }
        }
        elseif (-not $updateResult.Success) {
            Write-Log -Level 'ERROR' -Message ('Failed to update {0}: {1}' -f $displayName, $updateResult.Error)
            Write-AuditLog -Action 'APP_METADATA_FAILED' -Target $displayName -AdditionalData @{
                FamilyKey = $familyKey
                Error = $updateResult.Error
            }
        }

        $reportRows += [pscustomobject]@{
            DisplayName = $displayName
            FamilyKey = $familyKey
            CurrentPublisher = $currentPublisher
            InferredPublisher = $candidatePublisher
            CurrentSoftwareVersion = $currentVersion
            InferredSoftwareVersion = $candidateVersion
            Status = $updateResult.Status
            Error = $updateResult.Error
        }
    }

    $resolvedReportPath = $ReportPath
    if ([string]::IsNullOrWhiteSpace($resolvedReportPath)) {
        $resolvedReportPath = Join-Path -Path $PSScriptRoot -ChildPath ('SCCM-EnrichSoftwareMetadata-Report-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }

    $reportRows | Export-Csv -Path $resolvedReportPath -NoTypeInformation -Encoding UTF8

    Write-Log -Level 'INFO' -Message ('Report written to: {0}' -f $resolvedReportPath)
    Write-Log -Level 'INFO' -Message ('Summary | Updated={0}; Planned={1}; NoChange={2}; Failed={3}; Total={4}' -f $updatedCount, $plannedCount, $noChangeCount, $failedCount, $reportRows.Count)
}
catch {
    Write-Log -Level 'ERROR' -Message ('Fatal error: {0}' -f $_.Exception.Message)
    Write-AuditLog -Action 'SCRIPT_FATAL' -Target 'SCCM-EnrichSoftwareMetadata' -AdditionalData @{ Error = $_.Exception.Message }
    throw
}

