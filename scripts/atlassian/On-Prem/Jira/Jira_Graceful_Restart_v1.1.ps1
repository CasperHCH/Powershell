#requires -version 4
<#
.SYNOPSIS
    Gracefully restarts the Jira service, clears caches, and handles known errors.
.DESCRIPTION
    This script stops the Jira service, clears specific caches (Felix and Insight indexes), and restarts the Jira service.
    It also checks logs for known errors and provides options for handling them interactively.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Version:        1.2
    Author:         CHGY (Improved by GitHub Copilot)
    Creation Date:  15/07/2022
    Purpose/Change: Completed and optimized the script for better error handling and functionality.
#>

# --- Initializations ---
$ErrorActionPreference = "Stop"

# --- Parameters ---
$Service = 'JIRASW8_20_8'
$FelixPath = 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix\felix-cache'
$InsightPath = 'D:\Atlassian\jira-software-8.20.8-home\caches\insight_indexes'
$TranscriptPath = 'D:\Atlassian\Jira_Graceful_Restart_Transcript.txt'
$LogFilePath = 'D:\Atlassian\jira-software-8.20.8-home\log\atlassian-jira.log'

# Error patterns to search for in logs
$LockedError_Str = "Jira has been locked"
$JiraMonitoringError_Str = "Monitoring plugin error"
$Insight_Indexes_Str = "Insight index error"

$ErrorsFound = 0
$MonitoringErrorEventFound = 0

# --- Functions ---
function StopJiraService {
    Write-Output "Stopping Jira service..."
    try {
        Stop-Service -Name $Service -Force -ErrorAction Stop
        Write-Output "Jira service stopped successfully."
    } catch {
        Write-Warning "Failed to stop Jira service: $($_.Exception.Message)"
        throw
    }
}

function StartJiraService {
    Write-Output "Starting Jira service..."
    try {
        Start-Service -Name $Service -ErrorAction Stop
        Write-Output "Jira service started successfully."
    } catch {
        Write-Warning "Failed to start Jira service: $($_.Exception.Message)"
        throw
    }
}

function ClearFelixCache {
    Write-Output "Clearing Felix cache..."
    try {
        Remove-Item -Path $FelixPath -Recurse -Force -ErrorAction Stop
        Write-Output "Felix cache cleared successfully."
    } catch {
        Write-Warning "Failed to clear Felix cache: $($_.Exception.Message)"
        throw
    }
}

function ClearInsightIndexes {
    Write-Output "Clearing Insight indexes..."
    try {
        Remove-Item -Path $InsightPath -Recurse -Force -ErrorAction Stop
        Write-Output "Insight indexes cleared successfully."
    } catch {
        Write-Warning "Failed to clear Insight indexes: $($_.Exception.Message)"
        throw
    }
}

function CheckLogsForErrors {
    Write-Output "Checking logs for known errors..."
    try {
        $LogFile = Get-Content -Path $LogFilePath -ErrorAction Stop

        # Step 1: Check for locked errors
        $LastLockedEvent = $LogFile | Select-String $LockedError_Str -Context 1 | Select-Object -Last 1
        if ($null -ne $LastLockedEvent) {
            Write-Warning "Locked error found in logs."
            ClearFelixCache
            $ErrorsFound++
        }

        # Step 2: Check for Insight index errors
        $InsightErrorEvent = $LogFile | Select-String $Insight_Indexes_Str -First 1
        if ($null -ne $InsightErrorEvent) {
            Write-Warning "Insight index error found in logs."
            ClearInsightIndexes
            $ErrorsFound++
        }

        # Step 3: Check for monitoring plugin errors
        $MonitoringErrorEvent = $LogFile | Select-String $JiraMonitoringError_Str -First 1
        if ($null -ne $MonitoringErrorEvent) {
            Write-Warning "Monitoring plugin error found in logs."
            $MonitoringErrorEventFound = 1
            $ErrorsFound++
        }
    } catch {
        Write-Warning "Failed to check logs: $($_.Exception.Message)"
        throw
    }
}

# --- Execution ---
Start-Transcript -Path $TranscriptPath -Append -Force
Write-Output "Starting Jira graceful restart process..."

try {
    # Stop Jira service
    StopJiraService

    # Check logs for known errors
    CheckLogsForErrors

    # Handle errors if found
    if ($ErrorsFound -gt 0) {
        if ($MonitoringErrorEventFound -eq 1) {
            Write-Warning "Monitoring plugin error detected. Do you want to restart Jira? (y/n)"
            $Answer = Read-Host "Enter your choice"
            if ($Answer -match "y") {
                StartJiraService
            } else {
                Write-Warning "Jira service not restarted due to user input."
                Stop-Transcript
                return
            }
        } else {
            Write-Output "Restarting Jira service after resolving errors..."
            StartJiraService
        }
    } else {
        Write-Output "No errors found. Restarting Jira service..."
        StartJiraService
    }
} catch {
    Write-Warning "An error occurred during the Jira restart process: $($_.Exception.Message)"
} finally {
    Stop-Transcript
    Write-Output "Jira graceful restart process completed."
}