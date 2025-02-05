<#
.SYNOPSIS
	Lists all console colors
.DESCRIPTION
	This PowerShell script lists all available console colors.
.EXAMPLE
	PS> ./list-console-colors.ps1

	Color     As Foreground     As Background
	-----     -------------     -------------
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$Colors = [Enum]::GetValues([ConsoleColor])
	
	
	
	foreach($Color in $Colors) {
		$Color = 
		$Color = $Color.substring(0, 15)
		write-host -noNewline 
		write-host -noNewline -foregroundcolor $Color 
		write-host -noNewline -backgroundcolor $Color 
		write-host 
	}
	exit 0 # success
} catch {
	
	exit 1
}
