##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed
$baseurl = 
$username = 
$password = 
$data = ConvertTo-Json '{: []}'
$roleID = 


curl --insecure  -H  -u  | out-file .\Projects.json
$projects = Get-Content .\Projects.json | ConvertFrom-Json
foreach($p in $projects){
	#$($p.id)
	curl --insecure -i -H 'Content-Type: application/json' -X POST -d $data -u  
}
