<#
.SYNOPSIS
	Checks an IPv6 address for validity
.DESCRIPTION
	This PowerShell script checks the given IPv6 address for validity
.PARAMETER Address
	Specifies the IPv6 address to check
.EXAMPLE
	PS> ./check-ipv6-address fe80::200:5aee:feaa:20a2
	✔️ IPv6 fe80::200:5aee:feaa:20a2 is valid
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Address = )

)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))'
    $G = '[a-f\d]{1,4}'
    $Tail = @(,
    ,
    ,
    ,
    ,
    ,
    )
    [string] $IPv6RegexString = $G
    $Tail | foreach { $IPv6RegexString =  }
    $IPv6RegexString = 
    $IPv6RegexString = $IPv6RegexString -replace '\(' , '(?:' # make all groups non-capturing
    [regex] $IPv6Regex = $IPv6RegexString
    if ($IP -imatch ) {
    	return $true
    } else {
    	return $false
    }
}

try {
	if ($Address -eq  ) {
		$Address = read-host 
	}
	if (IsIPv6AddressValid $Address) {
		
		exit 0 # success
	} else {
		write-warning 
		exit 1
	}
} catch {
	
	exit 1
}
