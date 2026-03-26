<#
.SYNOPSIS
    Audits SCCM boundary groups, boundaries, and site systems.

.DESCRIPTION
    Builds a read-only audit of boundary groups using provider WMI classes.
    The report flags groups with no boundaries, no site systems, or incomplete
    configuration evidence so operators can review content-location and site
    assignment coverage.

.PARAMETER SiteCode
    SCCM site code. If omitted, the script attempts auto-detection.

.PARAMETER OutputDirectory
    Directory used for report output.

.PARAMETER PassThru
    Returns summary rows as objects.

.PARAMETER EnableDebugLog
    Enables DEBUG log output.

.EXAMPLE
    .\SCCM-BoundaryGroupAudit.ps1 -SiteCode P01
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false)]
    [string]$SiteCode,

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

$connectionContext = $null

try {
    $connectionContext = Connect-SccmSite -SiteCode $SiteCode
    $resolvedSiteCode = [string](Get-SccmObjectPropertyValue -InputObject $connectionContext -PropertyNames @('SiteCode'))
    $namespace = "root/SMS/site_$resolvedSiteCode"

    $groups = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_BoundaryGroup' -ErrorAction Stop)
    $members = @()
    $siteSystems = @()

    try {
        $members = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_BoundaryGroupMembers' -ErrorAction Stop)
    }
    catch {
        Write-SccmLog -Level 'DEBUG' -Message ("Boundary member query failed: {0}" -f $_.Exception.Message)
    }

    try {
        $siteSystems = @(Get-CimInstance -Namespace $namespace -ClassName 'SMS_BoundaryGroupSiteSystems' -ErrorAction Stop)
    }
    catch {
        Write-SccmLog -Level 'DEBUG' -Message ("Boundary site system query failed: {0}" -f $_.Exception.Message)
    }

    $summaryRows = @($groups | ForEach-Object {
        $groupId = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId'))
        $groupName = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Name', 'DisplayName'))
        $groupMembers = @($members | Where-Object {
            [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId')) -eq $groupId
        })
        $groupSiteSystems = @($siteSystems | Where-Object {
            [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId')) -eq $groupId
        })

        $issues = New-Object System.Collections.Generic.List[string]
        if ($groupMembers.Count -eq 0) {
            [void]$issues.Add('Boundary group has no boundaries.')
        }
        if ($groupSiteSystems.Count -eq 0) {
            [void]$issues.Add('Boundary group has no linked site systems.')
        }

        [pscustomobject]@{
            BoundaryGroupId   = $groupId
            BoundaryGroupName = $groupName
            BoundaryCount     = $groupMembers.Count
            SiteSystemCount   = $groupSiteSystems.Count
            IssueCount        = @($issues).Count
            Issues            = ($issues -join ' | ')
        }
    })

    $detailRows = @($siteSystems | ForEach-Object {
        [pscustomobject]@{
            BoundaryGroupId    = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupID', 'GroupId', 'BoundaryGroupID', 'BoundaryGroupId'))
            BoundaryGroupName  = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('GroupName', 'BoundaryGroupName', 'Name'))
            SiteSystem         = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('ServerName', 'NALPath', 'SiteSystem'))
            Role               = [string](Get-SccmObjectPropertyValue -InputObject $_ -PropertyNames @('Role', 'SiteSystemRole'))
        }
    })

    $timestamp = Get-SccmTimestampString
    $summaryPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-BoundaryGroupAuditSummary-{0}.csv" -f $timestamp)
    $detailPath = Resolve-SccmOutputPath -OutputDirectory $OutputDirectory -CreateDirectory -FileName ("SCCM-BoundaryGroupAuditDetail-{0}.csv" -f $timestamp)

    $null = Export-SccmData -InputObject ($summaryRows | Sort-Object IssueCount -Descending, BoundaryGroupName) -Path $summaryPath -Format 'Csv'
    if (@($detailRows).Count -gt 0) {
        $null = Export-SccmData -InputObject ($detailRows | Sort-Object BoundaryGroupName, SiteSystem) -Path $detailPath -Format 'Csv'
    }

    Write-SccmLog -Level 'SUCCESS' -Message ("Boundary group summary exported to [{0}]." -f $summaryPath)
    Write-SccmAuditLog -Action 'SCCM_BOUNDARY_GROUP_AUDIT' -Result 'Success' -AdditionalData @{ SummaryRows = @($summaryRows).Count; DetailRows = @($detailRows).Count }

    if ($PassThru) {
        return $summaryRows
    }
}
finally {
    Disconnect-SccmSite -ConnectionContext $connectionContext
}
