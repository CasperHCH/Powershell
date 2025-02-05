<#
.SYNOPSIS
	Launches Visual Studio
.DESCRIPTION
	This PowerShell script launches the Microsoft Visual Studio application.
.EXAMPLE
	PS> ./open-visual-studio.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


}

try {
	tryToLaunch 
	tryToLaunch 
	exit 0 # success
} catch {
	
	exit 1
}
