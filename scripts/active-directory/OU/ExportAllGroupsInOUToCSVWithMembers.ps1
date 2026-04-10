<#
.SYNOPSIS
Exports groups in an OU along with their members.

.DESCRIPTION
Creates an output folder structure for each group in the specified OU and writes
group metadata and member display names to text files for review.
#>

# Exports all groups in an OU to separate files for each group with the group name and description.
param(
    [string]$DistinguishedName,
    [string]$OutputPath = "C:\Temp\GroupExports"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$DistinguishedName) {
    $DistinguishedName = Read-Host -Prompt 'Please input the DistinguishedName of the desired OU you want to list users and the group they come from'
}

try {
    $groups = Get-ADGroup -filter * -SearchBase $DistinguishedName
    Write-Information "Found $($groups.Count) groups in OU" -InformationAction Continue

    $PathExist = $OutputPath
    Write-Information "Creating output directory: $PathExist" -InformationAction Continue
    If(!(Test-Path $PathExist)) {
        New-Item -ItemType Directory -Force -Path $PathExist
    }

    ForEach ($g in $groups) {
        Write-Information "Processing group: $($g.Name)" -InformationAction Continue

        $groupDir = Join-Path $PathExist $g.Name
        New-Item -ItemType Directory -Force -Path $groupDir | Out-Null

        $path = Join-Path $groupDir "$($g.Name).txt"

        # Export group info
        Get-ADGroup -Identity $g.Name -Properties * | Select-Object name,description | Out-File $path -Append

        # Export group members
        try {
            $results = Get-ADGroupMember -Identity $g.Name -Recursive | Get-ADUser -Properties displayname, name -ErrorAction SilentlyContinue

            ForEach ($r in $results) {
                "$($r.displayname)" | Out-File $path -Append
            }
            Write-Information "Exported $($results.Count) members for group $($g.Name)" -InformationAction Continue
        } catch {
            "No members found or error accessing members" | Out-File $path -Append
            Write-Warning "Could not retrieve members for group $($g.Name): $($_.Exception.Message)"
        }
    }

    Write-Information "Export completed. Files saved to: $PathExist" -InformationAction Continue
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
