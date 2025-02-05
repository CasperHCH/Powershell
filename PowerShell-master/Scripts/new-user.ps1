<#
.SYNOPSIS
	Creates a new user account
.DESCRIPTION
	This PowerShell script creates a new user account.
.EXAMPLE
	PS> ./new-user.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Username = )

try {
	if ($Username -eq ) { $Username = Read-Host  }
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsLinux) {
		& sudo adduser --encrypt-home $Username
	} else {
		throw 
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
