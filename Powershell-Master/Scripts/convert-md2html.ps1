<#
.SYNOPSIS
	Converts Markdown file(s) into HTML 
.DESCRIPTION
	This PowerShell script converts Markdown file(s) into HTML.
.PARAMETER FilePattern
	Specifies the file pattern to the Markdown file(s)
.EXAMPLE
	PS> ./convert-md2html.ps1 *.md
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$FilePattern = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($FilePattern -eq  ) { $FilePattern = Read-Host  }

	Write-Host  
	$null = (pandoc --version)
	if ($lastExitCode -ne ) { throw  }

	Write-Host 
	gci -r -i $FilePattern | foreach {
		$TargetPath = $_.directoryname +  + $_.basename + 
		pandoc --standalone --template  -s $_.name -o $TargetPath
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
