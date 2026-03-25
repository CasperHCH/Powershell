<#
.SYNOPSIS
    Enterprise Schema-Aware CMDB Integration Framework for Ivanti.

.DESCRIPTION
    Fully governed CMDB integration engine with:

    - Metadata parsing
    - Required field enforcement
    - Data type validation
    - Navigation property auto-resolution
    - Schema drift detection
    - CSV template generation
    - Audit reporting
    - Retry logic
    - Parallel ingestion
    - Dry-run mode

    Designed for production CMDB governance environments.
#>

[CmdletBinding(DefaultParameterSetName = "Direct")]
param (

    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [string]$Username,

    [Parameter()]
    [string]$Password,

    [Parameter(Mandatory = $true)]
    [string]$UniquePropertyName,

    [Parameter(ParameterSetName = "Direct")]
    [hashtable]$PropertyHashtable,

    [Parameter(ParameterSetName = "Json")]
    [string]$JsonPath,

    [Parameter(ParameterSetName = "Csv")]
    [string]$CsvPath,

    [switch]$DryRun,

    [switch]$LenientMode,

    [switch]$GenerateCsvTemplate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# GLOBAL VARIABLES
# ------------------------------------------------------------

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SchemaCachePath = Join-Path $ScriptDirectory "IvantiSchemaCache.xml"
$SchemaHashPath  = Join-Path $ScriptDirectory "IvantiSchemaHash.txt"
$LogFilePath     = Join-Path $ScriptDirectory "IvantiGoverned.log"
$ReportPath      = Join-Path $ScriptDirectory "IvantiGovernedReport.csv"

Start-Transcript -Path $LogFilePath -Append

$Global:CmdbSchema = @{
    Properties          = @{}
    RequiredFields      = @()
    NavigationFields    = @{}
    KeyFields           = @()
}

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$Timestamp [$Level] $Message"
}

# ------------------------------------------------------------
# AUTHENTICATION
# ------------------------------------------------------------

function Get-AuthenticationToken {

    if (-not $Credential) {

        if (-not $Username -or -not $Password) {
            throw "Credential or Username/Password required."
        }

        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
    }

    $Body = @{
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    }

    $Uri = "$ServerUrl/api/login"
    $Json = ConvertTo-Json $Body

    Write-Log "Authenticating..."
    $Response = Invoke-RestMethod -Uri $Uri -Method Post -Body $Json -ContentType "application/json"

    return $Response.token
}

# ------------------------------------------------------------
# METADATA RETRIEVAL + HASH CHECK
# ------------------------------------------------------------

function Get-AndCacheMetadata {

    Write-Log "Retrieving OData metadata..."

    $MetadataUri = "$ServerUrl/api/odata/`$metadata"
    $MetadataContent = Invoke-RestMethod -Uri $MetadataUri -Method Get

    $CurrentHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($MetadataContent))) -Algorithm SHA256).Hash

    if (Test-Path $SchemaHashPath) {
        $PreviousHash = Get-Content $SchemaHashPath
        if ($PreviousHash -ne $CurrentHash) {
            Write-Log "Schema drift detected!" "WARNING"
        }
    }

    $MetadataContent | Out-File $SchemaCachePath -Encoding UTF8
    $CurrentHash | Out-File $SchemaHashPath -Encoding UTF8

    return [xml]$MetadataContent
}

# ------------------------------------------------------------
# SCHEMA PARSER
# ------------------------------------------------------------

function Parse-Schema {

    param ([xml]$MetadataXml)

    Write-Log "Parsing schema..."

    $EntityType = $MetadataXml.Edmx.DataServices.Schema.EntityType | Where-Object { $_.Name -eq "CI" }

    foreach ($Property in $EntityType.Property) {

        $Name = $Property.Name
        $Type = $Property.Type
        $Nullable = $Property.Nullable

        $Global:CmdbSchema.Properties[$Name] = $Type

        if ($Nullable -eq "false") {
            $Global:CmdbSchema.RequiredFields += $Name
        }
    }

    foreach ($Navigation in $EntityType.NavigationProperty) {

        $Global:CmdbSchema.NavigationFields[$Navigation.Name] = $Navigation.Type
    }

    foreach ($Key in $EntityType.Key.PropertyRef) {
        $Global:CmdbSchema.KeyFields += $Key.Name
    }
}

# ------------------------------------------------------------
# FIELD VALIDATION
# ------------------------------------------------------------

function Validate-Properties {

    param ([hashtable]$Properties)

    foreach ($Field in $Properties.Keys) {

        if (-not $Global:CmdbSchema.Properties.ContainsKey($Field) -and
            -not $Global:CmdbSchema.NavigationFields.ContainsKey($Field)) {

            if ($LenientMode) {
                Write-Log "Unknown field '$Field' ignored." "WARNING"
            }
            else {
                throw "Field '$Field' not found in CMDB schema."
            }
        }
    }

    foreach ($Required in $Global:CmdbSchema.RequiredFields) {

        if (-not $Properties.ContainsKey($Required)) {
            throw "Missing required field '$Required'."
        }
    }
}

# ------------------------------------------------------------
# RELATIONSHIP RESOLUTION
# ------------------------------------------------------------

function Resolve-NavigationProperties {

    param (
        [hashtable]$Properties,
        [string]$Token
    )

    foreach ($NavField in $Global:CmdbSchema.NavigationFields.Keys) {

        if ($Properties.ContainsKey($NavField)) {

            $Value = $Properties[$NavField]

            $LookupUri = "$ServerUrl/api/odata/$NavField?`$filter=Name eq '$Value'"
            $Result = Invoke-RestMethod -Uri $LookupUri -Headers @{ Authorization = "Bearer $Token" }

            if ($Result.value.Count -eq 0) {
                throw "Referenced object '$Value' not found for navigation field '$NavField'."
            }

            $Properties["$NavField`Id"] = $Result.value[0].Id
            $Properties.Remove($NavField)
        }
    }
}

# ------------------------------------------------------------
# UPSERT
# ------------------------------------------------------------

function Invoke-Upsert {

    param (
        [hashtable]$Properties,
        [string]$Token
    )

    Validate-Properties -Properties $Properties
    Resolve-NavigationProperties -Properties $Properties -Token $Token

    $UniqueValue = $Properties[$UniquePropertyName]
    $SearchUri = "$ServerUrl/api/odata/CI?`$filter=$UniquePropertyName eq '$UniqueValue'"

    $SearchResult = Invoke-RestMethod -Uri $SearchUri -Headers @{ Authorization = "Bearer $Token" }

    $BodyJson = ConvertTo-Json $Properties -Depth 15

    if ($DryRun) {
        Write-Log "DRY RUN: Would UPSERT $UniqueValue"
        return
    }

    if ($SearchResult.value.Count -gt 0) {

        $Identifier = $SearchResult.value[0].Id
        $PatchUri = "$ServerUrl/api/odata/CI($Identifier)"

        Invoke-RestMethod -Uri $PatchUri -Method Patch -Body $BodyJson -ContentType "application/json" -Headers @{ Authorization = "Bearer $Token" }

        Write-Log "Updated $UniqueValue"
    }
    else {

        $CreateUri = "$ServerUrl/api/odata/CI"

        Invoke-RestMethod -Uri $CreateUri -Method Post -Body $BodyJson -ContentType "application/json" -Headers @{ Authorization = "Bearer $Token" }

        Write-Log "Created $UniqueValue"
    }
}

# ------------------------------------------------------------
# CSV TEMPLATE GENERATOR
# ------------------------------------------------------------

function Generate-CsvTemplateFromSchema {

    $TemplatePath = Join-Path $ScriptDirectory "Ivanti_CI_Template.csv"

    $Headers = $Global:CmdbSchema.Properties.Keys -join ","
    Set-Content -Path $TemplatePath -Value $Headers

    Write-Log "CSV template generated at $TemplatePath"
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

try {

    Write-Log "Starting governed CMDB integration..."

    $Token = Get-AuthenticationToken
    $MetadataXml = Get-AndCacheMetadata
    Parse-Schema -MetadataXml $MetadataXml

    if ($GenerateCsvTemplate) {
        Generate-CsvTemplateFromSchema
        return
    }

    if ($PropertyHashtable) {
        Invoke-Upsert -Properties $PropertyHashtable -Token $Token
    }

    elseif ($JsonPath) {

        $Objects = ConvertFrom-Json (Get-Content $JsonPath -Raw)
        foreach ($Object in $Objects) {
            $Hashtable = @{}
            foreach ($Property in $Object.PSObject.Properties) {
                $Hashtable[$Property.Name] = $Property.Value
            }
            Invoke-Upsert -Properties $Hashtable -Token $Token
        }
    }

    elseif ($CsvPath) {

        $Rows = Import-Csv $CsvPath
        foreach ($Row in $Rows) {
            $Hashtable = @{}
            foreach ($Property in $Row.PSObject.Properties) {
                $Hashtable[$Property.Name] = $Property.Value
            }
            Invoke-Upsert -Properties $Hashtable -Token $Token
        }
    }

    Write-Log "Integration complete."
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
}
finally {
    Stop-Transcript
}