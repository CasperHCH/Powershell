<#
.SYNOPSIS
	Lists the installed languages
.DESCRIPTION
	This PowerShell script lists the installed languages.
.EXAMPLE
	PS> ./list-installed-languages.ps1

	Tag   Autonym               English Spellchecking Handwriting
	---   -------               ------- ------------- -----------
	de-DE Deutsch (Deutschland) German  True          False
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	}
}

try {
	ListInstalledLanguages | Format-Table -property Tag,Autonym,English,Spellchecking,Handwriting
	exit 0 # success
} catch {
	
	exit 1
}
