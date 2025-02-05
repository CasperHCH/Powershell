<#
.SYNOPSIS
	Lists all automatic variables of PowerShell
.DESCRIPTION
	This PowerShell script lists all automatic variables of PowerShell.
.EXAMPLE
	PS> ./list-automatic-variables.ps1

	Variable                  Content
	--------                  -------
	$HOME                     C:\Users\Markus
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


}



try {
	ListAutomaticVariables | format-table -property Variable,Content
	exit 0 # success
} catch {
	
	exit 1
}
