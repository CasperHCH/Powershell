#requires -version 7.4.1
<#
.SYNOPSIS
	The PowerShell script automates the creation of tickets in Jira Service Management (JSM) on-premises by leveraging the JSM API.
  The script requires input parameters, including a valid username with ticket creation permissions, corresponding password,
  JSM base URL, and details for the new ticket such as summary and description.
  It encapsulates a function, CreateTicket, which constructs and submits API requests to JSM, resulting in the creation of a customer request.
  The script incorporates logging functionalities for better traceability and error handling.
.DESCRIPTION
	This PowerShell script facilitates the streamlined generation of customer requests within Jira Service Management on-premises.
  Users input essential parameters like the JSM username, password, base URL, ticket summary, and description.
  The script employs the CreateTicket function to orchestrate the communication with the JSM API.
  It constructs a JSON payload containing pertinent information for the new ticket, such as service desk ID, request type ID, summary, and description.
  Utilizing the curl command, the script sends a POST request to the specified API endpoint, triggering the creation of the customer request.

  The script adheres to logging best practices, capturing timestamps, log levels, and messages for each operation.
  It also features error handling mechanisms to gracefully manage exceptions during the execution.
  Additionally, the script includes parameter validation to ensure that mandatory inputs are provided.
  Security considerations are addressed by using secure credential handling practices.

  Overall, this script provides an efficient and automated solution for creating customer requests in
  Jira Service Management on-premises, enhancing the productivity of users managing ticketing systems.
.PARAMETER UserName
    Insert the username of an account, which have the permission to create tickets within a Jira Service Management on-prem setup
.PARAMETER password
    Insert the password of the username provided
.PARAMETER BaseUrl
   Add the base URL of the Jira Service Management system in the format:
   https://Jira.Domain.com
   The script will trim the trailing slash from the base URL
.PARAMETER Summary
  Add the summary of the wanted ticket - Format: "A summary is one line of text"
.PARAMETER Description
Add the wanted ticket description - Format: "A description is multiples lines of text\n separated by\n line feeds"
.INPUTS
	none
.OUTPUTS
  A log file is created and stored next to the script execution.
.NOTES
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  12-01-2024
  Purpose/Change: Create a new Customer Request within JSM on-prem through API

.EXAMPLE
  Replace "your_jira_username", "your_jira_password", "https://your-jira-domain.com", "A brief summary of the ticket", and "A detailed description of the ticket..."
  with your actual Jira Service Management credentials and the details for the ticket you want to create.

  Ensure that you are in the correct directory or provide the full path to your script (replace YourScript.ps1 with the actual name of your PowerShell script).
  This example assumes that the script is in the same directory where you are executing the commands.

  After running this example, the script will attempt to create a new ticket in Jira Service Management using the provided parameters,
  and the log file will capture the details of the script execution.

  Specify the necessary parameters
  $username = "your_jira_username"
  $password = "your_jira_password"
  $baseUrl = "https://your-jira-domain.com"
  $summary = "A brief summary of the ticket"
  $description = "A detailed description of the ticket, including multiple lines separated by line feeds."

  # Execute the script with the provided parameters
  .\YourScript.ps1 -username $username -password $password -baseUrl $baseUrl -summary $summary -description $description
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  [Parameter(Mandatory = $true)] $username,
  [Parameter(Mandatory = $true)] $password,
  [Parameter(Mandatory = $true)] $BaseUrl,
  $summary,
  $description
  #Script parameters go here
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
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

Function CreateTicket {
  Param ()
  Begin {
    Write-Log -Message 'Creating a Customer Request in On-prem JSM'
  }
  Process {
    Try {
      $Cred = "$($username):$($password)"
      $TrimmedURL = $BaseUrl.TrimEnd('/')
      $Url = "$TrimmedURL/rest/servicedeskapi/request"
      Write-Log -Message "Url collected and trimmed to: $url"

      # ServiceDeskID 58 is a static variable - please dont change it

      <# RequestTypeID
      insert what ever Request Type ID you want it to be created as
      373 = Generelle Henvendelser
      371 = Fejl/Nedbrud
      624 = Support
      625 = Opgave
      686 = Ændring
      688 = Atlassian Workshop eller Kursus
      802 = Licenser
      #>
      if ($null -eq $Summary) { $summary = "#1 test with api" }
      else {
        Write-Log -Message "Summary was not NULL it was:"
        Write-Log -message "$summary"
      }
      if ($null -eq $description) { $description = "test with api" }
      else {
        Write-Log -Message "Description was not NULL it was:"
        write-log -message "$description"
      }
      $data = @"
      {
        "serviceDeskId": "58",
        "requestTypeId": "624",
        "requestFieldValues": {
            "summary": "$Summary",
            "description": "$description"
        }
    }
"@
      Write-Log -Message "JSON Data created, it contains the following:"
      write-log -Message "$data"

      $curlResponse = curl -u $cred -X POST -H "Content-Type: application/json" --data $data --url $url
      write-log -Message "$curlResponse"
    }
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'CreateTicket completed Successfully.'
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

CreateTicket


Write-Log -message "End of Script"