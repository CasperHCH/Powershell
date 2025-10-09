<#
.SYNOPSIS
    Gets the uptime information for one or more servers.
.DESCRIPTION
    This function retrieves the boot time and calculates uptime for specified servers
    using WMI/CIM queries. It displays both simple and detailed uptime information.
.PARAMETER servers
    One or more server names to query. Defaults to the local computer.
.EXAMPLE
    Get-Uptime
    Gets uptime for the local computer.
.EXAMPLE
    Get-Uptime -servers "Server1", "Server2"
    Gets uptime for multiple servers.
.EXAMPLE
    "Server1", "Server2" | Get-Uptime
    Gets uptime using pipeline input.
.NOTES
    Requires appropriate WMI/CIM permissions on target servers.
#>
Function Get-Uptime {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False,
				   ValueFromPipeline = $True,
				   ValueFromPipelineByPropertyName = $True,
				   HelpMessage = 'What Server to query for Uptime')]
		[string[]]$servers = $env:COMPUTERNAME
    )

    process {
        foreach ($server in $servers) {
            $os = Get-CimInstance Win32_OperatingSystem -ComputerName $server
            $boottime = $OS.LastBootUpTime
            $uptime = New-TimeSpan (Get-Date $boottime)
            $uptime_days = [int]$uptime.days

            # Create output object for better pipeline compatibility
            [PSCustomObject]@{
                Server = $server
                BootTime = $boottime
                UptimeDays = $uptime_days
                FullUptime = "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
                TimeSpan = $uptime
            } | Format-Table -AutoSize

            # Also provide verbose output
            Write-Verbose "Server: $server" -Verbose
            Write-Verbose "Boot Time: $boottime" -Verbose
            Write-Verbose "Uptime: $uptime_days days" -Verbose
            Write-Verbose "Full Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" -Verbose
        }
    }
}
