<#
.SYNOPSIS
	Checks the ping latency 
.DESCRIPTION
	This PowerShell script measures the ping roundtrip times from the local computer to other computers (10 Internet servers by default).
.PARAMETER hosts
	Specifies the hosts to check, seperated by commata (default is: amazon.com,bing.com,cnn.com,dropbox.com,github.com,google.com,live.com,meta.com,x.com,youtube.com)
.EXAMPLE
	PS> ./check-ping.ps1
	✅ Online with 18ms latency average (13ms...109ms, 0/10 ping loss)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$hosts = )

try {
	$hostsArray = $hosts.Split()
	$parallelTasks = $hostsArray | foreach {
		(New-Object Net.NetworkInformation.Ping).SendPingAsync($_,750)
	}
	[int]$min = 9999999
	[int]$max = [int]$avg = [int]$success = 0
	[int]$total = $hostsArray.Count
	[Threading.Tasks.Task]::WaitAll($parallelTasks)
	foreach($ping in $parallelTasks.Result) {
		if ($ping.Status -ne ) { continue }
		$success++
		[int]$latency = $ping.RoundtripTime
		$avg += $latency
		if ($latency -lt $min) { $min = $latency }
		if ($latency -gt $max) { $max = $latency }
	}
	[int]$loss = $total - $success
	if ($success -ne 0) {
		$avg /= $success
		Write-Host 
	} else {
		Write-Host 
	}
	exit 0 # success
} catch {
	
	exit 1
}
