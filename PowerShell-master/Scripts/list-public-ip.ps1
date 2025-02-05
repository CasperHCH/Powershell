<#
.SYNOPSIS
        Lists the public IP address(es)
.DESCRIPTION
        This PowerShell script queries the public IP address(es) and prints it.
.EXAMPLE
        PS> ./list-public-ip.ps1
	✅ Public IP address 185.72.209.161, 2003:f2:6128:fc01:e503:601:30c2:a028 near Munich
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		$publicIPv4 = (curl -4 --silent ifconfig.co)
		$publicIPv6 = (curl -6 --silent ifconfig.co)
		$city = (curl --silent ifconfig.co/city)
	} else {
		$publicIPv4 = (curl.exe -4 --silent ifconfig.co)
		$publicIPv6 = (curl.exe -6 --silent ifconfig.co)
		$city = (curl.exe --silent ifconfig.co/city)
	}
	if ( -eq ) { $publicIPv4 =  }
	if ( -eq ) { $publicIPv6 =  }
	if ( -eq ) { $city =  }
	Write-Output 
	exit 0 # success
} catch {
        
        exit 1
}
