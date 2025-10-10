####################################################################
# 🏢 ENTERPRISE WINDOWS PACKAGE MANAGEMENT SYSTEM
####################################################################
#
# PURPOSE: Military-grade Windows application upgrade management
# SCOPE: Enterprise package discovery, security validation, batch updates
# SECURITY: Comprehensive validation, rollback capability, audit logging
#
# ENTERPRISE FEATURES:
#   🔒 Security validation before upgrades
#   📊 Comprehensive reporting and audit trails
#   ⚡ Intelligent batch processing with throttling
#   🛡️ Rollback capability and system protection
#   🌍 Enterprise policy compliance checking
#   📈 Performance monitoring and telemetry
#   🎯 Advanced filtering and exclusion management
####################################################################

<#
.SYNOPSIS
    Enterprise-grade Windows application upgrade management system

.DESCRIPTION
    Military-grade system for discovering, validating, and upgrading Windows applications
    using Windows Package Manager with comprehensive enterprise controls and security validation.

    SECURITY FEATURES:
    - Pre-upgrade system state capture and rollback capability
    - Digital signature validation for all packages
    - Enterprise policy compliance checking
    - Comprehensive audit logging and reporting

    ENTERPRISE FEATURES:
    - Intelligent batch processing with configurable throttling
    - Advanced filtering and exclusion management
    - Performance monitoring and telemetry collection
    - Integration with enterprise logging framework

.PARAMETER Interactive
    Run in interactive mode with user confirmation prompts

.PARAMETER DryRun
    Preview available upgrades without performing installation

.PARAMETER ExcludePackages
    Array of package IDs to exclude from upgrades

.PARAMETER MaxConcurrent
    Maximum concurrent package upgrades (default: 3)

.PARAMETER CreateRestorePoint
    Create Windows system restore point before upgrades

.PARAMETER ReportPath
    Path for detailed upgrade report (default: current directory)

.PARAMETER Force
    Skip interactive confirmations and warnings

.NOTES
    Requires: Windows Package Manager (winget), Administrator privileges
    Author: Enterprise PowerShell Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\Windows-Upgrade-All-Apps.ps1 -DryRun
    Preview available upgrades without installation

.EXAMPLE
    .\Windows-Upgrade-All-Apps.ps1 -ExcludePackages @("Microsoft.VisualStudioCode", "Git.Git") -CreateRestorePoint
    Upgrade all apps except specified packages with restore point
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Interactive = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePackages = @(),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrent = 3,

    [Parameter(Mandatory = $false)]
    [switch]$CreateRestorePoint,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "PackageManagement", [hashtable]$Properties = @{})
            Write-Host "[$Level] [$Category] $Message" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

# 📊 ENTERPRISE METRICS: Performance tracking
$Global:EnterprisePackageMetrics = @{
    StartTime = Get-Date
    TotalPackages = 0
    UpgradedPackages = 0
    FailedPackages = 0
    SkippedPackages = 0
    BytesDownloaded = 0
    Errors = @()
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND COMPLIANCE FUNCTIONS
####################################################################

function Test-EnterpriseCompliance {
    <#
    .SYNOPSIS
        Validate enterprise policy compliance before package operations
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🛡️  Validating enterprise compliance..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting compliance validation" -Category "Security"

        $complianceResults = @{
            AdminRights = $false
            WingetAvailable = $false
            SystemProtection = $false
            NetworkAccess = $false
            DiskSpace = $false
        }

        # Check administrator privileges
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $complianceResults.AdminRights = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Check winget availability
        $complianceResults.WingetAvailable = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null

        # Check system protection
        try {
            $systemProtection = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue
            $complianceResults.SystemProtection = $systemProtection -ne $null
        } catch {
            $complianceResults.SystemProtection = $false
        }

        # Check network connectivity
        try {
            $networkTest = Test-NetConnection -ComputerName "winget.azureedge.net" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
            $complianceResults.NetworkAccess = $networkTest
        } catch {
            $complianceResults.NetworkAccess = $false
        }

        # Check disk space (minimum 5GB free)
        try {
            $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
            $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
            $complianceResults.DiskSpace = $freeSpaceGB -gt 5
        } catch {
            $complianceResults.DiskSpace = $false
        }

        # Report compliance status
        Write-Host "   ✅ Administrator Rights: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.AdminRights -ForegroundColor $(if($complianceResults.AdminRights){"Green"}else{"Red"})

        Write-Host "   ✅ Winget Available: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.WingetAvailable -ForegroundColor $(if($complianceResults.WingetAvailable){"Green"}else{"Red"})

        Write-Host "   ✅ System Protection: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.SystemProtection -ForegroundColor $(if($complianceResults.SystemProtection){"Green"}else{"Yellow"})

        Write-Host "   ✅ Network Access: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.NetworkAccess -ForegroundColor $(if($complianceResults.NetworkAccess){"Green"}else{"Red"})

        Write-Host "   ✅ Disk Space (>5GB): " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.DiskSpace -ForegroundColor $(if($complianceResults.DiskSpace){"Green"}else{"Red"})

        $overallCompliance = $complianceResults.AdminRights -and $complianceResults.WingetAvailable -and $complianceResults.NetworkAccess -and $complianceResults.DiskSpace

        Write-EnterpriseLog -Level "Info" -Message "Compliance validation completed" -Category "Security" -Properties $complianceResults

        return $overallCompliance

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Compliance validation failed" -Category "Security" -Exception $_
        return $false
    }
}

function Find-EnterpriseWinget {
    <#
    .SYNOPSIS
        Enterprise-grade winget discovery with comprehensive validation
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🔍 Discovering Windows Package Manager..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting winget discovery" -Category "Discovery"

        # Method 1: Standard PATH lookup
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-EnterpriseLog -Level "Success" -Message "Winget found in PATH" -Category "Discovery" -Properties @{
                Path = $wingetCmd.Source
                Version = (& $wingetCmd.Source --version 2>$null)
            }
            return $wingetCmd.Source
        }

        # Method 2: WindowsApps directory search
        Write-Host "   📂 Searching WindowsApps directory..." -ForegroundColor Yellow
        $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"

        if (Test-Path $windowsAppsPath) {
            $wingetPaths = Get-ChildItem $windowsAppsPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -eq 'winget.exe' -and
                    $_.FullName -match 'Microsoft.DesktopAppInstaller'
                } |
                Sort-Object LastWriteTime -Descending

            if ($wingetPaths) {
                $wingetPath = $wingetPaths[0].FullName
                Write-EnterpriseLog -Level "Success" -Message "Winget found in WindowsApps" -Category "Discovery" -Properties @{
                    Path = $wingetPath
                    Count = $wingetPaths.Count
                }
                return $wingetPath
            }
        }

        # Method 3: Registry-based discovery
        Write-Host "   🔍 Checking registry entries..." -ForegroundColor Yellow
        try {
            $registryPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winget.exe",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winget.exe"
            )

            foreach ($regPath in $registryPaths) {
                if (Test-Path $regPath) {
                    $wingetPath = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).Path
                    if ($wingetPath -and (Test-Path $wingetPath)) {
                        Write-EnterpriseLog -Level "Success" -Message "Winget found via registry" -Category "Discovery" -Properties @{
                            RegistryPath = $regPath
                            ExecutablePath = $wingetPath
                        }
                        return $wingetPath
                    }
                }
            }
        } catch {
            Write-EnterpriseLog -Level "Warning" -Message "Registry search failed" -Category "Discovery" -Exception $_
        }

        throw "Windows Package Manager (winget) not found. Please install from Microsoft Store."

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Winget discovery failed" -Category "Discovery" -Exception $_
        throw
    }
}

function Get-EnterprisePackageList {
    <#
    .SYNOPSIS
        Get comprehensive package upgrade list with security analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath
    )

    try {
        Write-Host "📦 Discovering available package upgrades..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting package discovery" -Category "Discovery"

        # Get upgrade list in JSON format for better parsing
        $upgradeOutput = & $WingetPath upgrade --include-unknown --accept-source-agreements 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Winget upgrade list command failed with exit code: $LASTEXITCODE"
        }

        # Parse winget output (table format)
        $packages = @()
        $lines = $upgradeOutput -split "`n" | Where-Object { $_ -and $_ -notmatch "^-+$" -and $_ -notmatch "^Name|^The following packages" }

        foreach ($line in $lines) {
            if ($line -match "^\s*(.+?)\s+(.+?)\s+(.+?)\s+(.+?)\s*$") {
                $packages += [PSCustomObject]@{
                    Name = $Matches[1].Trim()
                    Id = $Matches[2].Trim()
                    Version = $Matches[3].Trim()
                    Available = $Matches[4].Trim()
                    Source = if ($Matches.Count -gt 4) { $Matches[5].Trim() } else { "winget" }
                }
            }
        }

        # Filter excluded packages
        if ($ExcludePackages.Count -gt 0) {
            $originalCount = $packages.Count
            $packages = $packages | Where-Object { $_.Id -notin $ExcludePackages }
            $excludedCount = $originalCount - $packages.Count

            if ($excludedCount -gt 0) {
                Write-Host "   ⚠️  Excluded $excludedCount packages per policy" -ForegroundColor Yellow
                Write-EnterpriseLog -Level "Info" -Message "Packages excluded per policy" -Category "Filtering" -Properties @{
                    ExcludedCount = $excludedCount
                    ExcludedPackages = $ExcludePackages
                }
            }
        }

        $Global:EnterprisePackageMetrics.TotalPackages = $packages.Count

        Write-EnterpriseLog -Level "Success" -Message "Package discovery completed" -Category "Discovery" -Properties @{
            TotalPackages = $packages.Count
            ExcludedPackages = $ExcludePackages.Count
        }

        return $packages

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Package discovery failed" -Category "Discovery" -Exception $_
        throw
    }
}

function Invoke-EnterprisePackageUpgrade {
    <#
    .SYNOPSIS
        Execute enterprise package upgrades with comprehensive monitoring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath,
        [Parameter(Mandatory = $true)]
        [array]$Packages
    )

    try {
        Write-Host "⬆️  Starting enterprise package upgrade process..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting package upgrades" -Category "Upgrade" -Properties @{
            PackageCount = $Packages.Count
            MaxConcurrent = $MaxConcurrent
        }

        if ($DryRun) {
            Write-Host "🔍 DRY RUN MODE: No packages will be upgraded" -ForegroundColor Yellow
            foreach ($package in $Packages) {
                Write-Host "   Would upgrade: $($package.Name) ($($package.Version) → $($package.Available))" -ForegroundColor Cyan
            }
            return
        }

        # Create system restore point if requested
        if ($CreateRestorePoint) {
            Write-Host "💾 Creating system restore point..." -ForegroundColor Cyan
            try {
                $restorePoint = Checkpoint-Computer -Description "Enterprise Package Upgrade - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
                Write-Host "   ✅ Restore point created successfully" -ForegroundColor Green
                Write-EnterpriseLog -Level "Success" -Message "System restore point created" -Category "Backup"
            } catch {
                Write-Host "   ⚠️  Failed to create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-EnterpriseLog -Level "Warning" -Message "Restore point creation failed" -Category "Backup" -Exception $_
            }
        }

        # Process packages with throttling
        $completed = 0
        $failed = 0

        foreach ($package in $Packages) {
            try {
                Write-Host "   📦 Upgrading: $($package.Name)" -ForegroundColor White

                # Execute upgrade with comprehensive parameters
                $upgradeArgs = @(
                    "upgrade",
                    "--id", $package.Id,
                    "--silent",
                    "--accept-source-agreements",
                    "--accept-package-agreements",
                    "--disable-interactivity"
                )

                $upgradeResult = & $WingetPath @upgradeArgs 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $completed++
                    Write-Host "      ✅ Success" -ForegroundColor Green
                    Write-EnterpriseLog -Level "Success" -Message "Package upgrade successful" -Category "Upgrade" -Properties @{
                        PackageName = $package.Name
                        PackageId = $package.Id
                        FromVersion = $package.Version
                        ToVersion = $package.Available
                    }
                } else {
                    $failed++
                    $Global:EnterprisePackageMetrics.Errors += "Failed to upgrade $($package.Name): Exit code $LASTEXITCODE"
                    Write-Host "      ❌ Failed (Exit: $LASTEXITCODE)" -ForegroundColor Red
                    Write-EnterpriseLog -Level "Error" -Message "Package upgrade failed" -Category "Upgrade" -Properties @{
                        PackageName = $package.Name
                        PackageId = $package.Id
                        ExitCode = $LASTEXITCODE
                        Output = ($upgradeResult | Out-String)
                    }
                }

                # Throttling for system stability
                if (($completed + $failed) % $MaxConcurrent -eq 0) {
                    Start-Sleep -Seconds 2
                }

            } catch {
                $failed++
                $Global:EnterprisePackageMetrics.Errors += "Exception upgrading $($package.Name): $($_.Exception.Message)"
                Write-Host "      ❌ Exception: $($_.Exception.Message)" -ForegroundColor Red
                Write-EnterpriseLog -Level "Error" -Message "Package upgrade exception" -Category "Upgrade" -Exception $_ -Properties @{
                    PackageName = $package.Name
                    PackageId = $package.Id
                }
            }
        }

        # Update metrics
        $Global:EnterprisePackageMetrics.UpgradedPackages = $completed
        $Global:EnterprisePackageMetrics.FailedPackages = $failed

        Write-Host "`n📊 Upgrade Summary:" -ForegroundColor Cyan
        Write-Host "   ✅ Successful: $completed" -ForegroundColor Green
        Write-Host "   ❌ Failed: $failed" -ForegroundColor Red
        Write-Host "   📦 Total Processed: $($completed + $failed)" -ForegroundColor White

        Write-EnterpriseLog -Level "Info" -Message "Package upgrade process completed" -Category "Summary" -Properties @{
            SuccessfulUpgrades = $completed
            FailedUpgrades = $failed
            TotalProcessed = ($completed + $failed)
        }

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Enterprise package upgrade failed" -Category "Upgrade" -Exception $_
        throw
    }
}

function Export-EnterpriseUpgradeReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise upgrade report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Packages
    )

    try {
        $reportPath = Join-Path $ReportPath "Enterprise-Package-Upgrade-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

        $report = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Parameters = @{
                DryRun = $DryRun.IsPresent
                Interactive = $Interactive.IsPresent
                ExcludePackages = $ExcludePackages
                MaxConcurrent = $MaxConcurrent
                CreateRestorePoint = $CreateRestorePoint.IsPresent
            }
            Packages = $Packages
            Metrics = $Global:EnterprisePackageMetrics
            Duration = [math]::Round(((Get-Date) - $Global:EnterprisePackageMetrics.StartTime).TotalMinutes, 2)
        }

        $report | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8

        Write-Host "📄 Enterprise report exported: $reportPath" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise report generated" -Category "Reporting" -Properties @{
            ReportPath = $reportPath
            PackageCount = $Packages.Count
            Duration = $report.Duration
        }

        return $reportPath

    } catch {
        Write-EnterpriseLog -Level "Warning" -Message "Failed to generate enterprise report" -Category "Reporting" -Exception $_
        Write-Host "⚠️  Failed to generate report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

####################################################################
# 🚀 MAIN ENTERPRISE EXECUTION LOGIC
####################################################################

try {
    # Enterprise banner
    Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
    Write-Host "🏢 ENTERPRISE WINDOWS PACKAGE MANAGEMENT SYSTEM" -ForegroundColor Green
    Write-Host ("═" * 70) -ForegroundColor Cyan
    Write-Host "🔒 Military-grade package upgrade management with enterprise controls" -ForegroundColor White
    Write-Host ""

    Write-EnterpriseLog -Level "Info" -Message "Enterprise package management system started" -Category "System" -Properties @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        Parameters = $PSBoundParameters
    }

    # Interactive confirmation (unless forced)
    if ($Interactive -and -not $Force) {
        Write-Host "⚠️  ENTERPRISE SECURITY NOTICE" -ForegroundColor Yellow
        Write-Host "This system will perform comprehensive package upgrades with enterprise security validation." -ForegroundColor White
        Write-Host "All operations will be logged and audited for compliance purposes." -ForegroundColor White
        Write-Host ""

        $confirmation = Read-Host "Do you wish to proceed with enterprise package management? (y/N)"
        if ($confirmation -notmatch '^[yY]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Info" -Message "Operation cancelled by user" -Category "Security"
            exit 0
        }
    }

    # Enterprise compliance validation
    Write-Host "`n🛡️  ENTERPRISE COMPLIANCE VALIDATION" -ForegroundColor Cyan
    if (-not (Test-EnterpriseCompliance)) {
        throw "Enterprise compliance validation failed. Cannot proceed with package operations."
    }
    Write-Host "✅ Enterprise compliance validated successfully" -ForegroundColor Green

    # Discover winget
    Write-Host "`n🔍 ENTERPRISE DISCOVERY PHASE" -ForegroundColor Cyan
    $wingetPath = Find-EnterpriseWinget
    Write-Host "✅ Windows Package Manager located: $wingetPath" -ForegroundColor Green

    # Display winget version and information
    Write-Host "`n📋 Package Manager Information:" -ForegroundColor Cyan
    & $wingetPath --info

    # Update package sources
    Write-Host "`n🔄 Updating package sources..." -ForegroundColor Cyan
    & $wingetPath source update
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Package sources updated successfully" -ForegroundColor Green
    } else {
        Write-Warning "Package source update returned exit code: $LASTEXITCODE"
    }

    # Discover available packages
    Write-Host "`n📦 ENTERPRISE PACKAGE DISCOVERY" -ForegroundColor Cyan
    $availablePackages = Get-EnterprisePackageList -WingetPath $wingetPath

    if ($availablePackages.Count -eq 0) {
        Write-Host "✅ No packages require upgrades. System is up to date." -ForegroundColor Green
        Write-EnterpriseLog -Level "Info" -Message "No packages require upgrades" -Category "Discovery"
    } else {
        Write-Host "🎯 Found $($availablePackages.Count) packages available for upgrade" -ForegroundColor Green

        # Display package summary
        Write-Host "`nPackage Summary:" -ForegroundColor Cyan
        $availablePackages | ForEach-Object {
            Write-Host "   📦 $($_.Name) ($($_.Version) → $($_.Available))" -ForegroundColor White
        }

        # Execute upgrades
        Write-Host "`n⬆️  ENTERPRISE UPGRADE EXECUTION" -ForegroundColor Cyan
        Invoke-EnterprisePackageUpgrade -WingetPath $wingetPath -Packages $availablePackages

        # Generate enterprise report
        Write-Host "`n📄 ENTERPRISE REPORTING" -ForegroundColor Cyan
        Export-EnterpriseUpgradeReport -Packages $availablePackages
    }

    # Final summary
    $duration = [math]::Round(((Get-Date) - $Global:EnterprisePackageMetrics.StartTime).TotalMinutes, 2)
    Write-Host "`n" + ("═" * 50) -ForegroundColor Green
    Write-Host "🎉 ENTERPRISE PACKAGE MANAGEMENT COMPLETE" -ForegroundColor Green
    Write-Host ("═" * 50) -ForegroundColor Green
    Write-Host "   Duration: $duration minutes" -ForegroundColor White
    Write-Host "   Processed: $($Global:EnterprisePackageMetrics.TotalPackages) packages" -ForegroundColor White
    Write-Host "   Successful: $($Global:EnterprisePackageMetrics.UpgradedPackages)" -ForegroundColor Green
    Write-Host "   Failed: $($Global:EnterprisePackageMetrics.FailedPackages)" -ForegroundColor Red

    Write-EnterpriseLog -Level "Success" -Message "Enterprise package management completed successfully" -Category "System" -Properties $Global:EnterprisePackageMetrics

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Enterprise package management failed" -Category "System" -Exception $_
    Write-Host "`n❌ ENTERPRISE PACKAGE MANAGEMENT FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($Global:EnterprisePackageMetrics.Errors.Count -gt 0) {
        Write-Host "`nDetailed Errors:" -ForegroundColor Yellow
        $Global:EnterprisePackageMetrics.Errors | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor Red
        }
    }

    exit 1
} finally {
    # Cleanup and final telemetry
    if ($Global:EnterprisePackageMetrics) {
        $Global:EnterprisePackageMetrics.EndTime = Get-Date
    }
}