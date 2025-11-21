<#
.SYNOPSIS
    Master launcher for EPM Automation Suite.

.DESCRIPTION
    Interactive menu to launch any EPM automation report quickly.
    Simplifies execution and provides a unified interface for all reports.

.PARAMETER JiraBaseUrl
    The base URL of your Jira instance (will be prompted if not provided).

.PARAMETER CloudId
    The Cloud ID for service account authentication (will be prompted if not provided).

.PARAMETER ServiceAccountEmail
    Service account email (will be prompted if not provided).

.EXAMPLE
    .\Start-EPMAutomation.ps1

.EXAMPLE
    .\Start-EPMAutomation.ps1 -JiraBaseUrl "https://company.atlassian.net" -CloudId "abc-123" -ServiceAccountEmail "bot@serviceaccount.atlassian.com"

.NOTES
    Author: EPM Automation Suite
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$CloudId,

    [Parameter(Mandatory = $false)]
    [string]$ServiceAccountEmail
)

function Show-Banner {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║            EPM AUTOMATION SUITE FOR JIRA                     ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║         Enterprise Project Management Automation             ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "                     AVAILABLE REPORTS                        " -ForegroundColor Yellow
    Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] 📊 Portfolio Health Dashboard" -ForegroundColor Green
    Write-Host "      Generate executive portfolio health insights (RAG status)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] 👥 Resource Capacity Report" -ForegroundColor Green
    Write-Host "      Analyze team workload and resource utilization" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] 📋 Automated Status Report" -ForegroundColor Green
    Write-Host "      Weekly/Monthly status report for stakeholders" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] ⚠️  Risk & Issue Analysis" -ForegroundColor Green
    Write-Host "      Portfolio risk register and aging analysis" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] ⚙️  Configure Settings" -ForegroundColor Green
    Write-Host "      Update Jira connection settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [0] ❌ Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Yellow
}

function Get-ProjectKeys {
    Write-Host ""
    Write-Host "Enter project keys to analyze (comma-separated):" -ForegroundColor Cyan
    Write-Host "Example: PROJ1, PROJ2, PROJ3" -ForegroundColor Gray
    $input = Read-Host "Project Keys"
    return $input -split "," | ForEach-Object { $_.Trim() }
}

function Get-Configuration {
    if (-not $script:JiraBaseUrl) {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║              JIRA CONNECTION CONFIGURATION                   ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        $script:JiraBaseUrl = Read-Host "Enter Jira Base URL (e.g., https://company.atlassian.net)"

        Write-Host ""
        Write-Host "Do you want to use Service Account authentication? (Y/N)" -ForegroundColor Yellow
        $useServiceAccount = Read-Host

        if ($useServiceAccount -eq "Y" -or $useServiceAccount -eq "y") {
            $script:CloudId = Read-Host "Enter Cloud ID"
            $script:ServiceAccountEmail = Read-Host "Enter Service Account Email"
        }
        else {
            $script:CloudId = $null
            $script:ServiceAccountEmail = $null
        }

        Write-Host ""
        Write-Host "✅ Configuration saved for this session!" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
}

function Invoke-Report {
    param([string]$ScriptName, [hashtable]$Parameters)

    $scriptPath = Join-Path $PSScriptRoot $ScriptName

    if (-not (Test-Path $scriptPath)) {
        Write-Host ""
        Write-Host "❌ Error: Script not found at $scriptPath" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    try {
        Write-Host ""
        Write-Host "🚀 Launching $ScriptName..." -ForegroundColor Cyan
        Write-Host ""

        & $scriptPath @Parameters

        Write-Host ""
        Write-Host "✅ Report generation completed!" -ForegroundColor Green
        Write-Host ""

        # Ask if user wants to open the report
        $openReport = Read-Host "Open the report now? (Y/N)"
        if ($openReport -eq "Y" -or $openReport -eq "y") {
            $reportPath = Get-ChildItem -Path $PSScriptRoot -Filter "*.html" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

            if ($reportPath) {
                Start-Process $reportPath.FullName
            }
        }

    }
    catch {
        Write-Host ""
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

# Script-level variables
$script:JiraBaseUrl = $JiraBaseUrl
$script:CloudId = $CloudId
$script:ServiceAccountEmail = $ServiceAccountEmail

# Main loop
do {
    Show-Banner

    # Show current configuration
    if ($script:JiraBaseUrl) {
        Write-Host "Current Configuration:" -ForegroundColor Cyan
        Write-Host "  Jira URL: $script:JiraBaseUrl" -ForegroundColor Gray
        if ($script:ServiceAccountEmail) {
            Write-Host "  Service Account: $script:ServiceAccountEmail" -ForegroundColor Gray
            Write-Host "  Cloud ID: $script:CloudId" -ForegroundColor Gray
        }
        else {
            Write-Host "  Auth Method: Personal API Token" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Show-Menu

    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1" {
            Get-Configuration
            $projects = Get-ProjectKeys

            $params = @{
                JiraBaseUrl = $script:JiraBaseUrl
                ProjectKeys = $projects
            }

            if ($script:CloudId) {
                $params.CloudId = $script:CloudId
                $params.ServiceAccountEmail = $script:ServiceAccountEmail
            }

            Invoke-Report -ScriptName "Get-PortfolioHealthDashboard.ps1" -Parameters $params
        }

        "2" {
            Get-Configuration
            $projects = Get-ProjectKeys

            $params = @{
                JiraBaseUrl = $script:JiraBaseUrl
                ProjectKeys = $projects
            }

            if ($script:CloudId) {
                $params.CloudId = $script:CloudId
                $params.ServiceAccountEmail = $script:ServiceAccountEmail
            }

            Invoke-Report -ScriptName "Get-ResourceCapacityReport.ps1" -Parameters $params
        }

        "3" {
            Get-Configuration
            $projects = Get-ProjectKeys

            Write-Host ""
            Write-Host "Select report period:" -ForegroundColor Cyan
            Write-Host "  [1] Weekly" -ForegroundColor Gray
            Write-Host "  [2] Monthly" -ForegroundColor Gray
            $periodChoice = Read-Host "Period"
            $period = if ($periodChoice -eq "2") { "Monthly" } else { "Weekly" }

            $params = @{
                JiraBaseUrl  = $script:JiraBaseUrl
                ProjectKeys  = $projects
                ReportPeriod = $period
            }

            if ($script:CloudId) {
                $params.CloudId = $script:CloudId
                $params.ServiceAccountEmail = $script:ServiceAccountEmail
            }

            Invoke-Report -ScriptName "New-AutomatedStatusReport.ps1" -Parameters $params
        }

        "4" {
            Get-Configuration
            $projects = Get-ProjectKeys

            $params = @{
                JiraBaseUrl = $script:JiraBaseUrl
                ProjectKeys = $projects
            }

            if ($script:CloudId) {
                $params.CloudId = $script:CloudId
                $params.ServiceAccountEmail = $script:ServiceAccountEmail
            }

            Invoke-Report -ScriptName "Get-RiskIssueAnalysis.ps1" -Parameters $params
        }

        "5" {
            $script:JiraBaseUrl = $null
            $script:CloudId = $null
            $script:ServiceAccountEmail = $null
            Get-Configuration
        }

        "0" {
            Write-Host ""
            Write-Host "Thank you for using EPM Automation Suite!" -ForegroundColor Cyan
            Write-Host ""
            break
        }

        default {
            Write-Host ""
            Write-Host "❌ Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }

} while ($choice -ne "0")
