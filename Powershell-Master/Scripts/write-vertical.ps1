<#
.SYNOPSIS
	Writes text in vertical direction
.DESCRIPTION
	This PowerShell script writes text in vertical direction.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-vertical 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

try {
	if ($text -eq  ) { $text = read-host  }

	[char[]]$TextArray = $text
	foreach($Char in $TextArray) {
		write-output $Char
	}
	exit 0 # success
} catch {
	
	exit 1
}
