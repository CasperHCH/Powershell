<#
.SYNOPSIS
	<Overview of script>
.DESCRIPTION
	Collect Old Active Directory SamAccountNames and Mail, along with Azure UPN, then replace Jira Usernames and email fields with the UPN based on usernames from old AD
.PARAMETER jirabaseurl
    the url address, including https:// of your jira instance
.PARAMETER AdminAccount
    Admin Account username
.PARAMETER Token
    Password for Admin account
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	A log file will be generated at the same location as this script, with the same name .log
.NOTES
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  <Date>
  Purpose/Change: To replace and change usernames and emails of Jira account, as Miracle has been purchased by KnowIT and is to replace their current AD with KnowIT AD.
  OBS!!!:         In current version, 1.0, the function, GetOldADUserObjects is hardcoded to a csv file, on developers machine. The query to generate a new is provided within the funciton.

.EXAMPLE
  RenameUsernamesFromNewADUPN -jirabaseurl https://jira-new-test.miracle.dk -AdminAccount chcadmin -token password
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
    #Script parameters go here
    [Parameter(Mandatory = $true)]$jirabaseurl,
    [Parameter(Mandatory = $true)]$UserList,
    [Parameter(Mandatory = $true)]$AdminAccount,
    [Parameter(Mandatory = $true)]$Token
)
#---------------------------------------------------------[Logging function has to come first]------------------------------------------------------
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
    Add-Content $slogfile -Value $Line -PassThru
}
#---------------------------------------------------------[Logging function has to come first]------------------------------------------------------


#---------------------------------------------------------[TEMP HARDCODED ADDITION]--------------------------------------------------------
if ($null -eq $jirabaseurl) {
    #BaseUrl
    #JiraTest
    $script:jirabaseurl = 
    #JiraProd
    #$jirabaseurl =
}

if ($null -eq $UserList) {
    $UserList = 
}
#---------------------------------------------------------[TEMP HARDCODED ADDITION]--------------------------------------------------------

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

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

#Load-Module AzureAD
Load-Module AzureAD

Connect-AzureAD

##	Change Aliases	##
#	Changing alias for Curl
Remove-Item alias:curl -Force
New-Alias curl curl.exe
#	Curl changed

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
write-log -Message 
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
write-log -Message 

$pair = 

#-----------------------------------------------------------[Functions]------------------------------------------------------------



#Was unable to connect to domain to collect user info from old AD, therefor they where extracted as CSV from server, and imported here...

    Process {
        Try {
            #csv contains a list of users extracted from Miracle Local AD, containing only the properties mail and samaccountname
            #get-aduser -Filter {mail -like  -or mail -like } -SearchBase  -Properties name, mail, samaccountname | Select-Object name, mail, samaccountname | Export-Csv C:\Temp\script_csv_files\Users.csv
            Write-Log -Message 
            if (Test-Path $UserList) {
                $extn = [IO.Path]::GetExtension($UserList)
                if ($extn -eq  ) {
                    $script:iul = Import-Csv $UserList
                }

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
                $email = $user.mail
                $username = $user.samaccountname
                $filter = 
                $KnowITUser = Get-AzureADUser -Filter $filter | Select-Object UserPrincipalName
                $KnowITUserUPN = $KnowITUser.UserPrincipalName
                #Write-Host 
                Write-Log -Message 
                if ($null -ne $KnowITUserUPN) {
                    if ($KnowITUserUPN -ne $username) {
                        ChangeUsernameAndEmail -email $email -username $username -upn $KnowITUserUPN
                    }
                }
            }
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

    Process {
        Try {
            $result = $exists = $overlapped = 
            $tries = 0
            do {
                $failed = $false

                #region Handle overlap - check if destination user exists already and rename if it is. And if there's something super odd and even renamed user exists already, do some tricks until renamed or tired 3 times.
                $innertries = 0
                do {
                    $innerfailed = $false
                    try {
                        #check if account already exist with upn as username
                        $uri = 
                        $exists = curl -H 'Content-Type: application/json' -X GET -u $pair $uri | ConvertFrom-Json
                    }
                    catch {
                        if ($exists.errormessages -like ) {
                            # Expected, continue
                            $exists = $null
                        }
                        else {
                            write-log -message yyyy-MM-dd HH:mm:ss.fff
                        }
                    }
                    if ($null -ne $exists) {
                        if ($exists.key -eq $username) {
                            write-log -message yyyy-MM-dd HH:mm:ss.fff
                            return
                        }
                        else {
                            $overlap = 
                            try {
                                #If account already exist, rename to overlap-.-upn
                                $uri = 
                                $body = '{: , : }' | ConvertTo-Json
                                $overlapped = curl -H 'Content-Type: application/json' -X PUT -u $pair -d $body $uri
                            }
                            catch {
                                if ($null -eq $(try { $overlapped.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                    $innerfailed = $true
                                    write-log -Level WARN -message 
                                }
                                else {
                                    $errmsg = $overlapped.message | ConvertFrom-Json
                                    if ($errmsg.errors.username -like ) {
                                        # Silent retry
                                        $innerfailed = $true
                                        if ($innertries -ge 3) {
                                            write-log -message yyyy-MM-dd HH:mm:ss.fff, , 
                                        }
                                    }
                                    else {
                                        write-log -message yyyy-MM-dd HH:mm:ss.fff, , 
                                    }
                                }
                            }
                            if ($null -ne $overlapped.name) {
                                $jiraOverlap.Add($overlap) | Out-Null
                            }
                        }
                    }
                    $innertries++
                }while ($innerfailed -and $innertries -lt 4)
                if ($innerfailed) {
                    write-log -Level WARN -message 
                }
                #endregion

                try {
                    #if no account is found, rename the account username and email to the knowit upn
                    $uri = 
                    $body = '{: , : }' | ConvertTo-Json
                    $result = curl -H 'Content-Type: application/json' -X PUT -u $pair -d $body $uri | ConvertFrom-Json
                }
                catch {
                    if ($result.messages -like ) {
                        write-log -message yyyy-MM-dd HH:mm:ss.fff
                    }
                    else {
                        # UPN might have been changed to incorrect one already so double-checking
                        $failed = $true
                        if ($null -eq $(try { $result.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                            write-log -Level WARN -message 
                        }
                        else {
                            $chngerrmsg = $result.message | ConvertFrom-Json
                            write-log -message yyyy-MM-dd HH:mm:ss.fff, , 
                        }
                    }
                }
                if ($null -ne $result -and $result.name -ne $upn) {
                    write-log -Level WARN -message 
                }
                $tries++
            }while ($failed -and $tries -lt 4)
            if ($failed) {
                write-log -Level WARN -message 
            }
        }


        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'ChangeUsernameAndEmail Completed Successfully.'
            Write-Log -Message ' '
        }
    }
}


<#
ALL FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message 


#Script Execution goes here
GetOldADUserObjects
GetAzureUserObject

<#
the function
ChangeUsernameAndEmail
will be called from GetAzureUserObject, as to only make changes to one user account at a time
#>


Write-Log -message
