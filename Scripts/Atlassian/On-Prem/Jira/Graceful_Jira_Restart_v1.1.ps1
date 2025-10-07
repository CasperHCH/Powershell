<# -- Graceful Jira Restart -- #>
<#
.SYNOPSIS
  Stopper Jira-service, rydder Felix-cache og starter Jira-service igen
.DESCRIPTION
  Dette script har til formål, at sikre at Jira kommer ordentligt op igen efter at serveren har være ude for en non-graceful shutdown.
  Den kører igennem at få stoppet Jira-servicen, clearet en plugin-cache mappe og så herefter starter servicen igen.
.INPUTS
  N/A
.OUTPUTS
  N/A
.NOTES
  Version:        1.1
  Author:         CHGY
  Creation Date:  15/07/2022
  Purpose/Change: Include webservice check and enable transcript
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"



#---------------------------------------------------------[Functions]--------------------------------------------------------

Function StopJiraService {
    Try {
        Write-Output "Stopping $Service service"
        Stop-Service -Name $Service -Force
        Write-Output "$Service service stopped successfully"
    }
    Catch {
        Write-Warning "Failed to stop $Service service"
        $Error[0]
        Break
    }
}

Function ClearFelixCache {
    Try {
        Write-Output "Clearing Felix cache at $FelixPath"
        if (Test-Path $FelixPath) {
            Remove-Item $FelixPath -Recurse -Force
            Write-Output "Felix cache cleared successfully"
        }
    }
    Catch {
        Write-Warning "Failed to clear Felix cache"
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


#----------------------------------------------------------[Declarations]----------------------------------------------------------
$Service = 'JIRASW8_20_8'
$FelixPath = 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix\felix-cache'
$InsightPath = 'D:\Atlassian\jira-software-8.20.8-home\caches\insight_indexes'
$TranscriptPath = '\\FSDKHER01\koncern$\Centrale funk\Økonomi og IT\IT\Drift og Support\Servicedesk\Powershell\Logs\Transcripts'
$ErrorsFound = 0

$LockedError_Str = "locked"
$JiraMonitoringError_Str = "monitoring"
$Insight_Indexes_Str = "indexes"
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Start-Transcript -OutputDirectory $TranscriptPath -Append -Force

#Stop Jira, clear Felix-cache and restart Jira
Write-Warning "Starting Jira restart process" -WarningAction Inquire
Write-Warning "This will stop the Jira service temporarily"

<#-------------------[Test Webservice]----------------------
$HTTP_Request = Invoke-WebRequest -Uri https:\\jira.lm-gruppen.dk
If ($HTTP_Request.StatusCode -ne 200) {
  Write-Output
}
ElseIf ($HTTP_Request.StatusCode -eq 200) {
  Write-Warning  -WarningAction Inquire
}
#>
Write-Output
Write-Verbose -Message
StopJiraService

#-------------------[Checking logs for known error]----------------------

Write-Output
Write-Output

  try {
    $LogFile = Get-Content  #FAKTISK PROD LOG
    #$LogFile = Get-Content  #Test-log
    #$LogFile = Get-Content 'I:\Centrale funk\Økonomi og IT\IT\Drift og Support\Servicedesk\Powershell\atlassian-jira.log' #lokal CHGY dev log
    If ($null -ne $LogFile) {
    Write-Verbose
    }
    Else {
      Write-Error  -ErrorAction Stop
    }
  }
  catch {
    Write-Warning
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
    Write-Output
  }

#------------------Step 3 - Monitoring plugin error:
  Write-Output
  $MonitoringErrorEvent = $logfile | Select-String $JiraMonitoringError_Str | Select-Object * -First 1
  If ($null -ne $MonitoringErrorEvent) {

    Write-Warning
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
    Write-Output
  }

  Write-Output
Write-Output
If ($ErrorsFound -gt 0) {
  If ($MonitoringErrorEventFound -eq 1) {
    Write-Warning
    $Answer = Read-Host -Prompt
    switch -wildcard ($Answer) {
      'j*' {StartJiraService}
      'n*' {Write-Warning ; Stop-Transcript; Break}
      Default {Write-Warning ; Stop-Transcript; Break}
    }
  }
  Write-Output
  StartJiraService
}
Elseif ($ErrorsFound -eq 0) {
  Write-Output
  $Answer = Read-Host -Prompt
  switch -wildcard ($Answer) {
    'j*' {StartJiraService}
    'n*' {Write-Warning ; Stop-Transcript; Break}
    Default {Write-Warning ; Stop-Transcript; Break}
  }
}

Stop-Transcript
