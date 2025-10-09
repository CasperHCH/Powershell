#requires -version 2
<#
.SYNOPSIS
  Disables a user on Confluence Data Center
.DESCRIPTION
  Uses the Confluence REST API to update the user's status to  effectively disabling the user.
.PARAMETER <CONFLUENCE_BASE_URL>
    The base URL of the Confluence instance
.PARAMETER <USERNAME>
    The username of the user to be disabled
.PARAMETER <ADMIN_USERNAME>
    The username of an admin user on Confluence
.PARAMETER <ADMIN_PASSWORD>
    The password of an admin user on Confluence
.INPUTS
  None
.OUTPUTS
  Outputs a message indicating whether the user was successfully disabled or not.
.NOTES
  Version:        1.0
  Author:         OpenAI
  Creation Date:  2022-12-22
  Purpose/Change: Initial script development

.EXAMPLE
  Disable-ConfluenceUser -confluenceUrl  -USERNAME  -adminUsername  -adminPassword
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
  [String]$confluenceUrl,
  [String]$username,
  [String]$adminUsername,
  [String]$adminPassword
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = "$sLogPath\$($sLogName.Replace('.ps1',''))_$(Get-Date -Format 'yyyy-MM-dd').log"

#Enabling log
Function Write-Log {
    param (
        [Parameter(Mandatory=$False, Position=0)]
        [String]$Entry
    )

     | Out-File -FilePath $sLogFile -Append
}

Write-Log -LogPath $sLogFile -TimeStamp -Message 'Initialisations started'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'
Write-Log -LogPath $sLogFile -TimeStamp -Message 'Changing alias, allowed to run CURL'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
##	Change Aliases	##
#	Changing alias for Curl
    del alias:curl -force
    new-alias curl curl.exe
#	Curl changed
Write-Log -LogPath $sLogFile -TimeStamp -Message 'Change complete'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '


#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
Write-Log -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        Write-Host "Module $m is already loaded"
		Write-Log -LogPath $sLogFile -TimeStamp -Message "Module $m is already loaded"
		Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
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
				Write-Log -LogPath $sLogFile -TimeStamp -Message "Module $m installed and imported successfully"
				Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                Write-Host "Module $m is not available and cannot be installed"
				Write-Log -LogPath $sLogFile -TimeStamp -Message "Module $m is not available and cannot be installed"
				Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
                EXIT 1
            }
        }
    }
}
#Load modules here
#Example: Load-Module PSLogging

Write-Log -LogPath $sLogFile -TimeStamp -Message 'Initialisations completed'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
#----------------------------------------------------------[Declarations]----------------------------------------------------------
Write-Log -LogPath $sLogFile -TimeStamp -Message 'Declarations started'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '

Write-Log -LogPath $sLogFile -TimeStamp -Message 'Declarations completed'
Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
#All script functions goes here
#Use this template:
<#Function <FunctionName>{
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



  Process{
    Try{
     # Set the user's status to
		$updateUserUrl = "$baseUrl/rest/api/user?username=$username"
		$updateUserBody = '{"active":false}'
		$updateUserResponse = Invoke-RestMethod -Method Put -Uri $updateUserUrl -Body $updateUserBody -ContentType "application/json" -Headers $headers
	# Check the response to see if the update was successful
		if ($updateUserResponse.status -eq "success") {
			Write-Log "User $username disabled successfully"
			}
		else {
			Write-Log "Failed to disable user $username"
			}
		}

    Catch{
      Write-Log -ExitGracefully $True
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


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -Entry
Write-Log -Entry
Write-Log -Entry
#Script Execution goes here

# Set up the basic auth header
$authHeader = ( -f $adminUsername, $adminPassword)
$authHeader = [System.Text.Encoding]::UTF8.GetBytes($authHeader)
$authHeader = [System.Convert]::ToBase64String($authHeader)
$headers = @{Authorization=( -f $authHeader)}

DisableUser

#No new executions below
Write-Log -Entry
