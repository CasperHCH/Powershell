<#
.SYNOPSIS
	Installs Spotify
.DESCRIPTION
	This PowerShell script installs Spotify from the Microsoft Store.
.EXAMPLE
	PS> ./install-spotify.ps1
.LINK
	https://github.com/fleschutz/talk2windows
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	

	& winget install  --source msstore --accept-package-agreements --accept-source-agreements
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
	
	exit 1
}
