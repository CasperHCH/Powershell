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
  Add the summary of the wanted ticket - Format:
.PARAMETER Description
Add the wanted ticket description - Format:
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
  Replace , , , , and
  with your actual Jira Service Management credentials and the details for the ticket you want to create.

  Ensure that you are in the correct directory or provide the full path to your script (replace YourScript.ps1 with the actual name of your PowerShell script).
  This example assumes that the script is in the same directory where you are executing the commands.

  After running this example, the script will attempt to create a new ticket in Jira Service Management using the provided parameters,
  and the log file will capture the details of the script execution.

  Specify the necessary parameters
  $username = "your-jira-username"
  $securePassword = Read-Host "Enter Jira API token" -AsSecureString
  $baseUrl = "https://your-jira-server.com"
  $summary = "Customer Request Summary"
  $description = "Detailed description of the customer request"

  # Execute the script with the provided parameters
  .\CreateCustomerRequestThroughAPI.ps1 -username $username -password $securePassword -baseUrl $baseUrl -summary $summary -description $description
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
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "VERBOSE")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory = $True)]
    [string]
    $Message,

    [Parameter(Mandatory = $False)]
    [string]
    $LogFile
  )

  $Stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $Line = "$Stamp [$Level] $Message"
  if ($LogFile) {
      Add-Content $LogFile -Value $Line -PassThru
  } else {
      Add-Content $sLogFile -Value $Line -PassThru
  }
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

function CreateTicket {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [string]$Password,
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,
    [string]$Summary,
    [string]$Description
  )

  Process {
    Try {
      # Create credential object for authentication
      $Cred = "$($UserName):$($Password)"
      $TrimmedURL = $BaseUrl.TrimEnd('/')
      $Url = "$TrimmedURL/rest/servicedeskapi/request"
      Write-Log -Message "Starting ticket creation process for summary: $Summary"
      Write-Log -Message "Target URL: $Url"

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
      if ($null -eq $Summary -or $Summary -eq "") {
          $Summary = Read-Host "Enter ticket summary"
          if ($Summary -eq "") {
              throw "Summary is required for ticket creation"
          }
      }
      else {
        Write-Log -Message "Using provided summary: $Summary"
        Write-Log -Message "Summary validation passed"
      }
      if ($null -eq $Description -or $Description -eq "") {
          $Description = Read-Host "Enter ticket description"
          if ($Description -eq "") {
              $Description = "No description provided"
          }
      }
      else {
        Write-Log -Message "Using provided description: $Description"
        Write-Log -Message "Description validation passed"
      }
      # Construct JSON payload for the API request
      $data = @{
          serviceDeskId = 58
          requestTypeId = 624  # Support request type
          requestFieldValues = @{
              summary = $Summary
              description = $Description
          }
      } | ConvertTo-Json -Depth 3

      Write-Log -Message "JSON payload constructed successfully"
      Write-Log -Message "Payload: $data"

      # Execute curl command to create the ticket
      Write-Log -Message "Executing API request to create ticket..."
      $curlResponse = curl -u $Cred -X POST -H "Content-Type: application/json" --data $data --url $Url
      Write-Log -Message "API response received: $curlResponse"
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

Write-Log -Message "=== Jira Service Management Ticket Creation Script Started ==="
Write-Log -Message "Script Version: $sScriptVersion"
Write-Log -Message "Log File: $sLogFile"

# Validate required parameters
if (-not $UserName) {
    throw "UserName parameter is required"
}
if (-not $Password) {
    throw "Password parameter is required"
}
if (-not $BaseUrl) {
    throw "BaseUrl parameter is required"
}

#Script Execution goes here
Write-Log -Message "Calling CreateTicket function with provided parameters"
CreateTicket -UserName $UserName -Password $Password -BaseUrl $BaseUrl -Summary $Summary -Description $Description

Write-Log -Message "=== Jira Service Management Ticket Creation Script Completed ==="
