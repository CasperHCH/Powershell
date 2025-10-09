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
            Write-Host "Server: $server" -ForegroundColor Cyan
            Write-Host "Boot Time: $boottime" -ForegroundColor Yellow
            Write-Host "Uptime: $uptime_days days" -ForegroundColor Green
            Write-Host "Full Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" -ForegroundColor White
            Write-Host ''
        }
    }
}
