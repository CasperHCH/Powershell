function Get-AdSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the AD Sync server name")]
        [string]$ComputerName,

        [Parameter(Mandatory = $false, HelpMessage = "Specify credentials for authentication")]
        [System.Management.Automation.PSCredential]$Credential
    )

    # Get AD Sync server from config file if not provided
    if (-not $ComputerName) {
        $ConfigPath = "$PSScriptRoot\..\data\config\adsync-server.txt"
        if (Test-Path $ConfigPath) {
            $ComputerName = Get-Content $ConfigPath -ErrorAction SilentlyContinue
        }

        if (-not $ComputerName) {
            $ComputerName = Read-Host "Enter AD Sync server name (e.g., adsync-server-01)"
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
    }
    catch {
        Write-Warning "Failed to connect to AD Sync server '$ComputerName': $($_.Exception.Message)"
        Write-Host "Ensure the server name is correct and you have appropriate permissions." -ForegroundColor Yellow
        Break
    }
}
