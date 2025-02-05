$credentials = Get-Credential
$computers = , , , , , , , , , , , , , , , , , , 
foreach($c in $computers){
Invoke-Command -FilePath   -ComputerName $c -Credential $credentials
}
