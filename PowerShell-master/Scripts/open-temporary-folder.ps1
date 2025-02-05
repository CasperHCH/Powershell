<#
.SYNOPSIS
	Opens the temporary folder
.DESCRIPTION
	This script launches the File Explorer showing the temporary folder.
.EXAMPLE
	PS> ./open-temporary-folder
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	if ( -ne )	{ return  }
	if ($IsLinux) { return  }
	return 
}

try {
	$Path = GetTempDir
	if (-not(test-path  -pathType container)) {
		throw 
	}
	&  
	exit 0 # success
} catch {
	
	exit 1
}
