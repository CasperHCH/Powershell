#import modules
Import-Module ConfluencePS

#Variables
$CSVFilePath = 'C:\users\Caspe\Downloads\confluence-spaces-to-keep.csv'

#login to confluence with admin
Set-ConfluenceInfo -BaseURi 'https://confluence.miracle.dk' -PromptCredentials

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
