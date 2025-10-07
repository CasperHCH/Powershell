#requires -version 4
<#
.SYNOPSIS
    Add a path to the environment.
.DESCRIPTION
    This script adds a specified path to the system or user environment variables.
.PARAMETER PathToAdd
    The path to add to the environment variable.
.PARAMETER UserType
    Specifies whether to add the path to the 'System' or 'User' environment variables.
.PARAMETER PathType
    Specifies whether to add the path to 'Path' or 'PSModulePath'.
.INPUTS
    None
.OUTPUTS
    The updated environment variable.
.NOTES
  Version:        1.0
  Author:         YorSubs
  Creation Date:  unknown
  URL:            https://stackoverflow.com/questions/714877/setting-windows-powershell-environment-variables
.EXAMPLE
    # Add to User Path (but only if not already present)
    AddTo-Path -PathToAdd "C:\NewPath" -UserType "User" -PathType "Path"

    # Just show the current status by putting an empty path
    AddTo-Path -PathToAdd "" -UserType "User" -PathType "Path"
#>
function AddTo-Path {
  param (
      [Parameter(Mandatory = $true, HelpMessage = "Specify the path to add.")]
      [ValidateNotNullOrEmpty()]
      [string]$PathToAdd,

      [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to the 'System' or 'User' environment variables.")]
      [ValidateSet('System', 'User')]
      [string]$UserType,

      [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to 'Path' or 'PSModulePath'.")]
      [ValidateSet('Path', 'PSModulePath')]
      [string]$PathType
  )

  # Determine the registry location based on UserType
  if ($UserType -eq 'System') {
      $RegPropertyLocation = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
  } elseif ($UserType -eq 'User') {
      $RegPropertyLocation = 'HKCU:\Environment'
  }

  # Get the current value of the environment variable
  $PathOld = (Get-ItemProperty -Path $RegPropertyLocation -Name $PathType).$PathType

  # Split the current path into an array
  $PathArray = $PathOld -Split ';' -replace '^\s+|\s+$', ''

  # Check if the path is already present
  if ($PathArray -notcontains $PathToAdd -and $PathToAdd -ne "") {
      # Add the new path to the array
      $PathNew = $PathOld + ';' + $PathToAdd
      # Update the environment variable in the registry
      Set-ItemProperty -Path $RegPropertyLocation -Name $PathType -Value $PathNew
      # Output the updated environment variable
      Get-ItemProperty -Path $RegPropertyLocation -Name $PathType | Select-Object -ExpandProperty $PathType

      # Update the environment variable for the current session
      if ($PathType -eq 'Path') {
          $env:Path += ";$PathToAdd"
      } elseif ($PathType -eq 'PSModulePath') {
          $env:PSModulePath += ";$PathToAdd"
      }
  } else {
      Write-Host "The path is already present or no path was provided." -ForegroundColor Yellow
  }
}

# Example usage:
# AddTo-Path -PathToAdd "C:\NewPath" -UserType "User" -PathType "Path"