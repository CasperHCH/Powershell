#requires -version 4
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
    [String]$url,
    [String]$AdminAccount,
    [String]$ApiToken,
    [String]$List,
    [String]$GroupName
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'



function Import-ModuleIfAvailable ($m) {
    Write-Log -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
    Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        write-host
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
                write-host
                Write-Log -LogPath $sLogFile -TimeStamp -Message
                Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
                EXIT 1
            }
        }
    }
}

#Import Modules & Snap-ins
#Import-Module

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#############################################################################################
##    Change Aliases    ##
#    Changing alias for Curl
Remove-Item alias:curl -force
new-alias curl curl.exe
#    Curl changed

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
<#
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
######### GetUrl #########


    Process {
        Try {
            $UserInputURL = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
            $script:url = $UserInputURL.TrimEnd('/')
        }

        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }

    End {
        If ($?) {
            Write-Log -Message
            Write-Log -Message
        }
    }
}
######### Collect Admin account email #########


    Process {
        Try {
            $script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account username'
            Write-Log -Message
            Write-Log -Message ' '
        }

        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }

    End {
        If ($?) {
            Write-Log -Message
            Write-Log -Message
        }
    }
}

######### Provide API Token#########


    Process {
        Try {
            $script:ApiToken = read-host -prompt 'Please insert admin account password'
            Write-Log -Message
            Write-Log -Message ' '
        }

        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }

    End {
        If ($?) {
            Write-Log -Message
            Write-Log -Message
        }
    }
}

######### Collect List #########
function CollectList() {
    write-log -message 'CollectList started'
    while (1) {
        try {
            Write-Log -Message
            $extn = [IO.Path]::GetExtension($List)
            if ($extn -eq  ) {
                Load-Module ImportExcel
                $script:importedList = Import-Excel (read-host -prompt 'provide List path')

            }
            else {
                $script:importedList = Import-Csv (read-host -prompt 'provide List path')
            }
        }
        Catch {
            Write-Log -Message
        }
    }

    Write-Log -Message
}
########## Import provided List #########
function ImportList() {
    Begin {
        Write-Log -Message 'ImportList started'
    }
    Process {
        Try {
            $extn = [IO.Path]::GetExtension($List)
            if ($extn -eq  ) {
                Load-Module ImportExcel
                $script:importedList = Import-Excel $List
            }
            elseif ($extn -eq  ) {
                $script:importedList = Import-Csv $List
            }
            else { CollectList }
        }
        Catch {
            Write-Log -Message $_.Exception

        }
    }
    End {
        If ($?) {
            Write-Log -Message
        }
    }
}
######### GetGroupName #########


    Process {
        Try {
            $InputGroupName = read-host -prompt 'Provide the full group name, of the group you want to add users to'
            $script:GroupName =
        }

        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }

    End {
        If ($?) {
            Write-Log -Message
            Write-Log -Message
        }
    }
}
######### AddUsersToGroup #########

    Process {
        Try {
            foreach ($u in $importedList) {
                $prejson = '{: }'
                $data = ConvertTo-Json $prejson
                $data
                curl -i -H 'Content-Type: application/json' -X POST -d $data -u
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

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message


#Script Execution goes here
#GET the URL
if($url -eq $null)
{GetUrl}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect the List of users
if($List -eq $null)
{CollectList}
else {ImportExcelFile}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect Admin account
if($AdminAccount -eq $null)
{CollectAdminAccount}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect API Token
if($token -eq $null)
{Providetoken}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect GroupName
if($GroupName -eq $null)
{GetGroupName}
#----------------------------------------------------------------------------------------------------------------------------------
AddUsersToGroup



Write-Log -message
