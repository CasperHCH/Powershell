param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUri,
    [Parameter(Mandatory=$true)]
    [string]$CSVFilePath
)

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
Get-ConfluenceSpace | select Key | export-csv 'C:\users\Caspe\Downloads\AllSpaces.csv' -Delimiter ','

#Collect CSV of spaces to keep
$AllSpaces = import-csv 'C:\users\Caspe\Downloads\AllSpaces.csv'


$SpacesToKeep = @{}
Import-Csv 'C:\users\Caspe\Downloads\confluence-spaces-to-keep.csv' | ForEach-Object {
    $SpacesToKeep[$_.Key] = $true
}

$AllSpaces | Where-Object {
    -not $SpacesToKeep.ContainsKey($_.Key)
} | Export-Csv 'C:\users\Caspe\Downloads\SpacesToDelete.csv' -Delimiter ','

#Delete all spaces listed in
foreach($Space in $SpacesToDelete){

Remove-ConfluenceSpace -SpaceKey $Space -WhatIf

}
