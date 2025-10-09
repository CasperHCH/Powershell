function Test-ADCrential {
    [CmdletBinding()]
    param(
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
            Write-Verbose "✅ Credentials validated successfully for $DomainName\\$UserName"
            return $True
        }
        else {
            throw "❌ Invalid credentials for $DomainName\\$UserName"
        }
    }

    catch {
        Write-Verbose
        return $False
    }
}
