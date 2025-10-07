# JCMA Migration - Test Atlassian URLs for accessibility
param(
    [string[]]$CustomUris = @()
)

# Jira Cloud Migration Assistant (JCMA) - Standard URLs to test
$Uris = @(
    "https://your-site.atlassian.net",
    "https://api.atlassian.com/ex/jira/instance-id/rest/api/2/serverInfo",
    "https://api.atlassian.com/ex/jira/instance-id/rest/api/2/project",
    "https://api.atlassian.com/ex/jira/instance-id/rest/api/2/issue",
    "https://api.atlassian.com/oauth/token",
    "https://auth.atlassian.com/oauth/token",
    "https://migration-assistant.atlassian.com",
    "https://support.atlassian.com/migration/jira/"
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
        $Response = Invoke-WebRequest -Uri $uri -ErrorAction SilentlyContinue -UseBasicParsing -DisableKeepAlive -TimeoutSec 30
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
