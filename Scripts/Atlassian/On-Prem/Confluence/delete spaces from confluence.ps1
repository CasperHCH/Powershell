param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUri,
    [Parameter(Mandatory=$true)]
    [string]$CSVFilePath
)

# Validate CSV file exists
if (-not (Test-Path $CSVFilePath)) {
    Write-Error "CSV file not found: $CSVFilePath"
    exit 1
}

#import modules
try {
    Import-Module ConfluencePS -ErrorAction Stop
} catch {
    Write-Error "ConfluencePS module not found. Install with: Install-Module ConfluencePS"
    exit 1
}

#Variables
if (-not (Test-Path $CSVFilePath)) {
    Write-Error "CSV file not found: $CSVFilePath"
    exit 1
}

#login to confluence with admin
Set-ConfluenceInfo -BaseUri $BaseUri -PromptCredentials

#Get all the spaces
Get-ConfluenceSpace | Select-Object Key | Export-Csv 'C:\users\Caspe\Downloads\AllSpaces.csv' -Delimiter ','

#Collect CSV of spaces to keep
$AllSpaces = import-csv 'C:\users\Caspe\Downloads\AllSpaces.csv'


$SpacesToKeep = @{}
Import-Csv $CSVFilePath | ForEach-Object {
    $SpacesToKeep[$_.Key] = $true
}

$AllSpaces | Where-Object {
    -not $SpacesToKeep.ContainsKey($_.Key)
} | Export-Csv 'C:\users\Caspe\Downloads\SpacesToDelete.csv' -Delimiter ','

#Delete all spaces listed in
foreach($Space in $SpacesToDelete){

Remove-ConfluenceSpace -SpaceKey $Space -WhatIf

}
