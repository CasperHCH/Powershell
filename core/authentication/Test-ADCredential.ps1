<#
.SYNOPSIS
    Tests Active Directory credentials for validity.
.DESCRIPTION
    This function validates Active Directory credentials by attempting to authenticate
    against the domain using the provided credentials or prompting for them.
.PARAMETER Credential
    The PSCredential object containing the username and password to test.
    If not provided, will prompt for credentials.
.EXAMPLE
    Test-ADCredential
    Prompts for credentials and tests them against Active Directory.
.EXAMPLE
    $cred = Get-Credential
    Test-ADCredential -Credential $cred
    Tests the provided credential object against Active Directory.
.OUTPUTS
    System.Boolean
    Returns $true if credentials are valid, $false otherwise.
.NOTES
    Requires the System.DirectoryServices.AccountManagement assembly.
    Works with domain\username or username@domain formats.
#>
function Test-ADCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [pscredential]$Credential
    )

    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        if (!$Credential) {
            $Credential = Get-Credential -ErrorAction Stop
        }

        # Parse domain and username from credential
        $Username = $Credential.UserName
        $DomainName = $null
        $UserName = $null

        if ($Username.Contains('\\')) {
            $parts = $Username.Split('\\')
            $DomainName = $parts[0]
            $UserName = $parts[1]
        } elseif ($Username.Contains('@')) {
            $parts = $Username.Split('@')
            $UserName = $parts[0]
            $DomainName = $parts[1]
        } else {
            $UserName = $Username
            $DomainName = $env:USERDOMAIN
        }

        if (-not $DomainName -or -not $UserName) {
            throw "Invalid credential format. Use DOMAIN\\Username or Username@domain.com"
        }

        $Password = $Credential.GetNetworkCredential().Password

        $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)

        if ($PC.ValidateCredentials($UserName,$Password)) {
            Write-Verbose "Credentials validated successfully for $DomainName\\$UserName"
            return $True
        }
        else {
            throw "Invalid credentials for $DomainName\\$UserName"
        }
    }

    catch {
        Write-Verbose "Credential validation failed: $($_.Exception.Message)"
        return $False
    }
}
