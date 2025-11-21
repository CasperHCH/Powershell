<#
.SYNOPSIS
    Generate automated weekly/monthly status reports from Jira.

.DESCRIPTION
    Creates comprehensive status reports with key metrics, accomplishments, blockers, and upcoming work.
    Suitable for stakeholder communications and executive summaries.

.PARAMETER JiraBaseUrl
    The base URL of the Jira instance.

.PARAMETER CloudId
    The Cloud ID for service account authentication.

.PARAMETER ServiceAccountEmail
    The service account email for authentication.

.PARAMETER ProjectKeys
    Array of project keys to include in the status report.

.PARAMETER ReportPeriod
    Report period: Weekly or Monthly.

.PARAMETER OutputPath
    Path to save the status report.

.EXAMPLE
    .\New-AutomatedStatusReport.ps1 -JiraBaseUrl "https://company.atlassian.net" -ProjectKeys @("PROJ1") -ReportPeriod "Weekly" -CloudId "abc-123" -ServiceAccountEmail "bot@serviceaccount.atlassian.com"

.NOTES
    Author: EPM Automation Suite
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
    [ValidateSet("Weekly", "Monthly")]
    [string]$ReportPeriod = "Weekly",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot "StatusReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"),

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "StatusReport_$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
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

function Get-ApiToken {
    $secureToken = Read-Host "Enter Jira API token" -AsSecureString
    return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    )
}

function Get-ApiHeaders {
    param([string]$Token)
    if ($ServiceAccountEmail -and $CloudId) {
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ServiceAccountEmail}:${Token}"))
        return @{'Authorization' = "Basic $base64Auth"; 'Accept' = 'application/json'; 'Content-Type' = 'application/json' }
    }
    else {
        return @{'Authorization' = "Bearer $Token"; 'Accept' = 'application/json'; 'Content-Type' = 'application/json' }
    }
}

function Get-ApiUrl {
    param([string]$Endpoint)
    if ($ServiceAccountEmail -and $CloudId) {
        return "https://api.atlassian.com/ex/jira/$CloudId/$Endpoint"
    }
    else {
        return "$JiraBaseUrl/$Endpoint"
    }
}

function Get-DateRange {
    $endDate = Get-Date
    $startDate = switch ($ReportPeriod) {
        "Weekly" { $endDate.AddDays(-7) }
        "Monthly" { $endDate.AddDays(-30) }
    }
    return @{
        Start          = $startDate.ToString("yyyy-MM-dd")
        End            = $endDate.ToString("yyyy-MM-dd")
        StartFormatted = $startDate.ToString("MMM dd, yyyy")
        EndFormatted   = $endDate.ToString("MMM dd, yyyy")
    }
}

function Get-StatusReportData {
    param([hashtable]$Headers, [hashtable]$DateRange)

    $projectList = $ProjectKeys -join ", "

    # Completed issues in period
    $completedJql = "project in ($projectList) AND status = Done AND resolutiondate >= '$($DateRange.Start)'"
    $completedIssues = Invoke-JiraSearch -JQL $completedJql -Headers $Headers

    # In progress issues
    $inProgressJql = "project in ($projectList) AND status in ('In Progress', 'In Review')"
    $inProgressIssues = Invoke-JiraSearch -JQL $inProgressJql -Headers $Headers

    # Blocked issues
    $blockedJql = "project in ($projectList) AND status = 'Blocked'"
    $blockedIssues = Invoke-JiraSearch -JQL $blockedJql -Headers $Headers

    # Upcoming (next sprint/period)
    $upcomingJql = "project in ($projectList) AND status = 'To Do' ORDER BY priority DESC"
    $upcomingIssues = Invoke-JiraSearch -JQL $upcomingJql -Headers $Headers -MaxResults 10

    return @{
        Completed  = $completedIssues
        InProgress = $inProgressIssues
        Blocked    = $blockedIssues
        Upcoming   = $upcomingIssues
    }
}

function Invoke-JiraSearch {
    param([string]$JQL, [hashtable]$Headers, [int]$MaxResults = 100)

    $url = Get-ApiUrl -Endpoint "rest/api/3/search"
    $body = @{
        jql        = $JQL
        maxResults = $MaxResults
        fields     = @("summary", "status", "priority", "assignee", "created", "resolutiondate")
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Post -Body $body -TimeoutSec $TimeoutSeconds
        Write-Log "JQL query returned $($response.total) issues" -Level "INFO"
        return $response.issues
    }
    catch {
        Write-Log "JQL query failed: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Export-StatusReport {
    param([hashtable]$ReportData, [hashtable]$DateRange)

    $completedRows = if ($ReportData.Completed.Count -gt 0) {
        $ReportData.Completed | ForEach-Object {
            "<tr><td><strong>$($_.key)</strong></td><td>$($_.fields.summary)</td><td>$($_.fields.assignee.displayName)</td><td>$($_.fields.priority.name)</td></tr>"
        } | Out-String
    }
    else {
        "<tr><td colspan='4' style='text-align: center; color: #999;'>No completed issues this period</td></tr>"
    }

    $inProgressRows = if ($ReportData.InProgress.Count -gt 0) {
        $ReportData.InProgress | ForEach-Object {
            "<tr><td><strong>$($_.key)</strong></td><td>$($_.fields.summary)</td><td>$($_.fields.assignee.displayName)</td><td>$($_.fields.status.name)</td></tr>"
        } | Out-String
    }
    else {
        "<tr><td colspan='4' style='text-align: center; color: #999;'>No in-progress issues</td></tr>"
    }

    $blockedRows = if ($ReportData.Blocked.Count -gt 0) {
        $ReportData.Blocked | ForEach-Object {
            "<tr><td><strong>$($_.key)</strong></td><td>$($_.fields.summary)</td><td>$($_.fields.assignee.displayName)</td><td style='color: #ff4444; font-weight: bold;'>BLOCKED</td></tr>"
        } | Out-String
    }
    else {
        "<tr><td colspan='4' style='text-align: center; color: #00cc44;'>✅ No blockers!</td></tr>"
    }

    $upcomingRows = if ($ReportData.Upcoming.Count -gt 0) {
        $ReportData.Upcoming | ForEach-Object {
            "<tr><td><strong>$($_.key)</strong></td><td>$($_.fields.summary)</td><td>$($_.fields.assignee.displayName)</td><td>$($_.fields.priority.name)</td></tr>"
        } | Out-String
    }
    else {
        "<tr><td colspan='4' style='text-align: center; color: #999;'>No upcoming work planned</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportPeriod Status Report - $(Get-Date -Format 'yyyy-MM-dd')</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #0052cc; padding-bottom: 10px; }
        h2 { color: #0052cc; margin-top: 30px; border-left: 4px solid #0052cc; padding-left: 10px; }
        .summary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .summary h3 { margin: 0 0 10px 0; }
        .metrics { display: flex; justify-content: space-around; margin-top: 15px; }
        .metric { text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { font-size: 0.9em; opacity: 0.9; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #0052cc; color: white; font-weight: bold; }
        tr:hover { background-color: #f5f5f5; }
        .footer { margin-top: 30px; text-align: center; color: #666; font-size: 0.9em; border-top: 1px solid #ddd; padding-top: 15px; }
        .blocked-alert { background-color: #fff3cd; border-left: 4px solid #ff4444; padding: 15px; margin: 15px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📋 $ReportPeriod Status Report</h1>
        <p><strong>Report Period:</strong> $($DateRange.StartFormatted) - $($DateRange.EndFormatted)</p>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Projects:</strong> $($ProjectKeys -join ", ")</p>

        <div class="summary">
            <h3>📊 Summary Metrics</h3>
            <div class="metrics">
                <div class="metric">
                    <div class="metric-value">$($ReportData.Completed.Count)</div>
                    <div class="metric-label">Completed</div>
                </div>
                <div class="metric">
                    <div class="metric-value">$($ReportData.InProgress.Count)</div>
                    <div class="metric-label">In Progress</div>
                </div>
                <div class="metric">
                    <div class="metric-value">$($ReportData.Blocked.Count)</div>
                    <div class="metric-label">Blocked</div>
                </div>
                <div class="metric">
                    <div class="metric-value">$($ReportData.Upcoming.Count)</div>
                    <div class="metric-label">Upcoming</div>
                </div>
            </div>
        </div>

        <h2>✅ Accomplishments (Completed This Period)</h2>
        <table>
            <thead>
                <tr><th>Issue Key</th><th>Summary</th><th>Assignee</th><th>Priority</th></tr>
            </thead>
            <tbody>
                $completedRows
            </tbody>
        </table>

        <h2>🔄 Work In Progress</h2>
        <table>
            <thead>
                <tr><th>Issue Key</th><th>Summary</th><th>Assignee</th><th>Status</th></tr>
            </thead>
            <tbody>
                $inProgressRows
            </tbody>
        </table>

        <h2>🚨 Blockers & Issues</h2>
        $(if ($ReportData.Blocked.Count -gt 0) { '<div class="blocked-alert"><strong>⚠️ Action Required:</strong> There are currently ' + $ReportData.Blocked.Count + ' blocked issue(s) requiring attention.</div>' } else { '' })
        <table>
            <thead>
                <tr><th>Issue Key</th><th>Summary</th><th>Assignee</th><th>Status</th></tr>
            </thead>
            <tbody>
                $blockedRows
            </tbody>
        </table>

        <h2>🔮 Upcoming Work (Next Period)</h2>
        <table>
            <thead>
                <tr><th>Issue Key</th><th>Summary</th><th>Assignee</th><th>Priority</th></tr>
            </thead>
            <tbody>
                $upcomingRows
            </tbody>
        </table>

        <div class="footer">
            <p>Generated by EPM Automation Suite | PowerShell Status Report Generator</p>
            <p>This report can be automated and scheduled for regular distribution to stakeholders.</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Status report generated: $OutputPath" -Level "SUCCESS"
}

try {
    Write-Log "🚀 Starting $ReportPeriod Status Report generation..." -Level "INFO"

    $apiToken = Get-ApiToken
    $headers = Get-ApiHeaders -Token $apiToken
    $dateRange = Get-DateRange

    $reportData = Get-StatusReportData -Headers $headers -DateRange $dateRange
    Export-StatusReport -ReportData $reportData -DateRange $dateRange

    Write-Log "✅ Status Report completed successfully!" -Level "SUCCESS"
    Write-Log "Report saved to: $OutputPath" -Level "SUCCESS"

}
catch {
    Write-Log "❌ Critical error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
finally {
    $apiToken = $null
}
