<#
.SYNOPSIS
    Prepares and validates SCCM prerequisite installation inputs from a manifest.

.DESCRIPTION
    This scaffold validates Configuration Manager prerequisite assumptions and logs
    the intended site server and SQL dependency model.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.EXAMPLE
    .\Install-SccmPrereqs.ps1 -ManifestPath ..\config\Environment.lab.psd1 -WhatIf
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
$checks.Add((Test-InfrastructurePrerequisite -Name 'Site server defined' -Test { -not [string]::IsNullOrWhiteSpace($manifest.SCCM.SiteServer) }))
$checks.Add((Test-InfrastructurePrerequisite -Name 'SQL server defined' -Test { -not [string]::IsNullOrWhiteSpace($manifest.SCCM.SqlServer) }))
$checks.Add((Test-InfrastructurePrerequisite -Name 'Site code length valid' -Test { $manifest.SCCM.SiteCode.Length -eq 3 }))

$checkArray = [object[]]$checks.ToArray()

if (@($checkArray | Where-Object { -not $_.Passed }).Count -gt 0) {
    $checkArray
    throw 'SCCM prerequisite validation failed.'
}

Write-InfrastructureAudit -Action 'SCCM_PREREQS_PREVIEW' -Target $manifest.SCCM.SiteServer -AdditionalData @{
    SiteCode = $manifest.SCCM.SiteCode
    SqlServer = $manifest.SCCM.SqlServer
    Roles = $manifest.SCCM.Roles
} -LogPath $logPath

if ($PSCmdlet.ShouldProcess($manifest.SCCM.SiteServer, 'Prepare SCCM prerequisite workflow')) {
    @{
        PlannedAction = 'Install SCCM prerequisites'
        SiteServer = $manifest.SCCM.SiteServer
        SiteCode = $manifest.SCCM.SiteCode
        SqlServer = $manifest.SCCM.SqlServer
        Roles = ($manifest.SCCM.Roles -join ', ')
        Status = 'Scaffold only - implement prerequisite installation steps next'
        Checks = $checkArray
    }
}