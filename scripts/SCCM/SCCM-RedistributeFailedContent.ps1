<#
.SYNOPSIS
    Redistributes failed content to one or more distribution points.

.DESCRIPTION
    Accepts content identifiers directly or imports them from the content
    validation detail report, then attempts redistribution using Configuration
    Manager cmdlets. This script supports WhatIf and only executes when the
    required cmdlet is available on the host.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER InputCsvPath
    Path to a CSV file produced by SCCM-ValidateContentDistribution.ps1.

.PARAMETER PackageId
    One or more package identifiers to redistribute.

.PARAMETER DistributionPointName
    One or more distribution point names. When omitted and InputCsvPath is used,
    the DP names are taken from the CSV rows.

.PARAMETER PassThru
    Returns redistribution results as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-RedistributeFailedContent.ps1 -InputCsvPath .\output\SCCM-ContentDistributionDetail.csv

.EXAMPLE
    .\SCCM-RedistributeFailedContent.ps1 -PackageId P0100123 -DistributionPointName dp01.contoso.com -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$InputCsvPath,

    [Parameter(Mandatory = $false)]
    [string[]]$PackageId,

    [Parameter(Mandatory = $false)]
    [string[]]$DistributionPointName,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

$targets = New-Object System.Collections.Generic.List[object]

foreach ($pkg in ConvertTo-SccmArray -InputObject $PackageId) {
    foreach ($dp in ConvertTo-SccmArray -InputObject $DistributionPointName) {
        if (-not [string]::IsNullOrWhiteSpace($pkg) -and -not [string]::IsNullOrWhiteSpace($dp)) {
            [void]$targets.Add([pscustomobject]@{ PackageId = $pkg.Trim(); DistributionPointName = $dp.Trim() })
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($InputCsvPath)) {
    foreach ($row in Import-Csv -Path $InputCsvPath) {
        $resolvedPackageId = [string](Get-SccmObjectPropertyValue -InputObject $row -PropertyNames @('PackageId', 'PackageID'))
        $resolvedDpName = [string](Get-SccmObjectPropertyValue -InputObject $row -PropertyNames @('DistributionPointName', 'ServerNALPath', 'NALPath'))

        if (-not [string]::IsNullOrWhiteSpace($resolvedPackageId) -and -not [string]::IsNullOrWhiteSpace($resolvedDpName)) {
            [void]$targets.Add([pscustomobject]@{ PackageId = $resolvedPackageId.Trim(); DistributionPointName = $resolvedDpName.Trim() })
        }
    }
}

if (@($targets).Count -eq 0) {
    throw 'No redistribution targets were resolved. Provide -PackageId with -DistributionPointName or use -InputCsvPath.'
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $command = Get-Command 'Start-CMContentDistribution' -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw 'Start-CMContentDistribution was not found. Install the Configuration Manager console on this host.'
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($target in $targets) {
        $resolvedPackageId = [string](Get-SccmObjectPropertyValue -InputObject $target -PropertyNames @('PackageId'))
        $resolvedDpName = [string](Get-SccmObjectPropertyValue -InputObject $target -PropertyNames @('DistributionPointName'))
        $status = 'Success'
        $errorMessage = $null

        try {
            if ($PSCmdlet.ShouldProcess($resolvedPackageId, ("Redistribute content to [{0}]" -f $resolvedDpName))) {
                Start-CMContentDistribution -PackageId $resolvedPackageId -DistributionPointName $resolvedDpName -ErrorAction Stop | Out-Null
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
            Write-SccmLog -Level 'ERROR' -Message ("Failed to redistribute package [{0}] to [{1}]: {2}" -f $resolvedPackageId, $resolvedDpName, $errorMessage)
        }

        $result = [pscustomobject]@{
            PackageId             = $resolvedPackageId
            DistributionPointName = $resolvedDpName
            Status                = $status
            Error                 = $errorMessage
            Timestamp             = Get-Date
        }

        [void]$results.Add($result)
        Write-SccmAuditLog -Action 'SCCM_CONTENT_REDISTRIBUTION' -Target $resolvedPackageId -Result $status -ErrorMessage $errorMessage -AdditionalData @{ DistributionPointName = $resolvedDpName }
    }

    if ($PassThru) {
        return $results
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
