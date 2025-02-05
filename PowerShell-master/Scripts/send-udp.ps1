<#
.SYNOPSIS
	Sends a UDP datagram message to an IP address and port
.DESCRIPTION
	This PowerShell script sends a UDP datagram message to an IP address and port.
.PARAMETER TargetIP
	Specifies the target IP address
.PARAMETER TargetPort
	Specifies the target port number
.PARAMETER Message
	Specifies the message text to send
.EXAMPLE
	PS> ./send-udp 192.168.100.100 8080 
	✔️  Done.
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$TargetIP = , [int]$TargetPort = 0, [string]$Message = )

try {
	if ($TargetIP -eq  ) { $TargetIP = read-host  }
	if ($TargetPort -eq 0 ) { $TargetPort = read-host  }
	if ($Message -eq  ) { $Message = read-host  }

	$IP = [System.Net.Dns]::GetHostAddresses($TargetIP) 
	$Address = [System.Net.IPAddress]::Parse($IP) 
	$EndPoints = New-Object System.Net.IPEndPoint($Address, $TargetPort) 
	$Socket = New-Object System.Net.Sockets.UDPClient 
	$EncodedText = [Text.Encoding]::ASCII.GetBytes($Message) 
	$SendMessage = $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints) 
	$Socket.Close() 

	
	exit 0 # success
} catch {
	
	exit 1
}
