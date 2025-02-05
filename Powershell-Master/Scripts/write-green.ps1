<#
.SYNOPSIS
	Writes text in a green foreground color
.DESCRIPTION
	This PowerShell script writes text in a green foreground color.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-green 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

if ($text -eq  ) { $text = read-host  }

write-host -foregroundColor green 
exit 0 # success
