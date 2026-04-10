<#
.SYNOPSIS
    Generate a portfolio health dashboard from Jira projects.

.DESCRIPTION
    Aggregates metrics across multiple Jira projects to provide executive-level portfolio health insights.
    Tracks project status, identifies at-risk projects, and generates executive summaries.
    Supports both Jira Cloud (with service account) and standard API token authentication.

.PARAMETER JiraBaseUrl
    The base URL of the Jira instance (e.g., https://company.atlassian.net).

.PARAMETER CloudId
    The Cloud ID for service account authentication (Jira Cloud only).

.PARAMETER ServiceAccountEmail
    The service account email for authentication (e.g., bot@serviceaccount.atlassian.com).

.PARAMETER ProjectKeys
    Array of project keys to include in the portfolio (e.g., @("PROJ1", "PROJ2")).

.PARAMETER OutputPath
    Path to save the dashboard report (default: current directory).

.PARAMETER ExportFormat
    Export format: JSON, CSV, HTML, or Excel (default: HTML).

.EXAMPLE
    .\Get-PortfolioHealthDashboard.ps1 -JiraBaseUrl "https://company.atlassian.net" -ProjectKeys @("PROJ1", "PROJ2") -CloudId "abc-123" -ServiceAccountEmail "bot@serviceaccount.atlassian.com"

.NOTES
    Author: EPM Automation Suite
    Requires: PowerShell 5.1+, Jira API access
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$CloudId,

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccountEmail,

    [Parameter(Mandatory = $true)]
    [string[]]$ProjectKeys,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot "PortfolioHealthReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "CSV", "HTML", "Excel")]
    [string]$ExportFormat = "HTML",

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
)

# Script-level variables
$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "PortfolioHealth_$(Get-Date -Format 'yyyyMMdd').log"
$script:JiraBaseUrl = $JiraBaseUrl
$script:CloudId = $CloudId
$script:ServiceAccountEmail = $ServiceAccountEmail
$script:ProjectKeys = $ProjectKeys
$script:TimeoutSeconds = $TimeoutSeconds

# Logging function
function Write-EpmLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$script:SessionId] [$Level] $Message"

    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }

    Write-Host $logEntry -ForegroundColor $color
    Add-Content -Path $script:LogFile -Value $logEntry
}

# Get API token securely
function Get-ApiToken {
    $secureToken = Read-Host "Enter Jira API token" -AsSecureString
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    )
}

# Build API headers
function Get-ApiHeader {
    param([string]$Token)

    if ($script:ServiceAccountEmail -and $script:CloudId) {
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($script:ServiceAccountEmail):${Token}"))
        return @{
            'Authorization' = "Basic $base64Auth"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/json'
        }
    }
    else {
        return @{
            'Authorization' = "Bearer $Token"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/json'
        }
    }
}

# Build API URL
function Get-ApiUrl {
    param([string]$Endpoint)

    if ($script:ServiceAccountEmail -and $script:CloudId) {
        return "https://api.atlassian.com/ex/jira/$($script:CloudId)/$Endpoint"
    }
    else {
        return "$($script:JiraBaseUrl)/$Endpoint"
    }
}

# Get project details
function Get-ProjectDetail {
    param(
        [string]$ProjectKey,
        [hashtable]$Headers
    )

    try {
        $url = Get-ApiUrl -Endpoint "rest/api/3/project/$ProjectKey"
        $project = Invoke-RestMethod -Uri $url -Headers $Headers -Method Get -TimeoutSec $script:TimeoutSeconds

        Write-EpmLog "Retrieved project details for $ProjectKey" -Level "INFO"
        return $project
    }
    catch {
        Write-EpmLog "Failed to retrieve project $ProjectKey : $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Get project issues with JQL
function Get-ProjectIssue {
    param(
        [string]$ProjectKey,
        [hashtable]$Headers
    )

    try {
        $jql = "project = $ProjectKey ORDER BY created DESC"
        $url = Get-ApiUrl -Endpoint "rest/api/3/search"

        $body = @{
            jql        = $jql
            maxResults = 1000
            fields     = @("status", "priority", "created", "updated", "resolutiondate", "assignee", "issuetype", "summary")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Post -Body $body -TimeoutSec $script:TimeoutSeconds

        Write-EpmLog "Retrieved $($response.total) issues for $ProjectKey" -Level "INFO"
        return $response.issues
    }
    catch {
        Write-EpmLog "Failed to retrieve issues for $ProjectKey : $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Calculate project health metrics
function Get-ProjectHealth {
    param(
        [object]$Project,
        [array]$Issues
    )

    $totalIssues = $Issues.Count
    $openIssues = ($Issues | Where-Object { $_.fields.status.statusCategory.key -ne "done" }).Count
    $inProgressIssues = ($Issues | Where-Object { $_.fields.status.statusCategory.key -eq "indeterminate" }).Count
    $doneIssues = ($Issues | Where-Object { $_.fields.status.statusCategory.key -eq "done" }).Count

    $highPriorityOpen = ($Issues | Where-Object {
            $_.fields.priority.name -in @("Highest", "High") -and
            $_.fields.status.statusCategory.key -ne "done"
        }).Count

    $unassignedIssues = ($Issues | Where-Object {
            $null -eq $_.fields.assignee -and
            $_.fields.status.statusCategory.key -ne "done"
        }).Count

    # Calculate completion percentage
    $completionRate = if ($totalIssues -gt 0) {
        [math]::Round(($doneIssues / $totalIssues) * 100, 2)
    }
    else { 0 }

    # Determine health status (RAG)
    $healthStatus = if ($highPriorityOpen -gt 5 -or $unassignedIssues -gt 10 -or $completionRate -lt 30) {
        "Red"
    }
    elseif ($highPriorityOpen -gt 2 -or $unassignedIssues -gt 5 -or $completionRate -lt 60) {
        "Amber"
    }
    else {
        "Green"
    }

    return [PSCustomObject]@{
        ProjectKey       = $Project.key
        ProjectName      = $Project.name
        ProjectLead      = $Project.lead.displayName
        HealthStatus     = $healthStatus
        TotalIssues      = $totalIssues
        OpenIssues       = $openIssues
        InProgress       = $inProgressIssues
        Done             = $doneIssues
        CompletionRate   = $completionRate
        HighPriorityOpen = $highPriorityOpen
        UnassignedIssues = $unassignedIssues
        LastUpdated      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# Generate HTML report
function Export-HtmlReport {
    param([array]$PortfolioData)

    $redProjects = ($PortfolioData | Where-Object { $_.HealthStatus -eq "Red" }).Count
    $amberProjects = ($PortfolioData | Where-Object { $_.HealthStatus -eq "Amber" }).Count
    $greenProjects = ($PortfolioData | Where-Object { $_.HealthStatus -eq "Green" }).Count

    $totalIssues = ($PortfolioData | Measure-Object -Property TotalIssues -Sum).Sum
    $totalOpen = ($PortfolioData | Measure-Object -Property OpenIssues -Sum).Sum
    $avgCompletion = [math]::Round(($PortfolioData | Measure-Object -Property CompletionRate -Average).Average, 2)

    $rows = $PortfolioData | ForEach-Object {
        $statusColor = switch ($_.HealthStatus) {
            "Red" { "#ff4444" }
            "Amber" { "#ffaa00" }
            "Green" { "#00cc44" }
        }

        @"
        <tr>
            <td><strong>$($_.ProjectKey)</strong></td>
            <td>$($_.ProjectName)</td>
            <td>$($_.ProjectLead)</td>
            <td style="background-color: $statusColor; color: white; font-weight: bold; text-align: center;">$($_.HealthStatus)</td>
            <td style="text-align: center;">$($_.TotalIssues)</td>
            <td style="text-align: center;">$($_.OpenIssues)</td>
            <td style="text-align: center;">$($_.InProgress)</td>
            <td style="text-align: center;">$($_.Done)</td>
            <td style="text-align: center;">$($_.CompletionRate)%</td>
            <td style="text-align: center;">$($_.HighPriorityOpen)</td>
            <td style="text-align: center;">$($_.UnassignedIssues)</td>
        </tr>
"@
    } -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portfolio Health Dashboard - $(Get-Date -Format 'yyyy-MM-dd')</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #0052cc;
            padding-bottom: 10px;
        }
        .summary {
            display: flex;
            justify-content: space-around;
            margin: 30px 0;
            flex-wrap: wrap;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            min-width: 200px;
            text-align: center;
            margin: 10px;
        }
        .summary-card h3 {
            margin: 0;
            font-size: 2em;
        }
        .summary-card p {
            margin: 5px 0 0 0;
            font-size: 0.9em;
            opacity: 0.9;
        }
        .rag-status {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin: 20px 0;
        }
        .rag-card {
            padding: 15px 30px;
            border-radius: 8px;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
        }
        .rag-red { background-color: #ff4444; }
        .rag-amber { background-color: #ffaa00; }
        .rag-green { background-color: #00cc44; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #0052cc;
            color: white;
            font-weight: bold;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Portfolio Health Dashboard</h1>
        <p><strong>Report Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <strong>Projects Analyzed:</strong> $($PortfolioData.Count)</p>

        <div class="summary">
            <div class="summary-card">
                <h3>$totalIssues</h3>
                <p>Total Issues</p>
            </div>
            <div class="summary-card">
                <h3>$totalOpen</h3>
                <p>Open Issues</p>
            </div>
            <div class="summary-card">
                <h3>$avgCompletion%</h3>
                <p>Avg Completion</p>
            </div>
            <div class="summary-card">
                <h3>$($PortfolioData.Count)</h3>
                <p>Active Projects</p>
            </div>
        </div>

        <h2>Project Health Status (RAG)</h2>
        <div class="rag-status">
            <div class="rag-card rag-red">🔴 Red: $redProjects</div>
            <div class="rag-card rag-amber">🟡 Amber: $amberProjects</div>
            <div class="rag-card rag-green">🟢 Green: $greenProjects</div>
        </div>

        <h2>Project Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Project Key</th>
                    <th>Project Name</th>
                    <th>Project Lead</th>
                    <th>Health</th>
                    <th>Total</th>
                    <th>Open</th>
                    <th>In Progress</th>
                    <th>Done</th>
                    <th>Completion</th>
                    <th>High Priority</th>
                    <th>Unassigned</th>
                </tr>
            </thead>
            <tbody>
                $rows
            </tbody>
        </table>

        <div class="footer">
            <p>Generated by EPM Automation Suite | PowerShell Portfolio Health Dashboard</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-EpmLog "HTML report generated: $OutputPath" -Level "SUCCESS"
}

# Main execution
try {
    Write-EpmLog "🚀 Starting Portfolio Health Dashboard generation..." -Level "INFO"

    # Get API token
    $apiToken = Get-ApiToken
    $headers = Get-ApiHeader -Token $apiToken

    # Collect portfolio data
    $portfolioData = @()

    foreach ($projectKey in $script:ProjectKeys) {
        Write-EpmLog "Processing project: $projectKey" -Level "INFO"

        $project = Get-ProjectDetail -ProjectKey $projectKey -Headers $headers
        if ($null -eq $project) { continue }

        $issues = Get-ProjectIssue -ProjectKey $projectKey -Headers $headers
        $healthMetrics = Get-ProjectHealth -Project $project -Issues $issues

        $portfolioData += $healthMetrics
    }

    # Export report
    switch ($ExportFormat) {
        "HTML" {
            Export-HtmlReport -PortfolioData $portfolioData
        }
        "JSON" {
            $portfolioData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-EpmLog "JSON report generated: $OutputPath" -Level "SUCCESS"
        }
        "CSV" {
            $portfolioData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-EpmLog "CSV report generated: $OutputPath" -Level "SUCCESS"
        }
    }

    Write-EpmLog "✅ Portfolio Health Dashboard completed successfully!" -Level "SUCCESS"
    Write-EpmLog "Report saved to: $OutputPath" -Level "SUCCESS"

}
catch {
    Write-EpmLog "❌ Critical error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
finally {
    $apiToken = $null
}
