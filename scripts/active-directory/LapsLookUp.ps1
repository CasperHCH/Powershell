param(
    [string]$SearchBase,
    [string]$ComputerName = "*"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (!$SearchBase) {
    $SearchBase = Read-Host "Enter the SearchBase DistinguishedName (or press Enter for entire domain)"
    if (!$SearchBase) {
        $SearchBase = (Get-ADDomain).DistinguishedName
    }
}

try {
    Write-Host "Looking up LAPS passwords for computers in: $SearchBase" -ForegroundColor Cyan

    $filter = if ($ComputerName -eq "*") { "*" } else { "Name -like '$ComputerName'" }

    $computers = Get-ADComputer -Filter $filter -SearchBase $SearchBase -Properties ms-Mcs-Admpwd,ms-Mcs-AdmPwdExpirationTime

    $results = $computers | Select-Object Name,
        @{Name="LAPS Password"; Expression={$_.'ms-Mcs-Admpwd'}},
        @{Name="Password Expiration"; Expression={if($_.'ms-Mcs-AdmPwdExpirationTime'){[DateTime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}else{"Not Set"}}}

    $results | Sort-Object Name | Format-Table -AutoSize

    Write-Host "Total computers found: $($computers.Count)" -ForegroundColor Green
} catch {
    Write-Error "Error: $($_.Exception.Message)"
}
