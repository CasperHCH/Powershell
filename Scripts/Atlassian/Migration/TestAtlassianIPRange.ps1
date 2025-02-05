$range = Invoke-RestMethod https://ip-ranges.atlassian.com
foreach($r in $range.items.network){ 
if(Test-Connection $r -count 1 -quiet -ErrorAction SilentlyContinue){Write-Host  -ForegroundColor green}
else{write-host   -ForegroundColor red}
}
