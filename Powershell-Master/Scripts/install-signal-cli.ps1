<#
.SYNOPSIS
	Installs signal-cli 
.DESCRIPTION
	This PowerShell script installs signal-cli from github.com/AsamK/signal-cli.
	See the Web page for the correct version number.
.PARAMETER Version
	Specifies the version to install
.EXAMPLE
	PS> ./install-signal-cli 0.11.12
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Version = )

try {
	if ($Version -eq ) { $Version = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	set-location /tmp

	& wget --version
	if ($lastExitCode -ne ) { throw  }

	& wget 
	if ($lastExitCode -ne ) { throw  }

	sudo tar xf  -C /opt
	if ($lastExitCode -ne ) { throw  }

	sudo ln -sf  /usr/local/bin/
	if ($lastExitCode -ne ) { throw  }

	rm 
	if ($lastExitCode -ne ) { throw  }

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
