<#
.SYNOPSIS
Lists Active Directory groups and their members for a given search base.

.DESCRIPTION
Retrieves all groups from the supplied OU or container, includes group metadata
and flattened member data, and optionally exports the results to CSV.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SearchBase,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not $SearchBase) {
    $SearchBase = Read-Host -Prompt 'Enter the DistinguishedName of the OU or container to search for groups'
}

$groups = Get-ADGroup -Filter * -SearchBase $SearchBase -Properties Members |
    Sort-Object Name |
    Select-Object Name, DistinguishedName, GroupCategory, GroupScope,
        @{ Name = 'MemberCount'; Expression = { @($_.Members).Count } },
        @{ Name = 'Members'; Expression = { ($_.Members -join '; ') } }

if ($OutputPath) {
    $groups | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Information "Exported $($groups.Count) group records to $OutputPath" -InformationAction Continue
}
else {
    $groups
}
