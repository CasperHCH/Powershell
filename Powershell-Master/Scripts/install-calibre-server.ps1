<#
.SYNOPSIS
	Installs Calibre server (needs admin rights)
.DESCRIPTION
	This PowerShell script installs and starts a local Calibre server as background process (using Web port 8099 by default).
.PARAMETER port
	Specifies the Web port number (8099 by default)
.EXAMPLE
	PS> ./install-calibre-server.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

param([int]$Port = 8099, [string]$UserDB = , [string]$Logfile = )

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	& sudo apt update -y
	if ($lastExitCode -ne ) { throw  }

	
	& sudo apt install calibre -y
	if ($lastExitCode -ne ) { throw  }

	
	& calibre-server --version
	if ($lastExitCode -ne ) { throw  }

	
	mkdir $HOME/'Calibre Library'

	
	& calibre-server --port $Port --num-per-page 100 --userdb $UserDB --log $Logfile --daemonize $HOME/'Calibre Library'

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
