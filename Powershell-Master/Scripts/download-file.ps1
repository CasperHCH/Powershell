<#
.SYNOPSIS
	Downloads a file from an URL
.DESCRIPTION
	This PowerShell script downloads a file from the given URL
.PARAMETER URL
	Specifies the URL where to download from
.EXAMPLE
	PS> ./download-file.ps1 https://www.cnn.com/index.html
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$URL = )

try {
	if ($URL -eq ) { $URL = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	& wget --version
	if ($lastExitCode -ne ) { throw  }

	& wget --mirror --convert-links --adjust-extension --page-requisites --no-parent $URL --directory-prefix . --no-verbose
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
