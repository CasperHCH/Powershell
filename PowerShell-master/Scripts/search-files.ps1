<#
.SYNOPSIS
	Searches for a pattern in files
.DESCRIPTION
	This PowerShell script searches for a pattern in the given files.
.PARAMETER pattern
	Specifies the search pattern
.PARAMETER files
	Specifies the files
.EXAMPLE
	PS> ./search-files UFO C:\Temp\*.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$pattern = , [string]$files = )


	}
	write-output 
}

try {
	if ($pattern -eq  ) { $pattern = read-host  }
	if ($files -eq  ) { $files = read-host  }

	ListLocations $pattern $files | format-table -property Path,Line,Text
	exit 0 # success
} catch {
	
	exit 1
}
