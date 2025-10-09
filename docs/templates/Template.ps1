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
	    2 Outputs will be produced.
  1. Log file is stored next to the script execution.
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
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Enabled Logging with timestamps, error level etc..
function Write-Log {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $False)]
    [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
    [String]$Level = "Info",

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $logfile
  )

  $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"

  If($logfile) {
    Add-Content $logfile -Value $Line -PassThru
  } Else {
    Write-Output $Line
  }
  Else {
    Write-Output $Line
  }
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

##	Change Aliases	##
#	Changing alias for Curl
Remove-Item alias:curl -Force
New-Alias curl curl.exe
#	Curl changed

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Invoke-WebRequest {
  Param (
    [Parameter(Mandatory = $true)]
    [string]$url,
    [Parameter(Mandatory = $true)]
    [string]$uri,
    [Parameter(Mandatory = $true)]
    [string]$method,
    [Parameter(Mandatory = $false)]
    [string]$Body,
    [Parameter(Mandatory = $false)]
    [string]$token
  )

  ### On-prem Auth
  $headers = @{}
  $headers.Add('Accept', 'application/json')
  $headers.Add('content-type', 'application/json')
  $headers.Add('Authorization', 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($username + ':' + $password)))

#Allowing for easier web requests

  ### END OF On-prem auth

  ### Cloud Auth
  #$headers = @{
  #  'Authorization' = 'Bearer ' + $token
  #  'Accept' = 'application/json'
  #  'content-type' = 'application/json'
  #}
  ### END OF Cloud Auth
  $uri = $url + $uri

  try {
    If ($method -eq 'GET') {
      $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    else {
      $response = Invoke-RestMethod -Uri $uri -Method $method -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -Headers $headers
    }
  }
  catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $response = $reader.ReadToEnd()
    $message = $response
    $message +=  + $uri +  + $_.Exception
    Write-Log -Message $message
  }
  return $response
}
<# USE THIS TEMPLATE FUNCTION FOR ALL
Function <FunctionName> {
  Param ()
  Begin {
    Write-Log -Message "Function started - Script v$sScriptVersion" -logfile $sLogFile
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

Function FunctionName {
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












<#
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message "Starting script execution - Version: $sScriptVersion" -logfile $sLogFile


#Script Execution goes here



Write-Log -message
