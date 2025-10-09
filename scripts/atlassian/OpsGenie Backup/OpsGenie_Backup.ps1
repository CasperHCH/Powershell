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
function Import-ModuleIfAvailable ($m) {
Write-LogInfo -LogPath $sLogFile -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported" -ForegroundColor Green
        Write-LogInfo -LogPath $sLogFile -Message "Module $m is already imported"
        Write-LogInfo -LogPath $sLogFile -Message ' '
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
            Write-LogInfo -LogPath $sLogFile -Message "Module $m imported from local system"
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
                write-host "Module $m is not available. Please install manually." -ForegroundColor Red
                Write-LogInfo -LogPath $sLogFile -Message "Module $m is not available and cannot be installed"
                Write-LogInfo -LogPath $sLogFile -Message ' '
                EXIT 1
            }
        }
    }
}

Import-ModuleIfAvailable PSLogging

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
    
    # Define environment configurations
    $environments = @{
        '1' = @{
            Name = 'TrialSite'
            CredentialFile = "$env:USERPROFILE\OpsGenie_TrialSite_Credential.xml"
        }
        '2' = @{
            Name = 'PandoraDigital'
            CredentialFile = "$env:USERPROFILE\OpsGenie_PandoraDigital_Credential.xml"
        }
        '3' = @{
            Name = 'Custom Environment'
            CredentialFile = "$env:USERPROFILE\OpsGenie_Custom_Credential.xml"
        }
    }

    if ($environments.ContainsKey($Selection)) {
        $selectedEnv = $environments[$Selection]
        Write-Host "You chose option #$Selection - $($selectedEnv.Name)" -ForegroundColor Green
        Write-LogInfo -LogPath $sLogFile -Message "$($selectedEnv.Name) selected"

        # Load or prompt for API key
        try {
            if (Test-Path $selectedEnv.CredentialFile) {
                Write-Host "Loading stored API key for $($selectedEnv.Name)..." -ForegroundColor Yellow
                $secureApiKey = Import-Clixml -Path $selectedEnv.CredentialFile
                $script:apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey))
                Write-LogInfo -LogPath $sLogFile -Message "API key loaded from secure storage"
            } else {
                Write-Host "No stored API key found for $($selectedEnv.Name)" -ForegroundColor Yellow
                $apiKeyInput = Read-Host "Enter OpsGenie API key for $($selectedEnv.Name)" -AsSecureString
                $script:apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeyInput))
                
                $saveChoice = Read-Host "Save API key securely for future use? (y/N)"
                if ($saveChoice -eq 'y' -or $saveChoice -eq 'Y') {
                    $apiKeyInput | Export-Clixml -Path $selectedEnv.CredentialFile
                    Write-Host "API key saved securely to: $($selectedEnv.CredentialFile)" -ForegroundColor Green
                    Write-LogInfo -LogPath $sLogFile -Message "API key saved to secure storage"
                }
            }
        }
        catch {
            Write-Host "Error loading API key: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogInfo -LogPath $sLogFile -Message "Error loading API key: $($_.Exception.Message)"
            return
        }

        Write-LogInfo -LogPath $sLogFile -Message "API key configured for $($selectedEnv.Name)"
        Write-LogInfo -LogPath $sLogFile -Message ' '
    } else {
        Write-Host "Invalid selection. Please choose 1, 2, or 3." -ForegroundColor Red
        Write-LogInfo -LogPath $sLogFile -Message 'Switchcase = Invalid entry.'
        Write-LogInfo -LogPath $sLogFile -Message ' '
        return
    }
}#End Function


######### Do Backup #########
function doBackup {
  [CmdletBinding()]
  param()

  Process {
    Try {
      Write-LogInfo -LogPath $sLogFile -Message "Starting OpsGenie backup with API key: $apiKey"
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
function CollectAccountName {
  [CmdletBinding()]
  param()

  Process {
    Try {
		if($script:Data = curl -X GET https://api.eu.opsgenie.com/v2/account --header "Authorization: GenieKey $apiKey" ){
			Write-LogInfo -LogPath $sLogFile -Message "Successfully retrieved account data from EU API"
		}
		Else{
			$script:Data = curl -X GET https://api.opsgenie.com/v2/account --header "Authorization: GenieKey $apiKey"
			Write-LogInfo -LogPath $sLogFile -Message "Retrieved account data from US API"
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
