<#
.SYNOPSIS
    Creates or validates baseline Active Directory groups from the infrastructure manifest.

.DESCRIPTION
    This script reads BaselineGroups entries from the ActiveDirectory section of the
    manifest and creates any missing groups. Use -ValidateOnly to review the plan without
    making changes.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER ValidateOnly
    Return the group plan and preflight results without creating groups.

.EXAMPLE
    .\New-ADBaselineGroups.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ })]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest

. (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Infrastructure-Common.ps1')

$scriptLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'ScriptAudit.log'
$manifest = Import-InfrastructureManifest -ManifestPath $ManifestPath
$baselineGroups = @($manifest.ActiveDirectory.BaselineGroups)
$newEntries = New-Object 'System.Collections.Generic.List[object]'
$existingEntries = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$groupCmdletsAvailable = [bool](Get-Command -Name Get-ADGroup -ErrorAction SilentlyContinue)

$checks.Add((New-InfrastructureCheckResult -Name 'Active Directory group cmdlets available' -Passed $groupCmdletsAvailable -Severity 'Error' -Details 'Get-ADGroup and New-ADGroup are required.'))
$checks.Add((New-InfrastructureCheckResult -Name 'Group definitions present in manifest' -Passed (@($baselineGroups).Count -gt 0) -Severity 'Error' -Details 'ActiveDirectory.BaselineGroups must contain one or more group entries.'))

foreach ($entry in $baselineGroups) {
    $hashtableEntry = $entry -is [hashtable]
    $name = if ($hashtableEntry -and $entry.ContainsKey('Name')) { $entry.Name } else { $null }
    $path = if ($hashtableEntry -and $entry.ContainsKey('Path')) { $entry.Path } else { $null }
    $scope = if ($hashtableEntry -and $entry.ContainsKey('GroupScope')) { $entry.GroupScope } else { $null }
    $category = if ($hashtableEntry -and $entry.ContainsKey('GroupCategory')) { $entry.GroupCategory } else { $null }

    $checks.Add((New-InfrastructureCheckResult -Name 'Group entry has name' -Passed (-not [string]::IsNullOrWhiteSpace($name)) -Severity 'Error' -Target $path -Details 'Each group entry must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Group entry has path' -Passed (-not [string]::IsNullOrWhiteSpace($path)) -Severity 'Error' -Target $name -Details 'Each group entry must define Path.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Group entry has scope' -Passed ($scope -in @('DomainLocal', 'Global', 'Universal')) -Severity 'Error' -Target $name -Details 'Each group entry must define GroupScope as DomainLocal, Global, or Universal.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'Group entry has category' -Passed ($category -in @('Distribution', 'Security')) -Severity 'Error' -Target $name -Details 'Each group entry must define GroupCategory as Security or Distribution.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $groupCmdletsAvailable) {
    foreach ($entry in $baselineGroups) {
        $targetDn = "CN=$($entry.Name),$($entry.Path)"
        try {
            $existingGroup = Get-ADGroup -Identity $targetDn -ErrorAction Stop
            $existingEntries.Add([pscustomobject]@{
                Name = $entry.Name
                DistinguishedName = $existingGroup.DistinguishedName
                Status = 'Exists'
            })
        }
        catch {
            $newEntries.Add([pscustomobject]@{
                Name = $entry.Name
                SamAccountName = if ($entry.ContainsKey('SamAccountName')) { $entry.SamAccountName } else { $entry.Name }
                Path = $entry.Path
                DistinguishedName = $targetDn
                GroupScope = $entry.GroupScope
                GroupCategory = $entry.GroupCategory
                Description = if ($entry.ContainsKey('Description')) { $entry.Description } else { $null }
                ManagedBy = if ($entry.ContainsKey('ManagedBy')) { $entry.ManagedBy } else { $null }
                Status = 'Missing'
            })
        }
    }
}

$summary = @{
    PlannedAction = 'Create baseline Active Directory groups'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($newEntries.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingGroups = [object[]]$existingEntries.ToArray()
    MissingGroups = [object[]]$newEntries.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'AD_BASELINE_GROUP_PLAN' -Target $manifest.Organization.Domain -AdditionalData @{
    ValidationStatus = $summary.ValidationStatus
    ExistingGroups = $existingEntries.Count
    MissingGroups = $newEntries.Count
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    $summary
    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'Active Directory group baseline validation failed.'
    }
    return
}

foreach ($entry in @($newEntries.ToArray())) {
    if ($PSCmdlet.ShouldProcess($entry.DistinguishedName, 'Create Active Directory group')) {
        $newGroupParams = @{
            Name = $entry.Name
            SamAccountName = $entry.SamAccountName
            Path = $entry.Path
            GroupScope = $entry.GroupScope
            GroupCategory = $entry.GroupCategory
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($entry.Description)) {
            $newGroupParams['Description'] = $entry.Description
        }

        $createdGroup = New-ADGroup @newGroupParams -PassThru

        if (-not [string]::IsNullOrWhiteSpace($entry.ManagedBy)) {
            Set-ADGroup -Identity $createdGroup.DistinguishedName -ManagedBy $entry.ManagedBy -ErrorAction Stop
        }

        $existingEntries.Add([pscustomobject]@{
            Name = $entry.Name
            DistinguishedName = $createdGroup.DistinguishedName
            Status = 'Created'
        })
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    CreatedOrExistingGroups = [object[]]$existingEntries.ToArray()
    Checks = [object[]]$checks.ToArray()
}