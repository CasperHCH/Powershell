#requires -version 4
<#
.SYNOPSIS
    Adds a path entry to Path or PSModulePath with WhatIf support.
.DESCRIPTION
    Defines Add-EnvPathEntry for adding a specified path to system or user environment
    variables. For backward compatibility, this script also creates an AddTo-Path alias.
.PARAMETER PathToAdd
    The path to add to the environment variable. Use an empty string to show current value.
.PARAMETER UserType
    Specifies whether to add the path to the System or User environment variables.
.PARAMETER PathType
    Specifies whether to add the path to Path or PSModulePath.
.EXAMPLE
    Add-EnvPathEntry -PathToAdd "C:\NewPath" -UserType "User" -PathType "Path"
.EXAMPLE
    AddTo-Path -PathToAdd "" -UserType "User" -PathType "Path"
#>
function Add-EnvPathEntry {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the path to add. Use an empty string to display the current value.")]
        [AllowEmptyString()]
        [string]$PathToAdd,

        [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to the System or User environment variables.")]
        [ValidateSet('System', 'User')]
        [string]$UserType,

        [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to Path or PSModulePath.")]
        [ValidateSet('Path', 'PSModulePath')]
        [string]$PathType
    )

    if ($UserType -eq 'System') {
        $regPropertyLocation = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
    } else {
        $regPropertyLocation = 'HKCU:\Environment'
    }

    # Some environments do not have a user-level Path/PSModulePath value yet.
    $pathOld = ''
    try {
        $pathOld = (Get-ItemProperty -Path $regPropertyLocation -Name $PathType -ErrorAction Stop).$PathType
    } catch {
        Write-Verbose "$PathType value was not found at $regPropertyLocation. It will be created if needed."
    }

    $pathArray = @()
    if (-not [string]::IsNullOrWhiteSpace($pathOld)) {
        $pathArray = $pathOld -split ';' -replace '^\s+|\s+$', ''
    }

    if ($PathToAdd -eq '') {
        Write-Information "Current $PathType ($UserType): $pathOld" -InformationAction Continue
        return
    }

    if ($pathArray -contains $PathToAdd) {
        Write-Information "Path '$PathToAdd' is already present in $PathType ($UserType)" -InformationAction Continue
        return
    }

    if (-not (Test-Path -Path $PathToAdd)) {
        Write-Warning "Path '$PathToAdd' does not exist. Adding anyway..."
    }

    $pathNew = if ([string]::IsNullOrWhiteSpace($pathOld)) { $PathToAdd } else { $pathOld + ';' + $PathToAdd }

    try {
        if ($PSCmdlet.ShouldProcess("$PathType ($UserType)", "Add path entry '$PathToAdd'")) {
            Set-ItemProperty -Path $regPropertyLocation -Name $PathType -Value $pathNew -ErrorAction Stop
            Write-Information "Successfully added '$PathToAdd' to $PathType ($UserType)" -InformationAction Continue
            Get-ItemProperty -Path $regPropertyLocation -Name $PathType | Select-Object -ExpandProperty $PathType

            try {
                if ($PathType -eq 'Path') {
                    $env:Path += ";$PathToAdd"
                } else {
                    $env:PSModulePath += ";$PathToAdd"
                }
                Write-Information "Current session environment updated." -InformationAction Continue
            } catch {
                Write-Warning "Registry updated but failed to update current session: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Error "Failed to update $PathType environment variable: $($_.Exception.Message)"
        Write-Information "You may need to run PowerShell as Administrator to modify system environment variables." -InformationAction Continue
    }
}

# Backward compatibility for existing profile usage.
function AddTo-Path {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the path to add. Use an empty string to display the current value.")]
        [AllowEmptyString()]
        [string]$PathToAdd,

        [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to the System or User environment variables.")]
        [ValidateSet('System', 'User')]
        [string]$UserType,

        [Parameter(Mandatory = $true, HelpMessage = "Specify whether to add the path to Path or PSModulePath.")]
        [ValidateSet('Path', 'PSModulePath')]
        [string]$PathType
    )

    Add-EnvPathEntry @PSBoundParameters
}
