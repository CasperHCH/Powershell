#requires -version 4
<#
.SYNOPSIS
  Needed a "smart" way to deleting bulk groups, created from the single line of "curl --request DELETE --url 'https://your-domain.atlassian.net/rest/api/3/group?groupId={groupId}' --user 'test@domain.com:XYZ"
.DESCRIPTION
  <Brief description of script>
.PARAMETER OrgKey
  Input the API of a organization, from where you wish to delete groups.
.PARAMETER url
  Input URL of the site, e.g. https://test-site.atlassian.net
.PARAMETER List
  Provide the path to a csv list, which contains a list of groups Atlassian Account ID's (GroupID)
.INPUTS
  CSV List of groups, for deletion - default exported group list works!
.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\AtlassianCloudDeletegroups.log
.NOTES
  Version:        1.0
  Author:         CHC
  Creation Date:  21-09-2022
  Purpose/Change: Delete atlassian cloud groups from a single Org.
.EXAMPLE
  .\AtlassianCloudDeletegroups.ps1 -url https://test-site.atlassian.net
   Will ask for all the parameters, and then if all is provided correctly, the deletion process will start.
 .EXAMPLE
  .\AtlassianCloudDeletegroups.ps1 -url https://test-site.atlassian.net -List c:\temp\Grouplist.csv
   Will ask for all the parameters, and then if all is provided correctly, the deletion process will start.
 .EXAMPLE
  .\AtlassianCloudDeletegroups.ps1 -url https://test-site.atlassian.net -List c:\temp\Grouplist.csv -AdminAccount test@domain.com
   Will ask for all the parameters, and then if all is provided correctly, the deletion process will start.
 .EXAMPLE
  .\AtlassianCloudDeletegroups.ps1 -url https://test-site.atlassian.net -List c:\temp\Grouplist.csv -AdminAccount test@domain.com -ApiToken XYZ
   Will start the deletion process
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
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Initialisations started'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Changing alias, allowed to run CURL'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Change complete'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '


#Import Modules & Snap-ins
function Load-Module ($m) {
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Module $m is already imported."
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
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
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Module not found, install started'
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Module $m not imported, not available and not in an online gallery, exiting."
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
                EXIT 1
            }
        }
    }
}

Load-Module PSLogging

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Initialisations completed'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#----------------------------------------------------------[Declarations]----------------------------------------------------------
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Declarations started'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogPath = 'C:\Windows\Temp'
$sLogName = 'AtlassianCloudDeletegroups.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
######### GetUrl #########
function GetUrl(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'GetUrl started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''

	$UserInput-URL = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
	$script:url = $UserInput-URL.TrimEnd('/')

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "url imported"
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
}
######### Collect CSV #########
function CollectList(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'CollectList started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''
	while(1){
		try{
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "While loop entered, waiting for CSV path"
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '

			$script:GroupIDList = import-csv -path (read-host -prompt 'provide csv path')
		break
		}
		Catach{
			write-host "Not a valid CSV, try again, expected header for Groups is : ID"

			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Not a valid CSV inserted"
			Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
		}
	}

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ""
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
}
######### Import provided CSV #########
function ImportCSV(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'ImportCSV started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''

	$script:GroupIDList = import-csv -path $List

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Import done"
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
}
######### Collect Admin account email #########
function CollectAdminAccount(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'CollectAdminAccount started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''

	$script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Email address provided"
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
}
######### Provide API Token#########
function ProvideAPIToken(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'ProvideAPIToken started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '

	$script:ApiToken = read-host -prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'

	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "API Token collected as $ApiToken"
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
}
######### DELETE BULK groups FROM LIST #########
function Delete(){
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Deletion started'
	Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ''

	foreach ($GroupID in $GroupIDList){
	curl --request DELETE --url "$url/rest/api/3/group?groupId=$($GroupID.'Group ID')" --user "${AdminAccount}:${ApiToken}" -verbose
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message $GroupID.'Group ID'
	}
#$GroupIDList | ForEach-Object -Parallel {
#    curl --request DELETE --url "$using:url/rest/api/3/group?groupId=$($GroupID.'Group ID')" --user "${using:AdminAccount}:${using:ApiToken}" -verbose
#    Write-LogInfo -LogPath $using:sLogFile -TimeStamp -Message $_.'Group ID'
#	}

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
Delete
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Script completed Successfully.'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
Stop-Log -LogPath $sLogFile