<#
.SYNOPSIS
	Installs GitHub CLI
.DESCRIPTION
	This PowerShell script installs the GitHub command-line interface (CLI).
.EXAMPLE
	PS> ./install-github-cli.ps1
	⏳ Installing GitHub CLI...
	✔ Installation of GitHub CLI took 17 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsMacOS) {
		& brew install gh
	} elseif ($IsLinux) {
		& sudo apt install gh
	} else {
		& winget install --id GitHub.cli
	}
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
