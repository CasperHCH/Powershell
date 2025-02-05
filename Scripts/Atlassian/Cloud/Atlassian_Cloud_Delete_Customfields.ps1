#requires -version 2
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
 $url,
 $List,
 $AdminAccount,
 $ApiToken
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = 
$now = Get-Date

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
    Write-LogInfo -LogPath $sLogFile -Message 
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
        Write-LogInfo -LogPath $sLogFile -Message  
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

Write-LogInfo -LogPath $sLogFile -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
<#
Function <FunctionName>{
 Param()
 
 Begin{
  Write-Log -Entry 
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
   Write-Log -Entry 
   Write-Log -Entry 
  }
 }
}
#>

Function Write-Log {
  param (
    [Parameter(Mandatory=$False, Position=0)]
    [String]$Entry
  )

   | Out-File -FilePath $sLogFile -Append
}
######### GetUrl #########

 
 Process{
  Try{
		$url = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
		$script:url = $url.TrimEnd('/')
  }
  
  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Entry 
   Write-Log -Entry 
  }
 }
}

######### Collect CSV #########
function CollectList(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'CollectList started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''
	while(1){
		try{
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '	
			
			$script:List = import-csv -path (read-host -prompt 'provide csv path')
		break
		}
		Catch{
			write-host 
			
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '	
		}
	}

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '	
}
######### Import provided CSV #########
function ImportCSV(){
Begin{
  	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'ImportCSV started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''
 }
 Process{
  Try{
   $script:List = import-csv -path $List
  }
  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }
 End{
  If($?){
   Write-Log -Entry 
   Write-Log -Entry 
  }
 }
}

######### Collect Admin account email #########

 
 Process{
  Try{
   $script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
	 	Write-LogInfo -LogPath $sLogFile -Message 
		Write-LogInfo -LogPath $sLogFile -Message ' '
  }
  
  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Entry 
   Write-Log -Entry 
  }
 }
}

######### Provide API Token#########

 
 Process{
  Try{
   $script:ApiToken = read-host -prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
	 	Write-LogInfo -LogPath $sLogFile -Message 
		Write-LogInfo -LogPath $sLogFile -Message ' '
  }
  
  Catch{
   Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
   Break
  }
 }
 
 End{
  If($?){
   Write-Log -Entry 
   Write-Log -Entry 
  }
 }
}
######### DeleteCustomFields #########
:${ApiToken}Deleting $($id.id)"
			}

}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $scriptname -ScriptVersion $sScriptVersion
#Script Execution goes here#
if($url -eq $null)
{GetUrl}
if($List -eq $null)
{CollectList}
else {ImportCSV}
if($AdminAccount -eq $null)
{CollectAdminAccount}
if($ApiToken -eq $null)
{ProvideAPIToken}
DeleteCustomFields
Log-Finish -LogPath $sLogFile
