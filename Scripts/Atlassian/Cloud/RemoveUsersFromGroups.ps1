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
    [String]$token,
    [String]$List
)
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'



function Load-Module ($m) {
    Write-Log -Message 'Import Modules'

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        Write-Log -Message "Module $m is already imported."
		
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
                Write-Log -Message 'Module not found, install started'
				
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                Write-Log -Message "Module $m not imported, not available and not in an online gallery, exiting."
				
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

$ListOfGroupsToBeRemovedFrom = "41b1db54-277a-48a3-930c-8ac002197370", "9de107f3-b54d-4208-bea4-6aa0ce09ed24", "c28569a8-f6d2-416f-a891-07915e5383a1" #ID Matches - Default Access Groups for Confluence, JSM and Software.
#                              jira-software-users                      jira-servicemanagement-users            confluence-users
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

######### GetUrl #########
Function GetUrl {
    Param()
 
    Begin {
        Write-Log -Message  'GetUrl started'
        Write-Log -Message  'Asking initiator to insert a URL for an Atlassian Cloud site.'
    }
 
    Process {
        Try {
            $url = read-host -prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
            $script:url = $url.TrimEnd('/')
        }
  
        Catch {
            Write-Log -Message $_.Exception
        }
    }
 
    End {
        If ($?) {
            Write-Log -Message  "GetUrl Completed Successfully."
        }
    }
}

######### Collect Admin account email #########
Function CollectAdminAccount {
    Param()
 
    Begin {
        Write-Log -Message  'CollectAdminAccount started'
    }
 
    Process {
        Try {
            $script:AdminAccount = read-host -prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
            Write-Log -Message  "AdminAccount Token collected as $AdminAccount"
        }
  
        Catch {
            Write-Log -Message $_.Exception
            
        }
    }
 
    End {
        If ($?) {
            Write-Log -Message  "CollectAdminAccount Completed Successfully."
        }
    }
}

######### Provide API Token#########
Function Providetoken {
    Param()
 
    Begin {
        Write-Log -Message 'Providetoken started'
    }
 
    Process {
        Try {
            $script:token = read-host -prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
            Write-Log -Message  "API Token collected as $token"
        }
  
        Catch {
            Write-Log -Message $_.Exception
            
        }
    }
 
    End {
        If ($?) {
            Write-Log -Message "ProvidetokenCompleted Successfully."
        }
    }
}

######### Collect List #########
function CollectList() {
    write-log -message 'CollectList started'
    while (1) {
        try {
            Write-Log -Message  "While loop entered, waiting for List path"
            $extn = [IO.Path]::GetExtension($List)
            if ($extn -eq ".xlsx" ) {
                Load-Module ImportExcel
                $script:importedList = Import-Excel (read-host -prompt 'provide List path')
                
            }
            else {
                $script:importedList = Import-Csv (read-host -prompt 'provide List path')
            }
        }
        Catch {
            Write-Log -Message  "Not a valid List inserted"
        }
    }

    Write-Log -Message  "CollectListCompleted Successfully."
}
########## Import provided Excel #########
function ImportList() {
    Begin {
        Write-Log -Message 'ImportList started'
    }
    Process {
        Try {
            $extn = [IO.Path]::GetExtension($List)
            if ($extn -eq ".xlsx" ) {
                Load-Module ImportExcel
                $script:importedList = Import-Excel $List
            }
            elseif ($extn -eq ".csv" ) {
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
            Write-Log -Message "ImportList Completed Successfully."
        }
    }
}

#Allowing for easier web requests
function WebApiRequest {
    param(
        [parameter(Mandatory = $true)] [string]$uri,
        [ValidateSet("DEFAULT", "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "PATCH", "POST", "PUT", "TRACE")] [String] $Method = "GET",
        [string] $Body = "",
        [string] $userID = ""
    )
    
    $pair = "$($AdminAccount):$($token)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"

    $headers = @{
        Authorization  = $basicAuthValue
        'Content-Type' = 'application/json'
        'Accept'       = 'application/json'
    }

    $uri = $url + $uri

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
        $StatusCode = [string]$_.Exception.Response.StatusCode.value__
        $StatusDescription = [string]$_.Exception.Response.StatusDescription
        $message = $response
        $message += " Url " + $uri + " : " + $_.Exception
        Write-Log -Message $message
    }
    return $response
}

######### Collect Atlassian ID based on list of emails #########
Function CollectID {
    Param ()
    Begin {
        Write-Log -Message 'Starting process of collecting Atlassian IDs based on Email'
    }
    Process {
        Try {
            foreach ($CollectIDFromEmail in $importedList) {
                Write-Log -message "Collecting Atlassian ID from email: $($CollectIDFromEmail.email)"
                $CollectedIDUri = "/rest/api/3/user/search?query=$($CollectIDFromEmail.email)"
                $returned = WebApiRequest -uri $CollectedIDUri
                Write-Log -Message "Collected the following ID: $($returned.accountID)"
                ########### Remove the new user account from Jira Software, JSM and Confluence default Groups ###########
                RemoveUserFromGroups $returned.accountID
            }
        }
        Catch {
            Write-Log -Level "ERROR" -Message $_.Exception
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'CollectID Completed Successfully.'
        }
    }
}


######### Remove User From Groups  #########
Function RemoveUserFromGroups {
    Param ($returnedResponse)
    Begin {
        Write-Log -Message 'Removing user from default groups'
    }
    Process {
        Try {
            foreach ($ID in $returnedResponse) {  
                foreach ($GroupID in $ListOfGroupsToBeRemovedFrom) {  
                    Write-Log -Message "Removing user $($ID) from Group with ID: $($GroupID)"
                    $RemoveUserFromGrpuri = '/rest/api/3/group/user?groupId=' + $($GroupID) + '&accountId=' + $($ID)

                    WebApiRequest -method "DELETE" -uri $RemoveUserFromGrpuri
                }
            }
        }
        Catch {
            Write-Log -Level "ERROR" -Message $_.Exception
        }
    }
    End {
        If ($?) {
            Write-Log -Message 'RemoveUserFromGroups Completed Successfully.'
        }
    }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message "Starting Script, $($sScriptVersion)"
Write-Log -message "--------------------------------------"
#Script Execution goes here
#----------------------------------------------------------------------------------------------------------------------------------
#GET the URL
if ($url -eq $null)
{ GetUrl }else { write-log -Message $url }
#----------------------------------------------------------------------------------------------------------------------------------
#Collect the List of users
if ($List -eq $null)
{ CollectList }
else {
    ImportList
    write-log -Message "Path of list is $List"
    Write-Log -Message "containing:"
    write-log -Message "$($importedList)"
}
#----------------------------------------------------------------------------------------------------------------------------------
#Collect Admin account
if ($AdminAccount -eq $null)
{ CollectAdminAccount }else { write-log -Message $AdminAccount }
#----------------------------------------------------------------------------------------------------------------------------------
#Collect API Token
if ($token -eq $null)
{ Providetoken }else { write-log -Message $token }

Write-Log -Message "Start Onboarding"
CollectID
Write-Log -message "--------------------------------------"
Write-Log -message "End of Script"