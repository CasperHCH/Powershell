<#
.SYNOPSIS
    Creates or validates baseline Active Directory GPOs from the infrastructure manifest.

.DESCRIPTION
    This script reads GpoBaselines entries from the ActiveDirectory section of the
    manifest, validates whether each GPO exists, and checks whether the expected
    target link is present. Use -ValidateOnly to review the plan without making changes.

.PARAMETER ManifestPath
    Path to the infrastructure manifest PSD1 file.

.PARAMETER ValidateOnly
    Return the GPO plan and preflight results without creating GPOs or links.

.EXAMPLE
    .\New-ADBaselineGpos.ps1 -ManifestPath ..\config\Environment.lab.psd1 -ValidateOnly
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
$gpoBaselines = @($manifest.ActiveDirectory.GpoBaselines)
$checks = New-Object 'System.Collections.Generic.List[object]'
$existingEntries = New-Object 'System.Collections.Generic.List[object]'
$missingEntries = New-Object 'System.Collections.Generic.List[object]'
$pendingLinks = New-Object 'System.Collections.Generic.List[object]'
$groupPolicyCmdletsAvailable = [bool](Get-Command -Name Get-GPO -ErrorAction SilentlyContinue)

$checks.Add((New-InfrastructureCheckResult -Name 'Group Policy cmdlets available' -Passed $groupPolicyCmdletsAvailable -Severity 'Error' -Details 'Get-GPO, New-GPO, and New-GPLink are required.'))
$checks.Add((New-InfrastructureCheckResult -Name 'GPO baseline definitions present in manifest' -Passed (@($gpoBaselines).Count -gt 0) -Severity 'Error' -Details 'ActiveDirectory.GpoBaselines must contain one or more GPO entries.'))

foreach ($entry in $gpoBaselines) {
    $hashtableEntry = $entry -is [hashtable]
    $name = if ($hashtableEntry -and $entry.ContainsKey('Name')) { $entry.Name } else { $null }
    $targetPath = if ($hashtableEntry -and $entry.ContainsKey('TargetPath')) { $entry.TargetPath } else { $null }
    $checks.Add((New-InfrastructureCheckResult -Name 'GPO entry has name' -Passed (-not [string]::IsNullOrWhiteSpace($name)) -Severity 'Error' -Target $targetPath -Details 'Each GPO entry must define Name.'))
    $checks.Add((New-InfrastructureCheckResult -Name 'GPO entry has target path' -Passed (-not [string]::IsNullOrWhiteSpace($targetPath)) -Severity 'Error' -Target $name -Details 'Each GPO entry must define TargetPath.'))
}

$failedChecks = @($checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' })

if ($failedChecks.Count -eq 0 -and $groupPolicyCmdletsAvailable) {
    foreach ($entry in $gpoBaselines) {
        try {
            $gpo = Get-GPO -Name $entry.Name -ErrorAction Stop
            $existingEntries.Add([pscustomobject]@{
                Name = $entry.Name
                Id = $gpo.Id.Guid
                TargetPath = $entry.TargetPath
                Status = 'Exists'
            })

            try {
                $inheritance = Get-GPInheritance -Target $entry.TargetPath -ErrorAction Stop
                $linkedNames = @($inheritance.GpoLinks | ForEach-Object { $_.DisplayName })
                if ($entry.Name -notin $linkedNames) {
                    $pendingLinks.Add([pscustomobject]@{
                        Name = $entry.Name
                        TargetPath = $entry.TargetPath
                        Description = if ($entry.ContainsKey('Description')) { $entry.Description } else { $null }
                        Status = 'MissingLink'
                    })
                }
            }
            catch {
                $pendingLinks.Add([pscustomobject]@{
                    Name = $entry.Name
                    TargetPath = $entry.TargetPath
                    Description = if ($entry.ContainsKey('Description')) { $entry.Description } else { $null }
                    Status = 'MissingLink'
                })
            }
        }
        catch {
            $missingEntries.Add([pscustomobject]@{
                Name = $entry.Name
                TargetPath = $entry.TargetPath
                Description = if ($entry.ContainsKey('Description')) { $entry.Description } else { $null }
                Status = 'MissingGpo'
            })
        }
    }
}

$summary = @{
    PlannedAction = 'Create baseline Active Directory GPOs'
    ValidationStatus = if ($failedChecks.Count -gt 0) { 'Failed' } elseif ($missingEntries.Count -gt 0 -or $pendingLinks.Count -gt 0) { 'PendingChanges' } else { 'Ready' }
    ExistingGpos = [object[]]$existingEntries.ToArray()
    MissingGpos = [object[]]$missingEntries.ToArray()
    MissingLinks = [object[]]$pendingLinks.ToArray()
    Checks = [object[]]$checks.ToArray()
}

Write-InfrastructureAudit -Action 'AD_BASELINE_GPO_PLAN' -Target $manifest.Organization.Domain -AdditionalData @{
    ValidationStatus = $summary.ValidationStatus
    ExistingGpos = $existingEntries.Count
    MissingGpos = $missingEntries.Count
    MissingLinks = $pendingLinks.Count
} -LogPath $scriptLogPath

if ($ValidateOnly -or $failedChecks.Count -gt 0) {
    $summary
    if ($failedChecks.Count -gt 0 -and -not $ValidateOnly) {
        throw 'Active Directory GPO baseline validation failed.'
    }
    return
}

foreach ($entry in @($missingEntries.ToArray())) {
    if ($PSCmdlet.ShouldProcess($entry.Name, 'Create Group Policy Object')) {
        $newGpoParams = @{
            Name = $entry.Name
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($entry.Description)) {
            $newGpoParams['Comment'] = $entry.Description
        }

        $createdGpo = New-GPO @newGpoParams
        $existingEntries.Add([pscustomobject]@{
            Name = $entry.Name
            Id = $createdGpo.Id.Guid
            TargetPath = $entry.TargetPath
            Status = 'Created'
        })

        $pendingLinks.Add([pscustomobject]@{
            Name = $entry.Name
            TargetPath = $entry.TargetPath
            Description = $entry.Description
            Status = 'MissingLink'
        })
    }
}

foreach ($entry in @($pendingLinks.ToArray())) {
    if ($PSCmdlet.ShouldProcess($entry.TargetPath, "Link GPO '$($entry.Name)'")) {
        New-GPLink -Name $entry.Name -Target $entry.TargetPath -ErrorAction Stop | Out-Null
    }
}

@{
    PlannedAction = $summary.PlannedAction
    ValidationStatus = 'Completed'
    ExistingOrCreatedGpos = [object[]]$existingEntries.ToArray()
    Checks = [object[]]$checks.ToArray()
}