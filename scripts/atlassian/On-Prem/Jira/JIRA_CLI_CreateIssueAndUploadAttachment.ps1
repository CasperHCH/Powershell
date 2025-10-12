<#
.SYNOPSIS
    Secure JIRA issue creation with attachment support

.DESCRIPTION
    Enterprise-grade script to create JIRA issues and upload attachments with secure authentication.
    All credentials are parameterized and support secure credential management.

.PARAMETER ProjectKey
    JIRA project key (e.g., "PROJ", "DEV")

.PARAMETER Summary
    Issue summary/title

.PARAMETER Description
    Detailed issue description

.PARAMETER AttachmentPath
    Optional path to file to attach to the issue

.PARAMETER JiraBaseUrl
    Base URL of the JIRA instance (e.g., "https://jira.contoso.com")

.PARAMETER JiraUser
    JIRA username for authentication

.PARAMETER JiraApiToken
    JIRA API token or password (secure string recommended)

.PARAMETER UseStoredCredentials
    Use stored encrypted credentials instead of prompting

.PARAMETER CredentialPath
    Path to stored credential file

.EXAMPLE
    .\JIRA_CLI_CreateIssueAndUploadAttachment.ps1 -ProjectKey "PROJ" -Summary "Test Issue" -Description "Test Description" -JiraBaseUrl "https://jira.contoso.com" -UseStoredCredentials

.NOTES
    SECURITY CLASSIFICATION: CONFIDENTIAL
    DATA HANDLING: JIRA issue and attachment operations
    AUDIT REQUIREMENTS: All API operations logged
    CREDENTIALS REQUIRED: JIRA project access
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="JIRA project key")]
    [ValidatePattern('^[A-Z0-9]+$')]
    [string]$ProjectKey,

    [Parameter(Mandatory=$true, HelpMessage="Issue summary")]
    [ValidateNotNullOrEmpty()]
    [string]$Summary,

    [Parameter(Mandatory=$true, HelpMessage="Issue description")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage="Path to attachment file")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$AttachmentPath,

    [Parameter(Mandatory=$true, HelpMessage="JIRA base URL (e.g., https://jira.contoso.com)")]
    [ValidatePattern('^https://.*')]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory=$false, HelpMessage="JIRA username")]
    [string]$JiraUser,

    [Parameter(Mandatory=$false, HelpMessage="JIRA API token")]
    [string]$JiraApiToken,

    [Parameter(Mandatory=$false, HelpMessage="Use stored encrypted credentials")]
    [switch]$UseStoredCredentials,

    [Parameter(Mandatory=$false, HelpMessage="Path to stored credential file")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CredentialPath
)

# 🔐 Secure credential management
if ($UseStoredCredentials) {
    $credPath = if ($CredentialPath) { $CredentialPath } else { "$env:USERPROFILE\.credentials\jira.xml" }
    
    if (Test-Path $credPath) {
        Write-Host "🔑 Loading stored credentials from $credPath" -ForegroundColor Yellow
        $credential = Import-Clixml -Path $credPath
        $JiraUser = $credential.UserName
        $JiraApiToken = $credential.GetNetworkCredential().Password
    } else {
        throw "Stored credentials not found at: $credPath"
    }
} else {
    if (-not $JiraUser) {
        $JiraUser = Read-Host "Enter JIRA username"
    }
    if (-not $JiraApiToken) {
        $secureToken = Read-Host "Enter JIRA API token" -AsSecureString
        $JiraApiToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
    }
}

Write-Host "🔒 Starting JIRA issue creation" -ForegroundColor Cyan
Write-Host "Target: $JiraBaseUrl" -ForegroundColor White
Write-Host "Project: $ProjectKey" -ForegroundColor White

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