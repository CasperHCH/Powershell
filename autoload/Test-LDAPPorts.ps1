<#
.SYNOPSIS
    Test LDAP and LDAPS connectivity to specified servers.
.DESCRIPTION
    This script tests LDAP and LDAPS connectivity to specified servers on various ports.
.PARAMETER ComputerName
    The name or IP address of the computer(s) to test.
.PARAMETER GCPortLDAP
    The port number for Global Catalog LDAP (default: 3268).
.PARAMETER GCPortLDAPSSL
    The port number for Global Catalog LDAPS (default: 3269).
.PARAMETER PortLDAP
    The port number for LDAP (default: 389).
.PARAMETER PortLDAPS
    The port number for LDAPS (default: 636).
.INPUTS
    None
.OUTPUTS
    A custom object with the test results.
.NOTES
    Ensure the Active Directory module is installed and available.
.EXAMPLE
    Test-LDAP -ComputerName "dc01.example.com"
    Tests LDAP and LDAPS connectivity to the specified server.
#>

function Test-LDAPPorts {
    [CmdletBinding()]
    param(
        [string] $ServerName,
        [int] $Port
    )
    if ($ServerName -and $Port -ne 0) {
        try {
            $LDAP = "LDAP://${ServerName}:${Port}"
            $Connection = [ADSI]($LDAP)
            $Connection.Close()
            return $true
        } catch {
            Write-Warning -Message "Failed to connect to $ServerName on port $($Port): ($_)"
        }
        return $false
    }
}

function Test-LDAP {
    [CmdletBinding()]
    param (
        [alias('Server', 'IpAddress')][Parameter(Mandatory = $True)][string[]]$ComputerName,
        [int] $GCPortLDAP = 3268,
        [int] $GCPortLDAPSSL = 3269,
        [int] $PortLDAP = 389,
        [int] $PortLDAPS = 636
    )

    # Checks for ServerName - Makes sure to convert IPAddress to DNS
    foreach ($Computer in $ComputerName) {
        $ADServerFQDN = Resolve-DnsName -Name $Computer -ErrorAction SilentlyContinue
        if ($ADServerFQDN) {
            if ($ADServerFQDN.NameHost) {
                $ServerName = $ADServerFQDN[0].NameHost
            } else {
                $FilterName = $ADServerFQDN | Where-Object { $_.QueryType -eq 'A' }
                $ServerName = $FilterName[0].Name
            }
        } else {
            $ServerName = ''
        }

        $GlobalCatalogSSL = Test-LDAPPorts -ServerName $ServerName -Port $GCPortLDAPSSL
        $GlobalCatalogNonSSL = Test-LDAPPorts -ServerName $ServerName -Port $GCPortLDAP
        $ConnectionLDAPS = Test-LDAPPorts -ServerName $ServerName -Port $PortLDAPS
        $ConnectionLDAP = Test-LDAPPorts -ServerName $ServerName -Port $PortLDAP

        $PortsThatWork = @(
            if ($GlobalCatalogNonSSL) { $GCPortLDAP }
            if ($GlobalCatalogSSL) { $GCPortLDAPSSL }
            if ($ConnectionLDAP) { $PortLDAP }
            if ($ConnectionLDAPS) { $PortLDAPS }
        ) | Sort-Object

        [pscustomobject]@{
            Computer           = $Computer
            ComputerFQDN       = $ServerName
            GlobalCatalogLDAP  = $GlobalCatalogNonSSL
            GlobalCatalogLDAPS = $GlobalCatalogSSL
            LDAP               = $ConnectionLDAP
            LDAPS              = $ConnectionLDAPS
            AvailablePorts     = $PortsThatWork -join ','
        }
    }
}

# Example usage:
# Test-LDAP -ComputerName "dc01.example.com"
# Test-LDAP -ComputerName "dc01.example.com", "dc02.example.com"