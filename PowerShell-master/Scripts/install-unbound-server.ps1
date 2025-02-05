<#
.SYNOPSIS
	Installs Unbound server (needs admin rights)
.DESCRIPTION
	This PowerShell script installs Unbound, a validating, recursive, caching DNS resolver. It needs admin rights.
.EXAMPLE
	PS> ./install-unbound-server.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	
	& sudo apt update -y
	if ($lastExitCode -ne ) { throw  }

	
	& sudo apt install unbound unbound-anchor -y
	if ($lastExitCode -ne ) { throw  }

	
	& sudo unbound-control-setup
	if ($lastExitCode -ne ) { throw  }

	
	& sudo unbound-anchor
	if ($lastExitCode -ne ) { throw  }

	
	& unbound-checkconf 
	if ($lastExitCode -ne ) { throw  }

	
	& sudo cp  /etc/unbound/unbound.conf
	if ($lastExitCode -ne ) { throw  }

	
	& sudo systemctl stop systemd-resolved
	& sudo systemctl disable systemd-resolved

	
	& sudo unbound-control stop
	& sudo unbound-control start
	if ($lastExitCode -ne ) { throw  }

	
	& sudo unbound-control status
	if ($lastExitCode -ne ) { throw  }

	
	&  
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
