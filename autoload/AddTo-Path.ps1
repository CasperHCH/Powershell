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
Add "C:\XXX" to User Path (but only if not already present)
AddTo-Path "C:\XXX" "User" "Path"

Just show the current status by putting an empty path
AddTo-Path "" "User" "Path"
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
function AddTo-Path {
  param ( 
      [string]$PathToAdd,
      [Parameter(Mandatory=$true)][ValidateSet('System','User')][string]$UserType,
      [Parameter(Mandatory=$true)][ValidateSet('Path','PSModulePath')][string]$PathType
  )

  # AddTo-Path "C:\XXX" "PSModulePath" 'System' 
  if ($UserType -eq "System" ) { $RegPropertyLocation = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' }
  if ($UserType -eq "User"   ) { $RegPropertyLocation = 'HKCU:\Environment' } # also note: Registry::HKEY_LOCAL_MACHINE\ format
  $PathOld = (Get-ItemProperty -Path $RegPropertyLocation -Name $PathType).$PathType
  "`n$UserType $PathType Before:`n$PathOld`n"
  $PathArray = $PathOld -Split ";" -replace "\\+$", ""
  if ($PathArray -notcontains $PathToAdd) {
      "$UserType $PathType Now:"   # ; sleep -Milliseconds 100   # Might need pause to prevent text being after Path output(!)
      $PathNew = "$PathOld;$PathToAdd"
      Set-ItemProperty -Path $RegPropertyLocation -Name $PathType -Value $PathNew
      Get-ItemProperty -Path $RegPropertyLocation -Name $PathType | select -ExpandProperty $PathType
      if ($PathType -eq "Path") { $env:Path += ";$PathToAdd" }                  # Add to Path also for this current session
      if ($PathType -eq "PSModulePath") { $env:PSModulePath += ";$PathToAdd" }  # Add to PSModulePath also for this current session
      "`n$PathToAdd has been added to the $UserType $PathType"
  }
  else {
      "'$PathToAdd' is already in the $UserType $PathType. Nothing to do."
  }
}