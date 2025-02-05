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
    [ValidateSet(, , , , )]
    [String]
    $Level = ,

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $logfile
  )

  $Stamp = (Get-Date).toString()
  $Line = 
  #If($logfile) {
  Add-Content $slogfile -Value $Line -PassThru
  #}
  #Else {
  #    Write-Output $Line
  #}
}

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

function Load-Module ($m) {
  Write-Log -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
  Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
  # If module is imported say that and do nothing
  if (Get-Module | Where-Object { $_.Name -eq $m }) {
    Write-Host 
    Write-Log -LogPath $sLogFile -TimeStamp -Message 
    Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
  }
  else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
      Import-Module $m -Verbose
    }
    else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
        Install-Module -Name $m -Force -Verbose -Scope CurrentUser
        Import-Module $m -Verbose
        Write-Log -LogPath $sLogFile -TimeStamp -Message 'Module not found, install started'
        Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
      }
      else {

        # If the module is not imported, not available and not in the online gallery then abort
        Write-Host 
        Write-Log -LogPath $sLogFile -TimeStamp -Message 
        Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
        EXIT 1
      }
    }
  }
}

#Import Modules & Snap-ins
#Load-Module

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

#Enabled Logging with timestamps, error level etc..
function Write-Log {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $False)]
    [ValidateSet(, , , , )]
    [String]
    $Level = ,

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $logfile
  )

  $Stamp = (Get-Date).toString()
  $Line = 
  #If($logfile) {
  Add-Content $slogfile -Value $Line -PassThru
  #}
  #Else {
  #    Write-Output $Line
  #}
}

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
    If ($method -eq ) {
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

Write-Log -message 


#Script Execution goes here



Write-Log -message
