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
    Write-Host "Found $($groups.Count) groups in OU" -ForegroundColor Green

    $PathExist = $OutputPath
    Write-Host "Creating output directory: $PathExist" -ForegroundColor Cyan
    If(!(Test-Path $PathExist)) {
        New-Item -ItemType Directory -Force -Path $PathExist
    }

    ForEach ($g in $groups) {
        Write-Host "Processing group: $($g.Name)" -ForegroundColor Yellow

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
            Write-Host "Exported $($results.Count) members for group $($g.Name)" -ForegroundColor Green
        } catch {
            "No members found or error accessing members" | Out-File $path -Append
            Write-Warning "Could not retrieve members for group $($g.Name): $($_.Exception.Message)"
        }
    }

    Write-Host "Export completed. Files saved to: $PathExist" -ForegroundColor Green
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
