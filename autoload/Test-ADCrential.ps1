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

        if ($Credential.username.split().count -ne 2) {
            throw 
        }
     
        $DomainName = $Credential.username.Split()[0]
        $UserName = $Credential.username.Split()[1]
        $Password = $Credential.GetNetworkCredential().Password
     
        $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)

        if ($PC.ValidateCredentials($UserName,$Password)) {
            Write-Verbose 
            return $True
        }

        else {
            throw 
        }
    }
    
    catch {
        Write-Verbose 
        return $False
    }
}
