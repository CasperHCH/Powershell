<#
.SYNOPSIS
    Exports SCCM application inventory and performs online version and vendor checks.

.DESCRIPTION
    Operates in two phases.

    Phase 1 – Export (requires SCCM access):
      Queries SCCM for all matching applications and writes a CSV containing
      DisplayName, Publisher, SoftwareVersion and related metadata.
      Use -ExportOnly to stop here – ideal when the SCCM server has no internet.

        Phase 2 – Lookup (requires internet access):
            For each row, queries a provider chain to find the current vendor name and
            the latest publicly available version:
                1. Evergreen App Tracker API for mapped applications
                2. GitHub latest release API for mapped applications
                3. Chocolatey community package pages as fallback
      Produces a report CSV with one row per application showing:
        - Current version in SCCM
        - Latest available version
        - VersionStatus: UpToDate / OutOfDate / Newer / Unknown
        - Resolved publisher from SCCM or lookup source

    You can split the phases across machines:
      1. Run -ExportOnly on the SCCM server; copy the CSV to an internet host.
      2. Run with -InputCsvPath on the internet host; no SCCM access needed.

.PARAMETER SiteCode
    SCCM site code (e.g. P03). Required for Phase 1.

.PARAMETER SoftwareName
    Optional name filter. Only applications whose DisplayName contains this
    string are processed. Minimum 3 characters for safety.

.PARAMETER IncludeAllApplications
    Required safety switch when SoftwareName is not provided.

.PARAMETER ExportOnly
    Runs Phase 1 only. Writes the export CSV and exits without web lookups.

.PARAMETER InputCsvPath
    Path to an existing export CSV (from a previous -ExportOnly run or the
    enrichment script). When provided, SiteCode is not required.

.PARAMETER OutputDirectory
    Directory for all output files (reports, cache). Defaults to ./output.
    Output filenames are auto-generated with timestamps.

.PARAMETER VendorMapOnly
    Skips all web lookups. Reads the input CSV, applies the built-in vendor
    overrides to the existing Publisher column, and writes a VendorMap JSON.
    Fastest option when you only need to refresh the vendor map.

.PARAMETER ExportVendorMap
    If specified, exports a JSON vendor map compatible with
    SCCM-EnrichSoftwareMetadata.ps1 -VendorMapPath.

.PARAMETER MaxLookups
    Safety cap on online lookups per run. Default: 0 (all rows).

.PARAMETER CacheTtlDays
    Lookup cache entry time-to-live in days. Default: 14.

.PARAMETER ExportUnresolvedReport
    If specified, exports unresolved or low-confidence rows to a separate CSV.

.PARAMETER EnableDebugLog
    Emits DEBUG level log lines for troubleshooting.

.EXAMPLE
    # Step 1: export from SCCM server (no internet needed)
    .\SCCM-SoftwareVersionAudit.ps1 -SiteCode P03 -IncludeAllApplications -ExportOnly

    # Step 2: run lookups from any internet-connected machine
    .\SCCM-SoftwareVersionAudit.ps1 -InputCsvPath .\SCCM-SoftwareExport-20260324-123000.csv

.EXAMPLE
    # Scoped run with custom output directory
    .\SCCM-SoftwareVersionAudit.ps1 -InputCsvPath .\export.csv -OutputDirectory ./reports

.EXAMPLE
    # Full audit with vendor map export and unresolved report
    .\SCCM-SoftwareVersionAudit.ps1 -InputCsvPath .\export.csv -ExportVendorMap -ExportUnresolvedReport
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$SoftwareName,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllApplications,

    [Parameter(Mandatory = $false)]
    [switch]$ExportOnly,

    [Parameter(Mandatory = $false)]
    [string]$InputCsvPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$VendorMapOnly,

    [Parameter(Mandatory = $false)]
    [switch]$ExportVendorMap,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$MaxLookups = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 90)]
    [int]$CacheTtlDays = 14,

    [Parameter(Mandatory = $false)]
    [switch]$ExportUnresolvedReport,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

$script:SessionId = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
$script:LogFile   = Join-Path -Path $PSScriptRoot -ChildPath 'SCCM-SoftwareVersionAudit.log'
$script:OutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path -Path $PSScriptRoot -ChildPath 'output'
} else {
    $OutputDirectory
}
$script:ThrottleDelayMs = 500  # Milliseconds between requests
$script:LookupCache = @{}
$script:LookupSkipPatterns = @(
    '(?i)\bhotfix\b',
    '(?i)\bkb\d{4,}\b',
    '(?i)\blanguage pack\b',
    '(?i)\bextended support\b',
    '(?i)\bmanagement framework\b'
)
$script:ChocoPackageIdOverrides = @{
    'visualstudiocode'   = 'vscode'
    'notepad'            = 'notepadplusplus'
    'notepadplusplus'    = 'notepadplusplus'
    'firefox'            = 'firefox'
    'googlechrome'       = 'googlechrome'
    '7zip'               = '7zip'
    'vlcmediaplayer'     = 'vlc'
    'winscp'             = 'winscp'
    'putty'              = 'putty'
}

$script:EvergreenAppOverrides = @{
    '7zip'                               = '7zip'
    'adobeacrobat'                       = 'AdobeAcrobatReaderDC'
    'adobeacrobatreaderdc'               = 'AdobeAcrobatReaderDC'
    'citrixworkspaceapp'                 = 'CitrixWorkspaceApp'
    'firefox'                            = 'MozillaFirefox'
    'googlechrome'                       = 'GoogleChrome'
    'libreoffice'                        = 'LibreOffice'
    'microsoftedge'                      = 'MicrosoftEdge'
    'microsoftpowershell'                = 'MicrosoftPowerShell'
    'microsoftsqlservermanagementstudio' = 'MicrosoftSsms'
    'microsoftteams'                     = 'MicrosoftTeams'
    'microsoftvisualstudiocode'          = 'MicrosoftVisualStudioCode'
    'notepadplusplus'                    = 'NotepadPlusPlus'
    'obsstudio'                          = 'OBSStudio'
    'oraclejava8'                        = 'OracleJava8'
    'oraclevirtualbox'                   = 'OracleVirtualBox'
    'powershell'                         = 'MicrosoftPowerShell'
    'putty'                              = 'PuTTY'
    'python'                             = 'Python'
    'pythonlauncher'                     = 'Python'
    'signal'                             = 'SignalDesktop'
    'techsmithsnagit'                    = 'TechSmithSnagit'
    'visualstudiocode'                   = 'MicrosoftVisualStudioCode'
    'vlc'                                = 'VideoLanVlcPlayer'
    'vlcmediaplayer'                     = 'VideoLanVlcPlayer'
    'winscp'                             = 'WinSCP'
    'wireshark'                          = 'Wireshark'
}

$script:GitHubReleaseOverrides = @{
    'gephi'           = 'gephi/gephi'
    'notepadplusplus' = 'notepad-plus-plus/notepad-plus-plus'
    'obsstudio'       = 'obsproject/obs-studio'
    'powershell'      = 'PowerShell/PowerShell'
    'scrcpy'          = 'Genymobile/scrcpy'
    'signal'          = 'signalapp/Signal-Desktop'
    'veracrypt'       = 'veracrypt/VeraCrypt'
    'winmerge'        = 'WinMerge/winmerge'
    'ytdlp'           = 'yt-dlp/yt-dlp'
}

$script:VendorOverrides = @{
    # Adobe Products
    'adobe illustrator'              = 'Adobe'
    'adobe photoshop'                = 'Adobe'
    'adobe premiere pro'              = 'Adobe'
    'adobe premiere'                  = 'Adobe'
    'adobe indesign'                 = 'Adobe'
    'adobe bridge'                   = 'Adobe'
    'adobe acrobat'                  = 'Adobe'
    'adobe acrobat pro'              = 'Adobe'
    'adobe acrobat reader'           = 'Adobe'
    'adobe acrobat reader dc'        = 'Adobe'
    'adobe flash player'             = 'Adobe'
    'adobe lightroom'                = 'Adobe'
    'adobe after effects'            = 'Adobe'
    'adobe dreamweaver'              = 'Adobe'
    'adobe xd'                       = 'Adobe'
    
    # Microsoft Products
    'visual studio code'             = 'Microsoft'
    'vs code'                        = 'Microsoft'
    'visual studio'                  = 'Microsoft'
    'microsoft visual studio'        = 'Microsoft'
    'microsoft visual c'             = 'Microsoft'
    'microsoft edge'                 = 'Microsoft'
    'microsoft teams'                = 'Microsoft'
    'microsoft skype'                = 'Microsoft'
    'microsoft laps'                 = 'Microsoft'
    'microsoft net framework'        = 'Microsoft'
    'microsoft sql server'           = 'Microsoft'
    'management studio'              = 'Microsoft'
    'windows sdk'                    = 'Microsoft'
    'windows admin center'           = 'Microsoft'
    'microsoft powershell'           = 'Microsoft'
    'powershell'                     = 'Microsoft'
    
    # Google Products
    'google chrome'                  = 'Google'
    'google earth'                   = 'Google'
    'google earth pro'               = 'Google'
    
    # Open Source Projects (maintainer names to proper project names)
    'obs studio'                     = 'OBS Project'
    'obs project'                    = 'OBS Project'
    'wireshark'                      = 'Wireshark Foundation'
    'vlc'                            = 'VideoLAN'
    'vlc media player'               = 'VideoLAN'
    'videolan'                       = 'VideoLAN'
    'python launcher'                = 'Python Software Foundation'
    'python'                         = 'Python Software Foundation'
    'open jdk'                       = 'Oracle'
    'openjdk'                        = 'Oracle'
    'scrcpy'                         = 'Genymobile'
    'tortoise svn'                   = 'TortoiseSVN'
    'tortoisesvn'                    = 'TortoiseSVN'
    'gpg4win'                        = 'GnuPG'
    'gnu privacy guard'              = 'GnuPG'
    'gnupg'                          = 'GnuPG'
    'signal'                         = 'Signal Messenger'
    'wire'                           = 'Wire Swiss GmbH'
    'kepf'                           = 'KeePass'
    'keepass'                        = 'KeePass'
    'kee pass'                       = 'KeePass'
    'veracrypt'                      = 'IDRIX'
    'irfanview'                      = 'Irfan Skiljan'
    'yt-dlp'                         = 'yt-dlp Contributors'
    'yt dlp'                         = 'yt-dlp Contributors'
    'gephi'                          = 'Gephi Consortium'
    'diskinternals'                  = 'Diskinternals'
    'graphviz'                       = 'GraphViz Foundation'
    'opera'                          = 'Opera Software'
    'opera browser'                  = 'Opera Software'
    
    # Other Software Companies
    'oracle'                         = 'Oracle'
    'oracle virtualbox'              = 'Oracle'
    'apple'                          = 'Apple Inc.'
    'apple itunes'                   = 'Apple Inc.'
    'itunes'                         = 'Apple Inc.'
    'citrix'                         = 'Citrix Systems'
    'citrix workspace'               = 'Citrix Systems'
    '7-zip'                          = '7-Zip'
    '7 zip'                          = '7-Zip'
    'winzip'                         = 'PKWARE'
    'winrar'                         = 'RARLAB'
    'putty'                          = 'Simon Tatham'
    'winscp'                         = 'Martin Prikryl'
    'notepad++'                      = 'Notepad++ Team'
    'firefox'                        = 'Mozilla'
    'thunderbird'                    = 'Mozilla'
    'qlikview'                       = 'Qlik'
    'qlik sense'                     = 'Qlik'
    'royal ts'                       = 'Royal TS'
    'imazing'                        = 'DigiDNA'
    'imazer'                         = 'DigiDNA'
    'support assistant'              = 'HP'
    'hp support'                     = 'HP'
    'elaborate bytes'                = 'Elaborate Bytes'
    'virtualclonedrive'              = 'Elaborate Bytes'
    'nero'                           = 'Nero'
    'nero burning'                   = 'Nero'
    'easylog'                        = 'LASCAR Electronics'
    'cutepdf'                        = 'Acro Software'
    'cutepdf writer'                 = 'Acro Software'
    'pdfforge'                       = 'pdfforge'
    'pdfcreator'                     = 'pdfforge'
    'ghostscript'                    = 'Artifex Software'
    'libreoffice'                    = 'The Document Foundation'
    'inkscape'                       = 'Inkscape Contributors'
    'corel'                          = 'Corel'
    'coreldraw'                      = 'Corel'
    'corelpaint'                     = 'Corel'
    'winmerge'                       = 'WinMerge Team'
    'hp universal print'             = 'HP'
    'orca'                           = 'Microsoft'
    'configuration manager'          = 'Microsoft'
    'npcap'                          = 'Nmap Project'
    'nmap'                           = 'Nmap Project'
    'sysmon'                         = 'Microsoft'
    'nagios'                         = 'Nagios Enterprises'
    'nxlog'                          = 'NXLog Ltd'
}

# -----------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------

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

    if ($Level -eq 'DEBUG' -and -not $EnableDebugLog) { return }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry     = '[{0}] [{1}] [{2}] {3}' -f $timestamp, $script:SessionId, $Level, $Message

    if (-not $Sensitive) {
        $color = switch ($Level) {
            'ERROR'   { 'Red'    }
            'WARN'    { 'Yellow' }
            'SUCCESS' { 'Green'  }
            'AUDIT'   { 'Cyan'   }
            'DEBUG'   { 'Gray'   }
            default   { 'White'  }
        }
        Write-Host $entry -ForegroundColor $color
    }

    try {
        Add-Content -Path $script:LogFile -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Host ('[LOG WRITE FAILED] {0}' -f $_.Exception.Message) -ForegroundColor DarkYellow
    }
}

# -----------------------------------------------------------------------
# UTILITY HELPERS
# -----------------------------------------------------------------------

function ConvertTo-NormalizedVersion {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }

    $clean = $Raw.Trim()
    $clean = $clean -replace ',', '.'
    $clean = $clean -replace '(?i)^v\s*', ''

    # Accept embedded versions such as "v1.2.3", "27.1-beta", or "2025.001.21288".
    $match = [regex]::Match($clean, '\d+(?:[._-]\d+){0,5}')
    if (-not $match.Success) { return $null }

    $token = $match.Value
    $parts = @($token -split '[^0-9]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) { return $null }

    if ($parts.Count -gt 4) {
        $parts = @($parts[0..3])
    }

    while ($parts.Count -lt 4) {
        $parts += '0'
    }

    return ($parts -join '.')
}

function Get-VersionFromName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $m = [regex]::Match($Name, '\b\d+(?:\.\d+){1,3}\b')
    if (-not $m.Success) { return $null }
    return ConvertTo-NormalizedVersion -Raw $m.Value
}

function Get-CleanedSearchName {
    <#
    .SYNOPSIS
        Strips version numbers, architecture tags, and other noise from a display
        name to produce the best search query for online package lookup.
    #>
    param([string]$DisplayName)

    if ([string]::IsNullOrWhiteSpace($DisplayName)) { return $DisplayName }
    $n = $DisplayName.Trim()

    # Remove trailing version numbers (e.g. "Firefox 134.0.2" -> "Firefox")
    $n = [regex]::Replace($n, '\s+\d+(?:\.\d+){0,3}\s*$', '')

    # Remove architecture hints
    $n = [regex]::Replace($n, '\s*[\(\-]?\s*(?:x64|x86|amd64|64[\s\-]?bit|32[\s\-]?bit)\s*\)?', '',
             [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    # Remove lone year in parens at the end
    $n = [regex]::Replace($n, '\s*\(\s*\d{4}\s*\)\s*$', '')

    $n = $n.Trim(' ()-_')
    return $n
}

function Compare-VersionStrings {
    param([string]$Current, [string]$Latest)

    if ([string]::IsNullOrWhiteSpace($Current)) { return 'UnknownCurrent' }
    if ([string]::IsNullOrWhiteSpace($Latest))  { return 'UnknownLatest'  }

    $nCur = ConvertTo-NormalizedVersion -Raw $Current
    $nLat = ConvertTo-NormalizedVersion -Raw $Latest
    if (-not $nCur) { return 'UnknownCurrent' }
    if (-not $nLat) { return 'UnknownLatest'  }

    try {
        $vCur = [version]$nCur
        $vLat = [version]$nLat
        if ($vCur -lt $vLat) { return 'OutOfDate' }
        if ($vCur -gt $vLat) { return 'Newer'     }
        return 'UpToDate'
    }
    catch {
        if ($nCur -eq $nLat) { return 'UpToDate' }
        return 'Unknown'
    }
}

function Get-PublisherFromWingetId {
    <#
    .SYNOPSIS
        Extracts a readable publisher name from a dotted winget package ID.
        e.g. 'Mozilla.Firefox' -> 'Mozilla'
             'VideoLAN.VLC'    -> 'VideoLAN'
    #>
    param([string]$PackageId)

    if ([string]::IsNullOrWhiteSpace($PackageId)) { return $null }
    if ($PackageId -match '^([^.]+)\.') { return $matches[1] }
    return $null
}

function Get-NormalizedLookupKey {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return ([regex]::Replace($Text.ToLowerInvariant(), '[^a-z0-9]+', ''))
}

function Get-VendorOverrideValue {
    param([string]$SearchName)

    $normalizedSearch = Get-NormalizedLookupKey -Text $SearchName
    foreach ($overrideKey in $script:VendorOverrides.Keys) {
        if ((Get-NormalizedLookupKey -Text $overrideKey) -eq $normalizedSearch) {
            return [string]$script:VendorOverrides[$overrideKey]
        }
    }

    return $null
}

function New-DirectoryIfMissing {
    param([Parameter(Mandatory = $true)] [string]$Path)

    if (-not (Test-Path -Path $Path)) {
        $null = New-Item -Path $Path -ItemType Directory -Force
    }

    return $Path
}

function Get-DefaultOutputPath {
    param([Parameter(Mandatory = $true)] [string]$FileName)

    $outputDirectory = New-DirectoryIfMissing -Path $script:OutputDirectory
    return (Join-Path -Path $outputDirectory -ChildPath $FileName)
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int]$BaseDelayMs = 500
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return (& $ScriptBlock)
        }
        catch {
            $lastError = $_
            if ($attempt -ge $MaxAttempts) { break }
            $delay = [Math]::Min(5000, $BaseDelayMs * [Math]::Pow(2, $attempt - 1))
            Start-Sleep -Milliseconds ([int]$delay)
        }
    }

    throw $lastError
}

function Get-LookupCachePath {
    return (Get-DefaultOutputPath -FileName 'SCCM-SoftwareVersionAudit-Cache.json')
}

function Initialize-LookupCache {
    $resolvedCachePath = Get-LookupCachePath
    $script:LookupCache = @{}

    if (-not (Test-Path -Path $resolvedCachePath)) {
        return
    }

    try {
        $cacheRaw = Get-Content -Path $resolvedCachePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($cacheRaw)) { return }

        $cacheObj = $cacheRaw | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $cacheObj) { return }

        $props = $cacheObj.PSObject.Properties
        foreach ($p in $props) {
            $script:LookupCache[[string]$p.Name] = $p.Value
        }

        Write-Log -Level 'INFO' -Message ('Lookup cache loaded: {0} (entries={1})' -f $resolvedCachePath, $script:LookupCache.Count)
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Lookup cache load failed; starting empty: {0}' -f $_.Exception.Message)
    }
}

function Save-LookupCache {
    $resolvedCachePath = Get-LookupCachePath
    try {
        $script:LookupCache | ConvertTo-Json -Depth 8 | Set-Content -Path $resolvedCachePath -Encoding UTF8
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Lookup cache save failed: {0}' -f $_.Exception.Message)
    }
}

function Test-SearchNameShouldBeSkipped {
    param([Parameter(Mandatory = $true)] [string]$SearchName)

    foreach ($pattern in @($script:LookupSkipPatterns)) {
        if ($SearchName -match $pattern) {
            return $pattern
        }
    }

    return $null
}

function Get-CacheLookupResult {
    param([Parameter(Mandatory = $true)] [string]$CacheKey)

    if (-not $script:LookupCache.ContainsKey($CacheKey)) { return $null }

    $entry = $script:LookupCache[$CacheKey]
    if ($null -eq $entry -or $null -eq $entry.TimestampUtc) { return $null }

    try {
        $entryTime = [datetime]::Parse([string]$entry.TimestampUtc)
        if ($entryTime -lt (Get-Date).AddDays(-1 * $CacheTtlDays)) {
            return $null
        }
    }
    catch {
        return $null
    }

    return $entry.Lookup
}

function Set-CacheLookupResult {
    param(
        [Parameter(Mandatory = $true)] [string]$CacheKey,
        [Parameter(Mandatory = $true)] $Lookup
    )

    $script:LookupCache[$CacheKey] = [ordered]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        Lookup = $Lookup
    }
}

function Get-ChocolateyPackageDetails {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $details = [pscustomobject]@{
        Found         = $false
        PackageId     = $PackageId
        Publisher     = $null
        LatestVersion = $null
        Notes         = $null
    }

    $packageUrl = 'https://community.chocolatey.org/packages/' + $PackageId
    $packageResponse = Invoke-WithRetry -ScriptBlock {
        Invoke-WebRequest -Uri $packageUrl -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    }
    $packageContent = [System.Net.WebUtility]::HtmlDecode([string]$packageResponse.Content)
    $packageText = $packageContent
    $packageText = [regex]::Replace($packageText, '(?is)<script\b[^>]*>.*?</script>', ' ')
    $packageText = [regex]::Replace($packageText, '(?is)<style\b[^>]*>.*?</style>', ' ')
    $packageText = [regex]::Replace($packageText, '<[^>]+>', "`n")
    $packageText = [regex]::Replace($packageText, '[\t ]+', ' ')
    $packageText = [regex]::Replace($packageText, '(\r?\n)\s*(\r?\n)+', "`n")
    $packageLines = @($packageText -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $version = $null
    $authors = $null

    if ($packageContent -match '/api/v2/package/' + [regex]::Escape($PackageId) + '/([^"''<>/\s]+)') {
        $version = $matches[1].Trim()
    }
    elseif ($packageContent -match 'Downloads of v\s*([0-9][0-9A-Za-z._-]*)') {
        $version = $matches[1].Trim()
    }
    elseif ($packageContent -match '<title>.*?([0-9]+(?:\.[0-9A-Za-z_-]+)+).*?</title>') {
        $version = $matches[1].Trim()
    }
    elseif ($packageText -match 'Downloads of v\s*([0-9][0-9A-Za-z._-]*)') {
        $version = $matches[1].Trim()
    }

    for ($i = 0; $i -lt $packageLines.Count; $i++) {
        if ($packageLines[$i] -eq 'Software Author(s):' -and $i + 1 -lt $packageLines.Count) {
            $authors = $packageLines[$i + 1]
            break
        }

        if ($packageLines[$i] -eq 'Package Maintainer(s):' -and $i + 1 -lt $packageLines.Count) {
            $authors = $packageLines[$i + 1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $details.Notes = 'Chocolatey package page did not expose a version'
        return $details
    }

    $normVersion = ConvertTo-NormalizedVersion -Raw $version

    $details.Found         = $true
    $details.Publisher     = if (-not [string]::IsNullOrWhiteSpace($authors)) { $authors } else { $PackageId }
    $details.LatestVersion = if (-not [string]::IsNullOrWhiteSpace($normVersion)) { $normVersion } else { $version }
    $details.Notes         = 'OK'
    return $details
}

# -----------------------------------------------------------------------
# PHASE 1 – SCCM EXPORT
# -----------------------------------------------------------------------

function Export-SccmApplications {
    param(
        [Parameter(Mandatory = $true)]  [string]$SiteCodeParam,
        [Parameter(Mandatory = $false)] [string]$NameFilter,
        [Parameter(Mandatory = $false)] [switch]$AllApps
    )

    Write-Log -Level 'INFO' -Message 'Connecting to SCCM...'
    Import-Module ConfigurationManager -ErrorAction Stop
    Set-Location -Path ('{0}:' -f $SiteCodeParam) -ErrorAction Stop

    $apps = @()

    if ($AllApps) {
        $apps = @(Get-CMApplication -ErrorAction Stop)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($NameFilter)) {
        try {
            $apps = @(Get-CMApplication -Name ('*{0}*' -f $NameFilter) -ErrorAction Stop)
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Name-filter query failed; using full-scan fallback: {0}' -f $_.Exception.Message)
            $apps = @(Get-CMApplication -ErrorAction SilentlyContinue | Where-Object {
                [string]$_.LocalizedDisplayName -like ('*{0}*' -f $NameFilter)
            })
        }
    }

    Write-Log -Level 'INFO' -Message ('Applications retrieved from SCCM: {0}' -f $apps.Count)

    $rows = foreach ($app in $apps) {
        $name     = $null; try { $name     = [string]$app.LocalizedDisplayName } catch { Write-Log -Level 'DEBUG' -Message ('Could not read LocalizedDisplayName: {0}' -f $_.Exception.Message) }
        $pub      = $null; try { $pub      = [string]$app.Publisher            } catch { Write-Log -Level 'DEBUG' -Message ('Could not read Publisher: {0}' -f $_.Exception.Message) }
        $ver      = $null; try { $ver      = [string]$app.SoftwareVersion      } catch { Write-Log -Level 'DEBUG' -Message ('Could not read SoftwareVersion: {0}' -f $_.Exception.Message) }
        $created  = $null; try { $created  = [string]$app.DateCreated          } catch { Write-Log -Level 'DEBUG' -Message ('Could not read DateCreated: {0}' -f $_.Exception.Message) }
        $modified = $null; try { $modified = [string]$app.DateLastModified     } catch { Write-Log -Level 'DEBUG' -Message ('Could not read DateLastModified: {0}' -f $_.Exception.Message) }
        $ciId     = $null; try { $ciId     = [string]$app.CI_ID                } catch { Write-Log -Level 'DEBUG' -Message ('Could not read CI_ID: {0}' -f $_.Exception.Message) }

        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        [pscustomobject]@{
            CI_ID            = $ciId
            DisplayName      = $name
            Publisher        = $pub
            SoftwareVersion  = $ver
            DateCreated      = $created
            DateLastModified = $modified
        }
    }

    return @($rows)
}

# -----------------------------------------------------------------------
# PHASE 2 – WEB LOOKUPS
# -----------------------------------------------------------------------

function Search-WingetPackage {
    <#
    .SYNOPSIS
        Searches the winget source for the best-matching package id and version.
        Returns a normalised result object regardless of success or failure.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    $result = [pscustomobject]@{
        Found         = $false
        PackageId     = $null
        Publisher     = $null
        LatestVersion = $null
        Source        = 'Winget'
        Notes         = $null
        MatchScore    = 0
        MatchReason   = $null
    }

    $wingetCmd = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if ($null -eq $wingetCmd) {
        $result.Notes = 'winget CLI not found on this machine'
        return $result
    }

    try {
        Write-Log -Level 'DEBUG' -Message ('Winget search: "{0}"' -f $SearchName)

        $searchArgs = @('search', '--query', $SearchName, '--source', 'winget', '--accept-source-agreements')

        # Capture both stdout and stderr; winget writes warnings and prompts to stderr.
        $rawOutput = & $wingetCmd.Source @searchArgs 2>&1
        $lines     = @($rawOutput | ForEach-Object { [string]$_ } | ForEach-Object { $_.TrimEnd() })

        if ($lines.Count -eq 0) {
            $result.Notes = 'No output returned by winget'
            return $result
        }

        $errorLine = @($lines | Where-Object {
            $_ -match '(?i)argument name was not recognized|no package found matching input criteria|source agreements|failed when searching source'
        } | Select-Object -First 1)
        if ($errorLine.Count -gt 0) {
            $result.Notes = $errorLine[0]
            return $result
        }

        $sepIdx = -1
        for ($j = 0; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '^-{5,}') {
                $sepIdx = $j
                break
            }
        }

        $candidateLines = if ($sepIdx -ge 0) {
            @($lines | Select-Object -Skip ($sepIdx + 1))
        }
        else {
            $lines
        }

        $firstDataLine = $null
        foreach ($line in $candidateLines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '(?i)^name\s+id\s+version') { continue }
            if ($line -match '^(\\|/|-)+$') { continue }

            $tokens = @($line -split '\s{2,}' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($tokens.Count -ge 2 -and $tokens[1].Trim() -match '^[A-Za-z0-9][A-Za-z0-9._-]+$') {
                $firstDataLine = $line
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($firstDataLine)) {
            $result.Notes = 'No results or unrecognised winget output format'
            return $result
        }

        $tokens = @($firstDataLine -split '\s{2,}' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $extractedId      = $tokens[1].Trim()
        $extractedVersion = if ($tokens.Count -ge 3) { $tokens[2].Trim() } else { $null }

        if ([string]::IsNullOrWhiteSpace($extractedId)) {
            $result.Notes = 'Empty package ID in winget result'
            return $result
        }

        $normVersion = ConvertTo-NormalizedVersion -Raw $extractedVersion
        $publisher   = Get-PublisherFromWingetId -PackageId $extractedId

        $result.Found         = $true
        $result.PackageId     = $extractedId
        $result.Publisher     = $publisher
        $result.LatestVersion = if (-not [string]::IsNullOrWhiteSpace($normVersion)) { $normVersion } else { $extractedVersion }
        $result.Notes         = 'OK'
        $result.MatchScore    = 70
        $result.MatchReason   = 'Winget first-result parse'
    }
    catch {
        $result.Notes = ('Winget error: {0}' -f $_.Exception.Message)
        Write-Log -Level 'DEBUG' -Message $result.Notes
    }

    return $result
}

function Search-EvergreenPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    $result = [pscustomobject]@{
        Found         = $false
        PackageId     = $null
        Publisher     = $null
        LatestVersion = $null
        Source        = 'Evergreen'
        Notes         = $null
        MatchScore    = 0
        MatchReason   = $null
    }

    try {
        $normalizedSearch = Get-NormalizedLookupKey -Text $SearchName
        if (-not $script:EvergreenAppOverrides.ContainsKey($normalizedSearch)) {
            $result.Notes = 'No Evergreen mapping configured'
            return $result
        }

        $appName = [string]$script:EvergreenAppOverrides[$normalizedSearch]
        $uri = 'https://evergreen-api.stealthpuppy.com/app/' + [uri]::EscapeDataString($appName)
        $headers = @{ 'User-Agent' = 'SCCM-SoftwareVersionAudit' }
        $response = Invoke-WithRetry -ScriptBlock {
            Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        }

        $payload = @(([string]$response.Content | ConvertFrom-Json -ErrorAction Stop))
        if ($payload.Count -eq 0) {
            $result.Notes = 'Evergreen returned no application data'
            return $result
        }

        $candidate = @($payload | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Version) } | Select-Object -First 1)
        if ($candidate.Count -eq 0) {
            $result.Notes = 'Evergreen returned no version data'
            return $result
        }

        $rawVersion = [string]$candidate[0].Version
        $normalizedVersion = ConvertTo-NormalizedVersion -Raw $rawVersion
        $publisher = Get-VendorOverrideValue -SearchName $SearchName

        $result.Found         = $true
        $result.PackageId     = $appName
        $result.Publisher     = $publisher
        $result.LatestVersion = if (-not [string]::IsNullOrWhiteSpace($normalizedVersion)) { $normalizedVersion } else { $rawVersion }
        $result.Notes         = 'OK'
        $result.MatchScore    = 98
        $result.MatchReason   = 'Evergreen API mapping'
    }
    catch {
        $result.Notes = ('Evergreen error: {0}' -f $_.Exception.Message)
        Write-Log -Level 'DEBUG' -Message $result.Notes
    }

    return $result
}

function Search-GitHubReleasePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    $result = [pscustomobject]@{
        Found         = $false
        PackageId     = $null
        Publisher     = $null
        LatestVersion = $null
        Source        = 'GitHubRelease'
        Notes         = $null
        MatchScore    = 0
        MatchReason   = $null
    }

    try {
        $normalizedSearch = Get-NormalizedLookupKey -Text $SearchName
        if (-not $script:GitHubReleaseOverrides.ContainsKey($normalizedSearch)) {
            $result.Notes = 'No GitHub release mapping configured'
            return $result
        }

        $repo = [string]$script:GitHubReleaseOverrides[$normalizedSearch]
        $uri = 'https://api.github.com/repos/' + $repo + '/releases/latest'
        $headers = @{
            'User-Agent' = 'SCCM-SoftwareVersionAudit'
            'Accept' = 'application/vnd.github+json'
        }
        $response = Invoke-WithRetry -ScriptBlock {
            Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        }

        $release = [string]$response.Content | ConvertFrom-Json -ErrorAction Stop
        $rawVersion = [string]$release.tag_name
        if ([string]::IsNullOrWhiteSpace($rawVersion)) {
            $rawVersion = [string]$release.name
        }
        if ([string]::IsNullOrWhiteSpace($rawVersion)) {
            $result.Notes = 'GitHub release did not expose a tag or name'
            return $result
        }

        $normalizedVersion = ConvertTo-NormalizedVersion -Raw $rawVersion
        $publisher = Get-VendorOverrideValue -SearchName $SearchName
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            $publisher = ($repo -split '/')[0]
        }

        $result.Found         = $true
        $result.PackageId     = $repo
        $result.Publisher     = $publisher
        $result.LatestVersion = if (-not [string]::IsNullOrWhiteSpace($normalizedVersion)) { $normalizedVersion } else { $rawVersion }
        $result.Notes         = 'OK'
        $result.MatchScore    = 92
        $result.MatchReason   = 'GitHub latest release mapping'
    }
    catch {
        $result.Notes = ('GitHub release error: {0}' -f $_.Exception.Message)
        Write-Log -Level 'DEBUG' -Message $result.Notes
    }

    return $result
}

function Search-ChocolateyPackage {
    <#
    .SYNOPSIS
        Queries the Chocolatey community package site for the latest package
        matching the search name. No authentication required.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    $result = [pscustomobject]@{
        Found         = $false
        PackageId     = $null
        Publisher     = $null
        LatestVersion = $null
        Source        = 'Chocolatey'
        Notes         = $null
        MatchScore    = 0
        MatchReason   = $null
    }

    try {
        # Enforce TLS 1.2 for compatibility with older PowerShell versions.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Log -Level 'DEBUG' -Message ('Chocolatey query for: "{0}"' -f $SearchName)

        $normalizedSearch = Get-NormalizedLookupKey -Text $SearchName

        if ($script:ChocoPackageIdOverrides.ContainsKey($normalizedSearch)) {
            $overridePackageId = [string]$script:ChocoPackageIdOverrides[$normalizedSearch]
            $overrideDetails = Get-ChocolateyPackageDetails -PackageId $overridePackageId
            if ($overrideDetails.Found) {
                $result.Found         = $true
                $result.PackageId     = $overrideDetails.PackageId
                $result.Publisher     = $overrideDetails.Publisher
                $result.LatestVersion = $overrideDetails.LatestVersion
                $result.Notes         = 'OK (override)'
                $result.MatchScore    = 100
                $result.MatchReason   = 'Configured package override'
                return $result
            }
        }

        $encodedSearchName = [uri]::EscapeDataString($SearchName)
        $searchUrl = 'https://community.chocolatey.org/packages?q=' + $encodedSearchName
        $searchResponse = Invoke-WithRetry -ScriptBlock {
            Invoke-WebRequest -Uri $searchUrl -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
        }
        $searchContent  = [string]$searchResponse.Content

        $candidateMap = @{}
        $resultMatches = [regex]::Matches(
            $searchContent,
            '(?is)<a[^>]+href="/packages/(?<id>[A-Za-z0-9][A-Za-z0-9._-]+)[^"'']*"[^>]*>\s*Learn\s+more\s+about\s*(?<title>.*?)\s*</a>'
        )

        foreach ($match in $resultMatches) {
            $packageId = [string]$match.Groups['id'].Value
            if ([string]::IsNullOrWhiteSpace($packageId)) { continue }

            $titleRaw = [string]$match.Groups['title'].Value
            $titleDecoded = [System.Net.WebUtility]::HtmlDecode($titleRaw)
            $title = [regex]::Replace($titleDecoded, '<[^>]+>', ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($title)) { $title = $packageId }

            if (-not $candidateMap.ContainsKey($packageId)) {
                $candidateMap[$packageId] = [pscustomobject]@{ PackageId = $packageId; Title = $title }
            }
        }

        if ($candidateMap.Count -eq 0) {
            $packageIdMatches = [regex]::Matches($searchContent, '/packages/([A-Za-z0-9][A-Za-z0-9._-]+)(?:["''#?/]|$)')
            foreach ($match in $packageIdMatches) {
                $packageId = [string]$match.Groups[1].Value
                if ([string]::IsNullOrWhiteSpace($packageId)) { continue }
                if (-not $candidateMap.ContainsKey($packageId)) {
                    $candidateMap[$packageId] = [pscustomobject]@{ PackageId = $packageId; Title = $packageId }
                }
            }
        }

        if ($candidateMap.Count -eq 0) {
            $result.Notes = 'No matching package in Chocolatey'
            return $result
        }

        $candidates = @($candidateMap.Values)
        $nonDeprecated = @($candidates | Where-Object { [string]$_.Title -notmatch '(?i)^\s*\[deprecated\]' })
        if ($nonDeprecated.Count -gt 0) { $candidates = $nonDeprecated }

        $searchTokens = @($SearchName.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 })
        $candidateScores = @{}

        foreach ($candidate in $candidates) {
            $packageId = [string]$candidate.PackageId
            if ([string]::IsNullOrWhiteSpace($packageId)) { continue }

            $normalizedId = Get-NormalizedLookupKey -Text $packageId
            $normalizedTitle = Get-NormalizedLookupKey -Text ([string]$candidate.Title)
            $score = 0

            if ($normalizedTitle -eq $normalizedSearch) {
                $score += 600
            }
            elseif (-not [string]::IsNullOrWhiteSpace($normalizedSearch) -and $normalizedTitle.Contains($normalizedSearch)) {
                $score += 120
            }

            if ($normalizedId -eq $normalizedSearch) {
                $score += 160
            }
            elseif (-not [string]::IsNullOrWhiteSpace($normalizedSearch) -and $normalizedId.Contains($normalizedSearch)) {
                $score += 40
            }

            $allTokensPresent = $true
            foreach ($token in $searchTokens) {
                if ($normalizedTitle.Contains($token)) {
                    $score += 25
                }
                else {
                    $allTokensPresent = $false
                }

                if ($normalizedId.Contains($token)) {
                    $score += 10
                }
            }
            if ($allTokensPresent -and $searchTokens.Count -gt 0) {
                $score += 120
            }

            if ([string]$candidate.Title -match '(?i)^\s*\[deprecated\]') { $score -= 300 }
            if ($packageId -match '(?i)\.(install|portable)$') { $score -= 10 }
            if ($packageId -match '(?i)(insiders|extension)$')  { $score -= 20 }
            if ($packageId -match '(?i)^devbox[-.]|^boxstarter[-.]') { $score -= 250 }

            $candidateScores[$packageId] = $score
        }

        if ($candidateScores.Count -eq 0) {
            $result.Notes = 'No matching package in Chocolatey'
            return $result
        }

        $orderedCandidates = @($candidateScores.GetEnumerator() | Sort-Object -Property Value -Descending)
        $topCandidate = @($orderedCandidates | Select-Object -First 1)[0]
        $pkgId = $topCandidate.Key
        $details = Get-ChocolateyPackageDetails -PackageId $pkgId
        if (-not $details.Found) {
            $result.Notes = if (-not [string]::IsNullOrWhiteSpace($details.Notes)) { $details.Notes } else { 'No matching package in Chocolatey' }
            return $result
        }

        $result.Found         = $true
        $result.PackageId     = $details.PackageId
        $result.Publisher     = $details.Publisher
        $result.LatestVersion = $details.LatestVersion
        $result.Notes         = 'OK'
        $result.MatchScore    = [Math]::Min(95, [Math]::Max(40, [int]$topCandidate.Value))
        $result.MatchReason   = 'Chocolatey search ranking'
    }
    catch {
        $result.Notes = ('Chocolatey error: {0}' -f $_.Exception.Message)
        Write-Log -Level 'DEBUG' -Message $result.Notes
    }

    return $result
}

function Invoke-PackageLookup {
    param(
        [Parameter(Mandatory = $true)] [string]$SearchName,
        [Parameter(Mandatory = $true)] [int]$DelayMs
    )

    $winget    = $null
    $evergreen = Search-EvergreenPackage -SearchName $SearchName
    $gitHub    = $null
    $choco     = $null

    if (-not $evergreen.Found) {
        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
        $gitHub = Search-GitHubReleasePackage -SearchName $SearchName
    }

    if (-not $evergreen.Found -and ($null -eq $gitHub -or -not $gitHub.Found)) {
        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
        $choco = Search-ChocolateyPackage -SearchName $SearchName
    }

    $best = $null
    if ($null -ne $evergreen -and $evergreen.Found)      { $best = $evergreen }
    elseif ($null -ne $gitHub -and $gitHub.Found)        { $best = $gitHub }
    elseif ($null -ne $winget -and $winget.Found)        { $best = $winget }
    elseif ($null -ne $choco -and $choco.Found)          { $best = $choco }

    $bestPublisher = if ($null -ne $best -and -not [string]::IsNullOrWhiteSpace($best.Publisher)) { $best.Publisher } else { $null }
    $vendorOverride = Get-VendorOverrideValue -SearchName $SearchName
    if (-not [string]::IsNullOrWhiteSpace($vendorOverride)) {
        $bestPublisher = $vendorOverride
    }

    $bestVersion = $null
    if ($null -ne $best -and -not [string]::IsNullOrWhiteSpace($best.LatestVersion)) {
        $bestVersion = $best.LatestVersion
    }

    $bestSource = $null
    if ($null -ne $best) { $bestSource = $best.Source }

    return [pscustomobject]@{
        EvergreenAppName    = if ($null -ne $evergreen) { $evergreen.PackageId     } else { $null }
        EvergreenPublisher  = if ($null -ne $evergreen) { if (-not [string]::IsNullOrWhiteSpace($vendorOverride)) { $vendorOverride } else { $evergreen.Publisher } } else { $null }
        EvergreenLatestVersion = if ($null -ne $evergreen) { $evergreen.LatestVersion } else { $null }
        EvergreenNotes      = if ($null -ne $evergreen) { $evergreen.Notes         } else { 'Not queried' }
        GitHubRepo          = if ($null -ne $gitHub)    { $gitHub.PackageId        } else { $null }
        GitHubPublisher     = if ($null -ne $gitHub)    { if (-not [string]::IsNullOrWhiteSpace($vendorOverride)) { $vendorOverride } else { $gitHub.Publisher } } else { $null }
        GitHubLatestVersion = if ($null -ne $gitHub)    { $gitHub.LatestVersion    } else { $null }
        GitHubNotes         = if ($null -ne $gitHub)    { $gitHub.Notes            } else { 'Not queried' }
        WingetPackageId     = if ($null -ne $winget) { $winget.PackageId     } else { $null }
        WingetPublisher     = if ($null -ne $winget) { $winget.Publisher     } else { $null }
        WingetLatestVersion = if ($null -ne $winget) { $winget.LatestVersion } else { $null }
        WingetNotes         = if ($null -ne $winget) { $winget.Notes         } else { 'Not queried' }
        ChocoPackageId      = if ($null -ne $choco)  { $choco.PackageId      } else { $null }
        ChocoPublisher      = if ($null -ne $choco)  { $choco.Publisher      } else { $null }
        ChocoLatestVersion  = if ($null -ne $choco)  { $choco.LatestVersion  } else { $null }
        ChocoNotes          = if ($null -ne $choco)  { $choco.Notes          } else { 'Not queried' }
        BestPublisher       = $bestPublisher
        BestLatestVersion   = $bestVersion
        BestSource          = $bestSource
        MatchScore          = if ($null -ne $best) { [int]$best.MatchScore } else { 0 }
        MatchReason         = if ($null -ne $best) { [string]$best.MatchReason } else { $null }
    }
}

function Resolve-LookupForSearchName {
    param(
        [Parameter(Mandatory = $true)] [string]$SearchName,
        [Parameter(Mandatory = $true)] [string]$Source,
        [Parameter(Mandatory = $true)] [int]$DelayMs
    )

    $skipRule = Test-SearchNameShouldBeSkipped -SearchName $SearchName
    if (-not [string]::IsNullOrWhiteSpace($skipRule)) {
        return [pscustomobject]@{
            EvergreenAppName    = $null
            EvergreenPublisher  = $null
            EvergreenLatestVersion = $null
            EvergreenNotes      = ('Skipped by rule: {0}' -f $skipRule)
            GitHubRepo          = $null
            GitHubPublisher     = $null
            GitHubLatestVersion = $null
            GitHubNotes         = ('Skipped by rule: {0}' -f $skipRule)
            WingetPackageId     = $null
            WingetPublisher     = $null
            WingetLatestVersion = $null
            WingetNotes         = ('Skipped by rule: {0}' -f $skipRule)
            ChocoPackageId      = $null
            ChocoPublisher      = $null
            ChocoLatestVersion  = $null
            ChocoNotes          = ('Skipped by rule: {0}' -f $skipRule)
            BestPublisher       = $null
            BestLatestVersion   = $null
            BestSource          = 'Skipped'
            MatchScore          = 0
            MatchReason         = ('Skipped pre-filter ({0})' -f $skipRule)
        }
    }

    $cacheKey = ('{0}|{1}' -f $Source, (Get-NormalizedLookupKey -Text $SearchName))
    $cached = Get-CacheLookupResult -CacheKey $cacheKey
    if ($null -ne $cached) {
        return $cached
    }

    $lookup = Invoke-PackageLookup -SearchName $SearchName -DelayMs $DelayMs
    Set-CacheLookupResult -CacheKey $cacheKey -Lookup $lookup
    return $lookup
}

function New-VendorMapFromReportRows {
    <#
    .SYNOPSIS
        Builds a keyword -> vendor map from audit report rows.

    .DESCRIPTION
        Produces JSON-compatible data for SCCM-EnrichSoftwareMetadata.ps1.
        Keys are normalized from SearchName/DisplayName and values are the most
        common resolved publisher per key.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Rows
    )

    $publisherCountsByKey = @{}

    foreach ($row in @($Rows)) {
        $rawKey = [string]$row.SearchName
        if ([string]::IsNullOrWhiteSpace($rawKey)) {
            $rawKey = [string]$row.DisplayName
        }

        if ([string]::IsNullOrWhiteSpace($rawKey)) {
            continue
        }
        $key = $rawKey.Trim().ToLowerInvariant()
        $key = [regex]::Replace($key, '[^a-z0-9]+', ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($key) -or $key.Length -lt 3) {
            continue
        }

        $publisher = [string]$row.ResolvedPublisher
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            $publisher = [string]$row.EvergreenPublisher
        }
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            $publisher = [string]$row.GitHubPublisher
        }
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            $publisher = [string]$row.WingetPublisher
        }
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            $publisher = [string]$row.ChocoPublisher
        }
        if ([string]::IsNullOrWhiteSpace($publisher)) {
            continue
        }

        $publisher = $publisher.Trim()

        if (-not $publisherCountsByKey.ContainsKey($key)) {
            $publisherCountsByKey[$key] = @{}
        }

        if ($publisherCountsByKey[$key].ContainsKey($publisher)) {
            $publisherCountsByKey[$key][$publisher] = [int]$publisherCountsByKey[$key][$publisher] + 1
        }
        else {
            $publisherCountsByKey[$key][$publisher] = 1
        }
    }

    $vendorMap = @{}
    foreach ($key in $publisherCountsByKey.Keys) {
        $top = @($publisherCountsByKey[$key].GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1)
        if ($top.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$top[0].Key)) {
            $vendorMap[$key] = [string]$top[0].Key
        }
    }

    # Apply vendor overrides to correct known misattributions
    foreach ($overrideKey in $script:VendorOverrides.Keys) {
        $normalizedOverrideKey = $overrideKey.Trim().ToLowerInvariant()
        $normalizedOverrideKey = [regex]::Replace($normalizedOverrideKey, '[^a-z0-9]+', ' ').Trim()

        if ($vendorMap.ContainsKey($normalizedOverrideKey)) {
            $vendorMap[$normalizedOverrideKey] = $script:VendorOverrides[$overrideKey]
        }
    }

    return $vendorMap
}

# -----------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------

try {
    $isExportPhaseNeeded = [string]::IsNullOrWhiteSpace($InputCsvPath)
    Initialize-LookupCache

    # --- Input validation ---
    if ($isExportPhaseNeeded) {
        if ([string]::IsNullOrWhiteSpace($SiteCode)) {
            throw 'SiteCode is required when not using -InputCsvPath.'
        }
        if ([string]::IsNullOrWhiteSpace($SoftwareName) -and -not $IncludeAllApplications) {
            throw 'Provide -SoftwareName for a scoped export, or use -IncludeAllApplications.'
        }
        if (-not [string]::IsNullOrWhiteSpace($SoftwareName) -and $SoftwareName.Trim().Length -lt 3) {
            throw ('SoftwareName "{0}" is too short for safe scope. Minimum 3 characters.' -f $SoftwareName)
        }
    }
    else {
        if (-not (Test-Path -Path $InputCsvPath)) {
            throw ('InputCsvPath not found: {0}' -f $InputCsvPath)
        }
    }

    # --- PHASE 1: Export or load CSV ---
    $appRows = @()

    if ($isExportPhaseNeeded) {
        Write-Log -Level 'INFO' -Message '-- Phase 1: Exporting from SCCM --'

        $appRows = @(Export-SccmApplications -SiteCodeParam $SiteCode `
                         -NameFilter $SoftwareName `
                         -AllApps:$IncludeAllApplications)

        if ($ExportOnly) {
            $exportPath = Get-DefaultOutputPath -FileName ('SCCM-SoftwareExport-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            $appRows | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
            Write-Log -Level 'SUCCESS' -Message ('Export written to: {0}' -f $exportPath)
            Write-Log -Level 'INFO'    -Message ('Transfer this file to an internet-connected machine and run with -InputCsvPath to complete the version audit.')
            return
        }
    }
    else {
        Write-Log -Level 'INFO' -Message ('-- Phase 1: Loading from CSV: {0} --' -f $InputCsvPath)
        $appRows = @(Import-Csv -Path $InputCsvPath -Encoding UTF8 -ErrorAction Stop)
        Write-Log -Level 'INFO' -Message ('Rows loaded: {0}' -f $appRows.Count)
    }

    if ($appRows.Count -eq 0) {
        Write-Log -Level 'WARN' -Message 'No application rows to process. Exiting.'
        return
    }

    # --- VENDOR MAP ONLY (no web lookups) ---
    if ($VendorMapOnly) {
        Write-Log -Level 'INFO' -Message '-- VendorMapOnly: building vendor map from CSV publishers + in-script overrides (no web lookups) --'

        # Support both raw SCCM export (Publisher column) and completed audit output (ResolvedPublisher column)
        $vmRows = @($appRows | ForEach-Object {
            $dn = [string]$_.DisplayName
            $pub = if (-not [string]::IsNullOrWhiteSpace([string]$_.ResolvedPublisher)) {
                [string]$_.ResolvedPublisher
            } else {
                [string]$_.Publisher
            }
            [pscustomobject]@{
                SearchName         = Get-CleanedSearchName -DisplayName $dn
                DisplayName        = $dn
                ResolvedPublisher  = $pub
                EvergreenPublisher = $null
                GitHubPublisher    = $null
                WingetPublisher    = $null
                ChocoPublisher     = $null
            }
        })

        $vendorMap = New-VendorMapFromReportRows -Rows $vmRows

        # Seed from VendorOverrides for every row whose SearchName matches an override key,
        # even if that key wasn't already in the map (raw exports have empty Publisher columns).
        $normalizedOverrideKeys = @{}
        foreach ($ok in $script:VendorOverrides.Keys) {
            $nk = [regex]::Replace($ok.Trim().ToLowerInvariant(), '[^a-z0-9]+', ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($nk)) {
                $normalizedOverrideKeys[$nk] = $script:VendorOverrides[$ok]
            }
        }

        foreach ($row in $vmRows) {
            $sn = ([string]$row.SearchName).Trim().ToLowerInvariant()
            $sn = [regex]::Replace($sn, '[^a-z0-9]+', ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($sn)) { continue }

            # Exact match first
            if ($normalizedOverrideKeys.ContainsKey($sn)) {
                $vendorMap[$sn] = $normalizedOverrideKeys[$sn]
                continue
            }

            # Partial match: any override key that appears as a substring of the SearchName
            foreach ($nk in $normalizedOverrideKeys.Keys) {
                if ($sn -like "*$nk*") {
                    $vendorMap[$sn] = $normalizedOverrideKeys[$nk]
                    break
                }
            }
        }

        $resolvedVendorMapPath = Get-DefaultOutputPath -FileName ('SCCM-VendorMap-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $vendorMap | ConvertTo-Json -Depth 5 | Set-Content -Path $resolvedVendorMapPath -Encoding UTF8
        Write-Log -Level 'SUCCESS' -Message ('Vendor map JSON written to: {0} (entries={1})' -f $resolvedVendorMapPath, $vendorMap.Count)
        Write-Log -Level 'INFO'    -Message ('Use with enrichment: -VendorMapPath "{0}"' -f $resolvedVendorMapPath)
        return
    }

    # --- PHASE 2: Online lookups ---
    $effectiveMaxLookups = $MaxLookups
    if ($effectiveMaxLookups -le 0) {
        $effectiveMaxLookups = $appRows.Count
    }

    Write-Log -Level 'INFO' -Message ('-- Phase 2: Online lookups (source=Evergreen>GitHub>Chocolatey, max={0}) --' -f $effectiveMaxLookups)

    $rowsToProcess = @($appRows | Select-Object -First $effectiveMaxLookups)
    $enrichedRows = @()
    foreach ($row in $rowsToProcess) {
        $displayName = [string]$row.DisplayName
        if ([string]::IsNullOrWhiteSpace($displayName)) { continue }

        $enrichedRows += [pscustomobject]@{
            RowData = $row
            DisplayName = $displayName
            SearchName = (Get-CleanedSearchName -DisplayName $displayName)
        }
    }

    $uniqueSearchNames = @($enrichedRows.SearchName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    Write-Log -Level 'INFO' -Message ('Unique search terms to resolve: {0}' -f $uniqueSearchNames.Count)

    $lookupBySearch = @{}
    for ($i = 0; $i -lt $uniqueSearchNames.Count; $i++) {
        $searchName = [string]$uniqueSearchNames[$i]
        Write-Log -Level 'DEBUG' -Message ('[Lookup {0}/{1}] search: "{2}"' -f ($i + 1), $uniqueSearchNames.Count, $searchName)

        $lookupBySearch[$searchName] = Resolve-LookupForSearchName -SearchName $searchName -Source 'ProviderChainV2' -DelayMs $script:ThrottleDelayMs

        if ($i -lt ($uniqueSearchNames.Count - 1) -and $script:ThrottleDelayMs -gt 0) {
            Start-Sleep -Milliseconds $script:ThrottleDelayMs
        }

        $pct = if ($uniqueSearchNames.Count -gt 0) { [math]::Round((($i + 1) / $uniqueSearchNames.Count) * 100) } else { 100 }
        Write-Progress -Activity 'SCCM Software Version Audit' `
                       -Status ('Lookup {0}/{1}: {2}' -f ($i + 1), $uniqueSearchNames.Count, $searchName) `
                       -PercentComplete $pct
    }

    $reportRows = @()
    foreach ($item in $enrichedRows) {
        $row = $item.RowData
        $displayName = [string]$item.DisplayName
        $searchName = [string]$item.SearchName

        $currentPub      = [string]$row.Publisher
        $currentVer      = [string]$row.SoftwareVersion
        $lookup = if ($lookupBySearch.ContainsKey($searchName)) { $lookupBySearch[$searchName] } else { $null }

        if ($null -eq $lookup) {
            $lookup = [pscustomobject]@{
                EvergreenAppName    = $null
                EvergreenPublisher  = $null
                EvergreenLatestVersion = $null
                EvergreenNotes      = 'Not queried'
                GitHubRepo          = $null
                GitHubPublisher     = $null
                GitHubLatestVersion = $null
                GitHubNotes         = 'Not queried'
                WingetPackageId     = $null
                WingetPublisher     = $null
                WingetLatestVersion = $null
                WingetNotes         = 'Not queried'
                ChocoPackageId      = $null
                ChocoPublisher      = $null
                ChocoLatestVersion  = $null
                ChocoNotes          = 'Not queried'
                BestPublisher       = $null
                BestLatestVersion   = $null
                BestSource          = $null
                MatchScore          = 0
                MatchReason         = 'Lookup missing'
            }
        }

        $resolvedPublisher = $null
        if (-not [string]::IsNullOrWhiteSpace($currentPub)) {
            $resolvedPublisher = $currentPub
        }
        elseif (-not [string]::IsNullOrWhiteSpace($lookup.BestPublisher)) {
            $resolvedPublisher = $lookup.BestPublisher
        }

        $versionForCompare = $currentVer
        if ([string]::IsNullOrWhiteSpace($versionForCompare)) {
            $extracted = Get-VersionFromName -Name $displayName
            if (-not [string]::IsNullOrWhiteSpace($extracted)) {
                $versionForCompare = $extracted
            }
        }

        $versionStatus = Compare-VersionStrings -Current $versionForCompare -Latest $lookup.BestLatestVersion
        $versionGapText = $null
        if ($versionStatus -in @('OutOfDate', 'Newer')) {
            $versionGapText = 'Current: {0} | Latest: {1}' -f $versionForCompare, $lookup.BestLatestVersion
        }

        $reportRows += [pscustomobject]@{
            DisplayName          = $displayName
            CurrentPublisher     = $currentPub
            CurrentVersion       = $currentVer
            SearchName           = $searchName
            EvergreenAppName     = $lookup.EvergreenAppName
            EvergreenPublisher   = $lookup.EvergreenPublisher
            EvergreenLatestVersion = $lookup.EvergreenLatestVersion
            EvergreenNotes       = $lookup.EvergreenNotes
            GitHubRepo           = $lookup.GitHubRepo
            GitHubPublisher      = $lookup.GitHubPublisher
            GitHubLatestVersion  = $lookup.GitHubLatestVersion
            GitHubNotes          = $lookup.GitHubNotes
            WingetPackageId      = $lookup.WingetPackageId
            WingetPublisher      = $lookup.WingetPublisher
            WingetLatestVersion  = $lookup.WingetLatestVersion
            WingetNotes          = $lookup.WingetNotes
            ChocoPackageId       = $lookup.ChocoPackageId
            ChocoPublisher       = $lookup.ChocoPublisher
            ChocoLatestVersion   = $lookup.ChocoLatestVersion
            ChocoNotes           = $lookup.ChocoNotes
            ResolvedPublisher    = $resolvedPublisher
            BestLatestVersion    = $lookup.BestLatestVersion
            BestSource           = $lookup.BestSource
            MatchScore           = $lookup.MatchScore
            MatchReason          = $lookup.MatchReason
            VersionStatus        = $versionStatus
            VersionGap           = $versionGapText
        }
    }

    Write-Progress -Activity 'SCCM Software Version Audit' -Completed

    # --- Write report ---
    $resolvedReportPath = Get-DefaultOutputPath -FileName ('SCCM-SoftwareVersionAudit-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    $reportRows | Export-Csv -Path $resolvedReportPath -NoTypeInformation -Encoding UTF8
    Write-Log -Level 'SUCCESS' -Message ('Report written to: {0}' -f $resolvedReportPath)

    if ($ExportUnresolvedReport) {
        $resolvedUnresolvedPath = Get-DefaultOutputPath -FileName ('SCCM-SoftwareVersionAudit-Unresolved-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

        $unresolvedRows = @($reportRows | Where-Object {
            $_.VersionStatus -in @('UnknownCurrent', 'UnknownLatest', 'Unknown') -or
            [int]$_.MatchScore -lt 50 -or
            [string]$_.BestSource -eq 'Skipped' -or
            [string]$_.BestSource -eq $null -or
            ([string]$_.BestSource -eq 'Winget' -and [string]$_.WingetNotes -notmatch '^(?i)OK') -or
            ([string]$_.BestSource -eq 'Chocolatey' -and [string]$_.ChocoNotes -notmatch '^(?i)OK')
        })

        $unresolvedRows | Export-Csv -Path $resolvedUnresolvedPath -NoTypeInformation -Encoding UTF8
        Write-Log -Level 'SUCCESS' -Message ('Unresolved report written to: {0} (rows={1})' -f $resolvedUnresolvedPath, $unresolvedRows.Count)
    }

    if ($ExportVendorMap) {
        $resolvedVendorMapPath = Get-DefaultOutputPath -FileName ('SCCM-VendorMap-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

        $vendorMap = New-VendorMapFromReportRows -Rows $reportRows
        $vendorMapJson = $vendorMap | ConvertTo-Json -Depth 5
        Set-Content -Path $resolvedVendorMapPath -Value $vendorMapJson -Encoding UTF8

        Write-Log -Level 'SUCCESS' -Message ('Vendor map JSON written to: {0}' -f $resolvedVendorMapPath)
        Write-Log -Level 'INFO' -Message ('Use with enrichment: -VendorMapPath "{0}"' -f $resolvedVendorMapPath)
    }

    # --- Summary ---
    $grouped  = @($reportRows | Group-Object -Property VersionStatus)
    $summary  = $grouped | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }
    Write-Log -Level 'INFO' -Message ('Summary | {0} | Total={1}' -f ($summary -join ' ; '), $reportRows.Count)
    Save-LookupCache
}
catch {
    Write-Log -Level 'ERROR' -Message ('Fatal error: {0}' -f $_.Exception.Message)
    throw
}
