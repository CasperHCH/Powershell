<#
.SYNOPSIS
	Checks PowerShell file(s) for validity
.DESCRIPTION
	This PowerShell script checks the given PowerShell script file(s) for validity.
.PARAMETER filePattern
	Specifies the file pattern to the PowerShell file(s)
.EXAMPLE
	PS> ./check-ps1-file *.ps1
	✔️ Valid PowerShell in myfile.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filePattern = )

try {
	if ($filePattern -eq  ) { $path = Read-Host  }

	$files = Get-ChildItem -path  -attributes !Directory
	foreach ($file in $files) {
		$syntaxError = @()
		[void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$syntaxError)
		if ( -ne ) { throw  }
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
