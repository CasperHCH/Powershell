<#
.SYNOPSIS
	Converts .DOCX file(s) into Markdown 
.DESCRIPTION
	This PowerShell script converts .DOCX file(s) into Markdown.
.PARAMETER FilePattern
	Specifies the file pattern to the .DOCX file(s)
.EXAMPLE
	PS> ./convert-docx2md *.docx
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
		& pandoc -f docx -s $_.name -o $TargetPath
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
