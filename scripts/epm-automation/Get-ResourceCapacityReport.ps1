<#
.SYNOPSIS
    Generate resource capacity and allocation report across Jira projects.

.DESCRIPTION
    Analyzes resource allocation, workload distribution, and capacity utilization across projects.
    Identifies over/under-utilized team members and provides capacity planning insights.

.PARAMETER JiraBaseUrl
    The base URL of the Jira instance.

.PARAMETER CloudId
    The Cloud ID for service account authentication (Jira Cloud only).

.PARAMETER ServiceAccountEmail
    The service account email for authentication.

.PARAMETER ProjectKeys
    Array of project keys to analyze for resource allocation.

.PARAMETER OutputPath
    Path to save the resource report.

.EXAMPLE
    .\Get-ResourceCapacityReport.ps1 -JiraBaseUrl "https://company.atlassian.net" -ProjectKeys @("PROJ1", "PROJ2") -CloudId "abc-123" -ServiceAccountEmail "bot@serviceaccount.atlassian.com"

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
    [string]$OutputPath = (Join-Path $PSScriptRoot "ResourceCapacity_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"),

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "ResourceCapacity_$(Get-Date -Format 'yyyyMMdd').log"
$script:JiraBaseUrl = $JiraBaseUrl
$script:CloudId = $CloudId
$script:ServiceAccountEmail = $ServiceAccountEmail
$script:ProjectKeys = $ProjectKeys
$script:TimeoutSeconds = $TimeoutSeconds

function Write-EpmLog {
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

function Get-ApiUrl {
    param([string]$Endpoint)
    if ($script:ServiceAccountEmail -and $script:CloudId) {
        return "https://api.atlassian.com/ex/jira/$($script:CloudId)/$Endpoint"
    }
    else {
        return "$($script:JiraBaseUrl)/$Endpoint"
    }
}

function Get-TeamWorkload {
    param([hashtable]$Headers)

    $jql = "project in (" + ($ProjectKeys -join ", ") + ") AND status != Done AND assignee is not EMPTY"
    $url = Get-ApiUrl -Endpoint "rest/api/3/search"

    $body = @{
        jql        = $jql
        maxResults = 1000
        fields     = @("assignee", "status", "priority", "created", "summary", "project")
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Post -Body $body -TimeoutSec $TimeoutSeconds
            Write-EpmLog "Retrieved $($response.total) assigned issues" -Level "INFO"
        return $response.issues
    }
    catch {
            Write-EpmLog "Failed to retrieve workload: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-ResourceMetric {
    param([array]$Issues)

    $resourceMap = @{}

    foreach ($issue in $Issues) {
        $assignee = $issue.fields.assignee.displayName
        $accountId = $issue.fields.assignee.accountId
        $email = $issue.fields.assignee.emailAddress

        if (-not $resourceMap.ContainsKey($assignee)) {
            $resourceMap[$assignee] = @{
                DisplayName    = $assignee
                AccountId      = $accountId
                Email          = $email
                TotalAssigned  = 0
                HighPriority   = 0
                MediumPriority = 0
                LowPriority    = 0
                InProgress     = 0
                ToDo           = 0
                Projects       = @()
            }
        }

        $resourceMap[$assignee].TotalAssigned++

        # Count by priority
        switch ($issue.fields.priority.name) {
            { $_ -in @("Highest", "High") } { $resourceMap[$assignee].HighPriority++ }
            "Medium" { $resourceMap[$assignee].MediumPriority++ }
            { $_ -in @("Low", "Lowest") } { $resourceMap[$assignee].LowPriority++ }
        }

        # Count by status
        switch ($issue.fields.status.statusCategory.key) {
            "indeterminate" { $resourceMap[$assignee].InProgress++ }
            "new" { $resourceMap[$assignee].ToDo++ }
        }

        # Track projects
        $projectKey = $issue.fields.project.key
        if ($projectKey -notin $resourceMap[$assignee].Projects) {
            $resourceMap[$assignee].Projects += $projectKey
        }
    }

    return $resourceMap.Values | ForEach-Object {
        $utilizationStatus = if ($_.TotalAssigned -gt 15) { "Over-Utilized" }
        elseif ($_.TotalAssigned -lt 3) { "Under-Utilized" }
        else { "Balanced" }

        [PSCustomObject]@{
            DisplayName       = $_.DisplayName
            Email             = $_.Email
            TotalAssigned     = $_.TotalAssigned
            HighPriority      = $_.HighPriority
            MediumPriority    = $_.MediumPriority
            LowPriority       = $_.LowPriority
            InProgress        = $_.InProgress
            ToDo              = $_.ToDo
            ProjectCount      = $_.Projects.Count
            Projects          = $_.Projects -join ", "
            UtilizationStatus = $utilizationStatus
        }
    } | Sort-Object TotalAssigned -Descending
}

function Export-HtmlReport {
    param([array]$ResourceData)

    $overUtilized = ($ResourceData | Where-Object { $_.UtilizationStatus -eq "Over-Utilized" }).Count
    $underUtilized = ($ResourceData | Where-Object { $_.UtilizationStatus -eq "Under-Utilized" }).Count
    $balanced = ($ResourceData | Where-Object { $_.UtilizationStatus -eq "Balanced" }).Count

    $totalAssignments = ($ResourceData | Measure-Object -Property TotalAssigned -Sum).Sum
    $avgAssignments = [math]::Round(($ResourceData | Measure-Object -Property TotalAssigned -Average).Average, 2)

    $rows = $ResourceData | ForEach-Object {
        $statusColor = switch ($_.UtilizationStatus) {
            "Over-Utilized" { "#ff4444" }
            "Under-Utilized" { "#ffaa00" }
            "Balanced" { "#00cc44" }
        }

        @"
        <tr>
            <td><strong>$($_.DisplayName)</strong></td>
            <td>$($_.Email)</td>
            <td style="text-align: center; font-weight: bold;">$($_.TotalAssigned)</td>
            <td style="text-align: center;">$($_.HighPriority)</td>
            <td style="text-align: center;">$($_.MediumPriority)</td>
            <td style="text-align: center;">$($_.LowPriority)</td>
            <td style="text-align: center;">$($_.InProgress)</td>
            <td style="text-align: center;">$($_.ToDo)</td>
            <td style="text-align: center;">$($_.ProjectCount)</td>
            <td>$($_.Projects)</td>
            <td style="background-color: $statusColor; color: white; font-weight: bold; text-align: center;">$($_.UtilizationStatus)</td>
        </tr>
"@
    } -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Resource Capacity Report - $(Get-Date -Format 'yyyy-MM-dd')</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #0052cc; padding-bottom: 10px; }
        .summary { display: flex; justify-content: space-around; margin: 30px 0; flex-wrap: wrap; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; min-width: 180px; text-align: center; margin: 10px; }
        .summary-card h3 { margin: 0; font-size: 2em; }
        .summary-card p { margin: 5px 0 0 0; font-size: 0.9em; opacity: 0.9; }
        .utilization-status { display: flex; justify-content: center; gap: 20px; margin: 20px 0; }
        .util-card { padding: 15px 30px; border-radius: 8px; color: white; font-weight: bold; font-size: 1.2em; }
        .util-over { background-color: #ff4444; }
        .util-under { background-color: #ffaa00; }
        .util-balanced { background-color: #00cc44; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #0052cc; color: white; font-weight: bold; }
        tr:hover { background-color: #f5f5f5; }
        .footer { margin-top: 30px; text-align: center; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>👥 Resource Capacity & Allocation Report</h1>
        <p><strong>Report Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <strong>Team Members:</strong> $($ResourceData.Count)</p>

        <div class="summary">
            <div class="summary-card">
                <h3>$totalAssignments</h3>
                <p>Total Assignments</p>
            </div>
            <div class="summary-card">
                <h3>$avgAssignments</h3>
                <p>Avg per Person</p>
            </div>
            <div class="summary-card">
                <h3>$($ResourceData.Count)</h3>
                <p>Team Members</p>
            </div>
        </div>

        <h2>Utilization Status</h2>
        <div class="utilization-status">
            <div class="util-card util-over">🔴 Over-Utilized: $overUtilized</div>
            <div class="util-card util-under">🟡 Under-Utilized: $underUtilized</div>
            <div class="util-card util-balanced">🟢 Balanced: $balanced</div>
        </div>

        <h2>Team Member Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Total Assigned</th>
                    <th>High Priority</th>
                    <th>Medium Priority</th>
                    <th>Low Priority</th>
                    <th>In Progress</th>
                    <th>To Do</th>
                    <th>Projects</th>
                    <th>Project Keys</th>
                    <th>Utilization</th>
                </tr>
            </thead>
            <tbody>
                $rows
            </tbody>
        </table>

        <div class="footer">
            <p>Generated by EPM Automation Suite | PowerShell Resource Capacity Report</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-EpmLog "HTML report generated: $OutputPath" -Level "SUCCESS"
}

try {
        Write-EpmLog "🚀 Starting Resource Capacity Report generation..." -Level "INFO"

    $apiToken = Get-ApiToken
    $headers = Get-ApiHeader -Token $apiToken

    $issues = Get-TeamWorkload -Headers $headers
    $resourceMetrics = Get-ResourceMetric -Issues $issues

    Export-HtmlReport -ResourceData $resourceMetrics

    Write-EpmLog "✅ Resource Capacity Report completed successfully!" -Level "SUCCESS"
    Write-EpmLog "Report saved to: $OutputPath" -Level "SUCCESS"

}
catch {
        Write-EpmLog "❌ Critical error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
finally {
    $apiToken = $null
}
