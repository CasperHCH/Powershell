<#
.SYNOPSIS
Runs a PowerShell script on one or more Citrix servers.

.DESCRIPTION
Uses PowerShell remoting to execute a local script file on the specified Citrix
servers. Returns a result object for each server and supports WhatIf semantics.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerNames,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential
)

$invokeCommandParameters = @{
    FilePath = $ScriptPath
}

if ($Credential) {
    $invokeCommandParameters.Credential = $Credential
}

foreach ($computerName in $ComputerNames) {
    $result = [pscustomobject]@{
        ComputerName = $computerName
        Succeeded    = $false
        Message      = $null
    }

    if (-not $PSCmdlet.ShouldProcess($computerName, "Execute script '$ScriptPath'")) {
        $result.Message = 'Skipped by WhatIf/ShouldProcess.'
        $result
        continue
    }

    try {
        Invoke-Command -ComputerName $computerName @invokeCommandParameters -ErrorAction Stop | Out-Null
        $result.Succeeded = $true
        $result.Message = 'Script executed successfully.'
    }
    catch {
        $result.Message = $_.Exception.Message
    }

    $result
}