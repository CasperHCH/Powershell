<#
.SYNOPSIS
    Performs baseline PKI health validation from a manifest.

.DESCRIPTION
    This scaffold checks for certutil and AD CS tooling presence and returns a
    structured summary for later CRL, AIA, and service-state expansion.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.EXAMPLE
    .\Test-PkiHealth.ps1 -ManifestPath ..\config\Environment.lab.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$checks = New-Object 'System.Collections.Generic.List[object]'
$checks.Add((Test-InfrastructurePrerequisite -Name 'certutil available' -Test { [bool](Get-Command -Name certutil.exe -ErrorAction SilentlyContinue) }))
$checks.Add((Test-InfrastructurePrerequisite -Name 'AD CS install command available' -Test { [bool](Get-Command -Name Install-AdcsCertificationAuthority -ErrorAction SilentlyContinue) } -Severity 'Warning'))
$checks.Add((Test-InfrastructurePrerequisite -Name 'Issuing CA common name defined' -Test { -not [string]::IsNullOrWhiteSpace($manifest.PKI.IssuingCACommonName) }))

$checkArray = [object[]]$checks.ToArray()

@{
    Environment = $manifest.Environment.Name
    IssuingCACommonName = $manifest.PKI.IssuingCACommonName
    TotalChecks = $checkArray.Count
    PassedChecks = @($checkArray | Where-Object Passed).Count
    FailedChecks = @($checkArray | Where-Object { -not $_.Passed }).Count
    Checks = $checkArray
}