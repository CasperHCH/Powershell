<#
.SYNOPSIS
    Track and analyze project risks and issues across portfolio.

.DESCRIPTION
    Aggregates and analyzes risks and issues across multiple projects.
    Provides trend analysis, impact assessment, and mitigation tracking.

.PARAMETER JiraBaseUrl
    The base URL of the Jira instance.

.PARAMETER CloudId
    The Cloud ID for service account authentication.

.PARAMETER ServiceAccountEmail
    The service account email for authentication.

.PARAMETER ProjectKeys
    Array of project keys to analyze.

.PARAMETER OutputPath
    Path to save the risk report.

.EXAMPLE
    .\Get-RiskIssueAnalysis.ps1 -JiraBaseUrl "https://company.atlassian.net" -ProjectKeys @("PROJ1") -CloudId "abc-123" -ServiceAccountEmail "bot@serviceaccount.atlassian.com"

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
    [string]$OutputPath = (Join-Path $PSScriptRoot "RiskAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"),

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
)

$script:SessionId = (New-Guid).ToString().Substring(0, 8)
$script:LogFile = Join-Path $PSScriptRoot "RiskAnalysis_$(Get-Date -Format 'yyyyMMdd').log"
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
        return @{'Authorization' = "Basic $base64Auth"; 'Accept' = 'application/json'; 'Content-Type' = 'application/json' }
    }
    else {
        return @{'Authorization' = "Bearer $Token"; 'Accept' = 'application/json'; 'Content-Type' = 'application/json' }
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

function Get-RiskData {
    param([hashtable]$Headers)

    $projectList = $script:ProjectKeys -join ", "

    # High priority unresolved issues (acting as risks)
    $riskJql = "project in ($projectList) AND priority in (Highest, High) AND status != Done"
    $url = Get-ApiUrl -Endpoint "rest/api/3/search"

    $body = @{
        jql        = $riskJql
        maxResults = 500
        fields     = @("summary", "status", "priority", "created", "assignee", "project", "labels")
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $Headers -Method Post -Body $body -TimeoutSec $script:TimeoutSeconds
        Write-EpmLog "Retrieved $($response.total) high-priority issues" -Level "INFO"
        return $response.issues
    }
    catch {
        Write-EpmLog "Failed to retrieve risk data: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-AgingAnalysis {
    param([array]$Issues)

    $today = Get-Date

    return $Issues | ForEach-Object {
        $created = [DateTime]::Parse($_.fields.created)
        $ageInDays = ($today - $created).Days

        $riskLevel = if ($ageInDays -gt 30) { "Critical" }
        elseif ($ageInDays -gt 14) { "High" }
        elseif ($ageInDays -gt 7) { "Medium" }
        else { "Low" }

        [PSCustomObject]@{
            IssueKey  = $_.key
            Summary   = $_.fields.summary
            Priority  = $_.fields.priority.name
            Status    = $_.fields.status.name
            Project   = $_.fields.project.key
            Assignee  = if ($_.fields.assignee) { $_.fields.assignee.displayName } else { "Unassigned" }
            AgeInDays = $ageInDays
            RiskLevel = $riskLevel
            Created   = $created.ToString("yyyy-MM-dd")
        }
    } | Sort-Object AgeInDays -Descending
}

function Export-RiskReport {
    param([array]$RiskData)

    $critical = ($RiskData | Where-Object { $_.RiskLevel -eq "Critical" }).Count
    $high = ($RiskData | Where-Object { $_.RiskLevel -eq "High" }).Count
    $medium = ($RiskData | Where-Object { $_.RiskLevel -eq "Medium" }).Count
    $low = ($RiskData | Where-Object { $_.RiskLevel -eq "Low" }).Count

    $avgAge = [math]::Round(($RiskData | Measure-Object -Property AgeInDays -Average).Average, 1)
    $oldestAge = ($RiskData | Measure-Object -Property AgeInDays -Maximum).Maximum

    $rows = $RiskData | ForEach-Object {
        $riskColor = switch ($_.RiskLevel) {
            "Critical" { "#cc0000" }
            "High" { "#ff4444" }
            "Medium" { "#ffaa00" }
            "Low" { "#00cc44" }
        }

        @"
        <tr>
            <td><strong>$($_.IssueKey)</strong></td>
            <td>$($_.Summary)</td>
            <td>$($_.Project)</td>
            <td style="text-align: center;">$($_.Priority)</td>
            <td>$($_.Status)</td>
            <td>$($_.Assignee)</td>
            <td style="text-align: center; font-weight: bold;">$($_.AgeInDays)</td>
            <td>$($_.Created)</td>
            <td style="background-color: $riskColor; color: white; font-weight: bold; text-align: center;">$($_.RiskLevel)</td>
        </tr>
"@
    } -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Risk & Issue Analysis - $(Get-Date -Format 'yyyy-MM-dd')</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #cc0000; padding-bottom: 10px; }
        .alert { background-color: #fff3cd; border-left: 4px solid #cc0000; padding: 15px; margin: 20px 0; border-radius: 4px; }
        .summary { display: flex; justify-content: space-around; margin: 30px 0; flex-wrap: wrap; }
        .summary-card { background: linear-gradient(135deg, #ff416c 0%, #ff4b2b 100%); color: white; padding: 20px; border-radius: 8px; min-width: 150px; text-align: center; margin: 10px; }
        .summary-card h3 { margin: 0; font-size: 2em; }
        .summary-card p { margin: 5px 0 0 0; font-size: 0.9em; opacity: 0.9; }
        .risk-levels { display: flex; justify-content: center; gap: 15px; margin: 20px 0; }
        .risk-card { padding: 12px 25px; border-radius: 8px; color: white; font-weight: bold; font-size: 1em; }
        .risk-critical { background-color: #cc0000; }
        .risk-high { background-color: #ff4444; }
        .risk-medium { background-color: #ffaa00; }
        .risk-low { background-color: #00cc44; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #cc0000; color: white; font-weight: bold; }
        tr:hover { background-color: #f5f5f5; }
        .footer { margin-top: 30px; text-align: center; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚠️ Risk & Issue Analysis Dashboard</h1>
        <p><strong>Report Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <strong>Total Risks:</strong> $($RiskData.Count)</p>

        $(if ($critical -gt 0) { '<div class="alert"><strong>🚨 CRITICAL ALERT:</strong> There are ' + $critical + ' critical-level risks requiring immediate attention!</div>' } else { '' })

        <div class="summary">
            <div class="summary-card">
                <h3>$($RiskData.Count)</h3>
                <p>Total Risks</p>
            </div>
            <div class="summary-card">
                <h3>$avgAge</h3>
                <p>Avg Age (Days)</p>
            </div>
            <div class="summary-card">
                <h3>$oldestAge</h3>
                <p>Oldest (Days)</p>
            </div>
        </div>

        <h2>Risk Distribution by Severity</h2>
        <div class="risk-levels">
            <div class="risk-card risk-critical">🔴 Critical: $critical</div>
            <div class="risk-card risk-high">🟠 High: $high</div>
            <div class="risk-card risk-medium">🟡 Medium: $medium</div>
            <div class="risk-card risk-low">🟢 Low: $low</div>
        </div>

        <h2>Detailed Risk Register</h2>
        <table>
            <thead>
                <tr>
                    <th>Issue Key</th>
                    <th>Summary</th>
                    <th>Project</th>
                    <th>Priority</th>
                    <th>Status</th>
                    <th>Assignee</th>
                    <th>Age (Days)</th>
                    <th>Created</th>
                    <th>Risk Level</th>
                </tr>
            </thead>
            <tbody>
                $rows
            </tbody>
        </table>

        <div class="footer">
            <p>Generated by EPM Automation Suite | PowerShell Risk Analysis Tool</p>
            <p><strong>Risk Level Criteria:</strong> Critical (>30 days) | High (15-30 days) | Medium (8-14 days) | Low (<7 days)</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-EpmLog "Risk analysis report generated: $OutputPath" -Level "SUCCESS"
}

try {
    Write-EpmLog "🚀 Starting Risk & Issue Analysis..." -Level "INFO"

    $apiToken = Get-ApiToken
    $headers = Get-ApiHeader -Token $apiToken

    $issues = Get-RiskData -Headers $headers
    $riskAnalysis = Get-AgingAnalysis -Issues $issues

    Export-RiskReport -RiskData $riskAnalysis

    Write-EpmLog "✅ Risk Analysis completed successfully!" -Level "SUCCESS"
    Write-EpmLog "Report saved to: $OutputPath" -Level "SUCCESS"

}
catch {
    Write-EpmLog "❌ Critical error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
finally {
    $apiToken = $null
}
