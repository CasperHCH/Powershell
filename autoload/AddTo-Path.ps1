#requires -version 4
<#
.SYNOPSIS
	add a path to environment
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
  Author:         YorSubs
  Creation Date:  unknown
  URL:            https://stackoverflow.com/questions/714877/setting-windows-powershell-environment-variables
.EXAMPLE
Add  to User Path (but only if not already present)
AddTo-Path   

Just show the current status by putting an empty path
AddTo-Path   
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
function AddTo-Path {
  param ( 
      [string]$PathToAdd,
      [Parameter(Mandatory=$true)][ValidateSet('System','User')][string]$UserType,
      [Parameter(Mandatory=$true)][ValidateSet('Path','PSModulePath')][string]$PathType
  )

  # AddTo-Path   'System' 
  if ($UserType -eq  ) { $RegPropertyLocation = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' }
  if ($UserType -eq    ) { $RegPropertyLocation = 'HKCU:\Environment' } # also note: Registry::HKEY_LOCAL_MACHINE\ format
  $PathOld = (Get-ItemProperty -Path $RegPropertyLocation -Name $PathType).$PathType
  
  $PathArray = $PathOld -Split  -replace , 
  if ($PathArray -notcontains $PathToAdd) {
         # ; sleep -Milliseconds 100   # Might need pause to prevent text being after Path output(!)
      $PathNew = 
      Set-ItemProperty -Path $RegPropertyLocation -Name $PathType -Value $PathNew
      Get-ItemProperty -Path $RegPropertyLocation -Name $PathType | select -ExpandProperty $PathType
      if ($PathType -eq ) { $env:Path +=  }                  # Add to Path also for this current session
      if ($PathType -eq ) { $env:PSModulePath +=  }  # Add to PSModulePath also for this current session
      
  }
  else {
      
  }
}
