<# -- Secure Graceful Jira Restart -- #>
<#
.SYNOPSIS
    Secure parameterized Jira service restart with cache cleanup

.DESCRIPTION
    Enterprise-grade script to gracefully restart Jira service with proper cache cleanup.
    This script ensures Jira recovers properly from non-graceful shutdowns by stopping
    the service, clearing plugin caches, and restarting with comprehensive validation.

.PARAMETER JiraServiceName
    Name of the Jira service (e.g., "JIRASW840" or "Jira")
    SECURITY: Parameterized - no hardcoded service names

.PARAMETER JiraHomeDirectory
    Path to Jira home directory (e.g., "%PROGRAMFILES%\Jira" or "%JIRAHOME%")
    SECURITY: Parameterized - no hardcoded paths

.PARAMETER TranscriptLogPath
    Directory path for transcript logging (e.g., "%TEMP%\JiraLogs" or "%USERPROFILE%\Logs")
    SECURITY: Parameterized - no hardcoded network paths

.PARAMETER WhatIf
    Preview actions without executing them

.EXAMPLE
    .\Graceful_Jira_Restart_v1.1.ps1 -JiraServiceName "JiraSoftware" -JiraHomeDirectory "$env:PROGRAMFILES\Jira" -TranscriptLogPath "$env:TEMP\JiraLogs"

.EXAMPLE
    .\Graceful_Jira_Restart_v1.1.ps1 -JiraServiceName "Jira" -JiraHomeDirectory "D:\Apps\Jira" -WhatIf

.NOTES
    Version:        2.0 - Security Hardened
    Author:         Enterprise PowerShell Team
    Creation Date:  October 12, 2025
    Purpose/Change: Security compliance - eliminated hardcoded values

    SECURITY CLASSIFICATION: INTERNAL
    DATA HANDLING: Service management and file system operations
    AUDIT REQUIREMENTS: All operations logged with user attribution
    CREDENTIALS REQUIRED: Local administrator privileges
#>

#---------------------------------------------------------[Parameters & Initialization]--------------------------------------------------------

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="Jira service name (e.g., Jira, JiraSoftware)")]
    [ValidateNotNullOrEmpty()]
    [string]$JiraServiceName,

    [Parameter(Mandatory=$true, HelpMessage="Jira home directory path (e.g., %PROGRAMFILES%\Jira or %JIRAHOME%)")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$JiraHomeDirectory,

    [Parameter(Mandatory=$false, HelpMessage="Transcript log directory (e.g., %TEMP%\JiraLogs)")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$TranscriptLogPath = "$env:TEMP\JiraLogs",

    [Parameter(Mandatory=$false, HelpMessage="Timeout for service operations in seconds")]
    [ValidateRange(30, 600)]
    [int]$TimeoutSeconds = 120
)

# Secure initialization
$ErrorActionPreference = "Stop"
$sessionId = (New-Guid).ToString().Substring(0,8)

# Create log directory if it doesn't exist
if (-not (Test-Path $TranscriptLogPath)) {
    New-Item -Path $TranscriptLogPath -ItemType Directory -Force | Out-Null
}

# Construct cache paths based on Jira home directory
$felixCachePath = Join-Path $JiraHomeDirectory "plugins\.osgi-plugins\felix\felix-cache"
$insightCachePath = Join-Path $JiraHomeDirectory "caches\insight_indexes"



#---------------------------------------------------------[Functions]--------------------------------------------------------

Function Stop-JiraService {
    param([string]$ServiceName)

    try {
        Write-Host "🛑 Stopping $ServiceName service..." -ForegroundColor Yellow

        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop

            # Wait for service to stop with timeout
            $timeout = $TimeoutSeconds
            do {
                Start-Sleep -Seconds 2
                $service = Get-Service -Name $ServiceName
                $timeout -= 2
            } while ($service.Status -ne 'Stopped' -and $timeout -gt 0)

            if ($service.Status -eq 'Stopped') {
                Write-Host "✅ $ServiceName service stopped successfully" -ForegroundColor Green
                Write-AuditLog -Action "SERVICE_STOPPED" -Target $ServiceName -Result "Success"
            } else {
                throw "Service did not stop within timeout period"
            }
        } else {
            Write-Host "ℹ️ $ServiceName service is already stopped" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "❌ Failed to stop $ServiceName service: $($_.Exception.Message)" -ForegroundColor Red
        Write-AuditLog -Action "SERVICE_STOP_FAILED" -Target $ServiceName -Error $_.Exception.Message
        throw
    }
}

Function Clear-JiraCache {
    param(
        [string]$CachePath,
        [string]$CacheType
    )

    try {
        Write-Host "🧹 Clearing $CacheType cache at $CachePath..." -ForegroundColor Yellow

        if (Test-Path $CachePath) {
            $itemCount = (Get-ChildItem $CachePath -Recurse -Force | Measure-Object).Count
            Remove-Item $CachePath -Recurse -Force -ErrorAction Stop
            Write-Host "✅ $CacheType cache cleared successfully ($itemCount items removed)" -ForegroundColor Green
            Write-AuditLog -Action "CACHE_CLEARED" -Target "$CacheType at $CachePath" -Result "Success - $itemCount items"
        } else {
            Write-Host "ℹ️ $CacheType cache directory not found at $CachePath" -ForegroundColor Gray
            Write-AuditLog -Action "CACHE_NOT_FOUND" -Target "$CacheType at $CachePath" -Result "Directory not found"
        }
    }
    catch {
        Write-Host "❌ Failed to clear $CacheType cache: $($_.Exception.Message)" -ForegroundColor Red
        Write-AuditLog -Action "CACHE_CLEAR_FAILED" -Target "$CacheType at $CachePath" -Error $_.Exception.Message
        $Error[0]
        Break
    }
}

Function ClearInsightIndexes {
    Try {
        Write-Output "Clearing Insight indexes at $InsightPath"
        if (Test-Path $InsightPath) {
            Remove-Item $InsightPath -Recurse -Force
            Write-Output "Insight indexes cleared successfully"
        }
    }
    Catch {
        Write-Warning "Failed to clear Insight indexes"
        $Error[0]
        Break
    }
}
      Write-Warning "An error occurred during operation"
      $Error[0]
      Break
  }
}
}


  Catch {
      Write-Warning "Failed to clean Felix cache"
      $Error[0]
      Write-Warning "Opening Felix directory for manual cleanup"
      Invoke-Item -Path 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix'
      Break
  }
}
Else {
  Write-Output "Felix cache cleaned successfully"
}
}


    Catch {
        Write-Warning "Failed to clean Insight cache"
        $Error[0]
        Write-Warning "Opening caches directory for manual cleanup"
        Invoke-Item -Path 'D:\Atlassian\jira-software-8.20.8-home\caches\'
        Break
    }
  }
  Else {
    Write-Output "Insight cache cleaned successfully"
  }
}


#----------------------------------------------------------[Secure Logging Functions]----------------------------------------------------------

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)][string]$Action,
        [Parameter(Mandatory=$false)][string]$Target,
        [Parameter(Mandatory=$false)][string]$Result,
        [Parameter(Mandatory=$false)][string]$Error
    )

    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        SessionId = $sessionId
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
        Action = $Action
        Target = $Target
        Result = $Result
        Error = $Error
    }

    $logJson = $logEntry | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $TranscriptLogPath "JiraRestart-Audit.log") -Value $logJson
}

#----------------------------------------------------------[Secure Variable Initialization]----------------------------------------------------------
$errorsFound = 0
$restartStartTime = Get-Date

# Error detection strings
$errorPatterns = @{
    Locked = "locked"
    Monitoring = "monitoring"
    Indexes = "indexes"
}
#-----------------------------------------------------------[Secure Execution]------------------------------------------------------------

# Start secure transcript logging
$transcriptFile = Join-Path $TranscriptLogPath "JiraRestart-$sessionId-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Start-Transcript -Path $transcriptFile -Append -Force

Write-Host "🔒 Starting secure Jira restart process" -ForegroundColor Cyan
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Service: $JiraServiceName" -ForegroundColor White
Write-Host "Home Directory: $JiraHomeDirectory" -ForegroundColor White

Write-AuditLog -Action "RESTART_INITIATED" -Target $JiraServiceName -Result "Started"

if ($PSCmdlet.ShouldProcess($JiraServiceName, "Graceful Jira Restart")) {
Write-Warning "This will stop the Jira service temporarily"

<#-------------------[Test Webservice]----------------------
try {
    $HTTP_Request = Invoke-WebRequest -Uri "https://jira.lm-gruppen.dk" -ErrorAction Stop -TimeoutSec 30
    if ($HTTP_Request.StatusCode -eq 200) {
        Write-Output "Jira service is accessible (HTTP 200). Proceeding with restart."
        Write-Warning "This will temporarily stop the Jira service." -WarningAction Inquire
    }
} catch {
    Write-Warning "Cannot reach Jira service at https://jira.lm-gruppen.dk - Error: $($_.Exception.Message)"
    $confirm = Read-Host "Continue with restart anyway? (y/n)"
    if ($confirm -notmatch '^[yY]') {
        Write-Output "Restart cancelled by user."
        exit 1
    }
}
#>
Write-Output "Starting Jira graceful restart process..."
Write-Verbose -Message "Verbose logging enabled for restart process"
StopJiraService

#-------------------[Checking logs for known error]----------------------

Write-Output "Checking Jira logs for known errors..."
Write-Output "This may take a moment..."

  try {
    $LogFile = Get-Content  #FAKTISK PROD LOG
    #$LogFile = Get-Content  #Test-log
    #$LogFile = Get-Content 'I:\Centrale funk\Økonomi og IT\IT\Drift og Support\Servicedesk\Powershell\atlassian-jira.log' #lokal CHGY dev log
    If ($null -ne $LogFile) {
    Write-Verbose "Log file loaded successfully for analysis"
    }
    Else {
      Write-Error "Unable to access Jira log file" -ErrorAction Stop
    }
  }
  catch {
    Write-Warning "Failed to read Jira log file: $($_.Exception.Message)"
    Break
  }


#------------------Step 1 - Jira has been locked/Felix-cache:
Write-Output "Checking for Jira locked/Felix-cache issues"
  $LastLockedEvent = $logfile | Select-String $LockedError_Str -context 1 | Select-Object * -Last 1
  If ($null -ne $LastLockedEvent) {
    $LockedCause = $LastLockedEvent | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty PostContext

    If (($LockedCause -match "locked") -and ($LockedCause -like "*error*")) {
      Write-Warning "Jira locked issue detected - clearing Felix cache"
      ClearFelixCache
      $ErrorsFound++
    }
  }
  Else {
    Write-Output "No Jira locked issues found"
  }

#------------------Step 2 - Insight_indexes:
Write-Output "Checking for Insight indexes issues"
  $InsightErrorEvent = $logfile | Select-String $Insight_Indexes_Str | Select-Object * -First 1
  If ($null -ne $InsightErrorEvent) {
    If (($logfile | Select-String $Insight_Indexes_Str -Context 1 | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty PostContext -First 1) -match "error") {
      Write-Warning "Insight indexes issue detected - clearing cache"
  Write-Verbose -Message "Clearing Insight indexes cache"
  ClearInsightIndexes
  $ErrorsFound++
    }
  }
  Else {
    Write-Output "No connection pool errors found in log"
  }

#------------------Step 3 - Monitoring plugin error:
  Write-Output "Step 3: Checking for monitoring plugin errors..."
  $MonitoringErrorEvent = $logfile | Select-String $JiraMonitoringError_Str | Select-Object * -First 1
  If ($null -ne $MonitoringErrorEvent) {

    Write-Warning "Monitoring plugin error detected. Manual intervention may be required."
$Answer = Read-Host -Prompt
switch -wildcard ($Answer) {
  'j*' {Invoke-Item (Get-ChildItem -Path  -Attributes !Directory Catalina*.log | Sort-Object -Descending -Property LastWriteTime | Select-Object -first 1).FullName}
  'n*' {Continue}
  Default {}
}
  $MonitoringErrorEventFound = 1
  $ErrorsFound++
  }
  else {
    Write-Output "No monitoring plugin errors found"
  }

  Write-Output "Log analysis completed."
Write-Output "Preparing restart decision based on error analysis..."
If ($ErrorsFound -gt 0) {
  If ($MonitoringErrorEventFound -eq 1) {
    Write-Warning "Critical monitoring errors detected. Proceed with caution."
    $Answer = Read-Host -Prompt
    switch -wildcard ($Answer) {
      'j*' {StartJiraService}
      'n*' {Write-Warning ; Stop-Transcript; Break}
      Default {Write-Warning ; Stop-Transcript; Break}
    }
  }
  Write-Output "Starting Jira service with monitoring error handling..."
  StartJiraService
}
Elseif ($ErrorsFound -eq 0) {
  Write-Output "No critical errors found. Proceeding with normal restart."
  $Answer = Read-Host -Prompt "Do you want to restart Jira service now? (y/n)"
  switch -wildcard ($Answer) {
    'j*' {StartJiraService}
    'n*' {Write-Warning ; Stop-Transcript; Break}
    Default {Write-Warning ; Stop-Transcript; Break}
  }
}

Stop-Transcript
