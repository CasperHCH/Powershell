# Define Jira credentials and base URL
$JiraBaseUrl = "https://miracledk.atlassian.net"
$JiraUser = "casper.christensen@knowit.dk"
$JiraToken = "ATATT3xFfGF0is5ZnzTRwkYP1en5XdF_OmRHzLTqB5lQdJLDV_gQ4RbtXDqUtXE7frqOKNphrhfKHt__2im5Q1xXhtpLAlSeQYRc6Yj2_U9KYhjA-s3XfLBUj8t8IykMgsN6jH7hQNaguW_Aope4wpokXyfSBWdxCOwOAbTlNfJ3-QBFbMt_Nis=2BFF7B80"

# Set headers
$Headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($JiraUser):$($JiraToken)"))
    "Accept"        = "application/json"
}

# Define the API endpoint
$IssueLinkTypeUrl = "$JiraBaseUrl/rest/api/3/issueLinkType"

# Fetch issue link types
try {
    $Response = Invoke-RestMethod -Uri $IssueLinkTypeUrl -Headers $Headers -Method Get
    Write-Host "Available Issue Link Types:" -ForegroundColor Green
    $Response.issueLinkTypes | ForEach-Object {
        Write-Host "- Name: $($_.name), Inward: $($_.inward), Outward: $($_.outward)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Failed to fetch issue link types: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response -and ($_.Exception.Response.Content -ne $null)) {
        Write-Host "Raw API Response: $($_.Exception.Response.Content)" -ForegroundColor Yellow
    }
}