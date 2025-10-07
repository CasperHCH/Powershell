#requires -version 4
<#
.SYNOPSIS
	<Overview of script>
.DESCRIPTION
	https://developer.atlassian.com/cloud/admin/user-management/rest/api-group-lifecycle/#api-users-account-id-manage-lifecycle-disable-post
    Discussion, of why it isnt working for others https://community.developer.atlassian.com/t/api-rest-manage-lifecycle-disable-and-response-401-you-are-unauthentificated/55808/8
    disable users within atlassian cloud
.PARAMETER Token
    For this script to work, you will need to use an Admin-API token, https://admin.atlassian.com/o/<Org ID>/admin-api
.PARAMETER List
    Path to a CSV list of users, containing AccountID's, with header AccountID
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	A log file will be produced, and placed next to the script file, same folder, same <name>.log
.NOTES
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  <Date>
  Purpose/Change: Disable Atlassian Cloud user accounts

.EXAMPLE
  .\DisableUser.ps1 -Token ATCTT3xFfGN0Xkc4ANG-yi9w9Q3cyodic4EKgcm9MpsZeO14J6x -List C:\Users\caspe\Downloads\AlmBrandAccountID.csv
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
    [Parameter(Mandatory=$true)]$Token,
    [Parameter(Mandatory=$true)]$List
    #Script parameters go here
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

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

#Allowing for easier web requests
function WebApiRequest {
    param(
        [parameter(Mandatory = $true)] [string]$uri,
        [ValidateSet("GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH")]
        [String] $method = "GET",
        [string] $Body = "",
        [string] $userID = ""
    )
    $headers = @{
        'Authorization' = 'Bearer ' + $token
        'Accept'        = 'application/json'
        'content-type'  = 'application/json'
    }

    $uri = "https://api.atlassian.com" + $uri

    try {
        If ($method -eq "GET") {
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
        $message += " Url " + $uri + " : " + $_.Exception
        Write-Log -Message $message
    }
    return $response
}

<#
ALL ACTIVE FUNCTIONS BELOW
#>

Function CollectList {
    Param ()
    Begin {
        Write-Log -Message 'CollectList of users, and call disable function pr user account id'
    }
    Process {
        Try {
            $UserAccounts = Import-Csv $List
            foreach ($u in $UserAccounts) {
                DisableUsers -AccountID $u.AccountID
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
        }
    }
}

Function DisableUsers {
    Param ($AccountID)
    Begin {
        Write-Log -Message 'start DisableUsers, '+$AccountID+''
    }
    Process {
        Try {
            <# https://developer.atlassian.com/cloud/admin/user-management/rest/api-group-lifecycle/#api-users-account-id-manage-lifecycle-disable-post
            CURL
            curl --request POST \
                 --url 'https://api.atlassian.com/users/{account_id}/manage/lifecycle/disable' \
                 --header 'Authorization: Bearer <access_token>' \
                 --header 'Content-Type: application/json' \
                 --data '{
                 "message": "On 6-month suspension"
                }'
        #>
            $uri = "/users/$($AccountID)/manage/lifecycle/disable"
            Write-Log -Message "URI is going to: "+$uri
            #A body can be added to the script, if a custom message of why an account is being disabled, is needed.
             #$body = '{
             #           "message": "< Custom Disablement message >"
             #           }'
            WebApiRequest -method POST -uri $uri #-Body $body
        }
        Catch {
            Write-Log -Level ERROR -Message $_.Exception
            Break
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'DisableUsers Completed Successfully.'
        }
    }
}

<#
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message "Starting Script, $sScriptVersion"

#Script Execution goes here
CollectList
#CollectList will call the DisableUser function, foreach accountID found within the provided CSV file.
Write-Log -message "End of Script"