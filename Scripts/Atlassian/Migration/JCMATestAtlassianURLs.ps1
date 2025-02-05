$Uris = , , , , , , , 

 $uriList = @()
    
   foreach ($uri in $Uris) {
     $uriObject = New-Object PSObject
     $Response = 
     try {
     $Response = Invoke-WebRequest -Uri $uri -ErrorAction SilentlyContinue -UseBasicParsing -DisableKeepAlive
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value $Response.BaseResponse.ResponseUri
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value $Response.StatusCode
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value $Response.StatusDescription
     Write-Host $Response.StatusCode $Response.StatusDescription $Response.BaseResponse.ResponseUri -ForegroundColor Green
     $uriList += $uriObject
   }
   catch {
     Write-Host  -ForegroundColor Red
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value $uri
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value 
     $uriObject | Add-Member -MemberType NoteProperty -Name  -Value 
     $uriList += $uriObject
   }
 }
