<#
.SYNOPSIS
Exports SCCM Applications and Packages to a CSV file.

.DESCRIPTION
Attempts to use the ConfigurationManager module (Get-CMApplication/Get-CMPackage) if available;
otherwise queries the SMS Provider WMI namespace (root\SMS\site_<SiteCode>) to enumerate
applications and packages. Exports a unified CSV with Type, Name, ID, Version, Publisher,
IsEnabled and Description.

.PARAMETER ProviderServer
SCCM provider server (FQDN or hostname). Defaults to the local computer.

.PARAMETER SiteCode
SCCM Site Code (e.g., ABC). Required when the ConfigurationManager module is not available.

.PARAMETER OutputPath
Path to the CSV output. Defaults to a file named "SCCM_Applications_And_Packages.csv"
in the script folder.

.PARAMETER CsvEncoding
Encoding used by Export-Csv. Defaults to 'UTF8'.

.PARAMETER UseConfigManagerModule
Switch to require the ConfigurationManager module. If set but module is not present,
the script will stop.

.EXAMPLE
.
\Export-SCCMAppsAndPackages.ps1 -ProviderServer sccm01 -SiteCode ABC -OutputPath C:\temp\sccm.csv

.NOTES
- Run with an account that can read from the SCCM site server / SMS Provider.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderServer = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteCode = '',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "SCCM_Applications_And_Packages.csv"),

    [Parameter(Mandatory = $false)]
    [ValidateSet('UTF8', 'UTF7', 'Unicode', 'UTF32', 'ASCII', 'Default')]
    [string]$CsvEncoding = 'UTF8',

    [Parameter(Mandatory = $false)]
    [switch]$UseConfigManagerModule
)

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)] [string]$Action,
        [Parameter(Mandatory = $false)] [string]$Target,
        [Parameter(Mandatory = $true)] [string]$User = $env:USERNAME,
        [Parameter(Mandatory = $false)] [string]$Error
    )
    $logPath = Join-Path -Path $PSScriptRoot -ChildPath "Export-SCCMAppsAndPackages.log"
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('o')
        Action    = $Action
        Target    = $Target
        User      = $User
        Error     = $Error
        Computer  = $env:COMPUTERNAME
    }
    try {
        $entry | ConvertTo-Json -Compress | Add-Content -Path $logPath -Encoding UTF8
    } catch {
        Write-Verbose "Failed to write audit log: $_"
    }
}

Write-Verbose "Starting SCCM export (ProviderServer=$ProviderServer, SiteCode=$SiteCode)"

# Detect / import ConfigurationManager module if available
$canUseCM = $false
try {
    if (Get-Command -Name Get-CMApplication -ErrorAction SilentlyContinue) {
        $canUseCM = $true
    } elseif (Get-Module -ListAvailable -Name ConfigurationManager -ErrorAction SilentlyContinue) {
        try {
            Import-Module ConfigurationManager -ErrorAction Stop
            if (Get-Command -Name Get-CMApplication -ErrorAction SilentlyContinue) {
                $canUseCM = $true
            }
        } catch {
            Write-Verbose "Import-Module ConfigurationManager failed: $_"
            $canUseCM = $false
        }
    }
} catch {
    Write-Verbose "Error checking ConfigurationManager module: $_"
    $canUseCM = $false
}

if ($UseConfigManagerModule.IsPresent -and -not $canUseCM) {
    throw "ConfigurationManager module requested but not available on this system."
}

$apps = @()
$packages = @()

if ($canUseCM) {
    Write-Verbose "Using ConfigurationManager module to enumerate items."
    try {
        if ($SiteCode) {
            # try to change to site PSDrive if present
            try { Set-Location "$SiteCode`:" -ErrorAction SilentlyContinue } catch { }
        }
        $apps = Get-CMApplication -ErrorAction Stop
        $packages = Get-CMPackage -ErrorAction Stop
    } catch {
        Write-Verbose "ConfigurationManager query failed, falling back to SMS Provider WMI: $_"
        $apps = @(); $packages = @(); $canUseCM = $false
    }
}

if (-not $canUseCM) {
    if (-not $SiteCode) {
        throw "-SiteCode is required when the ConfigurationManager module is not available. Provide -SiteCode.`nExample: -SiteCode ABC"
    }
    $namespace = "root/SMS/site_$SiteCode"
    try {
        Write-Verbose "Querying SMS Provider on $ProviderServer (namespace: $namespace)"
        $apps = Get-CimInstance -Namespace $namespace -ClassName SMS_Application -ComputerName $ProviderServer -ErrorAction Stop
        $packages = Get-CimInstance -Namespace $namespace -ClassName SMS_Package -ComputerName $ProviderServer -ErrorAction Stop
    } catch {
        throw "Failed to query SMS Provider on $ProviderServer/$namespace : $($_.Exception.Message)"
    }
}

function Map-Item {
    param(
        [Parameter(ValueFromPipeline = $true)] $InputObject,
        [Parameter(Mandatory = $true)] [string]$TypeLabel
    )
    process {
        $id = if ($InputObject.PSObject.Properties['CI_ID']) { $InputObject.CI_ID } elseif ($InputObject.PSObject.Properties['PackageID']) { $InputObject.PackageID } elseif ($InputObject.PSObject.Properties['CI_UniqueID']) { $InputObject.CI_UniqueID } else { $null }
        $version = if ($InputObject.PSObject.Properties['SoftwareVersion']) { $InputObject.SoftwareVersion } elseif ($InputObject.PSObject.Properties['Version']) { $InputObject.Version } else { $null }
        $publisher = if ($InputObject.PSObject.Properties['Publisher']) { $InputObject.Publisher } elseif ($InputObject.PSObject.Properties['Manufacturer']) { $InputObject.Manufacturer } else { $null }
        $isEnabled = if ($InputObject.PSObject.Properties['IsEnabled']) { $InputObject.IsEnabled } elseif ($InputObject.PSObject.Properties['IsHidden']) { -not $InputObject.IsHidden } else { $null }
        $description = if ($InputObject.PSObject.Properties['Description']) { $InputObject.Description } else { $null }

        [PSCustomObject]@{
            Type        = $TypeLabel
            Name        = $InputObject.Name
            ID          = $id
            Version     = $version
            Publisher   = $publisher
            IsEnabled   = $isEnabled
            Description = $description
        }
    }
}

$mappedApps = @()
$mappedPkgs = @()
if ($apps) { $mappedApps = $apps | Map-Item -TypeLabel 'Application' }
if ($packages) { $mappedPkgs = $packages | Map-Item -TypeLabel 'Package' }

$items = @()
if ($mappedApps) { $items += $mappedApps }
if ($mappedPkgs) { $items += $mappedPkgs }

if (-not $items -or $items.Count -eq 0) {
    Write-Warning "No applications or packages found."
    Write-AuditLog -Action 'EXPORT_EMPTY' -Target $OutputPath -User $env:USERNAME
    exit 0
}

try {
    $items | Sort-Object Type, Name | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding $CsvEncoding -Force
    Write-Host "Exported $($items.Count) items to $OutputPath"
    Write-AuditLog -Action 'EXPORT_SUCCESS' -Target $OutputPath -User $env:USERNAME
} catch {
    Write-AuditLog -Action 'EXPORT_FAILED' -Target $OutputPath -User $env:USERNAME -Error $_.Exception.Message
    throw "Failed to export CSV: $($_.Exception.Message)"
}

# EOF
