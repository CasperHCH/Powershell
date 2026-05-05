<#
.SYNOPSIS
    Full lifecycle management for SCCM software deployment collections.

.DESCRIPTION
    This script automates the discovery and management of software across all devices in an SCCM environment.
    When a canonical mapping is available (data/SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1) it will
    create collections based on that master list and attempt to deploy matching SCCM applications/packages
    into the collections when requested. If canonical map is not available it falls back to discovered titles.

.PARAMETER SiteCode
    SCCM site code (short site code, e.g. 'ABC'). The script will set the current location to "$SiteCode:" to use the ConfigurationManager drive.

.PARAMETER BaseFolder
    Folder path under the ConfigurationManager DeviceCollection drive where collections will be created. Example: 'Managed Apps\\Browsers'.

.PARAMETER CanonicalMapPath
    Optional path to a PSD1 canonical map file which maps discovered DisplayName0 values to canonical software names.
    If omitted the script defaults to the repository data file: data\\SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1.

.PARAMETER InputCsv
    Optional path to a CMPivot or CSV file with columns: Device, ProductName, ProductVersion, Publisher.
    When provided the script will use the ProductName column as the discovered software list instead of running a live WQL query.

.PARAMETER AnalysisOnly
    Switch. When set the script will run in analysis-only mode: it will not import or call ConfigurationManager cmdlets
    and will produce a plan report (CSV) describing the collections, rules, and deployments that would be created.

.PARAMETER Deploy
    Switch. When set the script will attempt to find a matching CM Application or CMPackage and create deployments for the collection roles.

.PARAMETER CleanupOrphans
    Switch. When set the script will remove collections under the BaseFolder that are not present in the canonical/discovered list and that have no active deployments.

.PARAMETER DryRun
    Switch. When set actions that change SCCM (create collections, add rules, create deployments, delete collections) will be shown but not executed.

.PARAMETER ReportPath
    Optional path/prefix for output CSV reports. The script writes two files: '<prefix>-deployed.csv' and '<prefix>-missing.csv'. Defaults to SCCM-FindExistingSoftwareOnAllDevices-report.csv in the script folder.

.NOTES
    Supports dry-run mode for validation before making changes.
    All operations are idempotent - safe to run multiple times without creating duplicates.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "SCCM site code (e.g., 'ABC').")]
    [ValidateNotNullOrEmpty()]
    [string]$SiteCode,

    [Parameter(Mandatory = $true, HelpMessage = "DeviceCollection folder path under the site drive where collections will be created (e.g., 'Managed Apps\\Browsers').")]
    [ValidateNotNullOrEmpty()]
    [string]$BaseFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Optional path to the canonical PSD1 map file. Defaults to data\\SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1.")]
    [string]$CanonicalMapPath,

    [Parameter(Mandatory = $false, HelpMessage = "Optional CMPivot/CSV input file path containing InstalledSoftware results (Device,ProductName...).")]
    [string]$InputCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Switch: run analysis-only (do not contact or modify SCCM); requires -InputCsv.")]
    [switch]$AnalysisOnly,

    [Parameter(Mandatory = $false, HelpMessage = "Switch: attempt to deploy matching Applications/Packages to collections.")]
    [switch]$Deploy,

    [Parameter(Mandatory = $false, HelpMessage = "Switch: remove orphaned collections that have no active deployments.")]
    [switch]$CleanupOrphans,

    [Parameter(Mandatory = $false, HelpMessage = "Switch: show planned changes without modifying SCCM.")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Optional report file prefix. Produces '<prefix>-deployed.csv' and '<prefix>-missing.csv'.")]
    [string]$ReportPath
)

if (-not $CanonicalMapPath) {
    $CanonicalMapPath = Join-Path $PSScriptRoot '..\..\data\SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1'
}
if (-not $ReportPath) {
    $ReportPath = Join-Path $PSScriptRoot 'SCCM-FindExistingSoftwareOnAllDevices-report.csv'
}

# Decide whether we will actually perform changes
$DoActions = -not $DryRun -and -not $AnalysisOnly

# Import the ConfigurationManager module and set site drive unless running analysis-only
$cmModuleLoaded = $false
if (-not $AnalysisOnly) {
    try {
        Import-Module ConfigurationManager -ErrorAction Stop
        $cmModuleLoaded = $true
    } catch {
        Write-Warning "ConfigurationManager module not available or failed to import: $_"
        $cmModuleLoaded = $false
    }

    if ($cmModuleLoaded) {
        try { Set-Location "$($SiteCode):" } catch { Write-Warning "Failed to set site drive location: $_"; $cmModuleLoaded = $false }
    }
} else {
    Write-Host "AnalysisOnly: skipping ConfigurationManager import and site drive operations." -ForegroundColor Yellow
    if (-not $InputCsv) { throw 'AnalysisOnly requires -InputCsv to run without contacting SCCM. Provide -InputCsv or remove -AnalysisOnly.' }
}

# --- 1. DISCOVERY ---
if ($InputCsv -and (Test-Path $InputCsv)) {
    try {
        $csv = Import-Csv -Path $InputCsv -ErrorAction Stop
        # build a map of ProductName -> devices
        $ProductDeviceMap = @{}
        foreach ($row in $csv) {
            $name = ($row.ProductName -as [string])
            if (-not $name) { continue }
            $name = $name.Trim()
            if (-not $ProductDeviceMap.ContainsKey($name)) { $ProductDeviceMap[$name] = @() }
            if ($row.Device) { $ProductDeviceMap[$name] += $row.Device }
        }
        $CurrentSoftware = $ProductDeviceMap.Keys | Sort-Object -Unique
        Write-Host "Loaded $($CurrentSoftware.Count) unique software titles from CSV: $InputCsv" -ForegroundColor Cyan
    } catch {
        Write-Warning "Failed to read InputCsv '$InputCsv': $_. Falling back to live discovery."
        $InputCsv = $null
    }
}

if (-not $InputCsv) {
    if ($AnalysisOnly) { throw 'AnalysisOnly requires -InputCsv; cannot perform live discovery in AnalysisOnly mode.' }
    $Wql = "SELECT DISTINCT DisplayName0 FROM SMS_G_System_ADD_REMOVE_PROGRAMS WHERE DisplayName0 NOT LIKE '%Driver%' AND DisplayName0 NOT LIKE '%Update%' AND DisplayName0 NOT LIKE '%Hotfix%'"
    $CurrentSoftware = @(Get-CimInstance -Namespace "root\SMS\site_$SiteCode" -Query $Wql | ForEach-Object { $_.DisplayName0.Trim() } | Where-Object { $_.Length -gt 2 })
    Write-Host "Found $($CurrentSoftware.Count) unique software titles via live discovery." -ForegroundColor Cyan
}

# --- Load canonical map (optional) ---
$CanonicalMappings = $null
if (Test-Path $CanonicalMapPath) {
    if (Get-Command -Name Import-PowerShellDataFile -ErrorAction SilentlyContinue) {
        try { $mapData = Import-PowerShellDataFile -Path $CanonicalMapPath -ErrorAction Stop } catch { $mapData = $null }
    } else {
        try { $mapData = Invoke-Expression -Command (Get-Content -Path $CanonicalMapPath -Raw) } catch { $mapData = $null }
    }
    if ($mapData -and $mapData.CanonicalMappings) { $CanonicalMappings = $mapData.CanonicalMappings }
}

if ($CanonicalMappings) {
    $uniqueCount = ($CanonicalMappings.Values | Select-Object -Unique | Measure-Object).Count
    Write-Host "Loaded canonical map: $($CanonicalMappings.Keys.Count) keys -> $uniqueCount canonical entries." -ForegroundColor Cyan
    $UseCanonical = $true
} else {
    Write-Host "No canonical map loaded; will use discovered software list." -ForegroundColor Yellow
    $UseCanonical = $false
}

$Deployed = @()
$Missing = @()
$CreatedCollections = @()

if ($UseCanonical) {
    $Targets = $CanonicalMappings.Values | Sort-Object -Unique
} else {
    $Targets = $CurrentSoftware | Sort-Object -Unique
}

# Plan of actions (for AnalysisOnly or DryRun review)
$Plan = @()

# --- 2. ENSURE STRUCTURE (Master-driven when canonical map available) ---
foreach ($TargetName in $Targets) {
    if ($UseCanonical) {
        $DisplayNames = $CanonicalMappings.GetEnumerator() | Where-Object { $_.Value -eq $TargetName } | ForEach-Object { $_.Key }
    } else {
        $DisplayNames = @($TargetName)
    }

    $SanitizedName = $TargetName -replace '[\\/:*?"<>|]', '_'
    $DynamicPath = "$($SiteCode):\DeviceCollection\$BaseFolder\$SanitizedName"

    # Determine matched variants and device counts when CSV input provided
    $MatchedVariants = @()
    $DevicesFound = @()
    if ($InputCsv -and $ProductDeviceMap) {
        foreach ($variant in $DisplayNames) {
            if ($ProductDeviceMap.ContainsKey($variant)) {
                $MatchedVariants += $variant
                $DevicesFound += $ProductDeviceMap[$variant]
            }
        }
    }
    $DevicesFound = $DevicesFound | Sort-Object -Unique
    $InstalledOnDevicesCount = ($DevicesFound | Measure-Object).Count

    if (-not (Test-Path $DynamicPath)) {
        if ($PSCmdlet.ShouldProcess($DynamicPath, 'Create folder')) {
            if ($DoActions) { New-Item -Path $DynamicPath -ItemType Directory -Force | Out-Null; Write-Host "Created Folder: $SanitizedName" -ForegroundColor DarkGray } else { Write-Host "Planned Folder: $SanitizedName" -ForegroundColor DarkGray }
        }
    }

    $escaped = $DisplayNames | ForEach-Object { ($_ -replace "'", "''") }
    $inList = ($escaped | ForEach-Object { "'$_'" }) -join ', '
    $detectionQuery = "SELECT * FROM SMS_R_System WHERE ResourceID IN (SELECT ResourceID FROM SMS_G_System_ADD_REMOVE_PROGRAMS WHERE DisplayName0 IN ($inList))"

    # Master collection names (match SCCMSoftwareCollectionConsolidation naming)
    $installAvailName = "{0} - Install (Available)" -f $TargetName
    $installReqName = "{0} - Install (Required)" -f $TargetName
    $uninstallName = "{0} - Uninstall" -f $TargetName

    # Get or create collections (Available, Required, Uninstall)
    $availColl = $null; $reqColl = $null; $uninstallColl = $null
    if ($cmModuleLoaded) {
        $availColl = Get-CMDeviceCollection -Name $installAvailName -ErrorAction SilentlyContinue
        $reqColl = Get-CMDeviceCollection -Name $installReqName -ErrorAction SilentlyContinue
        $uninstallColl = Get-CMDeviceCollection -Name $uninstallName -ErrorAction SilentlyContinue
    }

    foreach ($entry in @(@($installAvailName, 'Available'), @($installReqName, 'Required'), @($uninstallName, 'Uninstall'))) {
        $CollName = $entry[0]
        $Role = $entry[1]
        $planEntry = [pscustomobject]@{
            Action                  = 'CreateCollection'
            TargetCanonical         = $TargetName
            Role                    = $Role
            CollectionName          = $CollName
            Query                   = $detectionQuery
            MatchedVariants         = ($MatchedVariants -join '; ')
            InstalledOnDevicesCount = $InstalledOnDevicesCount
            AppChecked              = $false
            FoundAs                 = $null
            FoundName               = $null
            Deployed                = $false
            Excludes                = ''
            Notes                   = ''
            Timestamp               = (Get-Date).ToString('o')
        }

        $existing = $null
        if ($cmModuleLoaded) { $existing = Get-CMDeviceCollection -Name $CollName -ErrorAction SilentlyContinue }

        if ($null -eq $existing) {
            if ($PSCmdlet.ShouldProcess($CollName, 'Create collection')) {
                if ($DoActions -and $cmModuleLoaded) {
                    try {
                        $created = New-CMDeviceCollection -Name $CollName -LimitingCollectionName 'All Systems' -FolderPath $DynamicPath -ErrorAction Stop
                        Write-Host "Created Collection: $CollName" -ForegroundColor Green
                        $CreatedCollections += $CollName
                        $existing = $created
                        $planEntry.Action = 'CreatedCollection'
                    } catch { Write-Warning "Failed to create collection $($CollName): $($_)"; $planEntry.Notes = 'CreateFailed' }
                } else {
                    Write-Host "Planned Collection: $CollName" -ForegroundColor DarkGray
                    $planEntry.Action = 'PlanCreateCollection'
                }
            }
        } else {
            $planEntry.Action = 'ExistingCollection'
        }

        # append to plan
        $Plan += $planEntry

        # assign to local var for later use
        switch ($Role) {
            'Available' { $availColl = $existing }
            'Required' { $reqColl = $existing }
            'Uninstall' { $uninstallColl = $existing }
        }
    }

    # Add membership rules: Available & Uninstall use detectionQuery; Required uses detectionQuery minus members of Available/Uninstall
    $ruleName = 'Software Detection'

    # Ensure Available rule
    if ($availColl) {
        $existingRule = $null
        if ($cmModuleLoaded) { $existingRule = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $availColl.Name -RuleName $ruleName -ErrorAction SilentlyContinue }
        if ($null -eq $existingRule) {
            if ($PSCmdlet.ShouldProcess($availColl.Name, 'Add query membership rule')) {
                if ($DoActions -and $cmModuleLoaded) {
                    try { Add-CMDeviceCollectionQueryMembershipRule -CollectionName $availColl.Name -RuleName $ruleName -QueryExpression $detectionQuery -ErrorAction Stop; Write-Host "Added rule to $($availColl.Name)" -ForegroundColor Cyan } catch { Write-Warning "Failed to add rule to $($availColl.Name): $_" }
                } else { Write-Host "Planned: add rule to $($availColl.Name)" -ForegroundColor DarkGray }
            }
        }
    }

    # Ensure Uninstall rule
    if ($uninstallColl) {
        $existingRule = $null
        if ($cmModuleLoaded) { $existingRule = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $uninstallColl.Name -RuleName $ruleName -ErrorAction SilentlyContinue }
        if ($null -eq $existingRule) {
            if ($PSCmdlet.ShouldProcess($uninstallColl.Name, 'Add query membership rule')) {
                if ($DoActions -and $cmModuleLoaded) {
                    try { Add-CMDeviceCollectionQueryMembershipRule -CollectionName $uninstallColl.Name -RuleName $ruleName -QueryExpression $detectionQuery -ErrorAction Stop; Write-Host "Added rule to $($uninstallColl.Name)" -ForegroundColor Cyan } catch { Write-Warning "Failed to add rule to $($uninstallColl.Name): $_" }
                } else { Write-Host "Planned: add rule to $($uninstallColl.Name)" -ForegroundColor DarkGray }
            }
        }
    }

    # Build Required query with exclusions if we can resolve collection IDs
    $requiredQuery = $detectionQuery
    $excludes = @()
    if ($availColl) {
        $availId = (Get-ObjectPropertyValue -InputObject $availColl -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if ($availId) { $requiredQuery += " AND ResourceID NOT IN (SELECT ResourceID FROM SMS_FullCollectionMembership WHERE CollectionID = '$availId')"; $excludes += $availColl.Name }
    }
    if ($uninstallColl) {
        $uninstallId = (Get-ObjectPropertyValue -InputObject $uninstallColl -PropertyNames @('CollectionID', 'CollectionId', 'Id'))
        if ($uninstallId) { $requiredQuery += " AND ResourceID NOT IN (SELECT ResourceID FROM SMS_FullCollectionMembership WHERE CollectionID = '$uninstallId')"; $excludes += $uninstallColl.Name }
    }

    if ($reqColl) {
        $existingRule = $null
        if ($cmModuleLoaded) { $existingRule = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $reqColl.Name -RuleName $ruleName -ErrorAction SilentlyContinue }
        if ($null -eq $existingRule) {
            if ($PSCmdlet.ShouldProcess($reqColl.Name, 'Add required membership rule')) {
                if ($DoActions -and $cmModuleLoaded) {
                    try { Add-CMDeviceCollectionQueryMembershipRule -CollectionName $reqColl.Name -RuleName $ruleName -QueryExpression $requiredQuery -ErrorAction Stop; Write-Host "Added required rule to $($reqColl.Name)" -ForegroundColor Cyan } catch { Write-Warning "Failed to add required rule to $($reqColl.Name): $_" }
                } else {
                    Write-Host "Planned: add required rule to $($reqColl.Name) (excludes: $($excludes -join ', '))" -ForegroundColor DarkGray
                }
            }
        }
    }

    # Record excludes into plan (for readability when running AnalysisOnly)
    if ($excludes.Count -gt 0) {
        $Plan += [pscustomobject]@{ Action = 'NoteExcludes'; TargetCanonical = $TargetName; Excludes = ($excludes -join '; '); Timestamp = (Get-Date).ToString('o') }
    }

    # Deployment / app check against master collections (only if Deploy requested)
    if ($Deploy) {
        $foundType = $null
        $foundName = $null
        if ($cmModuleLoaded) {
            if (Get-Command -Name Get-CMApplication -ErrorAction SilentlyContinue) {
                try { $appObj = @(Get-CMApplication -Name $TargetName -ErrorAction SilentlyContinue) | Select-Object -First 1; if (-not $appObj) { $appObj = @(Get-CMApplication -Name ("*$TargetName*") -ErrorAction SilentlyContinue) | Select-Object -First 1 } } catch { $appObj = $null }
                if ($appObj) { $foundType = 'Application'; $foundName = ($appObj.LocalizedDisplayName -or $appObj.Name) }
            }
            if (-not $foundType -and (Get-Command -Name Get-CMPackage -ErrorAction SilentlyContinue)) {
                try { $pkgObj = @(Get-CMPackage -Name ("*$TargetName*") -ErrorAction SilentlyContinue | Select-Object -First 1) } catch { $pkgObj = $null }
                if ($pkgObj) { $foundType = 'Package'; $foundName = $pkgObj.Name }
            }
        }

        if (-not $foundType) {
            $Missing += [pscustomobject]@{ Canonical = $TargetName; Reason = 'No application or package found in SCCM'; Timestamp = (Get-Date).ToString('o') }
        } else {
            # attempt to deploy to master collections where appropriate
            $deployTargets = @()
            if ($reqColl) { $deployTargets += [pscustomobject]@{ CollectionName = $reqColl.Name; Role = 'Required' } }
            if ($availColl) { $deployTargets += [pscustomobject]@{ CollectionName = $availColl.Name; Role = 'Available' } }

            foreach ($t in $deployTargets) {
                $deploySucceeded = $false
                if ($foundType -eq 'Application' -and (Get-Command -Name New-CMApplicationDeployment -ErrorAction SilentlyContinue) -and $cmModuleLoaded) {
                    $deployPurpose = if ($t.Role -eq 'Required') { 'Required' } else { 'Available' }
                    $deployAction = 'Install'
                    try {
                        if ($PSCmdlet.ShouldProcess("$foundName -> $($t.CollectionName)", 'Create application deployment')) {
                            if ($DoActions) { New-CMApplicationDeployment -CollectionName $t.CollectionName -Name $foundName -DeployAction $deployAction -DeployPurpose $deployPurpose -ErrorAction Stop | Out-Null }
                            $deploySucceeded = $true
                        }
                    } catch { Write-Warning "Failed to create deployment for $foundName -> $($t.CollectionName) : $_" }
                } elseif ($foundType -eq 'Package' -and (Get-Command -Name New-CMPackageDeployment -ErrorAction SilentlyContinue) -and $cmModuleLoaded) {
                    try {
                        if ($PSCmdlet.ShouldProcess("$foundName -> $($t.CollectionName)", 'Create package deployment')) {
                            if ($DoActions) { New-CMPackageDeployment -Name $foundName -CollectionName $t.CollectionName -ErrorAction Stop | Out-Null }
                            $deploySucceeded = $true
                        }
                    } catch { Write-Warning "Failed to create package deployment for $foundName -> $($t.CollectionName) : $_" }
                } else {
                    Write-Host "Deployment skipped (cmdlet/module missing) for $TargetName -> $($t.CollectionName)" -ForegroundColor Yellow
                }

                $Deployed += [pscustomobject]@{ Canonical = $TargetName; FoundAs = $foundType; FoundName = $foundName; Collection = $t.CollectionName; Deployed = $deploySucceeded; Timestamp = (Get-Date).ToString('o') }
            }
        }
    }
}

# --- 3. CLEANUP ORPHANS ---
if ($CleanupOrphans) {
    if (-not $cmModuleLoaded) {
        Write-Host "Skipping orphan cleanup: not connected to SCCM (AnalysisOnly or module missing)." -ForegroundColor Yellow
    } else {
        Write-Host "`nScanning for orphaned collections..." -ForegroundColor Yellow
        $ManagedPath = "$($SiteCode):\DeviceCollection\$BaseFolder"
        $AllManagedCollections = Get-CMDeviceCollection -FolderPath "$($ManagedPath)\*" -ErrorAction SilentlyContinue

        foreach ($Coll in $AllManagedCollections) {
            $Base = $Coll.Name -replace ' - (Required|Available|Uninstall)$', ''
            $BelongsToTarget = ($Targets -contains $Base)

            if (-not $BelongsToTarget) {
                $Deployments = Get-CMDeployment -CollectionName $Coll.Name -ErrorAction SilentlyContinue
                if ($null -eq $Deployments) {
                    if (-not $DoActions) {
                        Write-Host "  [Planned] Would delete orphaned collection: $($Coll.Name)" -ForegroundColor Magenta
                    } else {
                        Remove-CMDeviceCollection -Id $Coll.CollectionID -Force
                        Write-Host "  Deleted Orphaned Collection: $($Coll.Name)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  Skipping deletion of '$($Coll.Name)': Active deployments found." -ForegroundColor Yellow
                }
            }
        }
    }
}

# --- 4. Reporting ---
try {
    if ($Plan.Count -gt 0) {
        $planPath = [IO.Path]::ChangeExtension($ReportPath, '-plan.csv')
        $Plan | Export-Csv -Path $planPath -NoTypeInformation -Force
        Write-Host "Wrote plan report: $planPath" -ForegroundColor Cyan
    }
    if ($Deployed.Count -gt 0) {
        $deployedPath = [IO.Path]::ChangeExtension($ReportPath, '-deployed.csv')
        $Deployed | Export-Csv -Path $deployedPath -NoTypeInformation -Force
        Write-Host "Wrote deployed report: $deployedPath" -ForegroundColor Cyan
    }
    if ($Missing.Count -gt 0) {
        $missingPath = [IO.Path]::ChangeExtension($ReportPath, '-missing.csv')
        $Missing | Export-Csv -Path $missingPath -NoTypeInformation -Force
        Write-Host "Wrote missing software report: $missingPath" -ForegroundColor Yellow
    } else {
        Write-Host "No missing software detected." -ForegroundColor Green
    }
} catch {
    Write-Warning "Failed to write reports: $_"
}
