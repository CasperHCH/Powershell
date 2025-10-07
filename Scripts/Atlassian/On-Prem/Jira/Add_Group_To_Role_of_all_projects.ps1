##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed
param(
    [Parameter(Mandatory=$true)]
    [string]$baseurl,
    [Parameter(Mandatory=$true)]
    [string]$username,
    [Parameter(Mandatory=$true)]
    [string]$password,
    [Parameter(Mandatory=$true)]
    [string]$groupName,
    [Parameter(Mandatory=$true)]
    [int]$roleID
)

$data = ConvertTo-Json @{"group" = @($groupName)}
$credentials = "$username`:$password"

Write-Host "Fetching all projects from: $baseurl" -ForegroundColor Yellow
curl --insecure "$baseurl/rest/api/2/project" -H "Content-Type: application/json" -u $credentials | Out-File ".\Projects.json"

$projects = Get-Content ".\Projects.json" | ConvertFrom-Json
Write-Host "Found $($projects.Count) projects. Adding group '$groupName' to role ID '$roleID' for all projects..." -ForegroundColor Green

foreach($p in $projects){
    Write-Host "Processing project: $($p.key) - $($p.name)" -ForegroundColor Cyan
    $apiUrl = "$baseurl/rest/api/2/project/$($p.key)/role/$roleID"
    curl --insecure -i -H "Content-Type: application/json" -X POST -d $data -u $credentials $apiUrl
}
