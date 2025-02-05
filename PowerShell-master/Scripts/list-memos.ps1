<#
.SYNOPSIS
	Lists your memo entries
.DESCRIPTION
	This PowerShell script lists all memo entries in Memos.csv in your home folder.
.EXAMPLE
	PS> ./list-memos.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


try {
	$Path = 
	if (Test-Path  -pathType leaf) {
		write-progress 
		$Table = Import-CSV 
		write-progress -completed 

		
		
		
		foreach($Row in $Table) {
			$Time = $Row.Time
			$Text = $Row.Text
			
		}
	} else {
		
		exit 1
	}
	exit 0 # success
} catch {
	
	exit 1
}
