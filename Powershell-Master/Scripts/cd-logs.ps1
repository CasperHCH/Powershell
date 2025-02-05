<#
.SYNOPSIS
	Sets the working directory to the logs folder
.DESCRIPTION
	This PowerShell script changes the current working directory to the logs directory.
.EXAMPLE
	PS> ./cd-logs
	📂/var/logs
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


	$WinDir = [System.Environment]::GetFolderPath('Windows')
	return 
}

try {
	$Path = GetLogsDir
	Set-Location 
	
	exit 0 # success
} catch {
	
	exit 1
}
