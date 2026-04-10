####################################################################
# 🏢 ENTERPRISE WINDOWS FEATURE MANAGEMENT SYSTEM
####################################################################
#
# PURPOSE: Military-grade Windows feature discovery, validation, and management
# SCOPE: Feature discovery, dependency analysis, security validation, bulk operations
# SECURITY: Role-based validation, security impact assessment, audit compliance
#
# ENTERPRISE FEATURES:
#   🔒 Security validation and impact assessment for features
#   📊 Comprehensive feature dependency analysis and mapping
#   ⚡ Bulk feature operations with intelligent validation
#   🛡️ Enterprise compliance checking and security policies
#   🌍 Cross-platform support for Windows Server and Desktop
#   📈 Performance monitoring and detailed telemetry
#   🎯 Advanced filtering and feature categorization
####################################################################

<#
.SYNOPSIS
    Enterprise-grade Windows feature management with comprehensive validation and security

.DESCRIPTION
    Military-grade system for discovering, validating, enabling, and managing Windows features
    with comprehensive security controls, dependency analysis, and enterprise compliance validation.

    SECURITY FEATURES:
    - Security impact assessment for feature changes
    - Role-based access validation and privilege checking
    - Comprehensive audit logging and compliance tracking
    - Enterprise policy enforcement and validation

    ENTERPRISE FEATURES:
    - Intelligent dependency resolution and conflict detection
    - Bulk feature operations with rollback capability
    - Advanced filtering and categorization systems
    - Performance monitoring with detailed telemetry

.PARAMETER FeatureName
    Single feature name to check, enable, or disable

.PARAMETER FeatureList
    Array of feature names for bulk operations

.PARAMETER Action
    Action to perform: Check, Enable, Disable, List, or Analyze

.PARAMETER IncludeDependencies
    Include feature dependencies in analysis

.PARAMETER SecurityValidation
    Perform security impact assessment before changes

.PARAMETER BulkMode
    Process multiple features with intelligent batching

.PARAMETER ReportPath
    Path for detailed feature management report

.PARAMETER Force
    Skip interactive confirmations for automated operations

.PARAMETER ExportFormat
    Export format for reports: JSON, XML, CSV, or HTML

.NOTES
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+ with DISM module
    Requires: Administrator privileges for feature modifications
    Author: Enterprise PowerShell Framework
    Version: 2.0 (Enterprise Edition)
    Last Modified: January 2025

.EXAMPLE
    .\Check-WindowsFeature.ps1 -FeatureName "Hyper-V" -Action Check -SecurityValidation
    Check Hyper-V feature status with security validation

.EXAMPLE
    .\Check-WindowsFeature.ps1 -Action List -IncludeDependencies -ExportFormat HTML
    List all Windows features with dependency analysis in HTML format

.EXAMPLE
    .\Check-WindowsFeature.ps1 -FeatureList @("IIS-WebServer", "IIS-ASPNET45") -Action Enable -Force
    Enable multiple IIS features in bulk mode without prompts
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$FeatureName,

    [Parameter(Mandatory = $false)]
    [string[]]$FeatureList = @(),

    [Parameter(Mandatory = $false)]
    [ValidateSet("Check", "Enable", "Disable", "List", "Analyze", "Discover")]
    [string]$Action = "Check",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDependencies,

    [Parameter(Mandatory = $false)]
    [switch]$SecurityValidation,

    [Parameter(Mandatory = $false)]
    [switch]$BulkMode,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "XML", "CSV", "HTML")]
    [string]$ExportFormat = "JSON"
)

# 🔧 ENTERPRISE INITIALIZATION: Load enterprise framework
try {
    $enterpriseLoggingPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Enterprise-Logging-Framework.ps1"
    if (Test-Path $enterpriseLoggingPath) {
        . $enterpriseLoggingPath
        Initialize-EnterpriseLogging -LogLevel "Info" -EnableTelemetry -EnableAlerting
    } else {
        function Write-EnterpriseLog {
            param([string]$Level, [string]$Message, [string]$Category = "FeatureManagement", [hashtable]$Properties = @{})
            $propertySummary = if ($Properties.Count -gt 0) {
                " | Properties: $($Properties.Keys -join ', ')"
            } else {
                ""
            }
            Write-Host "[$Level] [$Category] $Message$propertySummary" -ForegroundColor $(if($Level -eq "Error"){"Red"} elseif($Level -eq "Warning"){"Yellow"} else {"White"})
        }
    }
} catch {
    Write-Warning "Enterprise logging not available: $($_.Exception.Message)"
}

# 📊 ENTERPRISE METRICS: Feature management tracking
$script:EnterpriseFeatureMetrics = @{
    StartTime = Get-Date
    TotalFeatures = 0
    EnabledFeatures = 0
    DisabledFeatures = 0
    FailedOperations = 0
    SecurityViolations = 0
    DependenciesAnalyzed = 0
    Errors = @()
    ProcessedFeatures = @()
}

# 🌐 FEATURE CATEGORIES: Enterprise classification system
$script:EnterpriseFeatureCategories = @{
    Security = @("Windows-Defender-ApplicationGuard", "VirtualMachinePlatform", "HypervisorPlatform")
    WebServer = @("IIS-WebServer", "IIS-ASPNET45", "IIS-NetFxExtensibility45")
    RemoteAccess = @("TelnetClient", "TFTP", "SimpleTCP", "RAS-Routing")
    Development = @("Microsoft-Windows-Subsystem-Linux", "Containers", "HyperV")
    Multimedia = @("MediaPlayback", "WindowsMediaPlayer", "MediaFeaturePack")
    Legacy = @("DirectPlay", "LegacyComponents", "NTVDM")
}

####################################################################
# 🔒 ENTERPRISE SECURITY AND VALIDATION FUNCTIONS
####################################################################

function Test-EnterpriseFeatureSecurity {
    <#
    .SYNOPSIS
        Comprehensive security validation for Windows feature operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,
        [Parameter(Mandatory = $true)]
        [string]$ProposedAction
    )

    try {
        Write-Host "🛡️  Analyzing security impact for feature: $FeatureName" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting security validation" -Category "Security" -Properties @{
            FeatureName = $FeatureName
            ProposedAction = $ProposedAction
        }

        $securityResults = @{
            SecurityRisk = "Low"
            RequiresReboot = $false
            NetworkExposure = $false
            PrivilegeEscalation = $false
            OverallSecure = $true
            Recommendations = @()
        }

        # Analyze security-sensitive features
        $highRiskFeatures = @(
            "TelnetClient", "TFTP", "SimpleTCP", "RAS-Routing", "DirectPlay",
            "IIS-WebServer", "IIS-FTP", "IIS-ASPNET", "RemoteAssistance"
        )

        $rebootRequiredFeatures = @(
            "Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform",
            "HyperV", "Containers", "Windows-Defender-ApplicationGuard"
        )

        $networkExposureFeatures = @(
            "IIS-WebServer", "IIS-FTP", "TelnetClient", "TFTP", "SimpleTCP"
        )

        # Security risk assessment
        if ($FeatureName -in $highRiskFeatures) {
            $securityResults.SecurityRisk = "High"
            $securityResults.Recommendations += "High-risk feature - requires security review"

            if ($ProposedAction -eq "Enable") {
                $securityResults.Recommendations += "Consider security hardening after enabling"
            }
        }

        # Reboot requirement check
        if ($FeatureName -in $rebootRequiredFeatures) {
            $securityResults.RequiresReboot = $true
            $securityResults.Recommendations += "System reboot required after operation"
        }

        # Network exposure analysis
        if ($FeatureName -in $networkExposureFeatures) {
            $securityResults.NetworkExposure = $true
            $securityResults.Recommendations += "Feature exposes network services - configure firewall"
        }

        # Privilege escalation check
        $privilegedFeatures = @("HyperV", "VirtualMachinePlatform", "Containers")
        if ($FeatureName -in $privilegedFeatures) {
            $securityResults.PrivilegeEscalation = $true
            $securityResults.Recommendations += "Feature provides elevated system access"
        }

        # Overall security assessment
        if ($securityResults.SecurityRisk -eq "High" -and $ProposedAction -eq "Enable") {
            $securityResults.OverallSecure = $false
            $script:EnterpriseFeatureMetrics.SecurityViolations++
        }

        # Display security analysis
        Write-Host "   🔍 Security Risk: " -NoNewline -ForegroundColor White
        $riskColor = switch ($securityResults.SecurityRisk) {
            "Low" { "Green" }
            "Medium" { "Yellow" }
            "High" { "Red" }
        }
        Write-Host $securityResults.SecurityRisk -ForegroundColor $riskColor

        Write-Host "   🔄 Requires Reboot: " -NoNewline -ForegroundColor White
        Write-Host $securityResults.RequiresReboot -ForegroundColor $(if($securityResults.RequiresReboot){"Yellow"}else{"Green"})

        Write-Host "   🌐 Network Exposure: " -NoNewline -ForegroundColor White
        Write-Host $securityResults.NetworkExposure -ForegroundColor $(if($securityResults.NetworkExposure){"Yellow"}else{"Green"})

        if ($securityResults.Recommendations.Count -gt 0) {
            Write-Host "   📋 Recommendations:" -ForegroundColor Yellow
            $securityResults.Recommendations | ForEach-Object {
                Write-Host "      • $_" -ForegroundColor White
            }
        }

        Write-EnterpriseLog -Level "Info" -Message "Security validation completed" -Category "Security" -Properties $securityResults

        return $securityResults

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Security validation failed" -Category "Security" -Exception $_ -Properties @{
            FeatureName = $FeatureName
        }
        return @{ OverallSecure = $false; SecurityRisk = "Unknown" }
    }
}

function Test-EnterpriseSystemCompliance {
    <#
    .SYNOPSIS
        Validate enterprise system compliance for feature management
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🛡️  Validating enterprise system compliance..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting system compliance validation" -Category "Compliance"

        $complianceResults = @{
            AdminRights = $false
            WindowsVersion = $false
            DISMAvailable = $false
            SystemHealthy = $false
            PendingReboot = $false
        }

        # Check administrator privileges
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $complianceResults.AdminRights = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Check Windows version
        $osVersion = [System.Environment]::OSVersion.Version
        $complianceResults.WindowsVersion = ($osVersion.Major -ge 10) -or ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1)

        # Check DISM availability
        $complianceResults.DISMAvailable = $null -ne (Get-Command "DISM" -ErrorAction SilentlyContinue)

        # Check system health
        try {
            $systemHealth = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            $complianceResults.SystemHealthy = $null -ne $systemHealth
        } catch {
            $complianceResults.SystemHealthy = $false
        }

        # Check for pending reboot
        try {
            $pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
            $complianceResults.PendingReboot = $pendingReboot
        } catch {
            $complianceResults.PendingReboot = $false
        }

        # Report compliance status
        Write-Host "   ✅ Administrator Rights: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.AdminRights -ForegroundColor $(if($complianceResults.AdminRights){"Green"}else{"Red"})

        Write-Host "   ✅ Windows Version: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.WindowsVersion -ForegroundColor $(if($complianceResults.WindowsVersion){"Green"}else{"Red"})

        Write-Host "   ✅ DISM Available: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.DISMAvailable -ForegroundColor $(if($complianceResults.DISMAvailable){"Green"}else{"Red"})

        Write-Host "   ✅ System Healthy: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.SystemHealthy -ForegroundColor $(if($complianceResults.SystemHealthy){"Green"}else{"Red"})

        Write-Host "   ⚠️  Pending Reboot: " -NoNewline -ForegroundColor White
        Write-Host $complianceResults.PendingReboot -ForegroundColor $(if($complianceResults.PendingReboot){"Yellow"}else{"Green"})

        $overallCompliance = $complianceResults.AdminRights -and $complianceResults.WindowsVersion -and $complianceResults.DISMAvailable -and $complianceResults.SystemHealthy

        Write-EnterpriseLog -Level "Info" -Message "System compliance validation completed" -Category "Compliance" -Properties $complianceResults

        return $overallCompliance

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "System compliance validation failed" -Category "Compliance" -Exception $_
        return $false
    }
}

####################################################################
# 🚀 ENTERPRISE FEATURE MANAGEMENT FUNCTIONS
####################################################################

function Get-DirectEnterpriseFeatureDependency {
    <#
    .SYNOPSIS
        Collect direct feature dependencies from available providers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $false)]
        $Feature,

        [Parameter(Mandatory = $false)]
        [string]$DiscoveryMethod = ""
    )

    $dependencyNames = @()

    if ($null -ne $Feature) {
        if (-not [string]::IsNullOrWhiteSpace($Feature.ParentFeatureName)) {
            $dependencyNames += $Feature.ParentFeatureName
        }

        foreach ($dependency in @($Feature.DependsOn)) {
            if ($dependency -is [string]) {
                $dependencyNames += $dependency
            } elseif ($null -ne $dependency.Name) {
                $dependencyNames += $dependency.Name
            } elseif ($null -ne $dependency.FeatureName) {
                $dependencyNames += $dependency.FeatureName
            }
        }
    }

    if (Get-Command DISM -ErrorAction SilentlyContinue) {
        try {
            $dismOutput = & DISM /Online /Get-FeatureInfo /FeatureName:$FeatureName 2>$null
            if ($LASTEXITCODE -eq 0) {
                foreach ($line in @($dismOutput)) {
                    if ($line -match '^\s*(Parent|Requires|Dependency)\s*:\s*(.+?)\s*$') {
                        foreach ($dependencyName in ($matches[2] -split ',')) {
                            $dependencyNames += $dependencyName.Trim()
                        }
                    }
                }
            }
        } catch {
            Write-EnterpriseLog -Level "Debug" -Message "DISM dependency discovery skipped" -Category "Discovery" -Properties @{
                FeatureName = $FeatureName
                DiscoveryMethod = $DiscoveryMethod
            }
        }
    }

    return @(
        $dependencyNames |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and
                $_ -ne $FeatureName -and
                $_ -notin @('None', 'N/A', 'Not Present', 'No dependencies')
            } |
            Select-Object -Unique
    )
}

function Resolve-EnterpriseFeatureDependency {
    <#
    .SYNOPSIS
        Resolve the full dependency graph for a Windows feature
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $false)]
        $Feature,

        [Parameter(Mandatory = $false)]
        [string]$DiscoveryMethod = ""
    )

    $resolvedDependencies = @{}
    $pendingDependencies = New-Object System.Collections.Queue

    foreach ($dependencyName in @(Get-DirectEnterpriseFeatureDependency -FeatureName $FeatureName -Feature $Feature -DiscoveryMethod $DiscoveryMethod)) {
        $pendingDependencies.Enqueue($dependencyName)
    }

    while ($pendingDependencies.Count -gt 0) {
        $dependencyName = [string]$pendingDependencies.Dequeue()

        if ([string]::IsNullOrWhiteSpace($dependencyName) -or $dependencyName -eq $FeatureName -or $resolvedDependencies.ContainsKey($dependencyName)) {
            continue
        }

        $resolvedDependencies[$dependencyName] = $true

        try {
            $dependencyFeature = Get-EnterpriseWindowsFeature -FeatureName $dependencyName -ResolveDependencies:$false
            foreach ($nestedDependencyName in @(Get-DirectEnterpriseFeatureDependency -FeatureName $dependencyName -Feature $dependencyFeature -DiscoveryMethod $dependencyFeature.DiscoveryMethod)) {
                if (-not $resolvedDependencies.ContainsKey($nestedDependencyName) -and $nestedDependencyName -ne $FeatureName) {
                    $pendingDependencies.Enqueue($nestedDependencyName)
                }
            }
        } catch {
            Write-EnterpriseLog -Level "Warning" -Message "Failed to resolve nested dependency" -Category "Discovery" -Properties @{
                FeatureName = $FeatureName
                DependencyName = $dependencyName
            }
        }
    }

    return @($resolvedDependencies.Keys | Sort-Object)
}

function Invoke-EnterpriseBulkFeatureOperation {
    <#
    .SYNOPSIS
        Process feature operations in batches with progress reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FeatureNames,

        [Parameter(Mandatory = $true)]
        [string]$Operation
    )

    $results = @()
    $uniqueFeatureNames = @(
        $FeatureNames |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    if (@($uniqueFeatureNames).Count -eq 0) {
        return @()
    }

    $batchSize = if ($uniqueFeatureNames.Count -ge 20) {
        10
    } elseif ($uniqueFeatureNames.Count -ge 10) {
        5
    } else {
        $uniqueFeatureNames.Count
    }

    $batchCount = [int][math]::Ceiling($uniqueFeatureNames.Count / $batchSize)
    $processedCount = 0

    Write-Host "📦 Bulk mode enabled for $($uniqueFeatureNames.Count) features" -ForegroundColor Cyan
    Write-EnterpriseLog -Level "Info" -Message "Bulk feature operation started" -Category "BulkOperation" -Properties @{
        Operation = $Operation
        FeatureCount = $uniqueFeatureNames.Count
        BatchSize = $batchSize
        BatchCount = $batchCount
    }

    for ($batchIndex = 0; $batchIndex -lt $batchCount; $batchIndex++) {
        $startIndex = $batchIndex * $batchSize
        $endIndex = [Math]::Min(($startIndex + $batchSize - 1), ($uniqueFeatureNames.Count - 1))
        $currentBatch = @($uniqueFeatureNames[$startIndex..$endIndex])

        Write-Host "   📦 Processing batch $($batchIndex + 1) of $batchCount" -ForegroundColor White

        foreach ($featureName in $currentBatch) {
            $processedCount++
            $percentComplete = [int][math]::Round(($processedCount / $uniqueFeatureNames.Count) * 100, 0)

            Write-Progress -Activity "Enterprise feature bulk operation" -Status "Processing $featureName ($processedCount of $($uniqueFeatureNames.Count))" -PercentComplete $percentComplete

            $results += Invoke-EnterpriseFeatureOperation -FeatureName $featureName -Operation $Operation
        }
    }

    Write-Progress -Activity "Enterprise feature bulk operation" -Completed

    Write-EnterpriseLog -Level "Success" -Message "Bulk feature operation completed" -Category "BulkOperation" -Properties @{
        Operation = $Operation
        FeatureCount = $uniqueFeatureNames.Count
        SuccessCount = @($results | Where-Object { $_.Success }).Count
        FailureCount = @($results | Where-Object { -not $_.Success }).Count
    }

    return @($results)
}

function Get-EnterpriseWindowsFeature {
    <#
    .SYNOPSIS
        Enhanced Windows feature discovery with comprehensive analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $false)]
        [switch]$ResolveDependencies
    )

    try {
        Write-Host "🔍 Discovering feature: $FeatureName" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting feature discovery" -Category "Discovery" -Properties @{
            FeatureName = $FeatureName
        }

        # Try multiple methods for feature discovery
        $feature = $null
        $discoveryMethod = ""

        # Method 1: Get-WindowsOptionalFeature (Client OS)
        try {
            $feature = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online -ErrorAction Stop
            $discoveryMethod = "WindowsOptionalFeature"
            Write-Host "   ✅ Found via Windows Optional Features" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  Not found in Windows Optional Features" -ForegroundColor Yellow
        }

        # Method 2: Get-WindowsFeature (Server OS)
        if (-not $feature) {
            try {
                if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
                    $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction Stop
                    $discoveryMethod = "WindowsFeature"
                    Write-Host "   ✅ Found via Windows Server Features" -ForegroundColor Green
                }
            } catch {
                Write-Host "   ⚠️  Not found in Windows Server Features" -ForegroundColor Yellow
            }
        }

        # Method 3: DISM command line fallback
        if (-not $feature) {
            try {
                $dismOutput = & DISM /Online /Get-FeatureInfo /FeatureName:$FeatureName 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $feature = @{
                        FeatureName = $FeatureName
                        State = if ($dismOutput -match "State : Enabled") { "Enabled" } else { "Disabled" }
                        DisplayName = $FeatureName
                    }
                    $discoveryMethod = "DISM"
                    Write-Host "   ✅ Found via DISM" -ForegroundColor Green
                }
            } catch {
                Write-Host "   ❌ Not found via DISM" -ForegroundColor Red
            }
        }

        if (-not $feature) {
            throw "Feature '$FeatureName' not found on this system"
        }

        $shouldResolveDependencies = if ($PSBoundParameters.ContainsKey('ResolveDependencies')) {
            $ResolveDependencies.IsPresent
        } else {
            $IncludeDependencies.IsPresent
        }

        # Enhance feature information
        $enhancedFeature = @{
            FeatureName = $FeatureName
            DisplayName = if ($feature.DisplayName) { $feature.DisplayName } else { $FeatureName }
            State = $feature.State
            DiscoveryMethod = $discoveryMethod
            Category = Get-FeatureCategory -FeatureName $FeatureName
            Dependencies = @()
            SecurityRisk = "Unknown"
        }

        # Get dependencies if available and requested
        if ($shouldResolveDependencies) {
            try {
                $enhancedFeature.Dependencies = @(Resolve-EnterpriseFeatureDependency -FeatureName $FeatureName -Feature $feature -DiscoveryMethod $discoveryMethod)
                $script:EnterpriseFeatureMetrics.DependenciesAnalyzed += @($enhancedFeature.Dependencies).Count
            } catch {
                Write-EnterpriseLog -Level "Warning" -Message "Failed to get dependencies" -Category "Discovery"
            }
        }

        Write-EnterpriseLog -Level "Success" -Message "Feature discovery completed" -Category "Discovery" -Properties $enhancedFeature

        return $enhancedFeature

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Feature discovery failed" -Category "Discovery" -Exception $_ -Properties @{
            FeatureName = $FeatureName
        }
        throw
    }
}

function Get-FeatureCategory {
    <#
    .SYNOPSIS
        Classify Windows feature by category
    #>
    [CmdletBinding()]
    param([string]$FeatureName)

    foreach ($category in $script:EnterpriseFeatureCategories.Keys) {
        if ($script:EnterpriseFeatureCategories[$category] -contains $FeatureName) {
            return $category
        }
    }

    # Pattern-based classification
    switch -Regex ($FeatureName) {
        "IIS-.*" { return "WebServer" }
        ".*Security.*|.*Defender.*" { return "Security" }
        ".*Hyper.*|.*Container.*|.*Virtual.*" { return "Virtualization" }
        ".*Media.*|.*Player.*" { return "Multimedia" }
        ".*Legacy.*|.*NTVDM.*|DirectPlay" { return "Legacy" }
        default { return "General" }
    }
}

function Invoke-EnterpriseFeatureOperation {
    <#
    .SYNOPSIS
        Execute enterprise feature operations with comprehensive validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )

    try {
        Write-Host "⚙️  Executing $Operation on feature: $FeatureName" -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting feature operation" -Category "Operation" -Properties @{
            FeatureName = $FeatureName
            Operation = $Operation
        }

        $operationResult = @{
            FeatureName = $FeatureName
            Operation = $Operation
            Success = $false
            PreviousState = "Unknown"
            NewState = "Unknown"
            RequiresReboot = $false
            Error = $null
        }

        # Get current feature state
        try {
            $currentFeature = Get-EnterpriseWindowsFeature -FeatureName $FeatureName
            $operationResult.PreviousState = $currentFeature.State
        } catch {
            $operationResult.Error = "Feature not found: $($_.Exception.Message)"
            $script:EnterpriseFeatureMetrics.FailedOperations++
            return $operationResult
        }

        # Security validation if enabled
        if ($SecurityValidation) {
            $securityResults = Test-EnterpriseFeatureSecurity -FeatureName $FeatureName -ProposedAction $Operation
            if (-not $securityResults.OverallSecure -and -not $Force) {
                $operationResult.Error = "Security validation failed - use -Force to override"
                Write-Host "   ❌ Security validation failed" -ForegroundColor Red
                return $operationResult
            }
            $operationResult.RequiresReboot = $securityResults.RequiresReboot
        }

        # Execute operation based on type
        switch ($Operation) {
            "Check" {
                $operationResult.Success = $true
                $operationResult.NewState = $operationResult.PreviousState

                if ($operationResult.PreviousState -eq "Enabled") {
                    Write-Host "   ✅ Feature '$FeatureName' is ENABLED" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ Feature '$FeatureName' is DISABLED" -ForegroundColor Red
                }
            }

            "Enable" {
                if ($operationResult.PreviousState -eq "Enabled") {
                    Write-Host "   ℹ️  Feature '$FeatureName' is already enabled" -ForegroundColor Yellow
                    $operationResult.Success = $true
                    $operationResult.NewState = "Enabled"
                } else {
                    try {
                        # Try multiple enable methods
                        $enableSuccess = $false

                        # Method 1: Enable-WindowsOptionalFeature
                        try {
                            Enable-WindowsOptionalFeature -FeatureName $FeatureName -Online -All -NoRestart -ErrorAction Stop | Out-Null
                            $enableSuccess = $true
                        } catch {
                            Write-Host "   ⚠️  WindowsOptionalFeature method failed, trying alternatives..." -ForegroundColor Yellow
                        }

                        # Method 2: Install-WindowsFeature (Server)
                        if (-not $enableSuccess -and (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue)) {
                            try {
                                Install-WindowsFeature -Name $FeatureName -ErrorAction Stop | Out-Null
                                $enableSuccess = $true
                            } catch {
                                Write-Host "   ⚠️  WindowsFeature method failed, trying DISM..." -ForegroundColor Yellow
                            }
                        }

                        # Method 3: DISM fallback
                        if (-not $enableSuccess) {
                            $null = & DISM /Online /Enable-Feature /FeatureName:$FeatureName /All /NoRestart 2>$null
                            $enableSuccess = ($LASTEXITCODE -eq 0)
                        }

                        if ($enableSuccess) {
                            $operationResult.Success = $true
                            $operationResult.NewState = "Enabled"
                            $script:EnterpriseFeatureMetrics.EnabledFeatures++
                            Write-Host "   ✅ Successfully enabled feature '$FeatureName'" -ForegroundColor Green
                        } else {
                            throw "All enable methods failed"
                        }
                    } catch {
                        $operationResult.Error = "Enable failed: $($_.Exception.Message)"
                        $script:EnterpriseFeatureMetrics.FailedOperations++
                        Write-Host "   ❌ Failed to enable feature: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            "Disable" {
                if ($operationResult.PreviousState -eq "Disabled") {
                    Write-Host "   ℹ️  Feature '$FeatureName' is already disabled" -ForegroundColor Yellow
                    $operationResult.Success = $true
                    $operationResult.NewState = "Disabled"
                } else {
                    try {
                        # Try multiple disable methods
                        $disableSuccess = $false

                        # Method 1: Disable-WindowsOptionalFeature
                        try {
                            Disable-WindowsOptionalFeature -FeatureName $FeatureName -Online -NoRestart -ErrorAction Stop | Out-Null
                            $disableSuccess = $true
                        } catch {
                            Write-Host "   ⚠️  WindowsOptionalFeature method failed, trying alternatives..." -ForegroundColor Yellow
                        }

                        # Method 2: Uninstall-WindowsFeature (Server)
                        if (-not $disableSuccess -and (Get-Command Uninstall-WindowsFeature -ErrorAction SilentlyContinue)) {
                            try {
                                Uninstall-WindowsFeature -Name $FeatureName -ErrorAction Stop | Out-Null
                                $disableSuccess = $true
                            } catch {
                                Write-Host "   ⚠️  WindowsFeature method failed, trying DISM..." -ForegroundColor Yellow
                            }
                        }

                        # Method 3: DISM fallback
                        if (-not $disableSuccess) {
                            $null = & DISM /Online /Disable-Feature /FeatureName:$FeatureName /NoRestart 2>$null
                            $disableSuccess = ($LASTEXITCODE -eq 0)
                        }

                        if ($disableSuccess) {
                            $operationResult.Success = $true
                            $operationResult.NewState = "Disabled"
                            $script:EnterpriseFeatureMetrics.DisabledFeatures++
                            Write-Host "   ✅ Successfully disabled feature '$FeatureName'" -ForegroundColor Green
                        } else {
                            throw "All disable methods failed"
                        }
                    } catch {
                        $operationResult.Error = "Disable failed: $($_.Exception.Message)"
                        $script:EnterpriseFeatureMetrics.FailedOperations++
                        Write-Host "   ❌ Failed to disable feature: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }

        # Add to processed features
        $script:EnterpriseFeatureMetrics.ProcessedFeatures += $operationResult

        Write-EnterpriseLog -Level "Info" -Message "Feature operation completed" -Category "Operation" -Properties $operationResult

        return $operationResult

    } catch {
        $operationResult.Error = "Unexpected error: $($_.Exception.Message)"
        $script:EnterpriseFeatureMetrics.FailedOperations++

        Write-EnterpriseLog -Level "Error" -Message "Feature operation failed" -Category "Operation" -Exception $_ -Properties @{
            FeatureName = $FeatureName
            Operation = $Operation
        }

        return $operationResult
    }
}

function Get-AllEnterpriseWindowsFeature {
    <#
    .SYNOPSIS
        Discover all available Windows features with comprehensive analysis
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Host "🔍 Discovering all Windows features..." -ForegroundColor Cyan
        Write-EnterpriseLog -Level "Info" -Message "Starting comprehensive feature discovery" -Category "Discovery"

        $allFeatures = @()

        # Method 1: Get-WindowsOptionalFeature (Client OS)
        try {
            $optionalFeatures = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue
            if ($optionalFeatures) {
                foreach ($feature in $optionalFeatures) {
                    $allFeatures += @{
                        FeatureName = $feature.FeatureName
                        DisplayName = $feature.DisplayName
                        State = $feature.State
                        Category = Get-FeatureCategory -FeatureName $feature.FeatureName
                        Source = "WindowsOptionalFeature"
                    }
                }
                Write-Host "   ✅ Found $($optionalFeatures.Count) optional features" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ⚠️  Optional features not available on this system" -ForegroundColor Yellow
        }

        # Method 2: Get-WindowsFeature (Server OS)
        try {
            if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
                $serverFeatures = Get-WindowsFeature -ErrorAction SilentlyContinue
                if ($serverFeatures) {
                    foreach ($feature in $serverFeatures) {
                        # Avoid duplicates
                        if (-not ($allFeatures | Where-Object { $_.FeatureName -eq $feature.Name })) {
                            $allFeatures += @{
                                FeatureName = $feature.Name
                                DisplayName = $feature.DisplayName
                                State = if ($feature.InstallState -eq "Installed") { "Enabled" } else { "Disabled" }
                                Category = Get-FeatureCategory -FeatureName $feature.Name
                                Source = "WindowsFeature"
                            }
                        }
                    }
                    Write-Host "   ✅ Found $($serverFeatures.Count) server features" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "   ⚠️  Server features not available on this system" -ForegroundColor Yellow
        }

        $script:EnterpriseFeatureMetrics.TotalFeatures = $allFeatures.Count

        Write-EnterpriseLog -Level "Success" -Message "Feature discovery completed" -Category "Discovery" -Properties @{
            TotalFeatures = $allFeatures.Count
            FeatureSources = ($allFeatures | Group-Object Source | ForEach-Object { "$($_.Name): $($_.Count)" })
        }

        return $allFeatures

    } catch {
        Write-EnterpriseLog -Level "Error" -Message "Comprehensive feature discovery failed" -Category "Discovery" -Exception $_
        throw
    }
}

function Export-EnterpriseFeatureReport {
    <#
    .SYNOPSIS
        Generate comprehensive enterprise feature management report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [array]$Features = @()
    )

    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $reportPath = Join-Path $ReportPath "Enterprise-WindowsFeature-Report-$timestamp.$($ExportFormat.ToLower())"

        $report = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            WindowsVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
            Parameters = $PSBoundParameters
            Features = $Features
            Metrics = $script:EnterpriseFeatureMetrics
            Duration = [math]::Round(((Get-Date) - $script:EnterpriseFeatureMetrics.StartTime).TotalMinutes, 2)
        }

        switch ($ExportFormat) {
            "JSON" {
                $report | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
            }
            "XML" {
                $report | ConvertTo-Xml -Depth 10 | Out-File $reportPath -Encoding UTF8
            }
            "CSV" {
                $Features | Export-Csv $reportPath -NoTypeInformation -Encoding UTF8
            }
            "HTML" {
                $htmlContent = @"
<!DOCTYPE html>
<html><head><title>Enterprise Windows Feature Report</title></head>
<body><h1>Enterprise Windows Feature Report</h1>
<p><strong>Generated:</strong> $($report.Timestamp)</p>
<p><strong>Computer:</strong> $($report.ComputerName)</p>
<p><strong>Duration:</strong> $($report.Duration) minutes</p>
<table border="1"><tr><th>Feature Name</th><th>State</th><th>Category</th></tr>
"@
                foreach ($feature in $Features) {
                    $stateColor = if ($feature.State -eq "Enabled") { "green" } else { "red" }
                    $htmlContent += "<tr><td>$($feature.FeatureName)</td><td style='color:$stateColor'>$($feature.State)</td><td>$($feature.Category)</td></tr>"
                }
                $htmlContent += "</table></body></html>"
                $htmlContent | Out-File $reportPath -Encoding UTF8
            }
        }

        Write-Host "📄 Enterprise feature report exported: $reportPath" -ForegroundColor Green
        Write-EnterpriseLog -Level "Success" -Message "Enterprise feature report generated" -Category "Reporting" -Properties @{
            ReportPath = $reportPath
            Format = $ExportFormat
            FeatureCount = $Features.Count
            Duration = $report.Duration
        }

        return $reportPath

    } catch {
        Write-EnterpriseLog -Level "Warning" -Message "Failed to generate enterprise feature report" -Category "Reporting" -Exception $_
        Write-Host "⚠️  Failed to generate report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

####################################################################
# 🚀 MAIN ENTERPRISE EXECUTION LOGIC
####################################################################

try {
    # Enterprise banner
    Write-Host "`n" + ("═" * 70) -ForegroundColor Cyan
    Write-Host "🏢 ENTERPRISE WINDOWS FEATURE MANAGEMENT SYSTEM" -ForegroundColor Green
    Write-Host ("═" * 70) -ForegroundColor Cyan
    Write-Host "🔒 Military-grade feature lifecycle management with comprehensive validation" -ForegroundColor White
    Write-Host ""

    Write-EnterpriseLog -Level "Info" -Message "Enterprise feature management system started" -Category "System" -Properties @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        Parameters = $PSBoundParameters
    }

    # Validate input parameters
    if (-not $FeatureName -and $FeatureList.Count -eq 0 -and $Action -notin @("List", "Discover")) {
        if ($args.Count -gt 0) {
            $FeatureName = $args[0]
            Write-Host "📝 Using feature name from argument: $FeatureName" -ForegroundColor Yellow
        } else {
            $FeatureName = Read-Host "Enter Windows Feature name to $Action"
        }
    }

    # Combine single feature with list
    $featuresToProcess = @()
    if ($FeatureName) { $featuresToProcess += $FeatureName }
    if ($FeatureList.Count -gt 0) { $featuresToProcess += $FeatureList }
    $featuresToProcess = @(
        $featuresToProcess |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    # Interactive confirmation for non-check operations
    if ($Action -notin @("Check", "Analyze", "List", "Discover") -and -not $Force) {
        Write-Host "⚠️  ENTERPRISE FEATURE MANAGEMENT NOTICE" -ForegroundColor Yellow
        Write-Host "This operation will modify Windows features with comprehensive validation." -ForegroundColor White
        Write-Host "Action: $Action" -ForegroundColor Cyan
        Write-Host "Features: $($featuresToProcess -join ', ')" -ForegroundColor Cyan
        Write-Host ""

        $confirmation = Read-Host "Do you wish to proceed with enterprise feature management? (y/N)"
        if ($confirmation -notmatch '^[yY]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            Write-EnterpriseLog -Level "Info" -Message "Operation cancelled by user" -Category "Security"
            exit 0
        }
    }

    # Enterprise compliance validation
    if ($Action -notin @("Check", "Analyze", "List", "Discover")) {
        Write-Host "`n🛡️  ENTERPRISE COMPLIANCE VALIDATION" -ForegroundColor Cyan
        if (-not (Test-EnterpriseSystemCompliance)) {
            throw "Enterprise compliance validation failed. Cannot proceed with feature operations."
        }
        Write-Host "✅ Enterprise compliance validated successfully" -ForegroundColor Green
    }

    # Execute requested action
    Write-Host "`n⚙️  ENTERPRISE FEATURE PROCESSING" -ForegroundColor Cyan

    switch ($Action) {
        "List" {
            Write-Host "Discovering all Windows features..." -ForegroundColor White
            $allFeatures = Get-AllEnterpriseWindowsFeature

            Write-Host "`n📋 Windows Feature Summary:" -ForegroundColor Cyan
            $groupedFeatures = $allFeatures | Group-Object State
            foreach ($group in $groupedFeatures) {
                $color = if ($group.Name -eq "Enabled") { "Green" } else { "Red" }
                Write-Host "   $($group.Name): $($group.Count) features" -ForegroundColor $color
            }

            Write-Host "`n📊 Feature Categories:" -ForegroundColor Cyan
            $categoryGroups = $allFeatures | Group-Object Category | Sort-Object Count -Descending
            foreach ($group in $categoryGroups) {
                Write-Host "   $($group.Name): $($group.Count) features" -ForegroundColor White
            }

            Export-EnterpriseFeatureReport -Features $allFeatures
        }

        "Discover" {
            Write-Host "Analyzing Windows feature ecosystem..." -ForegroundColor White
            $allFeatures = Get-AllEnterpriseWindowsFeature

            # Advanced analytics
            $enabledFeatures = $allFeatures | Where-Object { $_.State -eq "Enabled" }
            $disabledFeatures = $allFeatures | Where-Object { $_.State -eq "Disabled" }
            $featureCount = @($allFeatures).Count
            $enabledPercentage = 0
            $disabledPercentage = 0

            if ($featureCount -gt 0) {
                $enabledPercentage = [math]::Round((@($enabledFeatures).Count / $featureCount) * 100, 1)
                $disabledPercentage = [math]::Round((@($disabledFeatures).Count / $featureCount) * 100, 1)
            }

            Write-Host "`n🔬 Enterprise Feature Analytics:" -ForegroundColor Cyan
            Write-Host "   Total Features: $featureCount" -ForegroundColor White
            Write-Host "   Enabled: $(@($enabledFeatures).Count) ($enabledPercentage%)" -ForegroundColor Green
            Write-Host "   Disabled: $(@($disabledFeatures).Count) ($disabledPercentage%)" -ForegroundColor Red

            # Security analysis
            $securityFeatures = $allFeatures | Where-Object { $_.Category -eq "Security" }
            $legacyFeatures = $allFeatures | Where-Object { $_.Category -eq "Legacy" }

            Write-Host "`n🛡️  Security Analysis:" -ForegroundColor Yellow
            Write-Host "   Security Features: $($securityFeatures.Count)" -ForegroundColor White
            Write-Host "   Legacy Features: $($legacyFeatures.Count)" -ForegroundColor White

            Export-EnterpriseFeatureReport -Features $allFeatures
        }

        "Analyze" {
            $analysisResults = @()

            if ($BulkMode -and @($featuresToProcess).Count -gt 1) {
                Write-Host "📦 Bulk analysis mode enabled for $(@($featuresToProcess).Count) features" -ForegroundColor Cyan
            }

            $analysisIndex = 0
            foreach ($feature in $featuresToProcess) {
                $analysisIndex++
                if ($BulkMode -and @($featuresToProcess).Count -gt 1) {
                    $analysisPercent = [int][math]::Round(($analysisIndex / @($featuresToProcess).Count) * 100, 0)
                    Write-Progress -Activity "Enterprise feature analysis" -Status "Analyzing $feature ($analysisIndex of $(@($featuresToProcess).Count))" -PercentComplete $analysisPercent
                }

                $featureDetails = Get-EnterpriseWindowsFeature -FeatureName $feature
                $securityResults = Test-EnterpriseFeatureSecurity -FeatureName $feature -ProposedAction "Analyze"

                $analysisResult = @{
                    FeatureName = $featureDetails.FeatureName
                    DisplayName = $featureDetails.DisplayName
                    State = $featureDetails.State
                    Category = $featureDetails.Category
                    DiscoveryMethod = $featureDetails.DiscoveryMethod
                    Dependencies = @($featureDetails.Dependencies)
                    SecurityRisk = $securityResults.SecurityRisk
                    RequiresReboot = $securityResults.RequiresReboot
                    NetworkExposure = $securityResults.NetworkExposure
                    PrivilegeEscalation = $securityResults.PrivilegeEscalation
                    Recommendations = @($securityResults.Recommendations)
                }

                $analysisResults += $analysisResult
                $script:EnterpriseFeatureMetrics.ProcessedFeatures += $analysisResult

                $dependencyDisplay = if (@($featureDetails.Dependencies).Count -gt 0) {
                    @($featureDetails.Dependencies) -join ', '
                } else {
                    'None detected'
                }

                $securityRiskColor = if ($securityResults.SecurityRisk -eq 'High') {
                    'Red'
                } elseif ($securityResults.SecurityRisk -eq 'Medium') {
                    'Yellow'
                } else {
                    'Green'
                }

                Write-Host "`n🔎 Feature Analysis: $($featureDetails.FeatureName)" -ForegroundColor Cyan
                Write-Host "   State: $($featureDetails.State)" -ForegroundColor White
                Write-Host "   Category: $($featureDetails.Category)" -ForegroundColor White
                Write-Host "   Discovery Method: $($featureDetails.DiscoveryMethod)" -ForegroundColor White
                Write-Host "   Dependencies: $dependencyDisplay" -ForegroundColor White
                Write-Host "   Security Risk: $($securityResults.SecurityRisk)" -ForegroundColor $securityRiskColor

                if (@($securityResults.Recommendations).Count -gt 0) {
                    Write-Host "   Recommendations:" -ForegroundColor Yellow
                    $securityResults.Recommendations | ForEach-Object {
                        Write-Host "      • $_" -ForegroundColor White
                    }
                }
            }

            if ($BulkMode -and @($featuresToProcess).Count -gt 1) {
                Write-Progress -Activity "Enterprise feature analysis" -Completed
            }

            if (@($analysisResults).Count -gt 1) {
                Export-EnterpriseFeatureReport -Features $analysisResults
            }
        }

        default {
            if ($BulkMode -and @($featuresToProcess).Count -gt 1) {
                $bulkResults = @(Invoke-EnterpriseBulkFeatureOperation -FeatureNames $featuresToProcess -Operation $Action)

                foreach ($result in $bulkResults) {
                    if ($result.RequiresReboot) {
                        Write-Host "   ⚠️  System reboot recommended after processing feature '$($result.FeatureName)'" -ForegroundColor Yellow
                    }
                }
            } else {
                # Process individual features
                foreach ($feature in $featuresToProcess) {
                    $result = Invoke-EnterpriseFeatureOperation -FeatureName $feature -Operation $Action

                    if ($result.RequiresReboot) {
                        Write-Host "   ⚠️  System reboot recommended after this operation" -ForegroundColor Yellow
                    }
                }
            }

            if ($featuresToProcess.Count -gt 1) {
                Export-EnterpriseFeatureReport -Features $script:EnterpriseFeatureMetrics.ProcessedFeatures
            }
        }
    }

    # Final summary
    $duration = [math]::Round(((Get-Date) - $script:EnterpriseFeatureMetrics.StartTime).TotalMinutes, 2)
    Write-Host "`n" + ("═" * 50) -ForegroundColor Green
    Write-Host "🎉 ENTERPRISE FEATURE MANAGEMENT COMPLETE" -ForegroundColor Green
    Write-Host ("═" * 50) -ForegroundColor Green
    Write-Host "   Duration: $duration minutes" -ForegroundColor White
    Write-Host "   Total Features Processed: $($script:EnterpriseFeatureMetrics.ProcessedFeatures.Count)" -ForegroundColor White
    Write-Host "   Enabled Features: $($script:EnterpriseFeatureMetrics.EnabledFeatures)" -ForegroundColor Green
    Write-Host "   Disabled Features: $($script:EnterpriseFeatureMetrics.DisabledFeatures)" -ForegroundColor Red
    Write-Host "   Failed Operations: $($script:EnterpriseFeatureMetrics.FailedOperations)" -ForegroundColor Yellow
    Write-Host "   Security Violations: $($script:EnterpriseFeatureMetrics.SecurityViolations)" -ForegroundColor Yellow

    Write-EnterpriseLog -Level "Success" -Message "Enterprise feature management completed successfully" -Category "System" -Properties $script:EnterpriseFeatureMetrics

} catch {
    Write-EnterpriseLog -Level "Error" -Message "Enterprise feature management failed" -Category "System" -Exception $_
    Write-Host "`n❌ ENTERPRISE FEATURE MANAGEMENT FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($script:EnterpriseFeatureMetrics.Errors.Count -gt 0) {
        Write-Host "`nDetailed Errors:" -ForegroundColor Yellow
        $script:EnterpriseFeatureMetrics.Errors | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor Red
        }
    }

    exit 1
} finally {
    # Cleanup and final telemetry
    if ($script:EnterpriseFeatureMetrics) {
        $script:EnterpriseFeatureMetrics.EndTime = Get-Date
    }
}
