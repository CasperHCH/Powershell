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
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
  [String]$Url,
  [String]$OrgID,
  [String]$AdminAccount,
  [String]$PersonalAccessToken,
  [String]$list
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Enabled Logging with timestamps, error level etc..
function Write-Log {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $False)]
    [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $logfile
  )

  $Stamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss.fff")
  $Line = "$Stamp $Level $Message"
  #If($logfile) {
  Add-Content $slogfile -Value $Line -PassThru
  #}
  #Else {
  #    Write-Output $Line
  #}
}

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

$sOutputPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sOutputName = $sLogName -replace '.ps1', '.log'
$sOutputFile = Join-Path -Path $sLogPath -ChildPath $sLogName
##	Change Aliases	##
#	Changing alias for Curl
Remove-Item alias:curl -Force
New-Alias curl curl.exe
#	Curl changed

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#Enabled Logging with timestamps, error level etc..
function Write-Log {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $False)]
    [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $logfile
  )

  $Stamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss.fff")
  $Line = "$Stamp $Level $Message"
  Add-Content $slogfile -Value $Line -PassThru
}

<# USE THIS TEMPLATE FUNCTION FOR ALL
Function <FunctionName> {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      <code goes here>
    }
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}
#>
<#
ALL ACTIVE FUNCTIONS BELOW
#>
$list = "C:\Users\caspe\Downloads\export-users.csv"
Function ImportFile {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      if (Test-Path $list) {
        $script:file = Import-Csv $list
        $file."user id"
      }
    }
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}
Function CollectApiInfo {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      $OrgID = '9k709933-bb51-192j-7jc5-d4b58k4a81bd'
      $PersonalAccessToken = 'ATCTT3xFfGN0U2Jwm-Bzn0JN9ABNH4keYzC5Y1CfbhiW05njF84gXLg6e970Sr8mQKXrxVcFuUtZ3lI1PfYfmIuWbZERwemMXRc_4eXYjwc-TGVbiyA8tAeb1KCJntiJKDzBHEspB64IfoobuTNKQokgxCvxE6u62c53O1QiIXDkFKFKp0ENFoE=367C1DB0'
      $auth = 'Authorization: Bearer ' + $PersonalAccessToken + ''
        foreach ($uid in $file."user id") {
          $user_id = ''+$uid+''
          $users = curl --request GET --url 'https://api.atlassian.com/admin/v1/orgs/'+$OrgID+'/directory/users/'+$user_id+'/last-active-dates' --header $auth --header 'Accept: application/json' | ConvertFrom-Json
          foreach ($u in $users) {
            [PSCustomObject]@{
              UserID     = $uid
              Product    = $u.data.product_access.key 
              Last_Login = $u.data.product_access.last_active
            } | Export-Csv $sOutputFile -Append
          }
        }
      }
      #$users = curl --request GET  --url 'https://api.atlassian.com/admin/v1/orgs/9k709933-bb51-192j-7jc5-d4b58k4a81bd/users' --header $auth --header 'Accept: application/json' | ConvertFrom-Json
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}











<#
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message "Starting Script, $sScriptVersion"


#Script Execution goes here



Write-Log -message "End of Script"