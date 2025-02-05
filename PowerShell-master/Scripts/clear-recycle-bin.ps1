<#
.SYNOPSIS
	Clears the recycle bin folder
.DESCRIPTION
	This PowerShell script removes the content of the recycle bin folder permanently.
	IMPORTANT NOTE: this cannot be undo!
.EXAMPLE
	PS> ./clear-recycle-bin
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Clear-RecycleBin -Confirm:$false
	if ($lastExitCode -ne ) { throw  }

	&  
	exit 0 # success
} catch {
	
	exit 1
}
