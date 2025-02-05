#requires -version 4
<#
.SYNOPSIS
	<Overview of script>
.DESCRIPTION
	<Brief description of script>
.PARAMETER UserList
    A full path to a CSV containing the following fields;
    Name, Mail, SamAccountName
    An example of how to produce the list could be;
    get-aduser -Filter {mail -like  -or mail -like } -SearchBase  -Properties name, mail, samaccountname | Select-Object name, mail, samaccountname | Export-Csv C:\Temp\script_csv_files\KnowITEmailUsers.csv
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	A log file, and a final CSV export of collected input; Name, Mail, SamAccountName and UPN.
    Files will be located next to the script
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
    $UserList
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
Load-Module AzureAD
Connect-AzureAD

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
$sOutputPath = $MyInvocation.MyCommand.Path | Split-Path -Parent
$sOutputName = $MyInvocation.MyCommand.Name 
$sOutputName = $sOutputName -replace '.ps1', '.csv'
$sOutputFile = Join-Path -Path $sOutputPath -ChildPath $sOutputName 
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
            #csv contains a list of users extracted from Miracle Local AD, containing only the properties mail and samaccountname
            #get-aduser -Filter {mail -like  -or mail -like } -SearchBase  -Properties name, mail, samaccountname | Select-Object name, mail, samaccountname | Export-Csv C:\Temp\script_csv_files\KnowITEmailUsers.csv
            Write-Log -Message 
            $extn = [IO.Path]::GetExtension($UserList)
            if ($extn -eq  ) {
                write-log -Message 
                $script:iul = Import-Csv $UserList
                Write-Log -Message 
            }
            else { 
                Write-Log -Message  
            }
        }
        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'GetOldADUserObjects Completed Successfully.'
            Write-Log -Message ' '
        }
    }
}

    Process {
        Try {
            foreach ($user in $iul) { 
                
                    $name           = $user.name
                    $mail           = $user.mail
                    $samaccountname = $user.samaccountname
                    $filter         = 
                    $KnowITUser     = Get-AzureADUser -Filter $filter | Select-Object UserPrincipalName
                    $upn            = $KnowITUser.UserPrincipalName

                    New-Object -TypeName PSCustomObject -Property @{
                        name=$name 
                        mail=$mail
                        samaccountname = $samaccountname
                        upn = $upn} | Export-Csv $sOutputFile -NoTypeInformation -Append
                }
            
            #Write-Host 
            #Write-Log -Message 
        }
        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'GetAzureUserObject Completed Successfully.'
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
GetOldADUserObjects
GetAzureUserObject


Write-Log -message
