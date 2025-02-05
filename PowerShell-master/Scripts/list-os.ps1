<#
.SYNOPSIS
	Lists the operating system version
.DESCRIPTION
	This PowerShell script lists the exact operating system version.
.EXAMPLE
	PS> ./list-os.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	if ($IsLinux) {
		
	} else {
		$OS = Get-WmiObject -class Win32_OperatingSystem
		$OSname = $OS.Caption
		$OSarchitecture = $OS.OSArchitecture
		$OSversion = $OS.Version
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
