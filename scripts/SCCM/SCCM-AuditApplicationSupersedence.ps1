<#
.SYNOPSIS
    Audits multi-version application families for supersedence gaps.

.DESCRIPTION
    Reviews application families that appear to contain multiple versions and
    highlights whether deployment type metadata exposes any supersedence-related
    properties. The report is intended to identify families that likely need a
    manual supersedence review before consolidation or cleanup.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER ApplicationName
    Optional application name filter.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns supersedence audit rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-AuditApplicationSupersedence.ps1 -ApplicationName Firefox
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru,

    [Parameter(Mandatory = $false)]
    [switch]$EnableDebugLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\SCCM-Common.ps1"

$null = Initialize-SccmScript -ScriptName $MyInvocation.MyCommand.Name -EnableDebugLog:$EnableDebugLog

function Get-ApplicationFamilyName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $normalized = $Name.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '\b(v)?\d+(\.\d+){0,3}\b', '')
    $normalized = [regex]::Replace($normalized, '\s+', ' ')
    return $normalized.Trim()
}

function Get-ApplicationVersionValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Application
    )

    $versionText = [string](Get-SccmObjectPropertyValue -InputObject $Application -PropertyNames @('SoftwareVersion', 'Version'))
    if ([string]::IsNullOrWhiteSpace($versionText)) {
        $displayName = [string](Get-SccmObjectPropertyValue -InputObject $Application -PropertyNames @('LocalizedDisplayName', 'DisplayName', 'Name'))
        $match = [regex]::Match($displayName, '\b(v)?\d+(\.\d+){0,3}\b')
        if ($match.Success) {
            $versionText = $match.Value.TrimStart('v', 'V')
        }
    }

    return $versionText
}

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $applications = if ([string]::IsNullOrWhiteSpace($ApplicationName)) {
        @(Get-CMApplication -Fast -ErrorAction SilentlyContinue)
    }
    else {
        @(Get-CMApplication -Name "*$ApplicationName*" -Fast -ErrorAction SilentlyContinue)
    }

    $deploymentTypeCommand = Get-Command 'Get-CMDeploymentType' -ErrorAction SilentlyContinue
    $results = New-Object System.Collections.Generic.List[object]

    $familyGroups = @($applications | Group-Object { Get-ApplicationFamilyName -Name ([string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('LocalizedDisplayName', 'DisplayName', 'Name'))) })

    foreach ($familyGroup in $familyGroups) {
        $groupRows = @($familyGroup.Group)
        if ($groupRows.Count -lt 2) {
            continue
        }

        $sortedRows = @($groupRows | Sort-Object {
            [string](Get-ApplicationVersionValue -Application $_)
        })

        foreach ($application in $sortedRows) {
            $applicationNameValue = [string](Get-SccmObjectPropertyValue -InputObject $application -PropertyNames @('LocalizedDisplayName', 'DisplayName', 'Name'))
            $applicationId = [string](Get-SccmObjectPropertyValue -InputObject $application -PropertyNames @('CI_ID', 'Id'))
            $versionValue = [string](Get-ApplicationVersionValue -Application $application)
            $supersedenceSignals = New-Object System.Collections.Generic.List[string]

            if ($deploymentTypeCommand) {
                try {
                    $deploymentTypes = @(Get-CMDeploymentType -InputObject $application -ErrorAction SilentlyContinue)
                    foreach ($deploymentType in $deploymentTypes) {
                        foreach ($property in $deploymentType.PSObject.Properties) {
                            if ($property.Name -match 'supersed') {
                                $propertyValue = [string]$property.Value
                                if (-not [string]::IsNullOrWhiteSpace($propertyValue)) {
                                    [void]$supersedenceSignals.Add(("{0}={1}" -f $property.Name, $propertyValue))
                                }
                            }
                        }
                    }
                }
                catch {
                    Write-SccmLog -Level 'DEBUG' -Message ("Deployment type query failed for [{0}]: {1}" -f $applicationNameValue, $_.Exception.Message)
                }
            }

            [void]$results.Add([pscustomobject]@{
                FamilyName            = $familyGroup.Name
                ApplicationName       = $applicationNameValue
                ApplicationId         = $applicationId
                Version               = $versionValue
                FamilyVersionCount    = $sortedRows.Count
                SupersedenceSignalCount = @($supersedenceSignals).Count
                SupersedenceSignals   = ($supersedenceSignals -join ' | ')
                AuditStatus           = if (@($supersedenceSignals).Count -gt 0) { 'SignalsPresent' } else { 'NeedsReview' }
            })
        }
    }

    $timestamp = Get-SccmTimestampString
    $reportPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-ApplicationSupersedenceAudit-{0}.csv" -f $timestamp)
    $null = Export-SccmData -InputObject ($results | Sort-Object FamilyName, Version) -Path $reportPath -Format 'Csv'

    Write-SccmLog -Level 'SUCCESS' -Message ("Application supersedence audit exported to [{0}]." -f $reportPath)
    Write-SccmAuditLog -Action 'SCCM_APPLICATION_SUPERSEDENCE_AUDIT' -Result 'Success' -AdditionalData @{ ResultCount = @($results).Count }

    if ($PassThru) {
        return @($results)
    }
}
finally {
    try {
        Disconnect-SccmSite -ConnectionContext $connectionContext
    } catch {
        $cleanupMsg = $_.Exception.Message
        if ($cleanupMsg -match 'Argument types do not match') {
            Write-SccmLog -Level 'DEBUG' -Message ("Disconnect-SccmSite cleanup quirk: {0}" -f $cleanupMsg)
        } else {
            Write-SccmLog -Level 'WARN' -Message ("Disconnect-SccmSite cleanup failed: {0}" -f $cleanupMsg)
        }
    }
}
