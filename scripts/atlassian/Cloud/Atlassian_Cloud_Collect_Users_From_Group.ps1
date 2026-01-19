#requires -version 2
<#
.SYNOPSIS
 Collects all users from a specified Atlassian Cloud group and exports them to a JSON file.

.DESCRIPTION
 This script retrieves all members from an Atlassian Cloud group using the Jira REST API v3. It handles
 pagination automatically by iterating through the group membership in batches of 50 users (up to 5000 total).
 The script prompts for required credentials and outputs results to a JSON file in the script directory.

 Active users are collected from the specified group and appended to a JSON output file for further processing
 or auditing purposes.

.PARAMETER url
 The base URL of your Atlassian Cloud site (e.g., https://yoursite.atlassian.net).
 Do not include a trailing slash. If not provided, the script will prompt for it.

.PARAMETER AdminAccount
 The email address of the Atlassian administrator account used to generate the API token.
 This account must have permissions to view group membership. If not provided, the script will prompt for it.

.PARAMETER ApiToken
 The API token for authentication with the Atlassian Cloud API.
 Can be generated at: https://id.atlassian.com/manage-profile/security/api-tokens
 If not provided, the script will prompt for it.

.PARAMETER GroupId
 The unique identifier (GUID format) of the group from which to extract users.
 Example format: 1X2X3X4-5Y6Y7Y8-0Z1Z2Z3
 If not provided, the script will prompt for it.

.INPUTS
 None. Parameters can be passed via command line or entered interactively.

.OUTPUTS
 - JSON file: <script_directory>\<script_name>.ps1.json (Contains paginated user data)
 - Log file: <script_directory>\<script_name>.ps1.log (Detailed execution log)

.NOTES
 Version:        1.0
 Author:         CHC
 Creation Date:  19/05/2023
 Purpose/Change: Initial script development

 Requirements:
  - PowerShell 2.0 or higher
  - PSLogging module (auto-installed if not present)
  - curl.exe (Windows 10/11 built-in)
  - Valid Atlassian Cloud administrator credentials
  - Network connectivity to Atlassian Cloud

 Security Considerations:
  - API tokens should be handled securely and not hardcoded
  - Log files may contain sensitive information - protect accordingly
  - Ensure proper permissions for the executing account

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group.ps1

 Runs interactively, prompting for all required parameters (URL, admin account, API token, and group ID).

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group.ps1 -url "https://mysite.atlassian.net" -AdminAccount "admin@company.com" -ApiToken "your-api-token-here" -GroupId "12345678-abcd-1234-efgh-567890abcdef"

 Runs with all parameters provided, collecting users from the specified group without interactive prompts.

.EXAMPLE
 .\Atlassian_Cloud_Collect_Users_From_Group.ps1 -url "https://mysite.atlassian.net" -GroupId "12345678-abcd-1234-efgh-567890abcdef"

 Runs with partial parameters, prompting only for the missing AdminAccount and ApiToken values.
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

param (
  #Script parameters go here
  [String]$url,
  [String]$AdminAccount,
  [String]$ApiToken,
  [String]$GroupId
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
del alias:curl -Force
New-Alias curl curl.exe
#	Curl changed
Write-LogInfo -LogPath $sLogFile -Message 'Change complete'
Write-LogInfo -LogPath $sLogFile -Message ' '


#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
  Write-LogInfo -LogPath $sLogFile -Message 'Import Modules'
  Write-LogInfo -LogPath $sLogFile -Message ' '
  # If module is imported say that and do nothing
  if (Get-Module | Where-Object { $_.Name -eq $m }) {
    Write-Host "Module $m is already imported."
    Write-LogInfo -LogPath $sLogFile -Message "Module $m is already imported."
    Write-LogInfo -LogPath $sLogFile -Message ' '
    break
  }
  else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
      Import-Module $m -Verbose
      break
    }
    else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
        Install-Module -Name $m -Force -Verbose -Scope CurrentUser
        Import-Module $m -Verbose
        Write-LogInfo -LogPath $sLogFile -Message 'Module not found, install started'
        Write-LogInfo -LogPath $sLogFile -Message ' '
        break
      }
      else {

        # If the module is not imported, not available and not in the online gallery then abort
        Write-Host "Module $m not imported, not available and not in an online gallery, exiting."
        Write-LogInfo -LogPath $sLogFile -Message "Module $m not imported, not available and not in an online gallery, exiting."
        Write-LogInfo -LogPath $sLogFile -Message ' '
        exit 1
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

function Write-Log {
  param (
    [Parameter(Mandatory = $False, Position = 0)]
    [String]$Entry
  )

  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Entry" | Out-File -FilePath $sLogFile -Append
}
######### GetUrl #########
function GetUrl {
  param()

  begin {
    Write-LogInfo -LogPath $sLogFile -Message 'GetUrl started'
    Write-LogInfo -LogPath $sLogFile -Message 'Asking initiator to insert a URL for an Atlassian Cloud site.'
  }

  process {
    try {
      $UserInputURL = Read-Host -Prompt 'provide the URL of your jira cloud site - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
      $script:url = $UserInputURL.TrimEnd('/')
    }

    catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      break
    }
  }

  end {
    if ($?) {
      Write-Log -Entry "Completed Successfully."
      Write-Log -Entry " "
    }
  }
}
######### Collect Admin account email #########
function CollectAdminAccount {
  param()

  begin {
    Write-LogInfo -LogPath $sLogFile -Message 'CollectAdminAccount started'
    Write-LogInfo -LogPath $sLogFile -Message ''
  }

  process {
    try {
      $script:AdminAccount = Read-Host -Prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
      Write-LogInfo -LogPath $sLogFile -Message "AdminAccount Token collected as $AdminAccount"
      Write-LogInfo -LogPath $sLogFile -Message ' '
    }

    catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      break
    }
  }

  end {
    if ($?) {
      Write-Log -Entry "Completed Successfully."
      Write-Log -Entry " "
    }
  }
}

######### Provide API Token#########
function ProvideAPIToken {
  param()

  begin {
    Write-LogInfo -LogPath $sLogFile -Message 'ProvideAPIToken started'
    Write-LogInfo -LogPath $sLogFile -Message ''
  }

  process {
    try {
      $script:ApiToken = Read-Host -Prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
      Write-LogInfo -LogPath $sLogFile -Message "API Token collected as $ApiToken"
      Write-LogInfo -LogPath $sLogFile -Message ' '
    }

    catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      break
    }
  }

  end {
    if ($?) {
      Write-Log -Entry "Completed Successfully."
      Write-Log -Entry " "
    }
  }
}
######### GetGroupID #########
function GetGroupID {
  param()

  begin {
    Write-LogInfo -LogPath $sLogFile -Message 'GetGroupID started'
    Write-LogInfo -LogPath $sLogFile -Message 'Asking initiator to insert the GroupID for the wanted Group'
  }

  process {
    try {
      $script:GroupID = Read-Host -Prompt 'provide the GroupID from where you wish to extract all users - e.g. 1X2X3X4-5Y6Y7Y8-0Z1Z2Z3'
    }

    catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      break
    }
  }

  end {
    if ($?) {
      Write-Log -Entry "Completed Successfully."
      Write-Log -Entry " "
    }
  }
}
######### CollectUsersFromGroup #########
function CollectUsersFromGroup {
  param()

  begin {
    Write-LogInfo -LogPath $sLogFile -Message 'CollectUsersFromGroup started'
    Write-LogInfo -LogPath $sLogFile -Message 'We dont know how many users there is - lets assume many... #5000?'
  }

  process {
    try {
      $startInt = 0
      Write-LogInfo -LogPath $sLogFile -Message "CollectUsersFromGroup started"
      Write-LogInfo -LogPath $sLogFile -Message ' '
      while ($startInt -lt 5001) {
        curl --URL "$($url)/rest/api/3/group/member?includeInactiveUsers=false&groupId=$($GroupID)&?startAt=$startInt" --USER "${using:AdminAccount}:${using:ApiToken}" --header 'Accept: application/json' | Out-File -FilePath "$($sLogPath)\$($sLogName).json" -Append
        Write-LogInfo -LogPath $sLogFile -Message "$($startInt) UsersFromGroup collected and added to $($sLogPath)\$($sLogName).json"
        Write-LogInfo -LogPath $sLogFile -Message ' '

        $startInt += 50
      }
    }

    catch {
      #Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      break
    }
  }

  end {
    if ($?) {
      Write-Log -Entry "Completed Successfully."
      Write-Log -Entry " "
    }
  }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $scriptname -ScriptVersion $sScriptVersion
#Script Execution goes here#
if ($url -eq $null)
{ GetUrl }
if ($AdminAccount -eq $null)
{ CollectAdminAccount }
if ($ApiToken -eq $null)
{ ProvideAPIToken }
if ($GroupID -eq $null)
{ GetGroupID }
CollectUsersFromGroup
Log-Finish -LogPath $sLogFile