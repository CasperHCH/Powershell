<#
.SYNOPSIS
	Writes text á la typewriter
.DESCRIPTION
	This PowerShell script writes the given text with the typewriter effect.
.PARAMETER text
	Specifies the text to write
.PARAMETER speed
	Specifies the speed (250 ms by default)
.EXAMPLE
	PS> ./write-typewriter 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = , [int]$speed = 200) # in milliseconds

try {
	$Random = New-Object System.Random
	$text -split '' | ForEach-Object {
		Write-Host -noNewline $_
		Start-Sleep -milliseconds $(1 + $Random.Next($speed))
	}
	Write-Host 
	exit 0 # success
} catch {
	
	exit 1
}
