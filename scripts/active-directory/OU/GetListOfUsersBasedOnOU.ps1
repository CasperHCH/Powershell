param(
    [string]$DistinguishedName,
    [string]$OutputPath
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$DistinguishedName) {
    $DistinguishedName = Read-Host -Prompt 'Please input the DistinguishedName of the desired OU you want to list users from:'
}

try {
    Write-Host "Retrieving users from OU: $DistinguishedName" -ForegroundColor Cyan

    $users = Get-ADUser -SearchBase $DistinguishedName -Filter * | Select-Object Name,SamAccountName,UserPrincipalName

    if ($OutputPath) {
        $users | Export-CSV -NoTypeInformation -Path $OutputPath
        Write-Host "User list exported to: $OutputPath" -ForegroundColor Green
    } else {
        $users | Format-Table -AutoSize
    }

    Write-Host "Total users found: $($users.Count)" -ForegroundColor Green
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
