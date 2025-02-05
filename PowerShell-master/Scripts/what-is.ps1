<#
.SYNOPSIS
	Explains an abbreviation
.DESCRIPTION
	This PowerShell script queries the meaning of the given abbreviation and prints it.
.PARAMETER abbr
	Specifies the abbreviation to query
.EXAMPLE
	PS> ./what-is VTOL
	💡 VTOL in aviation refers to: Vertical Take-Off and Landing
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$abbr = )

try {
	if ($abbr -eq  ) { $abbr = Read-Host  }
	$files = (Get-ChildItem )
	$basename = 
	foreach($file in $files) {
		$table = Import-CSV 
		foreach($row in $table) {
			if ($row.ABBR -ne $abbr) { continue }
			$basename = (Get-Item ).Basename -Replace ,
			
		}
	}
	if ($basename -eq ) {  }
	exit 0 # success
} catch {
	
	exit 1
}
