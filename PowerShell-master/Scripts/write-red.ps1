<#
.SYNOPSIS
	Writes text in a red foreground color
.DESCRIPTION
	This PowerShell script writes text in a red foreground color.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-red 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

if ($text -eq  ) { $text = read-host  }

write-host -foregroundcolor red 
exit 0 # success
