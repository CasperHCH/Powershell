# JQL Search Script for JIRA
<#
.SYNOPSIS
    Simple JQL (JIRA Query Language) search script for JIRA instances

.DESCRIPTION
    Performs JQL searches against JIRA and displays results in a formatted table.
    Supports both basic authentication and Personal Access Token authentication.

.PARAMETER JiraBaseUrl
    The base URL of your JIRA instance (e.g., https://jira.base.url)

.PARAMETER JQL
    The JQL query to execute (e.g., "project = TEST AND status = Open")

.PARAMETER PersonalAccessToken
    Personal Access Token for authentication (recommended)

.PARAMETER Username
    JIRA username for basic authentication

.PARAMETER Password
    JIRA password for basic authentication

.PARAMETER MaxResults
    Maximum number of results to return (default: 50)

.EXAMPLE
    .\JQL-Search.ps1 -JiraBaseUrl "https://jira.base.url" -JQL "project = ProjectName/Key" -PersonalAccessToken "your_token"

.EXAMPLE
    .\JQL-Search.ps1 -JiraBaseUrl "https://jira.base.url" -JQL "assignee = currentUser() AND status != Done" -Username "admin" -Password "password"

.EXAMPLE
    # List all projects to find correct project key/name
    .\JQL-Search.ps1 -JiraBaseUrl "https://jira.weibel.dk" -JQL "project is not empty" -PersonalAccessToken "your_token" -ListProjects
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$JQL,

    [string]$PersonalAccessToken,

    [string]$Username,

    [string]$Password,

    [int]$MaxResults = 50,

    [switch]$ListProjects
)

# Remove trailing slash from URL
$JiraBaseUrl = $JiraBaseUrl.TrimEnd('/')

# Setup authentication headers
$headers = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

if ($PersonalAccessToken) {
    $headers['Authorization'] = "Bearer $PersonalAccessToken"
    Write-Host "Using Personal Access Token authentication" -ForegroundColor Green
} elseif ($Username -and $Password) {
    $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
    $headers['Authorization'] = "Basic $credentials"
    Write-Host "Using Basic authentication for user: $Username" -ForegroundColor Green
} else {
    Write-Error "Authentication required: Provide either -PersonalAccessToken or both -Username and -Password"
    exit 1
}

# Handle special case: List all projects
if ($ListProjects) {
    Write-Host "`n=== Listing All Available Projects ===" -ForegroundColor Cyan
    Write-Host "JIRA URL: $JiraBaseUrl" -ForegroundColor Yellow

    try {
        $projectsUrl = "$JiraBaseUrl/rest/api/2/project"
        $projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -Headers $headers -UseBasicParsing

        Write-Host "`n=== Available Projects ===" -ForegroundColor Green
        Write-Host "Found $($projects.Count) projects:" -ForegroundColor Green

        $projectList = $projects | ForEach-Object {
            [PSCustomObject]@{
                Key = $_.key
                Name = $_.name
                ProjectType = $_.projectTypeKey
                Lead = if ($_.lead) { $_.lead.displayName } else { "Unknown" }
            }
        }

        $projectList | Format-Table -AutoSize

        Write-Host "`nTo search in a specific project, use one of these JQL queries:" -ForegroundColor Cyan
        $projects | ForEach-Object {
            Write-Host "  project = `"$($_.key)`"     # For project: $($_.name)" -ForegroundColor Yellow
        }

        return

    } catch {
        Write-Host "`nError listing projects:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
}

# Construct the search URL
$searchUrl = "$JiraBaseUrl/rest/api/2/search"

# Prepare the search payload
$searchPayload = @{
    jql = $JQL
    maxResults = $MaxResults
    fields = @(
        "key",
        "summary",
        "status",
        "assignee",
        "reporter",
        "priority",
        "created",
        "updated",
        "project"
    )
} | ConvertTo-Json -Depth 3

Write-Host "`n=== JQL Search ===" -ForegroundColor Cyan
Write-Host "JIRA URL: $JiraBaseUrl" -ForegroundColor Yellow
Write-Host "Query: $JQL" -ForegroundColor Yellow
Write-Host "Max Results: $MaxResults" -ForegroundColor Yellow

try {
    # Execute the search
    Write-Host "`nExecuting search..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $searchUrl -Method Post -Headers $headers -Body $searchPayload -UseBasicParsing

    # Display results
    Write-Host "`n=== Search Results ===" -ForegroundColor Green
    Write-Host "Total issues found: $($response.total)" -ForegroundColor Green
    Write-Host "Issues returned: $($response.issues.Count)" -ForegroundColor Green

    if ($response.issues.Count -gt 0) {
        Write-Host "`n=== Issue Details ===" -ForegroundColor Cyan

        $results = $response.issues | ForEach-Object {
            [PSCustomObject]@{
                Key = $_.key
                Summary = $_.fields.summary
                Status = $_.fields.status.name
                Assignee = if ($_.fields.assignee) { $_.fields.assignee.displayName } else { "Unassigned" }
                Reporter = if ($_.fields.reporter) { $_.fields.reporter.displayName } else { "Unknown" }
                Priority = if ($_.fields.priority) { $_.fields.priority.name } else { "None" }
                Project = $_.fields.project.name
                Created = if ($_.fields.created) { ([DateTime]$_.fields.created).ToString('yyyy-MM-dd') } else { "Unknown" }
                Updated = if ($_.fields.updated) { ([DateTime]$_.fields.updated).ToString('yyyy-MM-dd') } else { "Unknown" }
            }
        }

        # Display as formatted table
        $results | Format-Table -AutoSize -Wrap

        # Option to export results
        $export = Read-Host "`nExport results to CSV? (y/n)"
        if ($export -eq 'y' -or $export -eq 'Y') {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $exportPath = ".\JQL_Results_$timestamp.csv"
            $results | Export-Csv -Path $exportPath -NoTypeInformation
            Write-Host "Results exported to: $exportPath" -ForegroundColor Green
        }

    } else {
        Write-Host "No issues found matching the JQL query." -ForegroundColor Yellow
    }

} catch {
    Write-Host "`nError executing JQL search:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    # Try to get detailed error information
    if ($_.Exception.Response) {
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorBody = $reader.ReadToEnd()
            Write-Host "`nError details:" -ForegroundColor Red
            Write-Host $errorBody -ForegroundColor Red

            # Parse JSON error for better diagnostics
            try {
                $errorJson = $errorBody | ConvertFrom-Json
                if ($errorJson.errorMessages) {
                    Write-Host "`nJIRA Error Messages:" -ForegroundColor Yellow
                    $errorJson.errorMessages | ForEach-Object {
                        Write-Host "  • $_" -ForegroundColor Red
                    }
                }
                if ($errorJson.errors) {
                    Write-Host "`nField Errors:" -ForegroundColor Yellow
                    $errorJson.errors.PSObject.Properties | ForEach-Object {
                        Write-Host "  • $($_.Name): $($_.Value)" -ForegroundColor Red
                    }
                }
            } catch {
                # JSON parsing failed, raw output already shown
            }

        } catch {
            # Ignore errors reading error response
        }
    }

    Write-Host "`n=== Troubleshooting Tips ===" -ForegroundColor Cyan
    Write-Host "1. Use -ListProjects to see all available projects" -ForegroundColor Yellow
    Write-Host "2. Try using project KEY instead of project NAME" -ForegroundColor Yellow
    Write-Host "3. Check if project name contains special characters that need escaping" -ForegroundColor Yellow
    Write-Host "4. Verify you have permission to access this project" -ForegroundColor Yellow

    exit 1
}

Write-Host "`n=== JQL Search Completed ===" -ForegroundColor Green