 $Uris = "https://atl-paas.net","https://atlassian.com","https://atlassian.net","https://jira.com","https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net","https://jira-frontend-static.prod.public.atl-paas.net","https://id.atlassian.com","https://atlassian.com"
 $uriList = @()
    
   foreach ($uri in $Uris) {
     $uriObject = New-Object PSObject
     $Response = ""
     try {
     $Response = Invoke-WebRequest -Uri $uri -ErrorAction SilentlyContinue -UseBasicParsing -DisableKeepAlive
     $uriObject | Add-Member -MemberType NoteProperty -Name "URL" -Value $Response.BaseResponse.ResponseUri
     $uriObject | Add-Member -MemberType NoteProperty -Name "Status" -Value $Response.StatusCode
     $uriObject | Add-Member -MemberType NoteProperty -Name "Description" -Value $Response.StatusDescription
     Write-Host $Response.StatusCode $Response.StatusDescription $Response.BaseResponse.ResponseUri -ForegroundColor Green
     $uriList += $uriObject
   }
   catch {
     Write-Host "Unable to reach $uri" -ForegroundColor Red
     $uriObject | Add-Member -MemberType NoteProperty -Name "URL" -Value $uri
     $uriObject | Add-Member -MemberType NoteProperty -Name "Status" -Value "Not Responding"
     $uriObject | Add-Member -MemberType NoteProperty -Name "Description" -Value "Error"
     $uriList += $uriObject
   }
 }
