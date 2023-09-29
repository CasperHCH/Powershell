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
function StopJiraService {
  #-------------------[Check Jira Service]----------------------
  If ((Get-Service -Name $Service).status -eq "running") {
    Try {

Write-Warning "
------------ ADVARSEL ---------------------
*                                         *
*             JIRA STOPPES                *
*          ER DU HELT SIKKER?             *
*                                         *
------------ ADVARSEL ---------------------" -WarningAction Inquire
    Write-Output "Jira-servicen kører. Forsøger at stoppe..."
    Stop-Service -Name $Service -Verbose
    (Get-Service -Name $Service).WaitForStatus('Stopped')
    Write-Output "Jira-servicen er nu stoppet..."
    }
    Catch {
        Write-Warning "Noget gik galt - Servicen kunne ikke stoppes"
        $Error[0]
        Break
    }
  }
  Else {
  Write-Output "Jira-service er allerede stoppet. Går videre..."
  }
}

function StartJiraService {
#-------------------[Restart Jira-service]----------------------
If ((Get-Service -Name $Service).Status -eq 'Stopped') {
  Write-Output "Starter Jira-servicen..."
  Try {
      Start-Service -Name $Service -Verbose
      (Get-Service -Name $Service).WaitForStatus('Running')
      Write-Output "Jira-servicen er nu startet... Jira vil være tilgængeligt om ca. 15 minutter."
  }
  Catch {
      Write-Warning "Noget gik galt - Servicen kunne ikke startet"
      $Error[0]
      Break
  }
}
}

function ClearFelixCache {
#-------------------[Check Felix-Cache]----------------------
#Hvis mappen er der
If (Test-Path 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix\felix-cache') {
  Try {
      Write-Output "Fjerner Felix-cache mappen..."
      Remove-Item -Path $FelixPath -Recurse -Force
      Write-Output "Felix-cache mappen er nu fjernet."
  }
  Catch {
      Write-Warning "Noget gik galt - Felix-cache kunne ikke fjernes."
      $Error[0]
      Write-Warning "Tjek manuelt at $service er stoppet.`n
      Tilgå Felix-cache mappen på D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix\felix-cache og slet/omdøb mappen 'felix-cache'`n
      Kør scriptet her igen efterfølgende."
      Invoke-Item -Path 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix'
      Break            
  }
}
Else {
  Write-Output "Felix-cache mappen findes ikke... Går videre..."
}
}

function ClearInsightIndexes {
  #-------------------[Check Felix-Cache]----------------------
  #Hvis mappen er der
  If (Test-Path 'D:\Atlassian\jira-software-8.20.8-home\caches\insight_indexes') {
    Try {
        Write-Output "Fjerner Insight_Indexes mappen..."
        Remove-Item -Path $InsightPath -Recurse -Force
        Write-Output "Insight_indexes mappen er nu fjernet."
    }
    Catch {
        Write-Warning "Noget gik galt - Insight_indexes kunne ikke fjernes."
        $Error[0]
        Write-Warning "Tjek manuelt at $service er stoppet.`n
        Tilgå Insight_indexes mappen på D:\Atlassian\jira-software-8.20.8-home\caches\insight_indexes og slet/omdøb mappen 'insight_indexes'`n
        Kør scriptet igen efterfølgende."
        Invoke-Item -Path 'D:\Atlassian\jira-software-8.20.8-home\caches\'
        Break            
    }
  }
  Else {
    Write-Output "Insight_Indexes mappen findes ikke... Går videre til opstart af service"
  }
}
  

#----------------------------------------------------------[Declarations]----------------------------------------------------------
$Service = 'JIRASW8_20_8'
$FelixPath = 'D:\Atlassian\jira-software-8.20.8-home\plugins\.osgi-plugins\felix\felix-cache'
$InsightPath = 'D:\Atlassian\jira-software-8.20.8-home\caches\insight_indexes'
$TranscriptPath = '\\FSDKHER01\koncern$\Centrale funk\Økonomi og IT\IT\Drift og Support\Servicedesk\Powershell\Logs\Transcripts'
$ErrorsFound = 0

$LockedError_Str = "JIRA has been locked"
$JiraMonitoringError_Str = "jira-monitoring-plugin ERROR"
$Insight_Indexes_Str = "Unable to read objects from file"
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Start-Transcript -OutputDirectory $TranscriptPath -Append -Force

#Stop Jira, clear Felix-cache and restart Jira
Write-Warning "Dette script stopper Jira-servicen, tjekker logs, rydder caches og genstarter Jira-servicen. Jira vil være utilgængeligt i minimum 10 minutter.
Er du sikker på at du vil fortsætte?
" -WarningAction Inquire 
Write-Warning "Fortsætter...
"

<#-------------------[Test Webservice]----------------------
$HTTP_Request = Invoke-WebRequest -Uri https:\\jira.lm-gruppen.dk
If ($HTTP_Request.StatusCode -ne 200) {
  Write-Output "jira.lm-gruppen svarer ikke. fortsætter...
"
}
ElseIf ($HTTP_Request.StatusCode -eq 200) {
  Write-Warning "jira.lm-gruppen.dk svarer som den skal.
Er du sikker på at du vil fortsætte?
" -WarningAction Inquire
}
#>
Write-Output "`n------------ [Step 1 - Stop Jira Service]------------"
Write-Verbose -Message "Running StopJiraService"
StopJiraService

#-------------------[Checking logs for known error]----------------------

Write-Output "`n------------ [Step 2 - Hentning af logfil]------------"
Write-Output "Henter logfil (atlassian-jira.log)`n"

  try {
    $LogFile = Get-Content "D:\Atlassian\jira-software-8.20.8-home\log\atlassian-jira.log" #FAKTISK PROD LOG
    #$LogFile = Get-Content "D:\Atlassian\jira-software-8.20.8-home\atlassian-jira_TESTLOG_TEST.log" #Test-log
    #$LogFile = Get-Content 'I:\Centrale funk\Økonomi og IT\IT\Drift og Support\Servicedesk\Powershell\atlassian-jira.log' #lokal CHGY dev log
    If ($null -ne $LogFile) { 
    Write-Verbose "Logfil indlæst...
    "
    }
    Else {
      Write-Error "Der var ingen data i logfilen!" -ErrorAction Stop
    }
  }
  catch {
    Write-Warning "Logfil findes ikke.
    Manuel fejlsøgning må pågås?..."
    Break
  }


#------------------Step 1 - Jira has been locked/Felix-cache: 
Write-Output "`n------------ [Step 3 - Locked Jira/Felix Cache]------------
Søger efter kendt streng 'Jira has been locked' + '\felix'... (Felix-cache korruption)
"
  $LastLockedEvent = $logfile | Select-String $LockedError_Str -context 1 | Select-Object * -Last 1
  If ($null -ne $LastLockedEvent) {
    $LockedCause = $LastLockedEvent | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty PostContext

    If (($LockedCause -match "cache directory") -and ($LockedCause -like "*.osgi-plugins\felix")) {
      Write-Warning "
Locked event fundet i loggen.
Timestamp for locked event: $($LastLockedEvent.Line.Substring(0,19))
Mulig årsag: $LockedCause

Felix-cache korruption fundet. Igangsætter oprydning...
"
      ClearFelixCache
      $ErrorsFound++
    }
  }
  Else {
    Write-Output "Der blev ikke fundet 'Locked Event' i loggen..."
  }

#------------------Step 2 - Insight_indexes:
Write-Output "`n------------ [Step 4 - Insight_indexes] ------------
Søger efter kendt streng 'Unable to read objects from file'... (Insight_indexes korruption)
"
  $InsightErrorEvent = $logfile | Select-String $Insight_Indexes_Str | Select-Object * -First 1
  If ($null -ne $InsightErrorEvent) {
    If (($logfile | Select-String "Unable to read objects from file" -Context 1 | Select-Object -ExpandProperty Context | Select-Object -ExpandProperty PostContext -First 1) -match "Stream ended prematurely") {
      Write-Warning "
Insight ERROR fundet i loggen.
Timestamp for første event: $($InsightErrorEvent.Line.Substring(0,19))
Mulig årsag: Insight cache korrupt. 

Insight_indexes korruption fundet. Igangsætter oprydning...
"
  Write-Verbose -Message "Running ClearInsightIndexes..."
  ClearInsightIndexes
  $ErrorsFound++
    }
  }
  Else {
    Write-Output "Der blev ikke fundet Insight_indexes korruption i loggen..."
  }

#------------------Step 3 - Monitoring plugin error: 
  Write-Output "`n------------ [Step 5 - Monitoring-Plugin Error] ------------
  Søger efter kendt streng 'jira-monitoring-plugin ERROR'... (Catalina/Apache Tomcat fejl i opstart)
  "
  $MonitoringErrorEvent = $logfile | Select-String $JiraMonitoringError_Str | Select-Object * -First 1
  If ($null -ne $MonitoringErrorEvent) {

    Write-Warning "
Monitoring-plugin ERROR fundet i loggen.
Timestamp for første event: $($MonitoringErrorEvent.Line.Substring(0,19))
Mulig årsag: Catalina/Apache. Tjek nyeste Catalina log i D:\Atlassian\jira-software-8.20.8\logs\catalina.YYYY.MM.DD.log

Der blev fundet fejl som peger på problemer med Catalina / Apache Tomcat. 
Logs bør tjekkes på placering 'D:\Atlassian\jira-software-8.20.8\logs\catalina.YYYY.MM.DD.log. 
"  
$Answer = Read-Host -Prompt "Vil du åbne Catalina-loggen? (Ja/Nej)"
switch -wildcard ($Answer) {
  'j*' {Invoke-Item (Get-ChildItem -Path "D:\Atlassian\jira-software-8.20.8\logs" -Attributes !Directory Catalina*.log | Sort-Object -Descending -Property LastWriteTime | Select-Object -first 1).FullName}
  'n*' {Continue}
  Default {}
}
  $MonitoringErrorEventFound = 1
  $ErrorsFound++
  }
  else {
    Write-Output "Der blev ikke fundet 'Monitoring-plugin ERROR' i loggen..."
  }

  Write-Output "`n------------ [Step 6 - Opstart af Jira] ------------"
Write-Output "Der blev fundet i alt $ErrorsFound fejl"
If ($ErrorsFound -gt 0) {
  If ($MonitoringErrorEventFound -eq 1) {
    Write-Warning "Der blev fundet fejl i Catalina / Apache opstarten..."
    $Answer = Read-Host -Prompt "Vil du genstarte Jira Service alligevel? (Ja/Nej)"
    switch -wildcard ($Answer) {
      'j*' {StartJiraService}
      'n*' {Write-Warning "Afslutter scriptet. Jira ER IKKE STARTET..."; Stop-Transcript; Break}
      Default {Write-Warning "Afslutter scriptet. Jira ER IKKE STARTET..."; Stop-Transcript; Break}
    }
  }
  Write-Output "Jira service igangsættes igen"
  StartJiraService
}
Elseif ($ErrorsFound -eq 0) {
  Write-Output "Der blev ikke fundet nogle kendte fejl."
  $Answer = Read-Host -Prompt "Vil du genstarte Jira Service alligevel? (Ja/Nej)"
  switch -wildcard ($Answer) {
    'j*' {StartJiraService}
    'n*' {Write-Warning "Afslutter scriptet. Jira ER IKKE STARTET..."; Stop-Transcript; Break}
    Default {Write-Warning "Afslutter scriptet. Jira ER IKKE STARTET..."; Stop-Transcript; Break}
  }
}

Stop-Transcript








