#Import-module
Import-Module ActiveDirectory
#Set variable for VCF file
$vCardPath = "C:\temp\mobile.vcf"
#test to see if vcard file already exists
$outputvcard = Test-Path $vCardPath 
If (!$outputvcard){
 #if not then create the file
 $outputvcard = New-Item -Path $vCardPath -ItemType File -Force
}
#get AD users
$ADUsers = Get-ADUser -SearchBase "OU=My users,DC=domain,DC=com" -Filter {(ObjectClass -eq "User") -and (Enabled -eq $true) } -Properties * | Select givenName,SN,Mail,Mobile,OfficePhone 
ForEach ($user in $ADUsers){ 
 Add-Content -Path $vCardPath -Value "BEGIN:VCARD"
 Add-Content -Path $vCardPath -Value "VERSION:2.1"
 Add-Content -Path $vCardPath -Value "N:$($user.SN);$($user.givenName)"
 Add-Content -Path $vCardPath -Value "FN:$($user.givenName) $($user.SN)"
 Add-Content -Path $vCardPath -Value "ORG:Company name here"
 Add-Content -Path $vCardPath -Value "TEL;WORK;VOICE:$($user.Mobile)"
 Add-Content -Path $vCardPath -Value "TEL;HOME;VOICE:$($user.OfficePhone)"
 Add-Content -Path $vCardPath -Value "ADR;WORK;PREF:Street Address here;Postcode;City;UK"
 Add-Content -Path $vCardPath -Value "EMAIL;PREF;INTERNET:$($user.Mail)"
 Add-Content -Path $vCardPath -Value "END:VCARD"
}