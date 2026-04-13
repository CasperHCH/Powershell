<#
.SYNOPSIS
    Retrieves AD Sync scheduler information from Azure AD Connect server
.DESCRIPTION
    This function connects to an AD Sync server and retrieves the current status of the
    Azure AD Connect synchronization scheduler. It supports configuration-driven server
    selection and credential management.
.PARAMETER ComputerName
    The name or FQDN of the AD Sync server. If not provided, config file is used.
.PARAMETER Credential
    PowerShell credential object for authentication. If not provided, will use current context.
.PARAMETER Interactive
    Prompt for ComputerName when no value is supplied and config is missing.
.EXAMPLE
    Get-AdSync
    Retrieves AD Sync status using configured server or prompts for server name.
.EXAMPLE
    Get-AdSync -ComputerName "adsync-srv-01"
    Retrieves AD Sync status from the specified server.
.EXAMPLE
    $cred = Get-Credential
    Get-AdSync -ComputerName "adsync-srv-01" -Credential $cred
    Retrieves AD Sync status using provided credentials.
.NOTES
    Requires appropriate permissions on the AD Sync server.
    Configuration is saved to data/config/adsync-server.txt for future use.
#>
function Get-AdSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the AD Sync server name")]
        [string]$ComputerName,

        [Parameter(Mandatory = $false, HelpMessage = "Specify credentials for authentication")]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $false, HelpMessage = "Prompt for server name when not provided")]
        [switch]$Interactive
    )

    # Get AD Sync server from config file if not provided
    if (-not $ComputerName) {
        $ConfigPath = "$PSScriptRoot\..\data\config\adsync-server.txt"
        if (Test-Path $ConfigPath) {
            $ComputerName = Get-Content $ConfigPath -ErrorAction SilentlyContinue
        }

        if (-not $ComputerName) {
            if ($Interactive) {
                $ComputerName = Read-Host "Enter AD Sync server name (e.g., adsync-server-01)"
            } else {
                throw "ComputerName was not provided and no configuration value was found at '$ConfigPath'. Provide -ComputerName or use -Interactive."
            }
        }
    }

    try {
        Write-Verbose "Connecting to AD Sync server: $ComputerName"

        if ($Credential) {
            $Result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
                Get-ADSyncScheduler
            } -ErrorAction Stop
        } else {
            $Result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                Get-ADSyncScheduler
            } -ErrorAction Stop
        }

        # Save server config for future use
        $ConfigDir = "$PSScriptRoot\..\data\config"
        if (-not (Test-Path $ConfigDir)) {
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        }
        $ComputerName | Out-File "$ConfigDir\adsync-server.txt" -Force

        return $Result
    } catch {
        Write-Warning "Failed to connect to AD Sync server '$ComputerName': $($_.Exception.Message)"
        Write-Information "Ensure the server name is correct and you have appropriate permissions." -InformationAction Continue
        return $null
    }
}
