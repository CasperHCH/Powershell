#requires -version 4
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
#---------------------------------------------------------[Logging function has to come first]------------------------------------------------------


#---------------------------------------------------------[TEMP HARDCODED ADDITION]--------------------------------------------------------
if ($null -eq $jirabaseurl) {
    #BaseUrl
    #JiraTest
    $script:jirabaseurl = "jira-new-test.miracle.dk"
    #JiraProd
    #$jirabaseurl ="jira.miracle.dk"
}

if ($null -eq $UserList) {
    $UserList = "C:\Users\caspe\Downloads\users.csv"
}
#---------------------------------------------------------[TEMP HARDCODED ADDITION]--------------------------------------------------------

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

function Import-ModuleIfAvailable ($m) {
    Write-Log -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
    Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        Write-Host "Module $m is already imported."
        Write-Log -LogPath $sLogFile -TimeStamp -Message "Module $m is already imported."
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
                Write-Host "Module $m not imported, not available and not in an online gallery, exiting."
                Write-Log -LogPath $sLogFile -TimeStamp -Message "Module $m not imported, not available and not in an online gallery, exiting."
                Write-Log -LogPath $sLogFile -TimeStamp -Message ' '
                EXIT 1
            }
        }
    }
}

#Import Modules & Snap-ins
#Load-Module

#Load-Module AzureAD
Import-ModuleIfAvailable AzureAD

Connect-AzureAD


#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
write-log -Message "declarations - create path for log file"
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
write-log -Message "declarations - log is $($sLogFile)"

$pair = "$($AdminAccount):$($token)"

#-----------------------------------------------------------[Functions]------------------------------------------------------------



#Was unable to connect to domain to collect user info from old AD, therefor they where extracted as CSV from server, and imported here...
Function GetOldADUserObjects {
    Param ()
    Begin {
        Write-Log -Message 'Collect samAccountName and Mail from Old Active Directory (AD)'
    }
    Process {
        Try {
            #csv contains a list of users extracted from Miracle Local AD, containing only the properties mail and samaccountname
            #get-aduser -Filter {mail -like "*knowit.dk" -or mail -like "*miracle.dk"} -SearchBase "OU=Miracle Corp_New,DC=Miracle,DC=local" -Properties name, mail, samaccountname | Select-Object name, mail, samaccountname | Export-Csv C:\Temp\script_csv_files\Users.csv
            Write-Log -Message "running test-path on $($UserList)"
            if (Test-Path $UserList) {
                $extn = [IO.Path]::GetExtension($UserList)
                if ($extn -eq ".csv" ) {
                    $script:iul = Import-Csv $UserList
                }

            }
            else {
                Write-Log -Message "$($UserList) doesn't exist"
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
Function GetAzureUserObject {
    Param ($MiracleUserObject)
    Begin {
        Write-Log -Message 'Collect Azure user objects, based on samAccountName and mail from Old Active Directory (AD)'
    }
    Process {
        Try {
            foreach ($user in $iul) {
                $email = $user.mail
                $username = $user.samaccountname
                $filter = "proxyAddresses/any(p:startswith(p,'smtp:$email'))"
                $KnowITUser = Get-AzureADUser -Filter $filter | Select-Object UserPrincipalName
                $KnowITUserUPN = $KnowITUser.UserPrincipalName
                #Write-Host "Collected Old Mail as $($email) and Old samAccountName as $($username), new UPN is $($KnowITUserUPN)"
                Write-Log -Message "Collected Old Mail as $($email) and Old samAccountName as $($username), new UPN is $($KnowITUserUPN)"
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
Function ChangeUsernameAndEmail {
    Param ($email, $username, $upn)
    Begin {
        Write-Log -Message 'Now that all info has been collected, we will start the process of renaming Usernames and Email fields, to their new KNOWIT UPN'
    }
    Process {
        Try {
            $result = $exists = $overlapped = ""
            $tries = 0
            do {
                $failed = $false

                #region Handle overlap - check if destination user exists already and rename if it does. And if there's something super odd and even renamed user exists already, do some tricks until renamed or tired 3 times.
                $innertries = 0
                do {
                    $innerfailed = $false
                    try {
                        #check if account already exist with upn as username
                        write-log -Message "check if account already exist with upn as username"
                        $uri = "$($jirabaseurl)/rest/api/2/user?username=$($upn)"
                        $exists = curl -H 'Content-Type: application/json' -X GET -u $pair $uri | ConvertFrom-Json
                    }
                    catch {
                        if ($exists.errormessages -like "*does not exist*") {
                            # Expected, continue
                            write-log -Message "account doesn't exist already"
                            $exists = $null
                        }
                        else {
                            write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -! Destination user exists already, prefixing it with overlap-_-"
                        }
                    }
                    if ($null -ne $exists) {
                        if ($exists.key -eq $username) {
                            write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] -- key equals to old username, user processed correctly already."
                            return
                        }
                        else {
                            $overlap = "overlap-_-$upn"
                            try {
                                Write-Log -Message "UPN Account already exists - in process of renaming with overlap-_-$upn"
                                #If account already exist, rename to overlap-.-upn
                                $uri = "$($jirabaseurl)/rest/api/2/user?username=$($upn)"
                                $body = '{"name": "' + $overlap + '", "emailAddress": "' + $overlap + '"}' | ConvertTo-Json
                                $overlapped = curl -H 'Content-Type: application/json' -X PUT -u $pair -d $body $uri
                            }
                            catch {
                                if ($null -eq $(try { $overlapped.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                    $innerfailed = $true
                                    write-log -Level WARN -message "Catched error when renaming destination user but message is not jSON! Exception:`n$($_.Exception.Message)"
                                }
                                else {
                                    $errmsg = $overlapped.message | ConvertFrom-Json
                                    if ($errmsg.errors.username -like "*username already exists*") {
                                        # Silent retry
                                        $innerfailed = $true
                                        if ($innertries -ge 3) {
                                            write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Prefixing to '$overlap' failed, Jira returned error.`nerrorMessages: $($errmsg.errorMessages -join ", ")`nerrors:$($errmsg.errors -join ", ")"
                                        }
                                    }
                                    else {
                                        write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Prefixing to '$overlap' failed, Jira returned error.`nerrorMessages: $($errmsg.errorMessages -join ", ")`nerrors:$($errmsg.errors -join ", ")"
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
                    write-log -Level WARN -message "Failed changing overlapping username '$($upn) to '$overlap' after $innertries tries!"
                }
                #endregion

                try {
                    #if no account is found, rename the account username and email to the knowit upn
                    Write-Log -Message "No duplicate account found, renaming username:$username and email:$email to $upn"
                    $uri = "$($jirabaseurl)/rest/api/2/user?username=$($username)"
                    $body = '{"name": "' + $upn + '", "emailAddress": "' + $upn + '"}' | ConvertTo-Json
                    $result = curl -H 'Content-Type: application/json' -X PUT -u $pair -d $body $uri | ConvertFrom-Json
                }
                catch {
                    if ($result.messages -like "*does not exist*") {
                        write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Failed, user not found. Continuing with next user"
                    }
                    else {
                        # UPN might have been changed to incorrect one already so double-checking
                        $failed = $true
                        if ($null -eq $(try { $result.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                            write-log -Level WARN -message "Catched error when renaming destination user but message is not jSON! Exception:`n$($_.Exception.Message)"
                        }
                        else {
                            $chngerrmsg = $result.message | ConvertFrom-Json
                            write-log -message "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"))] !! Failed, Jira returned error.`nerrorMessages: $($chngerrmsg.errorMessages -join ", ")`nerrors:$($chngerrmsg.errors -join ", ")"
                        }
                    }
                }
                if ($null -ne $result -and $result.name -ne $upn) {
                    write-log -Level WARN -message "Failed changing username of $($username) to $($upn)! API returned $($result.name) as username."
                }
                $tries++
            }while ($failed -and $tries -lt 4)
            if ($failed) {
                write-log -Level WARN -message "Failed changing username '$($username)' to '$($upn)' after $tries tries!"
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
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message "Starting Script, $sScriptVersion"


#Script Execution goes here
GetOldADUserObjects
GetAzureUserObject

<#
the function
ChangeUsernameAndEmail
will be called from GetAzureUserObject, as to only make changes to one user account at a time
#>


Write-Log -message "End of Script"