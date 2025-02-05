<#
.SYNOPSIS
	Opens an editor to edit a file
.DESCRIPTION
	This PowerShell script opens a text editor to edit the given file.
.PARAMETER Filename
	Specifies the path to the filename
.EXAMPLE
	PS> ./edit.ps1 C:\MyFile.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Filename = )

try {
	if ($IsLinux) {
		& vi 
		if ($lastExitCode -ne ) { throw  }
	} else {
		& notepad.exe 
		if ($lastExitCode -ne ) { throw  }
	}
	exit 0 # success
} catch {
	
	exit 1
}
