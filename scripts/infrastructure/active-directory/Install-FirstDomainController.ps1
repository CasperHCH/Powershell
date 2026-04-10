<#
.SYNOPSIS
    Installs or validates the first domain controller build workflow from a manifest.

.DESCRIPTION
    This script validates the local environment for a first domain controller build and,
    when requested, installs required Windows features plus invokes Install-ADDSForest
    using values from the infrastructure manifest.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER SafeModeAdministratorPassword
    SecureString used as the Directory Services Restore Mode password for forest creation.

.PARAMETER SkipPrerequisiteInstall
    Skip Windows feature installation and only run validation or promotion.

.PARAMETER ValidateOnly
    Return preflight results and intended promotion parameters without making changes.

.PARAMETER NoRebootOnCompletion
    Do not reboot automatically after Install-ADDSForest completes.

.EXAMPLE
    .\Install-FirstDomainController.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly

.EXAMPLE
    .\Install-FirstDomainController.ps1 -ManifestPath ..\config\Environment.lab.psd1 -NoRebootOnCompletion -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [securestring]$SafeModeAdministratorPassword,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisiteInstall,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly,

    [Parameter(Mandatory = $false)]
    [switch]$NoRebootOnCompletion
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$adConfig = $manifest.ActiveDirectory
$domainController = @($adConfig.DomainControllers | Select-Object -First 1)[0]
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
$localComputerName = [Environment]::MachineName
$installAddsForestAvailable = [bool](Get-Command -Name Install-ADDSForest -ErrorAction SilentlyContinue)
$installWindowsFeatureAvailable = [bool](Get-Command -Name Install-WindowsFeature -ErrorAction SilentlyContinue)
$forestAlreadyExists = $false

if ($installAddsForestAvailable) {
    try {
        $null = Get-ADDomain -Identity $manifest.Organization.Domain -ErrorAction Stop
        $forestAlreadyExists = $true
    }
    catch {
        $forestAlreadyExists = $false
    }
}

$databasePath = if ($adConfig.ContainsKey('DatabasePath')) { $adConfig.DatabasePath } else { 'C:\Windows\NTDS' }
$ntdsLogPath = if ($adConfig.ContainsKey('LogPath')) { $adConfig.LogPath } else { 'C:\Windows\NTDS' }
$sysvolPath = if ($adConfig.ContainsKey('SysvolPath')) { $adConfig.SysvolPath } else { 'C:\Windows\SYSVOL' }
$installDns = if ($adConfig.ContainsKey('InstallDns')) { [bool]$adConfig.InstallDns } else { $true }
$createDnsDelegation = if ($adConfig.ContainsKey('CreateDnsDelegation')) { [bool]$adConfig.CreateDnsDelegation } else { $false }

$checks = New-Object 'System.Collections.Generic.List[object]'
$checks.Add((New-InfrastructureCheckResult -Name 'Install-ADDSForest available' -Passed $installAddsForestAvailable -Severity 'Error' -Details 'Required to promote the first domain controller.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Elevated session' -Passed (Test-InfrastructureAdministrator) -Severity 'Error' -Details 'Run the script in an elevated PowerShell session.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Primary domain controller defined' -Passed ($null -ne $domainController) -Severity 'Error' -Details 'The manifest must define at least one Active Directory domain controller entry.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Organization domain defined' -Passed (-not [string]::IsNullOrWhiteSpace($manifest.Organization.Domain)) -Severity 'Error' -Details 'The manifest must define Organization.Domain.'))
$checks.Add((New-InfrastructureCheckResult -Name 'NetBIOS name defined' -Passed (-not [string]::IsNullOrWhiteSpace($manifest.Organization.NetBIOSName)) -Severity 'Error' -Details 'The manifest must define Organization.NetBIOSName.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Forest mode defined' -Passed (-not [string]::IsNullOrWhiteSpace($adConfig.ForestMode)) -Severity 'Error' -Details 'The manifest must define ActiveDirectory.ForestMode.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Domain mode defined' -Passed (-not [string]::IsNullOrWhiteSpace($adConfig.DomainMode)) -Severity 'Error' -Details 'The manifest must define ActiveDirectory.DomainMode.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Computer is not already domain joined' -Passed (-not [bool]$computerSystem.PartOfDomain) -Severity 'Error' -Target $localComputerName -Details ($(if ($computerSystem.PartOfDomain) { 'This machine is already joined to a domain and should not be used to create a new forest root domain.' } else { 'The local machine is not domain joined.' }))))
$checks.Add((New-InfrastructureCheckResult -Name 'Target domain does not already exist' -Passed (-not $forestAlreadyExists) -Severity 'Error' -Target $manifest.Organization.Domain -Details ($(if ($forestAlreadyExists) { 'The target domain already resolves through Active Directory cmdlets.' } else { 'No existing domain was discovered through Active Directory cmdlets.' }))))

if ($null -ne $domainController) {
    $targetShortName = $domainController.ServerName.Split('.')[0]
    $checks.Add((New-InfrastructureCheckResult -Name 'Local host matches planned primary domain controller' -Passed ($localComputerName -eq $targetShortName) -Severity 'Warning' -Target $domainController.ServerName -Details ($(if ($localComputerName -eq $targetShortName) { 'The local machine matches the manifest host entry.' } else { "Local host '$localComputerName' does not match manifest server '$($domainController.ServerName)'." }))))
}

if (-not $SkipPrerequisiteInstall) {
    $checks.Add((New-InfrastructureCheckResult -Name 'Install-WindowsFeature available' -Passed $installWindowsFeatureAvailable -Severity 'Error' -Details 'Required to add AD DS and DNS features automatically.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })
$warningChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Warning' })
$overallStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($warningChecks.Count -gt 0) { 'Warning' } else { 'Ready' }

$promotionSummary = @{
    PlannedAction = 'Install first domain controller'
    ServerName = if ($null -ne $domainController) { $domainController.ServerName } else { $null }
    Domain = $manifest.Organization.Domain
    NetBIOSName = $manifest.Organization.NetBIOSName
    ForestMode = $adConfig.ForestMode
    DomainMode = $adConfig.DomainMode
    DatabasePath = $databasePath
    LogPath = $ntdsLogPath
    SysvolPath = $sysvolPath
    InstallDns = $installDns
    CreateDnsDelegation = $createDnsDelegation
    SkipPrerequisiteInstall = [bool]$SkipPrerequisiteInstall
    NoRebootOnCompletion = [bool]$NoRebootOnCompletion
    PasswordProvided = $PSBoundParameters.ContainsKey('SafeModeAdministratorPassword')
    ValidationStatus = $overallStatus
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'AD_FIRST_DC_PRECHECK' -Target $promotionSummary.ServerName -AdditionalData @{
    Domain = $promotionSummary.Domain
    ValidationStatus = $overallStatus
    FailedChecks = $failedChecks.Count
    WarningChecks = $warningChecks.Count
    ValidateOnly = [bool]$ValidateOnly
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    if ((-not $ValidateOnly) -and $failedChecks.Count -gt 0) {
        Write-InfrastructureLog -Message 'Active Directory promotion prerequisites failed.' -Level 'ERROR' -LogPath $scriptLogPath
    }

    $promotionSummary

    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'Active Directory build prerequisites failed.'
    }

    return
}

if (-not $PSBoundParameters.ContainsKey('SafeModeAdministratorPassword') -and -not $WhatIfPreference) {
    $SafeModeAdministratorPassword = Read-Host 'Enter Directory Services Restore Mode password' -AsSecureString
}

if ($PSCmdlet.ShouldProcess($promotionSummary.ServerName, 'Install first domain controller and create forest')) {
    try {
        if (-not $SkipPrerequisiteInstall) {
            Write-InfrastructureLog -Message 'Installing Active Directory Domain Services and DNS features.' -LogPath $scriptLogPath
            $featureNames = @('AD-Domain-Services')
            if ($installDns) {
                $featureNames += 'DNS'
            }

            $featureInstallResult = Install-WindowsFeature -Name $featureNames -IncludeManagementTools -Restart:$false -ErrorAction Stop
            Write-InfrastructureAudit -Action 'AD_FIRST_DC_FEATURE_INSTALL' -Target $promotionSummary.ServerName -AdditionalData @{
                Success = [bool]$featureInstallResult.Success
                RestartNeeded = [string]$featureInstallResult.RestartNeeded
                Features = $featureNames
            } -LogPath $scriptLogPath
        }

        $forestParams = @{
            DomainName = $promotionSummary.Domain
            DomainNetbiosName = $promotionSummary.NetBIOSName
            ForestMode = $promotionSummary.ForestMode
            DomainMode = $promotionSummary.DomainMode
            InstallDns = $promotionSummary.InstallDns
            CreateDnsDelegation = $promotionSummary.CreateDnsDelegation
            DatabasePath = $promotionSummary.DatabasePath
            LogPath = $promotionSummary.LogPath
            SysvolPath = $promotionSummary.SysvolPath
            NoRebootOnCompletion = $promotionSummary.NoRebootOnCompletion
            Force = $true
        }

        if ($PSBoundParameters.ContainsKey('SafeModeAdministratorPassword')) {
            $forestParams['SafeModeAdministratorPassword'] = $SafeModeAdministratorPassword
        }

        Write-InfrastructureAudit -Action 'AD_FIRST_DC_INSTALL_START' -Target $promotionSummary.ServerName -AdditionalData @{
            Domain = $promotionSummary.Domain
            NetBIOSName = $promotionSummary.NetBIOSName
            ForestMode = $promotionSummary.ForestMode
            DomainMode = $promotionSummary.DomainMode
            InstallDns = $promotionSummary.InstallDns
        } -LogPath $scriptLogPath

        $installResult = Install-ADDSForest @forestParams

        Write-InfrastructureAudit -Action 'AD_FIRST_DC_INSTALL_COMPLETE' -Target $promotionSummary.ServerName -AdditionalData @{
            ResultType = if ($null -ne $installResult) { $installResult.GetType().FullName } else { 'null' }
        } -LogPath $scriptLogPath

        @{
            PlannedAction = $promotionSummary.PlannedAction
            ServerName = $promotionSummary.ServerName
            Domain = $promotionSummary.Domain
            ValidationStatus = $promotionSummary.ValidationStatus
            ExecutionStatus = 'Completed'
            Result = $installResult
        }
    }
    catch {
        Write-InfrastructureAudit -Action 'AD_FIRST_DC_INSTALL_FAILED' -Target $promotionSummary.ServerName -AdditionalData @{
            Domain = $promotionSummary.Domain
            Error = $_.Exception.Message
        } -LogPath $scriptLogPath
        throw
    }
}