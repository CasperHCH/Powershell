<#
.SYNOPSIS
    Creates or validates baseline Active Directory OUs from the infrastructure manifest.

.DESCRIPTION
    This script reads OrganizationalUnits entries from the ActiveDirectory section of the
    manifest and creates any missing OUs in order. Use -ValidateOnly to review the plan
    without making changes.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER ValidateOnly
    Return the OU plan and preflight results without creating OUs.

.EXAMPLE
    .\New-ADBaselineOUs.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly
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
$organizationalUnits = @($manifest.ActiveDirectory.OrganizationalUnits)
$newEntries = New-Object 'System.Collections.Generic.List[object]'
$existingEntries = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$adModuleAvailable = [bool](Get-Command -Name Get-ADOrganizationalUnit -ErrorAction SilentlyContinue)

$checks.Add((New-InfrastructureCheckResult -Name 'Active Directory OU cmdlets available' -Passed $adModuleAvailable -Severity 'Error' -Details 'Get-ADOrganizationalUnit and New-ADOrganizationalUnit are required.'))
$checks.Add((New-InfrastructureCheckResult -Name 'OU definitions present in manifest' -Passed (@($organizationalUnits).Count -gt 0) -Severity 'Error' -Details 'ActiveDirectory.OrganizationalUnits must contain one or more OU entries.'))

foreach ($entry in $organizationalUnits) {
    $hashtableEntry = $entry -is [hashtable]
    $name = if ($hashtableEntry -and $entry.ContainsKey('Name')) { $entry.Name } else { $null }
    $path = if ($hashtableEntry -and $entry.ContainsKey('Path')) { $entry.Path } else { $null }
    $checks.Add((New-InfrastructureCheckResult -Name 'OU entry has name' -Passed (-not [string]::IsNullOrWhiteSpace($name)) -Severity 'Error' -Target $path -Details 'Each OU entry must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'OU entry has parent path' -Passed (-not [string]::IsNullOrWhiteSpace($path)) -Severity 'Error' -Target $name -Details 'Each OU entry must define Path.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $adModuleAvailable) {
    foreach ($entry in $organizationalUnits) {
        $targetDn = "OU=$($entry.Name),$($entry.Path)"
        try {
            $existingOu = Get-ADOrganizationalUnit -Identity $targetDn -ErrorAction Stop
            $existingEntries.Add([pscustomobject]@{
                Name = $entry.Name
                DistinguishedName = $existingOu.DistinguishedName
                Status = 'Exists'
            })
        }
        catch {
            $newEntries.Add([pscustomobject]@{
                Name = $entry.Name
                Path = $entry.Path
                DistinguishedName = $targetDn
                Description = $entry.Description
                ProtectedFromAccidentalDeletion = if ($entry.ContainsKey('ProtectedFromAccidentalDeletion')) { [bool]$entry.ProtectedFromAccidentalDeletion } else { $true }
                Status = 'Missing'
            })
        }
    }
}

$summary = @{
    PlannedAction = 'Create baseline Active Directory OUs'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($newEntries.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingOUs = [object[]]$existingEntries.ToArray()
    MissingOUs = [object[]]$newEntries.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'AD_BASELINE_OU_PLAN' -Target $manifest.Organization.Domain -AdditionalData @{
    ValidationStatus = $summary.ValidationStatus
    ExistingOUs = $existingEntries.Count
    MissingOUs = $newEntries.Count
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    $summary
    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'Active Directory OU baseline validation failed.'
    }
    return
}

foreach ($entry in @($newEntries.ToArray())) {
    if ($PSCmdlet.ShouldProcess($entry.DistinguishedName, 'Create organizational unit')) {
        $newOuParams = @{
            Name = $entry.Name
            Path = $entry.Path
            ProtectedFromAccidentalDeletion = $entry.ProtectedFromAccidentalDeletion
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($entry.Description)) {
            $newOuParams['Description'] = $entry.Description
        }

        $createdOu = New-ADOrganizationalUnit @newOuParams
        $existingEntries.Add([pscustomobject]@{
            Name = $entry.Name
            DistinguishedName = $createdOu.DistinguishedName
            Status = 'Created'
        })
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    CreatedOrExistingOUs = [object[]]$existingEntries.ToArray()
    Checks = [object[]]$checks.ToArray()
}