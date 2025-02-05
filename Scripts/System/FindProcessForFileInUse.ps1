#requires -version 2
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  Find the process which is blocking a file
.PARAMETER $FileOrFolderPath
    Insert the full path of the  file
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         CHC
  Creation Date:  08/11/2022
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
  [Path]$FileOrFolderPath
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = 

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
        write-host 
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 
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
                write-host 
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 
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

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
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
Function Write-Log {
    param (
        [Parameter(Mandatory=$False, Position=0)]
        [String]$Entry
    )

     | Out-File -FilePath $sLogFile -Append
}


  
  Process{
    Try{
      if ((Test-Path -Path $FileOrFolderPath) -eq $false) {
    Write-Warning        
	}
	else {
		$LockingProcess = CMD /C 
		Write-Host $LockingProcess
		}
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


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $scriptname -ScriptVersion $sScriptVersion
FindProcess
Log-Finish -LogPath $sLogFile
