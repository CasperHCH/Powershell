<#
.SYNOPSIS
	Launches OBS Studio
.DESCRIPTION
	This script launches the OBS Studio application.
.EXAMPLE
	PS> ./open-obs-studio
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


}

try {
	TryLaunching  
	TryLaunching  
	exit 0 # success
} catch {
	
	exit 1
}
