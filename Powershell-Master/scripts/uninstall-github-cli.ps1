<#
.SYNOPSIS
	Uninstalls GitHub CLI
.DESCRIPTION
	This PowerShell script uninstalls the GitHub CLI from the local computer.
.EXAMPLE
	PS> ./uninstall-github-cli.ps1
	⏳ Uninstalling GitHub CLI...
	✔️ Removal of GitHub CLI took 7 sec
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if ($IsMacOS) {
		& brew uninstall gh
	} elseif ($IsLinux) {
		& sudo apt remote gh
	} else {
		& winget uninstall --id GitHub.cli
	}
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
