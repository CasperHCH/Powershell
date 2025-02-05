<#
.SYNOPSIS
	Checks the given subnet mask for validity
.DESCRIPTION
	This PowerShell script checks the given subnet mask for validity.
.PARAMETER address
	Specifies the subnet mask to check
.EXAMPLE
	PS> ./check-subnet-mask.ps1 255.255.255.0
	✔️ subnet mask 255.255.255.0 is valid
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$address = )

 else {
		return $false
	}
}

try {
	if ($address -eq  ) { $address = read-host  }

	if (IsSubNetMaskValid $address) {
		
		exit 0 # success
	} else {
		write-warning 
		exit 1
	}
} catch {
	
	exit 1
}
