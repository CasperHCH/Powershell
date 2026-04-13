##  Change Title on Window  ##
#$Host.UI.RawUI.WindowTitle =
#$Host.UI.RawUI.WindowTitle =
#$Host.UI.RawUI.WindowTitle = (Get-Date -UFormat '%y/%m/%d %R').ToString()
Remove-Module PSReadline
Import-Module PSReadLine


Remove-Item alias:curl -Force
New-Alias curl curl.exe


Set-PSReadLineOption -colors @{
  Operator  = 'Cyan'
  Parameter = 'Cyan'
  String    = 'White'
}
##  change dir to PS-Drive ps:  ##
if (!(Test-Path ps:)) {
  New-PSDrive -PSProvider FileSystem -Name  -Root  #| Out-Null
}

##  Change location to PS  ##
#Set-Location PS:
Set-Location $PSScriptRoot\..\..

##  Load all O365 connections as functions  ##
#.\Connect-Office365Services.ps1
#
# list content of function/script file  ##



#Function Connect-OnPremPS {
#    Import-Module ActiveDirectory
#    $RPSession = New-PSSession -Name  -ConfigurationName Microsoft.Exchange -ConnectionUri https://PROD-EXCH-01/Powershell
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
$psdir = Join-Path (Split-Path $PSScriptRoot -Parent) "autoload"

# load all 'autoload' scripts
Get-ChildItem $psdir\*.ps1 | ForEach-Object { .$_ } | Out-Null

# Load scripts from the following locations
# Get environmental folders for PS scripts
$CustomScripts = Get-ChildItem -Path  -Directory -Recurse | ForEach-Object {$_.FullName}
foreach ($s in $CustomScripts) {
  $env:Path += ";$psdir"
}

#####  CREDENTIAL MANAGER #####
$KeyPath = "$env:USERPROFILE\.creds"

#Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $KeyPath | Measure-Object
if ($TestCredsPath.count -eq '0') {
  $creds = Get-Credential -Message "Please enter your credentials" | New-StoredCredential -target $KeyPath
} else {
  $creds = (Get-StoredCredential -UserName $env:USERNAME)
}

###  RUN PROGRAMS AS ADMIN ###
# Dynamic path resolution for admin tools
$PSRootPath = Split-Path $PSScriptRoot -Parent
$ToolsPath = Join-Path $PSRootPath "Tools\Powershell-Stuff"

if (Test-Path $ToolsPath) {
  Set-Alias adm (Join-Path $ToolsPath "Start-AllAdminPrograms.ps1")
  Set-Alias adminTools (Join-Path $ToolsPath "Start-AdminTools.ps1")
  Set-Alias capa (Join-Path $ToolsPath "Start-CapaAdmin.ps1")
  Set-Alias chrome (Join-Path $ToolsPath "Start-ChromeAdmin.ps1")
  Set-Alias IIS (Join-Path $ToolsPath "Start-IISadmin.ps1")
  Set-Alias mRemote (Join-Path $ToolsPath "Start-mRemote.ps1")
  Set-Alias SQL (Join-Path $ToolsPath "Start-SQLManagementServer.ps1")
}

###  PERSISTENT HISTORY  ###
$HistFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) .ps_history
Register-EngineEvent PowerShell.Exiting -Action { Get-History | Export-Clixml $HistFile } | Out-Null
if (Test-Path $HistFile) { Import-Clixml $HistFile | Add-History }

## Update help if today is tuesday ##
$dt = Get-Date
if ($dt.DayOfWeek -match "Tuesday") {
  $error.Clear()
  Update-Help -ErrorAction 0 -Force
  for ($i = 0 ; $i -lt $error.Count ; $i ++) {
    Write-Host $error[$i].exception
  }
  $UpdateModulesScript = Join-Path (Split-Path $PSScriptRoot -Parent) "PowerShell-Toolbox-master\Update-AllPowerShellModules.ps1"
  if (Test-Path $UpdateModulesScript) { & $UpdateModulesScript }
}

#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
  # If module is imported say that and do nothing
  if (Get-Module | Where-Object {$_.Name -eq $m}) {
    Write-Host
  } else {

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
      Import-Module $m -Verbose
    } else {

      # If module is not imported, not available on disk, but is in online gallery then install and import
      if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
        Install-Module -Name $m -Force -Verbose -Scope CurrentUser
        Import-Module $m -Verbose
      } else {

        # If the module is not imported, not available and not in the online gallery then abort
        Write-Host
        exit 1
      }
    }
  }
}



function Reload-Profile {
  & $profile
}

#Clear the screen
Clear-Host

