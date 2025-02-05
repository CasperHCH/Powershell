#Import-module
Import-Module ActiveDirectory
#Set variable for VCF file
$vCardPath = 
#test to see if vcard file already exists
$outputvcard = Test-Path $vCardPath 
If (!$outputvcard){
 #if not then create the file
 $outputvcard = New-Item -Path $vCardPath -ItemType File -Force
}
#get AD users
$ADUsers = Get-ADUser -SearchBase  -Filter {(ObjectClass -eq ) -and (Enabled -eq $true) } -Properties * | Select givenName,SN,Mail,Mobile,OfficePhone 
ForEach ($user in $ADUsers){ 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
 Add-Content -Path $vCardPath -Value 
}
