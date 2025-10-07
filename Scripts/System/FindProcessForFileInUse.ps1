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
$sLogFile = Join-Path $sLogPath "$($sLogName -replace '\.ps1$','')_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Validate required parameter
if (-not $FileOrFolderPath) {
    $FileOrFolderPath = Read-Host "Enter the full path of the file or folder to check"
}

if (-not (Test-Path $FileOrFolderPath)) {
    Write-Error "File or folder not found: $FileOrFolderPath"
    exit 1
}

# Simple logging function if Write-LogInfo is not available
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    function Write-LogInfo {
        param([string]$LogPath, [switch]$TimeStamp, [string]$Message)
        $logEntry = if ($TimeStamp) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" } else { $Message }
        Write-Host $logEntry
        Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
}

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Initialisations started for: $FileOrFolderPath"
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#Set Error Action to Continue
$ErrorActionPreference = 'Continue'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Process detection started'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '


#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported." -ForegroundColor Green
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
                write-host "Module $m not imported, not available and not in an online gallery, exiting." -ForegroundColor Red
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

    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Entry" | Out-File -FilePath $sLogFile -Append
}



  Process{
    Try{
      if ((Test-Path -Path $FileOrFolderPath) -eq $false) {
    Write-Warning "File or folder path '$FileOrFolderPath' does not exist."
	}
	else {
		$LockingProcess = CMD /C "handle.exe \"$FileOrFolderPath\""
		Write-Host "Locking process: $LockingProcess" -ForegroundColor Yellow
		}
	}

    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }

  End{
    If($?){
      Write-Log -Entry "Process detection completed successfully."
      Write-Log -Entry "Script execution finished."
    }
  }
}


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $scriptname -ScriptVersion $sScriptVersion
FindProcess
Log-Finish -LogPath $sLogFile
