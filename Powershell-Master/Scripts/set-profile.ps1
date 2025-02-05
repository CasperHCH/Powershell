<#
.SYNOPSIS
	Sets the user's PowerShell profile
.DESCRIPTION
	This PowerShell script sets the PowerShell profile for the current user.
.EXAMPLE
	PS> ./set-profile
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	$PathToProfile = $PROFILE.CurrentUserCurrentHost
	

	
	$Null = New-Item -Path $profile -ItemType  -Force

	
	$PathToRepo = 
	Copy-Item   -force

	
	exit 0 # success
} catch {
	
	exit 1
}
