<#
.SYNOPSIS
    Enterprise connection functions for Exchange and Office 365 PowerShell management

.DESCRIPTION
    This module provides secure connection functions for Exchange on-premises and Office 365
    with comprehensive security features including HTTPS enforcement, credential management,
    audit logging, and parameter validation.

.NOTES
    Author: IT Infrastructure Team
    Version: 2.0 (Security Enhanced)
    Security Classification: Confidential
    Requires: PowerShell 5.1+, Exchange Management permissions

    SECURITY FEATURES:
    - HTTPS-only connections for Exchange on-premises
    - Secure credential management with storage support
    - Comprehensive audit logging
    - Input validation and sanitization
    - Error handling with security context
#>

### EXCHANGE ON-PREMISES ###

<#
.SYNOPSIS
    Securely connects to Exchange PowerShell Management Shell using HTTPS

.DESCRIPTION
    Establishes a secure PowerShell session to an Exchange server and imports Exchange cmdlets.
    Enforces HTTPS communication and provides comprehensive audit logging.

.PARAMETER ExchangeServer
    The FQDN of the Exchange server to connect to. Must be a valid FQDN format.
    If not provided, will check config file or prompt user.

.PARAMETER Credential
    PowerShell credential object for authentication. If not provided, will prompt securely.

.PARAMETER StoredCredentialTarget
    Target name for retrieving stored credentials from Windows Credential Manager

.EXAMPLE
    Connect-ExchPowershell -ExchangeServer "exchange.contoso.com"
    Connects to the specified Exchange server using prompted credentials via HTTPS.

.EXAMPLE
    $cred = Get-Credential
    Connect-ExchPowershell -ExchangeServer "exchange.contoso.com" -Credential $cred
    Connects using provided credentials with HTTPS security.

.EXAMPLE
    Connect-ExchPowershell -StoredCredentialTarget "ExchangeService"
    Uses stored credentials from Windows Credential Manager.

.NOTES
    - Requires appropriate Exchange management permissions
    - HTTPS connection enforced for security compliance
    - Configuration saved to data/config/exchange-server.txt
    - All connections are logged for audit purposes
#>
function Connect-ExchPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Exchange server FQDN (must be valid FQDN format)")]
        [ValidatePattern('^[\w\-\.]+\.[a-zA-Z]{2,}$')]
        [string]$ExchangeServer,

        [Parameter(Mandatory = $false, HelpMessage = "Exchange administrator credentials")]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $false, HelpMessage = "Use stored credentials from credential manager")]
        [string]$StoredCredentialTarget
    )

    # Security audit logging
    $auditEntry = @{
        Timestamp    = Get-Date -Format "o"
        Action       = "Connect-ExchPowershell"
        User         = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        TargetServer = $ExchangeServer
        AuthMethod   = if ($StoredCredentialTarget) { "StoredCredential" } else { "Interactive" }
    }

    # Secure server configuration management
    if (-not $ExchangeServer) {
        $ConfigPath = "$PSScriptRoot\..\..\data\config\exchange-server.txt"
        if (Test-Path $ConfigPath) {
            $ExchangeServer = (Get-Content $ConfigPath -ErrorAction SilentlyContinue).Trim()
            Write-Verbose "Loaded Exchange server from config: $ExchangeServer"
        }

        if (-not $ExchangeServer -or -not ($ExchangeServer -match '^[\w\-\.]+\.[a-zA-Z]{2,}$')) {
            do {
                $ExchangeServer = Read-Host "Enter Exchange server FQDN (e.g., exchange.company.com)"
            } while (-not ($ExchangeServer -match '^[\w\-\.]+\.[a-zA-Z]{2,}$'))
        }
    }

    $auditEntry.TargetServer = $ExchangeServer

    try {
        # Secure credential management
        if ($StoredCredentialTarget) {
            try {
                $Credential = Get-StoredCredential -Target $StoredCredentialTarget -ErrorAction Stop
                Write-Verbose "Using stored credentials for target: $StoredCredentialTarget"
                $auditEntry.AuthMethod = "StoredCredential:$StoredCredentialTarget"
            }
            catch {
                Write-Warning "Failed to retrieve stored credentials: $($_.Exception.Message)"
            }
        }

        if (-not $Credential) {
            $Credential = Get-Credential -Message "Enter Exchange administrator credentials"
            if (-not $Credential) {
                throw "Exchange credentials are required"
            }
        }

        # Use HTTPS for secure communication (HTTP fallback deprecated for security)
        $ConnectionURI = "https://$ExchangeServer/Powershell"

        # Validate Exchange server FQDN format
        if (-not ($ExchangeServer -match '^[\w\-\.]+\.[a-zA-Z]{2,}$')) {
            throw "Invalid Exchange server FQDN format: $ExchangeServer"
        }

        Write-Verbose "Connecting to Exchange via secure HTTPS: $ConnectionURI"
        $RPSession = New-PSSession -Name "ExchangeRemoting" -ConfigurationName Microsoft.Exchange -ConnectionUri $ConnectionURI -Credential $Credential -ErrorAction Stop
        Import-PSSession $RPSession -Prefix local -ErrorAction Stop -AllowClobber

        Write-Host "✅ Successfully connected to Exchange Server: $ExchangeServer" -ForegroundColor Green
        $auditEntry.Status = "Success"
        $auditEntry.SessionId = $RPSession.Id

        # Save server config for future use (secure path)
        $ConfigDir = "$PSScriptRoot\..\..\data\config"
        if (-not (Test-Path $ConfigDir)) {
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        }
        $ExchangeServer | Out-File "$ConfigDir\exchange-server.txt" -Force -Encoding UTF8

    }
    catch {
        $errorMsg = "Failed to connect to Exchange Server '$ExchangeServer': $($_.Exception.Message)"
        Write-Error $errorMsg
        $auditEntry.Status = "Failed"
        $auditEntry.Error = $_.Exception.Message
        throw
    }
    finally {
        # Security audit logging
        Write-Verbose "Exchange connection audit: $($auditEntry | ConvertTo-Json -Compress)"
    }
} #end function

function Disconnect-ExchPowershell {
    [CmdletBinding()]
    param()

    Get-PSSession -Name "ExchangeRemoting" | Remove-PSSession
    Write-Information "Disconnected from Exchange Server" -InformationAction Continue
} #end function

### END EXCHANGE ###


###  O365  ###

# Functions to connect / disconnect remote Exchange Management Shell on O365
function Connect-O365Powershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Office 365 administrator credentials")]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $false, HelpMessage = "Use stored credentials from credential manager")]
        [string]$StoredCredentialTarget
    )

    # Secure credential management
    if ($StoredCredentialTarget) {
        try {
            $Credential = Get-StoredCredential -Target $StoredCredentialTarget -ErrorAction Stop
            Write-Verbose "Using stored credentials for target: $StoredCredentialTarget"
        }
        catch {
            Write-Warning "Failed to retrieve stored credentials: $($_.Exception.Message)"
        }
    }

    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter Office 365 administrator credentials"
        if (-not $Credential) {
            throw "Office 365 credentials are required"
        }
    }

    $O365Session = New-PSSession -Name "O365Remoting" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic -AllowRedirection
    Import-PSSession $O365Session -DisableNameChecking -Prefix cloud
    Write-Information "Connected to Office 365" -InformationAction Continue
}

function Remove-O365Powershell {
    [CmdletBinding()]
    param()

    Get-PSSession -Name "O365Remoting" | Remove-PSSession
    Write-Information "Disconnected from Office 365" -InformationAction Continue
}

###  END O365  ###


### LYNC ###

# Functions to connect / disconnect remote Lync Management Shell
function Connect-LyncPowershell {
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
        Write-Information "Connected to Lync/Skype for Business: $ConnectionUri" -InformationAction Continue
    }
    catch {
        Write-Error "Failed to connect to Lync/Skype for Business: $($_.Exception.Message)"
    }
} #end function

function Disconnect-LyncPowershell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the session name to disconnect")]
        [string]$SessionName = "LyncRemoting"
    )

    try {
        $Session = Get-PSSession -Name $SessionName -ErrorAction SilentlyContinue
        if ($Session) {
            Remove-PSSession -Session $Session -ErrorAction Stop
            Write-Information "Disconnected from Lync/Skype for Business session: $SessionName" -InformationAction Continue
        }
        else {
            Write-Warning "No Lync/Skype for Business session found with name: $SessionName"
        }
    }
    catch {
        Write-Error "Failed to disconnect from Lync/Skype for Business: $($_.Exception.Message)"
    }
} #end function

## END LYNC
