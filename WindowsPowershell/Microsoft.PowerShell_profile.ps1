##  Change Title on Window  ##
$Host.UI.RawUI.WindowTitle = "PowerShell - $env"
# Retrieve existing stored credential
$creds = Get-StoredCredential -UserName chchadmin
}

###  ADMIN PROGRAM ALIASES ###
# DISABLED: Referenced scripts do not exist in current structure
# The following aliases have been commented out until the referenced scripts are available
# Set-Alias adm C:\PS\Tools\Powershell-Stuff\Start-AllAdminPrograms.ps1
# Set-Alias adminTools C:\PS\Tools\Powershell-Stuff\Start-AdminTools.ps1
# Set-Alias capa C:\PS\Tools\Powershell-Stuff\Start-CapaAdmin.ps1
# Set-Alias chrome C:\PS\Tools\Powershell-Stuff\Start-ChromeAdmin.ps1
# Set-Alias IIS C:\PS\Tools\Powershell-Stuff\Start-IISadmin.ps1
# Set-Alias mRemote C:\PS\Tools\Powershell-Stuff\Start-mRemote.ps1
# Set-Alias SQL C:\PS\Tools\Powershell-Stuff\Start-SQLManagementServer.ps1

#$Host.UI.RawUI.WindowTitle = "PS $(Get-Location)"
#$Host.UI.RawUI.WindowTitle = (Get-Date -UFormat '%y/%m/%d %R').ToString()
Remove-Module PSReadline
Import-Module PSReadLine


Remove-Item alias:curl -Force
New-Alias curl curl.exe


Set-PSReadLineOption -colors @{
  Operator           = 'Cyan'
  Parameter          = 'Cyan'
  String             = 'White'
}
##  change dir to PS-Drive ps:  ##
$PSRootPath = Split-Path -Parent $PSScriptRoot
if (!(Test-Path ps:)) {
    New-PSDrive -PSProvider FileSystem -Name PS -Root $PSRootPath | Out-Null
}

##  Change location to PS  ##
#Set-Location PS:
    Set-Location $PSRootPath

##  Load all O365 connections as functions  ##
#.\Connect-Office365Services.ps1
#
# list content of function/script file  ##



#Function Connect-OnPremPS {
#    Import-Module ActiveDirectory
#    $RPSession = New-PSSession -Name  -ConfigurationName Microsoft.Exchange -ConnectionUri http://PROD-EXCH-01/Powershell
#    Import-PSSession $RPSession -AllowClobber
#}
#
#Function Remove-OnPremPS {
#    Get-PSSession -Name  | Remove-PSSession
#}
#
#Function Disconnect-EXO  {
#    Get-PSSession | ? { $_.ComputerName -eq  } | Remove-PSSession
#}
#
#Set-Alias -Name c-mbx -Value Connect-OnPremPS -Description
#Set-Alias -Name d-mbx -Value Remove-OnPremPS -Description
#Set-Alias -Name c-exo -Value Connect-ExchangeOnline -Description
#Set-Alias -Name d-exo -Value Disconnect-EXO -Description

# directory of scripts to auto-load in PS
# $psdir = "c:\ps"  # Variable assigned but never used

# load all 'autoload' scripts
Get-ChildItem "$PSRootPath\autoload\*.ps1" | ForEach-Object { .$_ } | out-null

# Load scripts from the following locations
# Get environmental folders for PS scripts
$CustomScripts = Get-ChildItem -path $PSRootPath -Directory -Recurse | ForEach-Object{$_.FullName}
# Ensure $env:Path is initialized before appending
if (-not $env:Path) { $env:Path = "" }
foreach($s in $CustomScripts)
{
    if ($null -ne $s -and $s -ne "") {
        $env:Path += ";$s"
    }
}

#####  CREDENTIAL MANAGER #####
$KeyPath = "$env:USERPROFILE\\.creds"

#Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $KeyPath | Measure-Object
if ($TestCredsPath.count -eq '0'){
# Create stored credential if none exists
$creds = Get-Credential -Message "Please enter credentials" | New-StoredCredential -target $KeyPath
}else{
# Retrieve existing stored credential
$creds = Get-StoredCredential -UserName chcadmin
}

###  ADMIN PROGRAM ALIASES - DISABLED ###
# The following aliases are disabled because the referenced script files do not exist
# TODO: Create or locate these administrative utility scripts
# Set-Alias adm C:\PS\Tools\Powershell-Stuff\Start-AllAdminPrograms.ps1
# Set-Alias adminTools C:\PS\Tools\Powershell-Stuff\Start-AdminTools.ps1
# Set-Alias capa C:\PS\Tools\Powershell-Stuff\Start-CapaAdmin.ps1
# Set-Alias chrome C:\PS\Tools\Powershell-Stuff\Start-ChromeAdmin.ps1
# Set-Alias IIS C:\PS\Tools\Powershell-Stuff\Start-IISadmin.ps1
# Set-Alias mRemote C:\PS\Tools\Powershell-Stuff\Start-mRemote.ps1
# Set-Alias SQL C:\PS\Tools\Powershell-Stuff\Start-SQLManagementServer.ps1

###  PERSISTENT HISTORY  ###
$HistFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) .ps_history
Register-EngineEvent PowerShell.Exiting -Action { Get-History | Export-Clixml $HistFile } | Out-Null
if (Test-Path $HistFile) { Import-Clixml $HistFile | Add-History }

## Update help if today is tuesday ##
$dt = Get-Date
if ($dt.DayOfWeek -eq "Tuesday") {
    $error.Clear()
    Update-Help -ErrorAction SilentlyContinue -Force
    for ($i = 0 ; $i -lt $error.Count ; $i ++) {
         Write-Host $error[$i].exception
    }
    & "$PSRootPath\PowerShell-Toolbox-master\Update-AllPowerShellModules.ps1"
}

#Import Modules & Snap-ins
function Import-ModuleIfAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $ModuleName}) {
        Write-Verbose "Module $ModuleName is already loaded" -Verbose
    }
    else {
        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleName}) {
            Import-Module $ModuleName -Verbose
        }
        else {
            # If module is not imported, not available on disk, but is in online gallery then install and import
            try {
                if (Find-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
                    Install-Module -Name $ModuleName -Force -Verbose -Scope CurrentUser
                    Import-Module $ModuleName -Verbose
                } else {
                    Write-Warning "Module $ModuleName not found and cannot be installed"
                    return $false
                }
            }
            catch {
                Write-Error "Failed to install module $ModuleName`: $($_.Exception.Message)"
                return $false
            }
      }
    }
  }

# REST API Helper Function
function Invoke-RestApiCall {
  param(
    [string]$url,
    [string]$uri,
    [string]$method = "GET",
    [hashtable]$headers,
    [string]$Body
  )

  $uri = $url + $uri

  try {
      If($method -eq "GET") {
          $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
      }
      else{
          $response = Invoke-RestMethod -Uri $uri -Method $method -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -Headers $headers
      }
  } catch {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $reader.BaseStream.Position = 0
      $reader.DiscardBufferedData()
      $response = $reader.ReadToEnd()
      $reader.Close()
      # $StatusCode = [string]$_.Exception.Response.StatusCode.value__  # Variable assigned but never used
      # $StatusDescription = [string]$_.Exception.Response.StatusDescription  # Variable assigned but never used
      $message = $response
      $message += " URI: " + $uri + " Exception: " + $_.Exception
      Write-Log -Message $message
  }
  return $response
}


function Invoke-ProfileReload {
& $profile
}

#Clear the screen
Clear-Host
