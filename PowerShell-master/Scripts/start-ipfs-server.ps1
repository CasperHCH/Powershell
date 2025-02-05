<#
.SYNOPSIS
	Start an IPFS server 
.DESCRIPTION
	This PowerShell script starts a local IPFS server as a daemon process.
.EXAMPLE
	PS> ./start-ipfs-server
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -noNewline
	& ipfs --version
	if ($lastExitCode -ne ) { throw  }
	
	& ipfs init --profile lowpower

	
	& ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
	if ($lastExitCode -ne ) { throw  }

	& ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8765
	if ($lastExitCode -ne ) { throw  }

	$Hostname = $(hostname)
	& ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '[\, \, \, \]'
	if ($lastExitCode -ne ) { throw  }

	& ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '[\, \]'
	if ($lastExitCode -ne ) { throw  }

	& ipfs config --json AutoNAT.Throttle.GlobalLimit 1 # (30 by default)
	if ($lastExitCode -ne ) { throw  }

	& ipfs config --json AutoNAT.Throttle.PeerLimit 1 # (3 by default)
	if ($lastExitCode -ne ) { throw  }
	
	Write-Host  -noNewline
	& sudo sysctl -w net.core.rmem_max=2500000
	if ($lastExitCode -ne ) { throw  }
	
#	Start-Process nohup 'ipfs daemon'
	Start-Process nohup -ArgumentList 'ipfs','daemon' -RedirectStandardOutput  -RedirectStandardError 

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	
	exit 0 # success
} catch {
	
	exit 1
}
