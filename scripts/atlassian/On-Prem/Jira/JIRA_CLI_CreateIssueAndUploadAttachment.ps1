param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectKey,
    [Parameter(Mandatory=$true)]
    [string]$Summary,
    [Parameter(Mandatory=$true)]
    [string]$Description,
    [string]$AttachmentPath
)

# Jira server details
$JiraBaseUrl = "http://your-jira-server"
$JiraUser = "your-username"
$JiraApiToken = "your-api-token-or-password"

# Create issue payload
$body = @{
    fields = @{
        project     = @{ key = $ProjectKey }
        summary     = $Summary
        description = $Description
        issuetype   = @{ name = "Task" }
    }
} | ConvertTo-Json -Depth 5

# Create issue
$issueResponse = Invoke-RestMethod -Uri "$JiraBaseUrl/rest/api/2/issue" `
    -Method Post `
    -Headers @{ "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($JiraUser):$($JiraApiToken)")) } `
    -ContentType "application/json" `
    -Body $body

$issueKey = $issueResponse.key
Write-Host "Created issue: $issueKey"

# Attach file if provided
if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
    $fileName = [System.IO.Path]::GetFileName($AttachmentPath)
    $fileBytes = [System.IO.File]::ReadAllBytes($AttachmentPath)

    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $bodyLines = (
        "--$boundary$LF" +
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"$LF" +
        "Content-Type: application/octet-stream$LF$LF"
    )
    $bodyEnd = "$LF--$boundary--$LF"
    $bodyStream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.StreamWriter($bodyStream)
    $writer.Write($bodyLines)
    $writer.Flush()
    $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
    $writer.Write($bodyEnd)
    $writer.Flush()
    $bodyStream.Position = 0

    Invoke-RestMethod -Uri "$JiraBaseUrl/rest/api/2/issue/$issueKey/attachments" `
        -Method Post `
        -Headers @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($JiraUser):$($JiraApiToken)"))
            "X-Atlassian-Token" = "no-check"
            "Content-Type" = "multipart/form-data; boundary=$boundary"
        } `
        -Body $bodyStream

    Write-Host "Attachment uploaded to $issueKey"
}