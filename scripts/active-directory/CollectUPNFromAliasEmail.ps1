#requires -version 5.1

<#
.SYNOPSIS
Resolves Azure AD user principal names from a CSV of email aliases.

.DESCRIPTION
Imports a CSV containing Name, Mail, and SamAccountName columns, connects to
Azure AD, resolves matching user principal names, and exports the results to CSV.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'Path to a CSV containing Mail, Name, and SamAccountName columns.')]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$UserList,

    [Parameter(Mandatory = $false, HelpMessage = 'Optional output CSV path.')]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'CollectUPNFromAliasEmail.csv'),

    [Parameter(Mandatory = $false, HelpMessage = 'Path to a reusable Azure AD sign-in file created with Export-Clixml.')]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$AzureAdAuthFilePath
)

$script:SessionId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$script:LogPath = Join-Path -Path $PSScriptRoot -ChildPath 'CollectUPNFromAliasEmail.log'

function Write-ScriptLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'AUDIT')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$script:SessionId] [$Level] $Message"
    Add-Content -Path $script:LogPath -Value $entry

    if ($Level -eq 'ERROR') {
        Write-Error $Message
        return
    }

    if ($Level -eq 'WARNING') {
        Write-Warning $Message
        return
    }

    Write-Verbose $Message
}

function Connect-AzureAdIfNeeded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$AzureAdAuthFilePath
    )

    Import-Module AzureAD -ErrorAction Stop

    try {
        $null = Get-AzureADTenantDetail -ErrorAction Stop
        Write-ScriptLog -Message 'Reusing existing Azure AD session.'
        return
    }
    catch {
        Write-ScriptLog -Message 'No active Azure AD session found. Connecting now.'
    }

    if ($AzureAdAuthFilePath) {
        $azureAdAuthData = Import-Clixml -Path $AzureAdAuthFilePath
        Connect-AzureAD -Credential $azureAdAuthData -ErrorAction Stop | Out-Null
    }
    else {
        Connect-AzureAD -ErrorAction Stop | Out-Null
    }

    Write-ScriptLog -Message 'Azure AD connection established.'
}

function Resolve-AzureAdUserPrincipalName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mail
    )

    $escapedMail = $Mail.Replace("'", "''")

    try {
        $user = Get-AzureADUser -All $true -Filter "mail eq '$escapedMail'" -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        $user = $null
    }

    if (-not $user) {
        $user = Get-AzureADUser -All $true | Where-Object {
            $_.Mail -eq $Mail -or $_.UserPrincipalName -eq $Mail
        } | Select-Object -First 1
    }

    return $user
}

try {
    $inputUsers = Import-Csv -Path $UserList -ErrorAction Stop
    if (-not $inputUsers) {
        throw 'The provided CSV file contains no rows.'
    }

    foreach ($requiredColumn in @('Mail', 'Name', 'SamAccountName')) {
        if ($requiredColumn -notin $inputUsers[0].PSObject.Properties.Name) {
            throw "The CSV file must contain a '$requiredColumn' column."
        }
    }

    Connect-AzureAdIfNeeded -AzureAdAuthFilePath $AzureAdAuthFilePath

    $results = foreach ($user in $inputUsers) {
        if ([string]::IsNullOrWhiteSpace($user.Mail)) {
            Write-ScriptLog -Level 'WARNING' -Message "Skipping row with empty mail value for '$($user.SamAccountName)'."
            continue
        }

        $azureUser = Resolve-AzureAdUserPrincipalName -Mail $user.Mail

        if (-not $azureUser) {
            Write-ScriptLog -Level 'WARNING' -Message "No Azure AD match found for '$($user.Mail)'."
        }

        [pscustomobject]@{
            Name              = $user.Name
            Mail              = $user.Mail
            SamAccountName    = $user.SamAccountName
            UserPrincipalName = $azureUser.UserPrincipalName
        }
    }

    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-ScriptLog -Level 'AUDIT' -Message "Resolved $($results.Count) records to '$OutputPath'."
    $results
}
catch {
    Write-ScriptLog -Level 'ERROR' -Message $_.Exception.Message
    throw
}