<#
.SYNOPSIS
    Orchestrates phased infrastructure bootstrap workflows from a validated manifest.

.DESCRIPTION
    This script loads a manifest, validates core prerequisites, and then invokes the
    scaffolded Active Directory, PKI, and SCCM phase scripts in a controlled order.

.PARAMETER ManifestPath
    Path to the manifest file describing the target environment. Supports .psd1 and .ps1.

.PARAMETER Phase
    Limit execution to one phase or run all phases.

.PARAMETER ValidateOnly
    Validate the manifest and planned execution order without invoking child scripts.

.EXAMPLE
    .\Invoke-InfrastructureBootstrap.ps1 -ManifestPath .\config\Environment.lab.psd1 -ValidateOnly

.EXAMPLE
    .\Invoke-InfrastructureBootstrap.ps1 -ManifestPath .\config\Environment.SCCM.template.ps1 -Phase SCCM -ValidateOnly

.EXAMPLE
    .\Invoke-InfrastructureBootstrap.ps1 -ManifestPath .\config\Environment.lab.psd1 -Phase ActiveDirectory -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('All', 'ActiveDirectory', 'PKI', 'SCCM')]
    [string]$Phase = 'All',

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath 'Infrastructure-Common.ps1')

$logPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath

if (-not (Test-InfrastructureAdministrator)) {
    throw 'Run this workflow in an elevated PowerShell session.'
}

$plan = @(
    [pscustomobject]@{ Phase = 'ActiveDirectory'; Script = (Join-Path $PSScriptRoot 'active-directory\Install-FirstDomainController.ps1') },
    [pscustomobject]@{ Phase = 'ActiveDirectory'; Script = (Join-Path $PSScriptRoot 'active-directory\New-ADBaselineOUs.ps1') },
    [pscustomobject]@{ Phase = 'ActiveDirectory'; Script = (Join-Path $PSScriptRoot 'active-directory\New-ADBaselineGroups.ps1') },
    [pscustomobject]@{ Phase = 'ActiveDirectory'; Script = (Join-Path $PSScriptRoot 'active-directory\New-ADBaselineGpos.ps1') },
    [pscustomobject]@{ Phase = 'ActiveDirectory'; Script = (Join-Path $PSScriptRoot 'active-directory\Test-ADDomainHealth.ps1') },
    [pscustomobject]@{ Phase = 'PKI'; Script = (Join-Path $PSScriptRoot 'pki\Install-IssuingCA.ps1') },
    [pscustomobject]@{ Phase = 'PKI'; Script = (Join-Path $PSScriptRoot 'pki\Test-PkiHealth.ps1') },
    [pscustomobject]@{ Phase = 'SCCM'; Script = (Join-Path $PSScriptRoot 'sccm\Install-SccmPrereqs.ps1') },
    [pscustomobject]@{ Phase = 'SCCM'; Script = (Join-Path $PSScriptRoot 'sccm\New-SccmBoundaryModel.ps1') },
    [pscustomobject]@{ Phase = 'SCCM'; Script = (Join-Path $PSScriptRoot 'sccm\New-SccmBaselineCollections.ps1') },
    [pscustomobject]@{ Phase = 'SCCM'; Script = (Join-Path $PSScriptRoot 'sccm\Test-SccmSiteHealth.ps1') }
)

$selectedPlan = if ($Phase -eq 'All') {
    $plan
}
else {
    $plan | Where-Object { $_.Phase -eq $Phase }
}

Write-InfrastructureAudit -Action 'INFRASTRUCTURE_BOOTSTRAP_PLAN' -Target $Phase -AdditionalData @{
    ManifestPath = $ManifestPath
    EnvironmentName = $manifest.Environment.Name
    StepCount = $selectedPlan.Count
} -LogPath $logPath

if ($ValidateOnly) {
    $selectedPlan | Select-Object Phase, Script
    return
}

foreach ($step in $selectedPlan) {
    if ($PSCmdlet.ShouldProcess($step.Script, 'Invoke infrastructure phase script')) {
        & $step.Script -ManifestPath $ManifestPath -WhatIf:$WhatIfPreference
    }
}