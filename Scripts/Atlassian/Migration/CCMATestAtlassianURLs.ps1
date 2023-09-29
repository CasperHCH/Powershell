$Uris = "https://api.media.atlassian.com", "https://api-private.atlassian.com", "https://marketplace.atlassian.com", "https://api.atlassian.com", "https://migration.atlassian.com", "https://rps--prod-east--app-migration-service--ams.s3.amazonaws.com"

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
