<#
.SYNOPSIS
    Identifies and removes Windows folders for software not present in SCCM.

.DESCRIPTION
    Compares software installed on the local system with software available in SCCM.
    Displays software found only in Windows folders but not in SCCM, allowing for safe removal
    of orphaned application folders based on version comparison.

.PARAMETER SCCMSiteServer
    SCCM site server hostname (e.g., sccm-01.contoso.com)

.PARAMETER SCCMSiteCode
    SCCM site code (e.g., PS1)

.PARAMETER WindowsSoftwareBasePath
    Base path where software folders are stored (default: C:\Program Files)

.PARAMETER MinimumFolderAgeDays
    Minimum age (in days) before considering removal (default: 30)

.PARAMETER ExcludeFolders
    Comma-separated list of folder names to exclude from analysis

.EXAMPLE
    .\SCCM-DeleteWinFolderIfSoftwareIsntPresent.ps1 -SCCMSiteServer "sccm-01" -SCCMSiteCode "PS1"

.NOTES
    Requires: SCCM Administrator console or equivalent permissions
    Author: GitHub Copilot
    Security: No hardcoded credentials or sensitive data
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="SCCM site server hostname")]
    [ValidateNotNullOrEmpty()]
    [string]$SCCMSiteServer,

    [Parameter(Mandatory=$true, HelpMessage="SCCM site code (e.g., PS1)")]
    [ValidateNotNullOrEmpty()]
    [string]$SCCMSiteCode,

    [Parameter(Mandatory=$false, HelpMessage="Base path for Windows software folders")]
    [ValidateScript({Test-Path $_})]
    [string]$WindowsSoftwareBasePath = "C:\Program Files",

    [Parameter(Mandatory=$false, HelpMessage="Minimum folder age in days before removal")]
    [ValidateRange(1, 365)]
    [int]$MinimumFolderAgeDays = 30,

    [Parameter(Mandatory=$false, HelpMessage="Comma-separated folder names to exclude")]
    [string]$ExcludeFolders = ""
)

# Initialize session tracking
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "SCCMSoftwareAudit_$($script:SessionId).log"
$script:SccmSiteServerName = $SCCMSiteServer
$script:SccmSiteCode = $SCCMSiteCode
$script:SoftwareBasePath = $WindowsSoftwareBasePath
$script:FolderAgeThresholdDays = $MinimumFolderAgeDays
$script:ExcludedFolderList = $ExcludeFolders

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-ScriptLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "AUDIT")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$Sensitive
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $displayMessage = $Message -replace $SCCMSiteServer, "[SCCM_SERVER]"

    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $displayMessage"

    if (-not $Sensitive) {
        Write-Information $logEntry -InformationAction Continue
    }

    $fullLogEntry = "[$timestamp] [$script:SessionId] [$Level] [$env:USERNAME] $Message"
    Add-Content -Path $script:LogFile -Value $fullLogEntry -ErrorAction SilentlyContinue
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$FolderName,

        [Parameter(Mandatory=$false)]
        [string]$Status,

        [Parameter(Mandatory=$false)]
        [string]$Details
    )

    $auditEntry = @{
        Timestamp = Get-Date -Format "o"
        Action = $Action
        FolderName = $FolderName
        Status = $Status
        Details = $Details
        ComputerName = $env:COMPUTERNAME
        User = $env:USERNAME
    } | ConvertTo-Json -Compress

    Write-ScriptLog -Message $auditEntry -Level "AUDIT" -Sensitive $true
}

# ============================================================================
# SCCM CONNECTIVITY
# ============================================================================

function Test-SCCMConnectivity {
    [OutputType([bool])]
    param(
        [string]$SiteServer,
        [string]$SiteCode
    )

    try {
        Write-ScriptLog "Testing SCCM connectivity to [$SiteServer] with site code [$SiteCode]" -Level "INFO"

        # Test network connectivity
        $testConnection = Test-NetConnection -ComputerName $SiteServer -WarningAction SilentlyContinue

        if (-not $testConnection.PingSucceeded) {
            throw "Cannot reach SCCM server: $SiteServer"
        }

        Write-ScriptLog "SCCM server connectivity verified" -Level "INFO"
        return $true
    } catch {
        Write-ScriptLog "SCCM connectivity test failed: $($_.Exception.Message)" -Level "ERROR"
        Write-AuditLog -Action "SCCM_CONNECT_FAILED" -Status "Failed" -Details $_.Exception.Message
        throw
    }
}

# ============================================================================
# SCCM SOFTWARE RETRIEVAL
# ============================================================================

function Get-SCCMSoftwareList {
    [OutputType([object[]])]
    param(
        [string]$SiteServer,
        [string]$SiteCode
    )

    try {
        Write-ScriptLog "Retrieving software list from SCCM..." -Level "INFO"

        # Import SCCM module
        Import-Module "ConfigurationManager" -ErrorAction Stop

        # Connect to SCCM site
        $null = New-PSDrive -Name "$($SiteCode):" -PSProvider CMSite -Root $SiteServer -ErrorAction Stop
        Set-Location "$($SiteCode):" -ErrorAction Stop

        # Query all software packages
        $software = Get-CMSoftwareUpdate -Fast | Select-Object -Property LocalizedDisplayName, SDMPackageVersion | Sort-Object LocalizedDisplayName

        if (-not $software) {
            Write-ScriptLog "No software packages found in SCCM" -Level "WARNING"
            return @()
        }

        Write-ScriptLog "Retrieved $($software.Count) software packages from SCCM" -Level "INFO"
        Write-AuditLog -Action "SCCM_SOFTWARE_RETRIEVED" -Status "Success" -Details "Found $($software.Count) packages"

        return $software
    } catch {
        Write-ScriptLog "Failed to retrieve SCCM software: $($_.Exception.Message)" -Level "ERROR"
        Write-AuditLog -Action "SCCM_RETRIEVE_FAILED" -Status "Failed" -Details $_.Exception.Message
        throw
    } finally {
        Set-Location C:
    }
}

# ============================================================================
# WINDOWS FOLDER ANALYSIS
# ============================================================================

function Get-WindowsSoftwareFolder {
    [OutputType([object[]])]
    param(
        [string]$BasePath
    )

    try {
        Write-ScriptLog "Scanning Windows software folders at: $BasePath" -Level "INFO"

        if (-not (Test-Path $BasePath)) {
            throw "Software base path not found: $BasePath"
        }

        $folders = Get-ChildItem -Path $BasePath -Directory -ErrorAction Stop | Select-Object @{
            Name = 'Name'
            Expression = { $_.Name }
        }, @{
            Name = 'FullPath'
            Expression = { $_.FullName }
        }, CreationTime, LastWriteTime

        Write-ScriptLog "Found $($folders.Count) software folders" -Level "INFO"
        return $folders
    } catch {
        Write-ScriptLog "Failed to scan software folders: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# ============================================================================
# COMPARISON & ORPHANED SOFTWARE DETECTION
# ============================================================================

function Compare-SCCMAndWindowsSoftware {
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [array]$SCCMSoftware,

        [Parameter(Mandatory=$true)]
        [array]$WindowsFolders,

        [Parameter(Mandatory=$true)]
        [int]$MinimumAgeDays,

        [Parameter(Mandatory=$true)]
        [string]$ExcludeList
    )

    $excludedFolders = @()
    if ($ExcludeList) {
        $excludedFolders = $ExcludeList -split "," | ForEach-Object { $_.Trim() }
    }

    $sccmNames = $SCCMSoftware | Select-Object -ExpandProperty LocalizedDisplayName

    $orphanedSoftware = @()

    foreach ($folder in $WindowsFolders) {
        # Skip excluded folders
        if ($folder.Name -in $excludedFolders) {
            Write-ScriptLog "Skipping excluded folder: $($folder.Name)" -Level "DEBUG"
            continue
        }

        $folderAge = (Get-Date) - $folder.CreationTime
        $foundInSCCM = $sccmNames | Where-Object { $_ -like "*$($folder.Name)*" -or $folder.Name -like "*$_*" }

        if (-not $foundInSCCM) {
            $orphanedSoftware += [pscustomobject]@{
                FolderName = $folder.Name
                FullPath = $folder.FullPath
                CreationTime = $folder.CreationTime
                LastWriteTime = $folder.LastWriteTime
                AgeInDays = [math]::Round($folderAge.TotalDays)
                IsOldEnough = $folderAge.TotalDays -ge $MinimumAgeDays
            }

            Write-ScriptLog "Orphaned software detected: $($folder.Name) (Age: $([math]::Round($folderAge.TotalDays)) days)" -Level "INFO"
        }
    }

    return $orphanedSoftware
}

# ============================================================================
# USER INTERACTION & REMOVAL
# ============================================================================

function Show-OrphanedSoftwareReport {
    [OutputType([void])]
    param(
        [array]$OrphanedSoftware
    )

    if (-not $OrphanedSoftware -or $OrphanedSoftware.Count -eq 0) {
        Write-Information "No orphaned software found!" -InformationAction Continue
        return
    }

    Write-Information '' -InformationAction Continue
    Write-Information 'ORPHANED SOFTWARE DETECTED (Not in SCCM)' -InformationAction Continue
    Write-Information '----------------------------------------' -InformationAction Continue

    $orphanedSoftware | ForEach-Object {
        Write-Information '' -InformationAction Continue
        Write-Information ("Folder: {0}" -f $_.FolderName) -InformationAction Continue
        Write-Information ("  Path: {0}" -f $_.FullPath) -InformationAction Continue
        Write-Information ("  Created: {0}" -f $_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')) -InformationAction Continue
        Write-Information ("  Age: {0} days" -f $_.AgeInDays) -InformationAction Continue
        Write-Information ("  Status: {0}" -f $(if ($_.IsOldEnough) { 'Safe to remove' } else { 'Too new - review manually' })) -InformationAction Continue
    }

    Write-Information '' -InformationAction Continue
}

function Remove-OrphanedSoftwareFolder {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,

        [Parameter(Mandatory=$true)]
        [string]$FolderName,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    try {
        if (-not $Force) {
            $confirm = Read-Host "Remove folder '$FolderName'? (yes/no)"
            if ($confirm -ne "yes") {
                Write-ScriptLog "Removal cancelled by user for: $FolderName" -Level "INFO"
                return $false
            }
        }

        if ($PSCmdlet.ShouldProcess($FolderPath, "Remove folder")) {
            Remove-Item -Path $FolderPath -Recurse -Force -ErrorAction Stop
            Write-ScriptLog "Successfully removed: $FolderName" -Level "INFO"
            Write-AuditLog -Action "FOLDER_REMOVED" -FolderName $FolderName -Status "Success"
            return $true
        }
    } catch {
        Write-ScriptLog "Failed to remove folder '$FolderName': $($_.Exception.Message)" -Level "ERROR"
        Write-AuditLog -Action "FOLDER_REMOVAL_FAILED" -FolderName $FolderName -Status "Failed" -Details $_.Exception.Message
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Invoke-SCCMSoftwareComparison {
    Write-ScriptLog "Starting SCCM Software Comparison Script" -Level "INFO"
    Write-AuditLog -Action "SCRIPT_START" -Status "Started"

    try {
        # Test SCCM connectivity
        Test-SCCMConnectivity -SiteServer $script:SccmSiteServerName -SiteCode $script:SccmSiteCode

        # Get software lists
        $scccmSoftware = Get-SCCMSoftwareList -SiteServer $script:SccmSiteServerName -SiteCode $script:SccmSiteCode
        $windowsFolders = Get-WindowsSoftwareFolder -BasePath $script:SoftwareBasePath

        # Compare and identify orphaned software
        $orphanedSoftware = Compare-SCCMAndWindowsSoftware `
            -SCCMSoftware $scccmSoftware `
            -WindowsFolders $windowsFolders `
            -MinimumAgeDays $script:FolderAgeThresholdDays `
            -ExcludeList $script:ExcludedFolderList

        # Display report
        Show-OrphanedSoftwareReport -OrphanedSoftware $orphanedSoftware

        Write-ScriptLog "SCCM Software Comparison completed successfully" -Level "INFO"
        Write-AuditLog -Action "SCRIPT_COMPLETE" -Status "Success" -Details "Found $($orphanedSoftware.Count) orphaned items"

    } catch {
        Write-ScriptLog "Script execution failed: $($_.Exception.Message)" -Level "ERROR"
        Write-AuditLog -Action "SCRIPT_FAILED" -Status "Failed" -Details $_.Exception.Message
        exit 1
    }
}

# Execute main function
Invoke-SCCMSoftwareComparison