<#
.SYNOPSIS
    Wrapper to invoke SCCMSoftwareCollectionConsolidation.ps1 on a remote SCCM host.

.DESCRIPTION
    Copies and executes the consolidation script on a remote computer that has
    the ConfigurationManager module available. Uses Invoke-Command -FilePath so
    the local script is transferred and executed remotely.

    Requirements:
    - PowerShell Remoting (WinRM) enabled and reachable on the target host.
    - The target host must have the SCCM ConfigurationManager PowerShell module
      and network access/permissions required to manage the site.

.EXAMPLE
    # Run a dry-run on the SCCM server (prompts for credentials)
    .\run-on-sccm-host.ps1 -ComputerName SCCMSERVER01 -Credential (Get-Credential) -SiteCode P03 -SoftwareName 'Adobe Acrobat Pro' -TargetFolder 'Adobe Acrobat Pro' -DryRun -EnableDebugLog
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ComputerName,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$LocalScriptPath = (Join-Path $PSScriptRoot 'SCCMSoftwareCollectionConsolidation.ps1'),

    [Parameter(Mandatory = $true)][string]$SiteCode,
    [Parameter(Mandatory = $true)][string]$SoftwareName,
    [Parameter(Mandatory = $true)][string]$TargetFolder,

    [Parameter(Mandatory = $false)][bool]$ManageSupersedence = $true,
    [Parameter(Mandatory = $false)][bool]$DeleteOldCollections = $true,
    [Parameter(Mandatory = $false)][switch]$AutoApprove,
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$DryRun,
    [Parameter(Mandatory = $false)][int]$RetryCount = 1,
    [Parameter(Mandatory = $false)][int]$RetryDelaySeconds = 60,
    [Parameter(Mandatory = $false)][switch]$EnableDebugLog,
    [Parameter(Mandatory = $false)][bool]$CleanupCollectionMembershipDependencies = $true,
    [Parameter(Mandatory = $false)][switch]$ReassignLimitingCollectionDependencies,
    [Parameter(Mandatory = $false)][string]$FallbackLimitingCollectionName = 'All Systems',
    [Parameter(Mandatory = $false)][string]$ApplicationDeploymentRootPath = '',
    [Parameter(Mandatory = $false)][switch]$StrictApplicationDeploymentRootDiscovery,
    [Parameter(Mandatory = $false)][string]$ScriptBuildId = ''
)

Write-Host "Invoking remote script '$LocalScriptPath' on $ComputerName" -ForegroundColor Cyan

# Build positional argument list in the same order as the target script's param block.
$argList = @(
    $SiteCode,
    $SoftwareName,
    $TargetFolder,
    [bool]$ManageSupersedence,
    [bool]$DeleteOldCollections,
    ([bool]($AutoApprove.IsPresent -or $AutoApprove -eq $true)),
    ([bool]($NonInteractive.IsPresent -or $NonInteractive -eq $true)),
    ([bool]($DryRun.IsPresent -or $DryRun -eq $true)),
    [int]$RetryCount,
    [int]$RetryDelaySeconds,
    ([bool]($EnableDebugLog.IsPresent -or $EnableDebugLog -eq $true)),
    [bool]$CleanupCollectionMembershipDependencies,
    ([bool]($ReassignLimitingCollectionDependencies.IsPresent -or $ReassignLimitingCollectionDependencies -eq $true)),
    $FallbackLimitingCollectionName,
    $ApplicationDeploymentRootPath,
    ([bool]($StrictApplicationDeploymentRootDiscovery.IsPresent -or $StrictApplicationDeploymentRootDiscovery -eq $true)),
    $ScriptBuildId
)

$invokeParams = @{ ComputerName = $ComputerName; FilePath = $LocalScriptPath; ArgumentList = $argList; ErrorAction = 'Stop' }
if ($Credential) { $invokeParams.Credential = $Credential }

try {
    $out = Invoke-Command @invokeParams
    Write-Output $out
} catch {
    Write-Error "Remote execution failed: $($_.Exception.Message)"
    throw
}
