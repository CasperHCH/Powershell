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
  [String]$ListOfOptions,
  [String]$CustomFieldID,
  [String]$ContextID
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'



function Load-Module ($m) {
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
#Import-Module
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
#Allowing for easier web requests
function WebApiRequest {
  param(
    [parameter(Mandatory = $true)] [string]$uri,
    [Parameter(Mandatory = $False)] [ValidateSet("DEFAULT", "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "PATCH", "POST", "PUT", "TRACE")]
    [String] $Method = "GET",
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
    #$message += " Status Code " + $StatusCode + " Status Description: " + $StatusDescription

    Write-Log -Message $message
  }
  return $response
}
######### GetUrl #########
Function GetUrl {
  Param()

  Begin {
    Write-Log -Message 'GetUrl started'
    Write-Log -Message 'Asking initiator to insert a URL for an Atlassian Cloud site.'
  }

  Process {
    Try {
      $url = Read-Host -Prompt 'provide the URL of your jira cloud site, from where you want to delete users - e.g. https://jiracloudtest.atlassian.net OBS! Remember to remove any trailing / '
      $script:url = $url.TrimEnd('/')
    }

    Catch {
      Write-Log -Message $_.Exception
      Break
    }
  }

  End {
    If ($?) {
      Write-Log -Message "GetUrl Completed Successfully."
    }
  }
}

######### Collect Admin account email #########
Function CollectAdminAccount {
  Param()

  Begin {
    Write-Log -Message 'CollectAdminAccount started'
  }

  Process {
    Try {
      $script:AdminAccount = Read-Host -Prompt 'Please provide your Atlassian Admin account Email, with which you have generated a token'
      Write-Log -Message "AdminAccount Token collected as $AdminAccount"
    }

    Catch {
      Write-Log -Message $_.Exception
      Break
    }
  }

  End {
    If ($?) {
      Write-Log -Message "CollectAdminAccount Completed Successfully."
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
      $script:token = Read-Host -Prompt 'Please insert your API Token, can be created here; https://id.atlassian.com/manage-profile/security/api-tokens'
      Write-Log -Message "API Token collected as $token"
    }

    Catch {
      Write-Log -Message $_.Exception
      Break
    }
  }

  End {
    If ($?) {
      Write-Log -Message "ProvidetokenCompleted Successfully."
    }
  }
}
######### Import list of Custom Field Options #########
Function CollectOrProvideCustomFieldOptions {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      #Code here
      if ($ListOfOptions -ne $null) {
        try {
          $options = Import-Excel -Path $ListOfOptions
        }
        catch {
          $script:ListOfOptions = Read-Host "provide path to excel of custom field options"
          $options = Import-Excel -Path $ListOfOptions
        }
        else {
          <# Action when all if and elseif conditions are false #>
          $ListOfOptions = Read-Host "provide path to excel of custom field options"
          $script:options = Import-Excel -Path $ListOfOptions
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
      Write-Log -Message 'Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}
######### Collect Custom Field ID based on name #########
Function CollectCustomFieldID {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      $CustomFieldName = Read-Host "please provide the custom field name, if you do not know the ID"
      #https://docs.atlassian.com/software/jira/docs/api/REST/9.10.0/#api/2/customFields-getCustomFields
      #GET
      $CollectIDUri = '/rest/api/2/customFields'
      $listOfCustomFields = WebApiRequest -uri $CollectIDUri -Method GET
      foreach ($lcf in $listOfCustomFields) {
        if ($lcf.name -eq $CustomFieldName) {
          $script:CustomFieldID = $lcf.ID
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
      Write-Log -Message 'Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}
######### Collect the Context ID of a custom field, ensuring we edit the right context. #########
Function CollectContextID {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      #https://developer.atlassian.com/cloud/jira/platform/rest/v2/api-group-issue-custom-field-contexts/#api-rest-api-2-field-fieldid-context-get
      #/rest/api/2/field/{fieldId}/context
      $CollectContextUri = "/rest/api/latest/field/$($CustomFieldID)/context"
      $ListOfContexts = WebApiRequest -uri $CollectContextUri -Method GET
      $script:ContextID = $ListOfContexts.id
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
######### Add the provided options to the Custom Field within the correct Context #########
Function AddOptionsToCustomFieldID {
  Param ()
  Begin {
    Write-Log -Message '<description of what is going on>...'
  }
  Process {
    Try {
      #https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-options/#api-rest-api-3-field-fieldid-context-contextid-option-post
      #POST /rest/api/3/field/{fieldId}/context/{contextId}/option
      foreach ($o in $options) {
        $NewOption = "$($o.ARE) - $($o."Company Name")"
        $NewOption
        $data = '{{"options": [{"disabled": false,"value": "' + $NewOption + '"}]}}'
        $data
        $webRequestUri = "/rest/api/3/field/$($CustomFieldID)/context/$($ContextID)/option"
        WebApiRequest -uri $webRequestUri -Body $data -method POST
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

<#
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------
Write-Log -message "Starting Script, $sScriptVersion"

#Script Execution goes here
#----------------------------------------------------------------------------------------------------------------------------------
#GET the URL
if ($url -eq $null)
{ GetUrl }else { write-log -Message $url }
#----------------------------------------------------------------------------------------------------------------------------------
#Collect Admin account
if ($AdminAccount -eq $null)
{ CollectAdminAccount }else { write-log -Message $AdminAccount }
#----------------------------------------------------------------------------------------------------------------------------------
#Collect API Token
if ($token -eq $null)
{ Providetoken }else { write-log -Message $token }
#----------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------
#CollectCustomFieldID
if ($CustomFieldID -eq $null)
{ CollectCustomFieldID }
#----------------------------------------------------------------------------------------------------------------------------------
#CollectContextID
if ($ContextID -eq $null)
{ CollectContextID }#Add what ever provided options to the custom field
#----------------------------------------------------------------------------------------------------------------------------------
#Collect List of Custom Field options
CollectOrProvideCustomFieldOptions
#----------------------------------------------------------------------------------------------------------------------------------
AddOptionsToCustomFieldID
#----------------------------------------------------------------------------------------------------------------------------------
#End of Script
Write-Log -message "End of Script"