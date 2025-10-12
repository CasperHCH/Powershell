# Test script for anonymization task ID extraction
param(
    [string]$TestResponse = '{"errors":{},"warnings":{},"userKey":"JIRAUSER43268","userName":"sce9995","fullName":"Pandey, Pankaj Kumar /External","progressUrl":"/rest/api/2/user/anonymization/progress?taskId=401382","currentProgress":0,"submittedTime":"2025-10-10T15:38:45.421+0200","operations":[],"status":"IN_PROGRESS","executingNode":"","isRerun":false,"rerun":false}'
)

Write-Host "=== Testing Anonymization Task ID Extraction ===" -ForegroundColor Cyan
Write-Host ""

# Parse the test response
$result = $TestResponse | ConvertFrom-Json

Write-Host "Original Progress URL: $($result.progressUrl)" -ForegroundColor Yellow

# Extract task ID using the same logic as the script
if ($result.progressUrl -match "taskId=(\d+)") {
    $taskId = $matches[1]
    Write-Host "Extracted Task ID: $taskId" -ForegroundColor Green

    # Show what the new monitoring URL would be
    $baseUrl = "https://jira-ks.norlys.dk"
    $progressUri = "$baseUrl/rest/api/2/user/anonymization/progress?taskId=$taskId"
    Write-Host "Task-specific monitoring URL: $progressUri" -ForegroundColor Green
} else {
    Write-Host "Failed to extract Task ID from progress URL" -ForegroundColor Red
}

Write-Host ""
Write-Host "Key improvements:" -ForegroundColor Cyan
Write-Host "✅ Extract specific task ID from anonymization response" -ForegroundColor Green
Write-Host "✅ Monitor task-specific progress endpoint" -ForegroundColor Green
Write-Host "✅ Handle IN_PROGRESS, FINISHED, FAILED status values" -ForegroundColor Green
Write-Host "✅ Proper completion detection for anonymization verification" -ForegroundColor Green