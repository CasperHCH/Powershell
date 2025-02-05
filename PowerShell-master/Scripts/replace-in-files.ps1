<#
.SYNOPSIS
	Search and replace a pattern in the given files by the replacement
.DESCRIPTION
	This PowerShell script searches and replaces a pattern in the given files by the replacement.
.PARAMETER pattern
	Specifies the pattern to look for
.PARAMETER replacement
	Specifies the replacement
.PARAMETER files
	Specifies the file to scan
.EXAMPLE
	PS> ./replace-in-files NSA  C:\Temp\*.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$pattern = , [string]$replacement = , [string]$files = )



try {
	if ($pattern -eq  ) { $pattern = read-host  }
	if ($replacement -eq  ) { $replacement = read-host  }
	if ($files -eq  ) { $files = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	$fileList = (get-childItem -path  -attributes !Directory)
	foreach($file in $fileList) {
		ReplaceInFile $file $pattern $replacement
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
