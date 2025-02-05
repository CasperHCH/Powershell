<#
.SYNOPSIS
	With only OrgID and Org API Key, collect Last Login for all Users, on all Applications
.DESCRIPTION
	On date; 05-10-2023; I didn't have the option to access an Atlassian Cloud, with Managed User Accounts.
  A managed user account, is an account where the domain has been .
  Due to this, I used the option of Exporting a list of all users within an Org, which contains Account ID's.
  This export, also contains Last Login on each application, however, currently the user Export can not be done automatically.

  The script will take the User Export.CSV file, and collect their Last Login info for each product within the Org.
.PARAMETER OrgID
    Organizational ID, of the org to process. Collected by e.g accessing the Org. in a browser, and copying from the URL.
.PARAMETER OrgAccessToken
    A requirement to create an Org. API key, is to be an Org. Admin.
    Head into the Org. -> Settings -> API and generate a new key.
.PARAMETER List
    The current List parameter is made from accesing an Cloud Org.
    From here navigate to either:
    Directory -> Managed Accounts -> Export Accounts
    Products -> ... besides a product -> Manage users -> Export users
.INPUTS
	An List of users, containing their User ID
.OUTPUTS
	    2 Outputs will be produced.
  1. Log file is stored next to the script execution.
  2. CSV output, containing the Last Login of users.
.NOTES
  Version:        1.0
  Author:         Casper Hjorth Christensen
  Creation Date:  05-10-2023
  Purpose/Change: Collect Last Login info on Atlassian Cloud user accounts

.EXAMPLE
  .\CollectLastLogin.ps1 -OrgID XYZ -OrgAccessToken ABC -List C:\Temp\UserList.csv
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
  #Script parameters go here
  [String]$OrgID,
  [String]$OrgAccessToken,
  [String]$List
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

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = '1.0'

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sOutputName = $sLogName -replace '.ps1', '.csv'
$sLogName = $sLogName -replace '.ps1', '.log'
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
$sOutputFile = Join-Path -Path $sLogPath -ChildPath $sOutputName
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
      $url = 
      while (condition) {


        $ManagedUserAccounts = curl --request GET --url $url --header $auth --header 'Accept: application/json' | ConvertFrom-Json
        #Add managed users account to table
        #https://www.delftstack.com/howto/powershell/powershell-create-table/
        $table = New-Object System.Data.Datatable

        # Adding columns
        [void]$table.Columns.Add()
        [void]$table.Columns.Add()
        [void]$table.Columns.Add()
        [void]$table.Columns.Add()
        [void]$table.Columns.Add()

        # Adding rows
        foreach ($MUA in $ManagedUserAccounts) {
          [void]$table.Rows.Add($MUA.data., $MUA.data., $MUA.data.,$MUA.data.product_access(, $MUA.data.product_access()))
        }
      }
      $table
    }
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'CollectUserIDFromManagedAccounts Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}


  Process {
    Try {
      if (Test-Path $List) {
        $script:file = Import-Csv $List
        $file.
      }
    }
    Catch {
      Write-Log -Level ERROR -Message $_.Exception
      Break
    }
  }
  End {
    If ($?) {
      Write-Log -Message 'ImportFile Completed Successfully.'
      Write-Log -Message ' '
    }
  }
}

  Process {
    Try {
      # Using the following API; https://developer.atlassian.com/cloud/admin/organization/rest/api-group-directory/#api-v1-orgs-orgid-directory-users-accountid-last-active-dates-get
      Write-Log -Message 
      $auth = 'Authorization: Bearer ' + $OrgAccessToken + ''
      foreach ($f in $file) {
        Write-Log -Message email
        Write-Log -Message 
        $url = 
        $user = curl --request GET --url $url --header $auth --header 'Accept: application/json' | ConvertFrom-Json

        Write-Log -Message 

        foreach ($u in $user.data.product_access) {
          [PSCustomObject]@{
            UserID     = $f.
            UserName   = $f.'User name'
            Product    = $u.key
            Last_Login = $u.last_active
          } | Export-Csv -Path $sOutputFile -Append -NoTypeInformation
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
      Write-Log -Message 'CollectApiInfo Completed Successfully.'
      Write-Log -Message 
    }
  }
}


<#
ALL ACTIVE FUNCTIONS ABOVE
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Log -message 


#Script Execution goes here
ImportFile
CollectApiInfo

Write-Log -message
