<#
.SYNOPSIS
    Prepares and validates an issuing CA deployment workflow from a manifest.

.DESCRIPTION
    This scaffold validates AD CS prerequisites and records the intended issuing CA
    deployment details for future implementation.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.EXAMPLE
    .\Install-IssuingCA.ps1 -ManifestPath ..\config\Environment.lab.psd1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$logPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath

$checks = New-Object 'System.Collections.Generic.List[object]'
$checks.Add((Test-InfrastructurePrerequisite -Name 'AD CS install command available' -Test { [bool](Get-Command -Name Install-AdcsCertificationAuthority -ErrorAction SilentlyContinue) }))
$checks.Add((Test-InfrastructurePrerequisite -Name 'Elevated session' -Test { Test-InfrastructureAdministrator }))
$checks.Add((Test-InfrastructurePrerequisite -Name 'Issuing CA common name defined' -Test { -not [string]::IsNullOrWhiteSpace($manifest.PKI.IssuingCACommonName) }))

$checkArray = [object[]]$checks.ToArray()

if (@($checkArray | Where-Object { -not $_.Passed }).Count -gt 0) {
    $checkArray
    throw 'PKI build prerequisites failed.'
}

Write-InfrastructureAudit -Action 'PKI_ISSUING_CA_PREVIEW' -Target $manifest.PKI.IssuingCACommonName -AdditionalData @{
    CdpUrl = $manifest.PKI.CdpUrl
    AiaUrl = $manifest.PKI.AiaUrl
} -LogPath $logPath

if ($PSCmdlet.ShouldProcess($manifest.PKI.IssuingCACommonName, 'Prepare issuing CA workflow')) {
    @{
        PlannedAction = 'Install issuing CA'
        IssuingCACommonName = $manifest.PKI.IssuingCACommonName
        CdpUrl = $manifest.PKI.CdpUrl
        AiaUrl = $manifest.PKI.AiaUrl
        Status = 'Scaffold only - implement AD CS configuration steps next'
        Checks = $checkArray
    }
}