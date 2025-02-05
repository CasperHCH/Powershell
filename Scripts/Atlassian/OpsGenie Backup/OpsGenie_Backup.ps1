#requires -version 4
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER apiKey
  Input the API of a given site, to export the configuration
.INPUTS
  None
.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\OpsGenie Backup.log
 .OUTPUTS Backupfile
  The script will create a new folder called , and then rename it to the current account name, once the backup is done.
  The Backup will be placed at $PSScriptRoot
.NOTES
  Version:        1.0
  Author:         CHC
  Creation Date:  24-08-2022
  Purpose/Change: Backup OpsGenie configuration
.EXAMPLE
  .\OpsGenie_Backup.ps1
  Will start a switch case for known API keys, to grab a backup of the chosen site
  
 .EXAMPLE
  .\OpsGenie_Backup.ps1 -apiKey XX-YY-ZZ
  Will start the backup process of the given API Key site.

#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
  $apiKey
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Log File Info
$sLogPath = 'C:\Windows\Temp'
$sLogName = 'OpsGenie Backup.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

Write-LogInfo -LogPath $sLogFile -Message 'Initialisations started'
Write-LogInfo -LogPath $sLogFile -Message ' '
#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'
Write-LogInfo -LogPath $sLogFile -Message 'Changing alias, allowed to run CURL'
Write-LogInfo -LogPath $sLogFile -Message ' '
##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed
Write-LogInfo -LogPath $sLogFile -Message 'Change complete'
Write-LogInfo -LogPath $sLogFile -Message ' '


#Import Modules & Snap-ins
function Load-Module ($m) {
Write-LogInfo -LogPath $sLogFile -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host 
		Write-LogInfo -LogPath $sLogFile -Message 
		Write-LogInfo -LogPath $sLogFile -Message ' '
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
				Write-LogInfo -LogPath $sLogFile -Message 'Module not found, install started'
				Write-LogInfo -LogPath $sLogFile -Message ' '
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host 
				Write-LogInfo -LogPath $sLogFile -Message 
				Write-LogInfo -LogPath $sLogFile -Message ' '
                EXIT 1
            }
        }
    }
}

Load-Module PSLogging

Write-LogInfo -LogPath $sLogFile -Message 'Initialisations completed'
Write-LogInfo -LogPath $sLogFile -Message ' '
#----------------------------------------------------------[Declarations]----------------------------------------------------------
Write-LogInfo -LogPath $sLogFile -Message 'Declarations started'
Write-LogInfo -LogPath $sLogFile -Message ' '

#Script Version
$sScriptVersion = '1.0'

##Log File Info
#$sLogPath = 'C:\Windows\Temp'
#$sLogName = 'OpsGenie Backup.log'
#$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#To rename the backup Folder, we need the account name
$FolderName = $null

Write-LogInfo -LogPath $sLogFile -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
######### SELECT API #########

function SelectAPI(){
	Write-LogInfo -LogPath $sLogFile -Message 'Switchcase started to select an account'
	Write-LogInfo -LogPath $sLogFile -Message ' '
    Write-Host  -ForegroundColor Green
    Write-Host -ForegroundColor Green
    Write-Host -ForegroundColor Green
	Write-Host -ForegroundColor Green

    $Selection = Read-Host 
    switch ($Selection)
        {
            '1' {#Option 1 is selected
                    'You chose option #1 - TrialSite'
                    
                    $script:apiKey = '3df04bcd-b699-4fae-b19f-50f219666590'
					Write-LogInfo -LogPath $sLogFile -Message 'TrialSite selected'
					Write-LogInfo -LogPath $sLogFile -Message ' '
                }#End Option 1
               
                
                 
            '2' {#Option 2 is selected
                'You chose option #2 - PandoraDigital'
                 
                    $script:apiKey = '39500cda-727f-424f-b53e-d9829b9c93aa'
					Write-LogInfo -LogPath $sLogFile -Message 'PandoraDigital selected'
					Write-LogInfo -LogPath $sLogFile -Message ' '               
                }#end option 2
				
				
			'3' {#Option 3 is selected
                'You chose option #3 - to be filled in'
                 
                    $script:apiKey = 'xxx'
					Write-LogInfo -LogPath $sLogFile -Message 'to be filled in selected'
					Write-LogInfo -LogPath $sLogFile -Message ' '
                
                }#end option 3
        Default {Write-Host  -ForegroundColor Red
				Write-LogInfo -LogPath $sLogFile -Message 'Switchcase = Invalid entry.'
				Write-LogInfo -LogPath $sLogFile -Message ' '}#END Default
        }#End Switch
}#End Function


######### Do Backup #########



  Process {
    Try {
      java -jar OpsGenieExportUtil-0.23.7.jar --apiKey $apiKey
    }
    Catch {
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully
      Break
    }
  }
  End {
    If ($?) {
      Write-LogInfo -LogPath $sLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $sLogFile -Message ' '
    }
  }
}

########## Collect AccountName #########

  Process {
    Try {	   
		if($script:Data = curl -X GET https://api.eu.opsgenie.com/v2/account --header  ){}
		Else{
			$script:Data = curl -X GET https://api.opsgenie.com/v2/account --header 
		}
    }
    Catch {
		
			Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully
      Break
    }
  }
  End {
    If ($?) {
      Write-LogInfo -LogPath $sLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $sLogFile -Message ' '
    }
  }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here#
if($apiKey -eq $null)
{SelectAPI}
doBackup
CollectAccountName
		$AccountName = $Data | ConvertFrom-Json
		$FolderName = $AccountName.data.name
if($FolderName -ne $null) {	New-Item $PSScriptRoot\$FolderName -itemType Directory
							Move-Item -Path $PSScriptRoot\OpsGenieBackups -Destination $FolderName
							Write-LogInfo -LogPath $sLogFile -Message 
							Write-LogInfo -LogPath $sLogFile -Message ' '}
Write-LogInfo -LogPath $sLogFile -Message 'Script completed Successfully.'
Write-LogInfo -LogPath $sLogFile -Message ' '
Stop-Log -LogPath $sLogFile
