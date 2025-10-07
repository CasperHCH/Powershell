# Test HTTPS connections to various endpoints
param(
    [string[]]$CustomUris = @(),
    [int]$TimeoutSeconds = 30
)

# Common HTTPS endpoints to test
$Uris = @(
    "https://www.google.com",
    "https://www.microsoft.com",
    "https://github.com",
    "https://stackoverflow.com",
    "https://docs.microsoft.com",
    "https://portal.azure.com",
    "https://admin.microsoft.com",
    "https://outlook.office365.com"
)

# Add custom URIs if provided
if ($CustomUris.Count -gt 0) {
    $Uris += $CustomUris
}

$uriList = @()

foreach ($uri in $Uris) {
    $uriObject = New-Object PSObject
    $Response = $null
    try {
        Write-Host "Testing: $uri" -ForegroundColor Cyan
        $Response = Invoke-WebRequest -Uri $uri -ErrorAction SilentlyContinue -UseBasicParsing -DisableKeepAlive -TimeoutSec $TimeoutSeconds
        $uriObject | Add-Member -MemberType NoteProperty -Name "URI" -Value $Response.BaseResponse.ResponseUri
        $uriObject | Add-Member -MemberType NoteProperty -Name "StatusCode" -Value $Response.StatusCode
        $uriObject | Add-Member -MemberType NoteProperty -Name "StatusDescription" -Value $Response.StatusDescription
        Write-Host "SUCCESS: $($Response.StatusCode) $($Response.StatusDescription) $($Response.BaseResponse.ResponseUri)" -ForegroundColor Green
        $uriList += $uriObject
    }
    catch {
        Write-Host "FAILED: $uri - $($_.Exception.Message)" -ForegroundColor Red
        $uriObject | Add-Member -MemberType NoteProperty -Name "URI" -Value $uri
        $uriObject | Add-Member -MemberType NoteProperty -Name "StatusCode" -Value "ERROR"
        $uriObject | Add-Member -MemberType NoteProperty -Name "StatusDescription" -Value $_.Exception.Message
        $uriList += $uriObject
    }
}

# Output results
$uriList | Format-Table -AutoSize
$successCount = ($uriList | Where-Object { $_.StatusCode -ne "ERROR" }).Count
Write-Host "\nSummary: $successCount of $($uriList.Count) URLs accessible" -ForegroundColor $(if ($successCount -eq $uriList.Count) { "Green" } else { "Yellow" })
