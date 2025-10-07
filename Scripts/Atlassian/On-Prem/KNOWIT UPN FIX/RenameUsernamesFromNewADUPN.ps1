#requires -version 4
<#
.SYNOPSIS
    Replace Jira usernames and email fields with new UPNs from Azure AD.
.DESCRIPTION
    This script collects old Active Directory `SamAccountNames` and emails, along with Azure UPNs, and updates Jira usernames and email fields accordingly.
.PARAMETER jirabaseurl
    The URL address, including `https://`, of your Jira instance.
.PARAMETER UserList
    Path to the CSV file containing old AD user data (SamAccountName and email).
.PARAMETER AdminAccount
    Jira admin account username.
.PARAMETER Token
    Jira admin account API token.
.INPUTS
    None.
.OUTPUTS
    A log file will be generated at the same location as this script, with the same name but `.log` extension.
.NOTES
    Version:        1.1
    Author:         Casper Hjorth Christensen
    Purpose/Change: To replace and change usernames and emails of Jira accounts after an AD migration.
.EXAMPLE
    RenameUsernamesFromNewADUPN -jirabaseurl https://jira-instance.example.com -UserList C:\Temp\Users.csv -AdminAccount admin -Token password
#>

# --- Parameters ---
Param (
    [Parameter(Mandatory = $true)]
    [string]$jirabaseurl,

    [Parameter(Mandatory = $true)]
    [string]$UserList,

    [Parameter(Mandatory = $true)]
    [string]$AdminAccount,

    [Parameter(Mandatory = $true)]
    [string]$Token
)

# --- Log File Setup ---
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path -Path $scriptDirectory -ChildPath "$($MyInvocation.MyCommand.Name -replace '.ps1$', '.log')"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

# --- Azure AD Connection ---
function Connect-AzureAD {
    Write-Log -Message "Connecting to Azure AD..." -Level "INFO"
    try {
        Import-Module AzureAD -ErrorAction Stop
        Connect-AzureAD -ErrorAction Stop
        Write-Log -Message "Connected to Azure AD successfully." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to connect to Azure AD: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# --- Load User List ---
function Load-UserList {
    Write-Log -Message "Loading user list from $UserList..." -Level "INFO"
    try {
        $users = Import-Csv -Path $UserList
        if (-not $users) {
            Write-Log -Message "The user list is empty." -Level "ERROR"
            throw "User list is empty."
        }
        Write-Log -Message "User list loaded successfully." -Level "INFO"
        return $users
    } catch {
        Write-Log -Message "Failed to load user list: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# --- Update Jira User ---
function Update-JiraUser {
    param (
        [string]$OldUsername,
        [string]$OldEmail,
        [string]$NewUPN
    )
    Write-Log -Message "Updating Jira user: $OldUsername -> $NewUPN" -Level "INFO"
    try {
        $uri = "$jirabaseurl/rest/api/3/user?username=$OldUsername"
        $body = @{
            name = $NewUPN
            emailAddress = $NewUPN
        } | ConvertTo-Json -Depth 10

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$AdminAccount`:$Token"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body -ErrorAction Stop
        Write-Log -Message "Successfully updated user: $OldUsername -> $NewUPN" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to update user $($OldUsername): $($_.Exception.Message)" -Level "ERROR"
    }
}

# --- Process Users ---
function Process-Users {
    param (
        [array]$UserList
    )
    foreach ($user in $UserList) {
        $OldUsername = $user.samaccountname
        $OldEmail = $user.mail

        Write-Log -Message "Processing user: $OldUsername ($OldEmail)" -Level "INFO"

        try {
            $filter = "mail eq '$($OldEmail)'"
            $AzureUser = Get-AzureADUser -Filter $filter | Select-Object -First 1 -Property UserPrincipalName

            if ($null -eq $AzureUser) {
                Write-Log -Message "No matching Azure AD user found for $OldEmail." -Level "WARNING"
                continue
            }

            $NewUPN = $AzureUser.UserPrincipalName
            if ($NewUPN -ne $OldUsername) {
                Update-JiraUser -OldUsername $OldUsername -OldEmail $OldEmail -NewUPN $NewUPN
            } else {
                Write-Log -Message "No update needed for $OldUsername." -Level "INFO"
            }
        } catch {
            Write-Log -Message "Error processing user $($OldUsername): $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# --- Execution ---
Write-Log -Message "Script execution started." -Level "INFO"

try {
    Connect-AzureAD
    $users = Load-UserList
    Process-Users -UserList $users
} catch {
    Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level "ERROR"
} finally {
    Write-Log -Message "Script execution completed." -Level "INFO"
}