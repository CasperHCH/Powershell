<#
.SYNOPSIS
	Sends a TCP message to an IP address and port
.DESCRIPTION
	This PowerShell script sends a TCP message to the given IP address and port.
.PARAMETER TargetIP
	Specifies the target IP address
.PARAMETER TargetPort
	Specifies the target port number
.PARAMETER Message
	Specifies the message to send
.EXAMPLE
	PS> ./send-tcp 192.168.100.100 8080 
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
        $Socket = New-Object System.Net.Sockets.TCPClient($Address,$TargetPort) 
        $Stream = $Socket.GetStream() 
        $Writer = New-Object System.IO.StreamWriter($Stream)
        $Message | % {
        	$Writer.WriteLine($_)
        	$Writer.Flush()
        }
        $Stream.Close()
        $Socket.Close()

	
	exit 0 # success
} catch {
	
	exit 1
}
