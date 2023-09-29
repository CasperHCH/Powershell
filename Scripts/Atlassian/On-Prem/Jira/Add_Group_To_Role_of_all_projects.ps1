##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed

$data = ConvertTo-Json '{"group": ["GroupNameHere"]}'


curl --insecure https://BaseURL//rest/api/latest/project -H "Accept: application/json" -u "username:password" | out-file .\Projects.json
$projects = Get-Content .\Projects.json | ConvertFrom-Json
foreach($p in $projects){
	#$($p.id)
	curl --insecure -i -H 'Content-Type: application/json' -X POST -d $data -u "username:password" https://BaseURL/rest/api/2/project/$($p.id)/role/<RoleID>
}