<#
.SYNOPSIS
	Lists verbs
.DESCRIPTION
	This PowerShell script lists all allowed verbs.
.EXAMPLE
	PS> ./list-verbs.ps1

	Verb        Group
	----        -----
	Add         Common            
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Get-Verb | Sort-Object -Property Verb
	exit 0 # success
} catch {
	
	exit 1
}
