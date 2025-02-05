##  Change Title on Window  ##
#$Host.UI.RawUI.WindowTitle = 
#$Host.UI.RawUI.WindowTitle = 
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
if (!(Test-Path ps:)) {
    New-PSDrive -PSProvider FileSystem -Name  -Root  #| Out-Null
}

##  Change location to PS  ##
#Set-Location PS:
    Set-Location C:\PS\Scripts

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
$psdir = 

# load all 'autoload' scripts
Get-ChildItem  | ForEach-Object { .$_ } | out-null

# Load scripts from the following locations
# Get environmental folders for PS scripts
$CustomScripts = Get-ChildItem -path  -Directory -Recurse | ForEach-Object{$_.FullName}
foreach($s in $CustomScripts)
{
    $env:Path += 
}

#####  CREDENTIAL MANAGER #####
$KeyPath = 

#Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $KeyPath | Measure-Object
if ($TestCredsPath.count -eq '0'){
$creds = Get-Credential -Message | New-StoredCredential -target $KeyPath
}else{
$creds = (Get-StoredCredential -UserName chcadmin)
}

###  RUN PROGRAMS AS ADMIN ###
Set-Alias adm C:\PS\Tools\Powershell-Stuff\Start-AllAdminPrograms.ps1
Set-Alias adminTools C:\PS\Tools\Powershell-Stuff\Start-AdminTools.ps1
Set-Alias capa C:\PS\Tools\Powershell-Stuff\Start-CapaAdmin.ps1
Set-Alias chrome C:\PS\Tools\Powershell-Stuff\Start-ChromeAdmin.ps1
Set-Alias IIS C:\PS\Tools\Powershell-Stuff\Start-IISadmin.ps1
Set-Alias mRemote C:\PS\Tools\Powershell-Stuff\Start-mRemote.ps1
Set-Alias SQL C:\PS\Tools\Powershell-Stuff\Start-SQLManagementServer.ps1

###  PERSISTENT HISTORY  ###
$HistFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) .ps_history
Register-EngineEvent PowerShell.Exiting -Action { Get-History | Export-Clixml $HistFile } | Out-Null
if (Test-Path $HistFile) { Import-Clixml $HistFile | Add-History }

## Update help if today is tuesday ##
$dt = Get-Date
if ($dt.DayOfWeek -match ) {
    $error.Clear()
    Update-Help -ErrorAction 0 -Force
    for ($i = 0 ; $i -lt $error.Count ; $i ++) {
         ; $error[$i].exception
    }
    C:\PS\PowerShell-Toolbox-master\Update-AllPowerShellModules.ps1
}

#Import Modules & Snap-ins
function Load-Module ($m) {
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
      write-host 
    }
    else {

      # If module is not imported, but available on disk then import
      if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
        Import-Module $m -Verbose
      }
      else {

        # If module is not imported, not available on disk, but is in online gallery then install and import
        if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
          Install-Module -Name $m -Force -Verbose -Scope CurrentUser
          Import-Module $m -Verbose
        }
        else {

          # If the module is not imported, not available and not in the online gallery then abort
          write-host 
          EXIT 1
        }
      }
    }
  }



  $uri = $url + $uri

  try {
      If($method -eq ) {
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
      $StatusCode = [string]$_.Exception.Response.StatusCode.value__
      $StatusDescription = [string]$_.Exception.Response.StatusDescription
      $message = $response
      $message +=   + $uri +  + $_.Exception
      Write-Log -Message $message
  }
  return $response
}


function Reload-Profile {
& $profile
}

#Clear the screen
Clear
