### EXCHANGE ###

# Functions to connect / disconnect Remote Exchange Management Shell
Function Connect-ExchPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the Exchange server FQDN")]
        [string]$ExchangeServer,

        [Parameter(Mandatory = $false, HelpMessage = "Specify credentials for authentication")]
        [System.Management.Automation.PSCredential]$Credential
    )

    # Get Exchange server from config file if not provided
    if (-not $ExchangeServer) {
        $ConfigPath = "$PSScriptRoot\..\..\data\config\exchange-server.txt"
        if (Test-Path $ConfigPath) {
            $ExchangeServer = Get-Content $ConfigPath -ErrorAction SilentlyContinue
        }

        if (-not $ExchangeServer) {
            $ExchangeServer = Read-Host "Enter Exchange server FQDN (e.g., exchange.company.com)"
        }
    }

    try {
        if (-not $Credential) {
            $Credential = Get-Credential -Message "Enter Exchange credentials"
        }

        $ConnectionURI = "http://$ExchangeServer/Powershell"
        $RPSession = New-PSSession -Name "ExchangeRemoting" -ConfigurationName Microsoft.Exchange -ConnectionURI $ConnectionURI -Credential $Credential -ErrorAction Stop
        Import-PSSession $RPSession -Prefix local -ErrorAction Stop
        Write-Host "Connected to Exchange Server: $ExchangeServer" -ForegroundColor Green

        # Save server config for future use
        $ConfigDir = "$PSScriptRoot\..\..\data\config"
        if (-not (Test-Path $ConfigDir)) {
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        }
        $ExchangeServer | Out-File "$ConfigDir\exchange-server.txt" -Force
    }
    catch {
        Write-Error "Failed to connect to Exchange Server: $($_.Exception.Message)"
    }
} #end function

Function Disconnect-ExchPowershell {
    Get-PSSession -Name "ExchangeRemoting" | Remove-PSSession
    Write-Host "Disconnected from Exchange Server" -ForegroundColor Yellow
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
Function Connect-O365Powershell {
    $O365Session = New-PSSession -Name "O365Remoting" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential (Get-Credential) -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
    Write-Host "Connected to Office 365" -ForegroundColor Green
}

Function Remove-O365Powershell {
    Get-PSSession -Name "O365Remoting" | Remove-PSSession
    Write-Host "Disconnected from Office 365" -ForegroundColor Yellow
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
Function Connect-LyncPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the Lync/Skype for Business server URI")]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionUri,

        [Parameter(Mandatory = $false, HelpMessage = "Specify the session name")]
        [string]$SessionName = "LyncRemoting",

        [Parameter(Mandatory = $false, HelpMessage = "Specify credentials for authentication")]
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        if (-not $Credential) {
            $Credential = Get-Credential -Message "Enter Lync/Skype for Business credentials"
        }

        $CSSession = New-PSSession -Name $SessionName -ConnectionUri $ConnectionUri -Credential $Credential -ErrorAction Stop
        Import-PSSession $CSSession -ErrorAction Stop
        Write-Host "Connected to Lync/Skype for Business: $ConnectionUri" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Lync/Skype for Business: $($_.Exception.Message)"
    }
} #end function

Function Disconnect-LyncPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the session name to disconnect")]
        [string]$SessionName = "LyncRemoting"
    )

    try {
        $Session = Get-PSSession -Name $SessionName -ErrorAction SilentlyContinue
        if ($Session) {
            Remove-PSSession -Session $Session -ErrorAction Stop
            Write-Host "Disconnected from Lync/Skype for Business session: $SessionName" -ForegroundColor Yellow
        } else {
            Write-Warning "No Lync/Skype for Business session found with name: $SessionName"
        }
    }
    catch {
        Write-Error "Failed to disconnect from Lync/Skype for Business: $($_.Exception.Message)"
    }
} #end function

## END LYNC
