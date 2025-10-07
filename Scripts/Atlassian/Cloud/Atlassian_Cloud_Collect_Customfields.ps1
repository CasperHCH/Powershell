﻿#requires -version 2
<#
.SYNOPSIS
 <Overview of script>
.DESCRIPTION
 <Brief description of script>
.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
 <Inputs if any, otherwise state None>
.OUTPUTS
 <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
 Version:    1.0
 Author:     <Name>
 Creation Date: <Date>
 Purpose/Change: Initial script development

.EXAMPLE
 <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
 #Script parameters go here
 [String]$url,
 [String]$AdminAccount,
 [String]$ApiToken
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = "$sLogPath\$sLogName.log"

Write-LogInfo -LogPath $sLogFile -Message 'Initialisations started'
Write-LogInfo -LogPath $sLogFile -Message ' '
#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'
Write-LogInfo -LogPath $sLogFile -Message 'Changing alias, allowed to run CURL'
Write-LogInfo -LogPath $sLogFile -Message ' '
##	Change Aliases	##
#	Changing alias for Curl
  Remove-Item alias:curl -force
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
    write-host "Module $m is already imported."
		Write-LogInfo -LogPath $sLogFile -Message "Module $m is already imported."
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
        write-host "Module $m not imported, not available and not in an online gallery, exiting."
				Write-LogInfo -LogPath $sLogFile -Message "Module $m not imported, not available and not in an online gallery, exiting."
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

Write-LogInfo -LogPath $sLogFile -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
<#
Function <FunctionName>{
 Param()

 Begin{
  Write-Log -Entry "<description of what is going on>..."
 }

 Process{
  Try{
   <code goes here>
  }

  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }

 End{
  If($?){
   Write-Log -Entry "Completed Successfully."
   Write-Log -Entry " "
  }
 }
}
#>

Function Write-Log {
  param (
    [Parameter(Mandatory=$False, Position=0)]
    [String]$Entry
  )

  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Entry" | Out-File -FilePath $sLogFile -Append
}
######### GetUrl #########
Function GetUrl{
 Param()

 Begin{
  Write-LogInfo -LogPath $sLogFile -Message 'GetUrl started'
	Write-LogInfo -LogPath $sLogFile -Message 'Asking initiator to insert a URL for an Atlassian Cloud site.'
 }

 Process{
  Try{
		$UserInputURL = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
		$script:url = $UserInputURL.TrimEnd('/')
  }

  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }

 End{
  If($?){
   Write-Log -Entry "Completed Successfully."
   Write-Log -Entry " "
  }
 }
}
######### Collect Admin account email #########
Function CollectAdminAccount{
 Param()

 Begin{
  	Write-LogInfo -LogPath $sLogFile -Message 'CollectAdminAccount started'
		Write-LogInfo -LogPath $sLogFile -Message ''
 }

 Process{
  Try{
   $script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
	 	Write-LogInfo -LogPath $sLogFile -Message "AdminAccount Token collected as $AdminAccount"
		Write-LogInfo -LogPath $sLogFile -Message ' '
  }

  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }

 End{
  If($?){
   Write-Log -Entry "Completed Successfully."
   Write-Log -Entry " "
  }
 }
}

######### Provide API Token#########
Function ProvideAPIToken{
 Param()

 Begin{
  	Write-LogInfo -LogPath $sLogFile -Message 'ProvideAPIToken started'
		Write-LogInfo -LogPath $sLogFile -Message ''
 }

 Process{
  Try{
   $script:ApiToken = read-host -prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
	 	Write-LogInfo -LogPath $sLogFile -Message "API Token collected as $ApiToken"
		Write-LogInfo -LogPath $sLogFile -Message ' '
  }

  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }

 End{
  If($?){
   Write-Log -Entry "Completed Successfully."
   Write-Log -Entry " "
  }
 }
}
######### CollectCustomFields #########
Function CollectCustomFields{
 Param()

 Begin{
  	Write-LogInfo -LogPath $sLogFile -Message 'CollectCustomFields started'
		Write-LogInfo -LogPath $sLogFile -Message 'We dont know how many fields there is - lets assume many... #1000?'
 }

 Process{
  Try{
		$startInt = 0
		Write-LogInfo -LogPath $sLogFile -Message "CollectCustomFields started"
		Write-LogInfo -LogPath $sLogFile -Message ' '
			while($startInt -lt 1001){
				curl --URL "$($url)/rest/api/3/field/search?startAt=$($startInt)" --USER $($AdminAccount):$($token) | Out-File -FilePath "$($sLogPath)\$($sLogName).json" -Append
				Write-LogInfo -LogPath $sLogFile -Message "$($startInt) CustomFields collected and added to $($sLogPath)\$($sLogName).json"
				Write-LogInfo -LogPath $sLogFile -Message ' '

				$startInt += 50
			}
  }

  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }

 End{
  If($?){
   Write-Log -Entry "Completed Successfully."
   Write-Log -Entry " "
  }
 }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $scriptname -ScriptVersion $sScriptVersion
#Script Execution goes here#
if($url -eq $null)
{GetUrl}
if($AdminAccount -eq $null)
{CollectAdminAccount}
if($ApiToken -eq $null)
{ProvideAPIToken}
CollectCustomFields
Log-Finish -LogPath $sLogFile