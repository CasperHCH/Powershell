<#
.SYNOPSIS
    Build a unified endpoint inventory from Ivanti CMDB, SCCM, and Zabbix.

.DESCRIPTION
    Normalizes records from three endpoint data sources into one dataset and exports CSV/JSON output.
    This MVP supports CSV ingestion fully and API ingestion for Ivanti/Zabbix as a starting point.

.PARAMETER Mode
    Data ingestion mode: Csv or Api.

.PARAMETER IvantiCmdbCsvPath
    Path to Ivanti CMDB CSV export when Mode is Csv.

.PARAMETER SccmCsvPath
    Path to SCCM device CSV export when Mode is Csv.

.PARAMETER ZabbixCsvPath
    Path to Zabbix host CSV export when Mode is Csv.

.PARAMETER IvantiApiBaseUrl
    HTTPS base URL for Ivanti CMDB API when Mode is Api.

.PARAMETER IvantiApiToken
    Secure token for Ivanti CMDB API.

.PARAMETER ZabbixApiBaseUrl
    HTTPS base URL for Zabbix API when Mode is Api.

.PARAMETER ZabbixAuthToken
    Secure token for Zabbix API.

.PARAMETER OrganizationDomain
    Optional domain string to sanitize in console output.

.PARAMETER DaysStaleThreshold
    Device stale threshold in days used for IsStale calculation.

.PARAMETER OutputPath
    Destination folder for generated reports.

.EXAMPLE
    .\Get-EpmUnifiedInventory.ps1 -Mode Csv -IvantiCmdbCsvPath C:\Data\ivanti.csv -SccmCsvPath C:\Data\sccm.csv -ZabbixCsvPath C:\Data\zabbix.csv

.NOTES
    SECURITY CLASSIFICATION: INTERNAL
    DATA HANDLING: Endpoint inventory metadata only.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Csv", "Api")]
    [string]$Mode = "Csv",

    [Parameter(Mandatory = $false)]
    [string]$IvantiCmdbCsvPath,

    [Parameter(Mandatory = $false)]
    [string]$SccmCsvPath,

    [Parameter(Mandatory = $false)]
    [string]$ZabbixCsvPath,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ -match '^https://' })]
    [string]$IvantiApiBaseUrl,

    [Parameter(Mandatory = $false)]
    [SecureString]$IvantiApiToken,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ -match '^https://' })]
    [string]$ZabbixApiBaseUrl,

    [Parameter(Mandatory = $false)]
    [SecureString]$ZabbixAuthToken,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$DaysStaleThreshold = 30,

    [Parameter(Mandatory = $false)]
    [string]$OrganizationDomain,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot "output")
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogPath = Join-Path $PSScriptRoot "Get-EpmUnifiedInventory.log"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $displayMessage = $Message

    if ($OrganizationDomain) {
        $displayMessage = $displayMessage -replace [regex]::Escape($OrganizationDomain), "[DOMAIN]"
    }

    $line = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"
    if (-not $Sensitive) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "AUDIT" { "Cyan" }
            default { "White" }
        }
        Write-Host $line -ForegroundColor $color
    }

    $fullLine = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    Add-Content -Path $script:LogPath -Value $fullLine
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalData
    )

    $entry = @{
        Timestamp = (Get-Date).ToString("o")
        SessionId = $script:SessionId
        Action = $Action
        User = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        ScriptName = $MyInvocation.ScriptName
        AdditionalData = $AdditionalData
    }

    Write-Log -Message ($entry | ConvertTo-Json -Compress) -Level "AUDIT" -Sensitive
}

function ConvertTo-PlainText {
    param([SecureString]$SecureValue)

    if (-not $SecureValue) {
        return $null
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Resolve-Field {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Record,

        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($name in $Candidates) {
        $property = $Record.PSObject.Properties[$name]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    return $null
}

function Resolve-Date {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    try {
        return [datetime]::Parse($Value)
    }
    catch {
        return $null
    }
}

function Get-IdentityKey {
    param(
        [string]$SerialNumber,
        [string]$BiosUuid,
        [string]$HostName
    )

    if (-not [string]::IsNullOrWhiteSpace($SerialNumber)) {
        return "SERIAL:$($SerialNumber.Trim().ToUpperInvariant())"
    }
    if (-not [string]::IsNullOrWhiteSpace($BiosUuid)) {
        return "UUID:$($BiosUuid.Trim().ToUpperInvariant())"
    }
    if (-not [string]::IsNullOrWhiteSpace($HostName)) {
        return "HOST:$($HostName.Trim().ToUpperInvariant())"
    }
    return $null
}

function Get-RecordsFromCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    if (-not (Test-Path -Path $Path)) {
        throw "CSV path not found for source '$Source': $Path"
    }

    $rows = Import-Csv -Path $Path
    Write-Log -Message "Loaded $($rows.Count) records from $Source CSV" -Level "INFO"
    return $rows
}

function Get-IvantiApiRecords {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [SecureString]$Token
    )

    $tokenPlain = ConvertTo-PlainText -SecureValue $Token
    $headers = @{
        Authorization = "Bearer $tokenPlain"
        Accept = "application/json"
    }

    try {
        $uri = "$ApiBaseUrl/api/ci"
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
        if ($response.items) { return $response.items }
        return @($response)
    }
    finally {
        $tokenPlain = $null
    }
}

function Get-ZabbixApiRecords {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [SecureString]$Token
    )

    $tokenPlain = ConvertTo-PlainText -SecureValue $Token
    $headers = @{
        Authorization = "Bearer $tokenPlain"
        Accept = "application/json"
    }

    try {
        $uri = "$ApiBaseUrl/api_jsonrpc.php"
        $body = @{
            jsonrpc = "2.0"
            method = "host.get"
            params = @{ output = @("host", "name", "status") }
            id = 1
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
        if ($response.result) { return $response.result }
        return @()
    }
    finally {
        $tokenPlain = $null
    }
}

function Update-InventoryRecord {
    param(
        [hashtable]$Inventory,
        [pscustomobject]$Normalized,
        [string]$SourceName
    )

    $key = Get-IdentityKey -SerialNumber $Normalized.SerialNumber -BiosUuid $Normalized.BiosUuid -HostName $Normalized.HostName
    if (-not $key) {
        return
    }

    if (-not $Inventory.ContainsKey($key)) {
        $Inventory[$key] = [ordered]@{
            IdentityKey = $key
            HostName = $Normalized.HostName
            SerialNumber = $Normalized.SerialNumber
            BiosUuid = $Normalized.BiosUuid
            OperatingSystem = $Normalized.OperatingSystem
            LastSeenIvanti = $null
            LastSeenSccm = $null
            LastSeenZabbix = $null
            OwnerIvanti = $null
            OwnerSccm = $null
            OwnerZabbix = $null
            SiteIvanti = $null
            SiteSccm = $null
            SiteZabbix = $null
            InIvantiCmdb = $false
            InSccm = $false
            InZabbix = $false
        }
    }

    $current = $Inventory[$key]
    if ([string]::IsNullOrWhiteSpace($current.HostName) -and $Normalized.HostName) {
        $current.HostName = $Normalized.HostName
    }
    if ([string]::IsNullOrWhiteSpace($current.SerialNumber) -and $Normalized.SerialNumber) {
        $current.SerialNumber = $Normalized.SerialNumber
    }
    if ([string]::IsNullOrWhiteSpace($current.BiosUuid) -and $Normalized.BiosUuid) {
        $current.BiosUuid = $Normalized.BiosUuid
    }
    if ([string]::IsNullOrWhiteSpace($current.OperatingSystem) -and $Normalized.OperatingSystem) {
        $current.OperatingSystem = $Normalized.OperatingSystem
    }

    switch ($SourceName) {
        "Ivanti" {
            $current.InIvantiCmdb = $true
            $current.LastSeenIvanti = $Normalized.LastSeen
            $current.OwnerIvanti = $Normalized.Owner
            $current.SiteIvanti = $Normalized.Site
        }
        "Sccm" {
            $current.InSccm = $true
            $current.LastSeenSccm = $Normalized.LastSeen
            $current.OwnerSccm = $Normalized.Owner
            $current.SiteSccm = $Normalized.Site
        }
        "Zabbix" {
            $current.InZabbix = $true
            $current.LastSeenZabbix = $Normalized.LastSeen
            $current.OwnerZabbix = $Normalized.Owner
            $current.SiteZabbix = $Normalized.Site
        }
    }
}

function ConvertTo-NormalizedRecord {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InputRecord,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Ivanti", "Sccm", "Zabbix")]
        [string]$Source
    )

    return [pscustomobject]@{
        HostName = Resolve-Field -Record $InputRecord -Candidates @("HostName", "Hostname", "Name", "DeviceName", "host")
        SerialNumber = Resolve-Field -Record $InputRecord -Candidates @("SerialNumber", "Serial", "Serial No", "serial", "Serial_No")
        BiosUuid = Resolve-Field -Record $InputRecord -Candidates @("BiosUuid", "BIOSUUID", "UUID", "SystemUUID")
        Owner = Resolve-Field -Record $InputRecord -Candidates @("Owner", "PrimaryUser", "AssignedUser", "owner")
        Site = Resolve-Field -Record $InputRecord -Candidates @("Site", "Location", "SiteCode", "site")
        OperatingSystem = Resolve-Field -Record $InputRecord -Candidates @("OperatingSystem", "OS", "OSName", "platform")
        LastSeen = Resolve-Date -Value (Resolve-Field -Record $InputRecord -Candidates @("LastSeen", "LastContact", "LastActive", "LastCheckIn", "lastaccess"))
        Source = $Source
    }
}

try {
    Write-Log -Message "Starting unified inventory build. Mode=$Mode" -Level "INFO"
    Write-AuditLog -Action "UNIFIED_INVENTORY_START" -AdditionalData @{ Mode = $Mode }

    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $ivantiRecords = @()
    $sccmRecords = @()
    $zabbixRecords = @()

    if ($Mode -eq "Csv") {
        if (-not $IvantiCmdbCsvPath -or -not $SccmCsvPath -or -not $ZabbixCsvPath) {
            throw "When Mode is Csv, IvantiCmdbCsvPath, SccmCsvPath, and ZabbixCsvPath are required."
        }

        $ivantiRecords = Get-RecordsFromCsv -Path $IvantiCmdbCsvPath -Source "Ivanti"
        $sccmRecords = Get-RecordsFromCsv -Path $SccmCsvPath -Source "SCCM"
        $zabbixRecords = Get-RecordsFromCsv -Path $ZabbixCsvPath -Source "Zabbix"
    }
    else {
        if (-not $IvantiApiBaseUrl -or -not $IvantiApiToken -or -not $ZabbixApiBaseUrl -or -not $ZabbixAuthToken) {
            throw "When Mode is Api, IvantiApiBaseUrl, IvantiApiToken, ZabbixApiBaseUrl, and ZabbixAuthToken are required."
        }

        $ivantiRecords = Get-IvantiApiRecords -ApiBaseUrl $IvantiApiBaseUrl -Token $IvantiApiToken
        $zabbixRecords = Get-ZabbixApiRecords -ApiBaseUrl $ZabbixApiBaseUrl -Token $ZabbixAuthToken

        Write-Log -Message "SCCM API mode is not implemented in this MVP. Provide SCCM data by CSV for now." -Level "WARNING"
        $sccmRecords = @()
    }

    $inventory = @{}

    foreach ($record in $ivantiRecords) {
        $normalized = ConvertTo-NormalizedRecord -InputRecord $record -Source "Ivanti"
        Update-InventoryRecord -Inventory $inventory -Normalized $normalized -SourceName "Ivanti"
    }

    foreach ($record in $sccmRecords) {
        $normalized = ConvertTo-NormalizedRecord -InputRecord $record -Source "Sccm"
        Update-InventoryRecord -Inventory $inventory -Normalized $normalized -SourceName "Sccm"
    }

    foreach ($record in $zabbixRecords) {
        $normalized = ConvertTo-NormalizedRecord -InputRecord $record -Source "Zabbix"
        Update-InventoryRecord -Inventory $inventory -Normalized $normalized -SourceName "Zabbix"
    }

    $staleCutoff = (Get-Date).AddDays(-$DaysStaleThreshold)
    $result = foreach ($item in $inventory.Values) {
        $latestSeen = @($item.LastSeenIvanti, $item.LastSeenSccm, $item.LastSeenZabbix) |
            Where-Object { $_ -is [datetime] } |
            Sort-Object -Descending |
            Select-Object -First 1

        [pscustomobject]@{
            IdentityKey = $item.IdentityKey
            HostName = $item.HostName
            SerialNumber = $item.SerialNumber
            BiosUuid = $item.BiosUuid
            OperatingSystem = $item.OperatingSystem
            InIvantiCmdb = $item.InIvantiCmdb
            InSccm = $item.InSccm
            InZabbix = $item.InZabbix
            LastSeenIvanti = $item.LastSeenIvanti
            LastSeenSccm = $item.LastSeenSccm
            LastSeenZabbix = $item.LastSeenZabbix
            LastSeenLatest = $latestSeen
            OwnerIvanti = $item.OwnerIvanti
            OwnerSccm = $item.OwnerSccm
            OwnerZabbix = $item.OwnerZabbix
            SiteIvanti = $item.SiteIvanti
            SiteSccm = $item.SiteSccm
            SiteZabbix = $item.SiteZabbix
            MissingInIvantiCmdb = ($item.InSccm -and -not $item.InIvantiCmdb)
            MissingInSccm = ($item.InIvantiCmdb -and -not $item.InSccm)
            MissingInZabbix = (($item.InIvantiCmdb -or $item.InSccm) -and -not $item.InZabbix)
            IsStale = ($latestSeen -and $latestSeen -lt $staleCutoff)
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvOut = Join-Path $OutputPath "UnifiedInventory_$timestamp.csv"
    $jsonOut = Join-Path $OutputPath "UnifiedInventory_$timestamp.json"

    $result | Sort-Object HostName | Export-Csv -Path $csvOut -NoTypeInformation -Encoding UTF8
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonOut -Encoding UTF8

    $summary = [ordered]@{
        TotalDevices = $result.Count
        InIvantiCmdb = ($result | Where-Object { $_.InIvantiCmdb }).Count
        InSccm = ($result | Where-Object { $_.InSccm }).Count
        InZabbix = ($result | Where-Object { $_.InZabbix }).Count
        MissingInIvantiCmdb = ($result | Where-Object { $_.MissingInIvantiCmdb }).Count
        MissingInSccm = ($result | Where-Object { $_.MissingInSccm }).Count
        MissingInZabbix = ($result | Where-Object { $_.MissingInZabbix }).Count
        StaleDevices = ($result | Where-Object { $_.IsStale }).Count
    }

    Write-Host "`nUnified inventory summary:" -ForegroundColor Cyan
    $summary.GetEnumerator() | ForEach-Object {
        Write-Host (" - {0}: {1}" -f $_.Key, $_.Value) -ForegroundColor White
    }

    Write-Host "`nOutputs:" -ForegroundColor Cyan
    Write-Host " - $csvOut" -ForegroundColor White
    Write-Host " - $jsonOut" -ForegroundColor White

    Write-AuditLog -Action "UNIFIED_INVENTORY_COMPLETE" -AdditionalData @{
        TotalDevices = $summary.TotalDevices
        CsvPath = $csvOut
        JsonPath = $jsonOut
    }
}
catch {
    Write-Log -Message "Unified inventory failed: $($_.Exception.Message)" -Level "ERROR"
    Write-AuditLog -Action "UNIFIED_INVENTORY_FAILED" -AdditionalData @{ Error = $_.Exception.Message }
    throw
}
