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
            $os = gwmi Win32_OperatingSystem -ComputerName $server
            $boottime = $OS.converttodatetime($OS.LastBootUpTime)
            $uptime = New-TimeSpan (Get-Date $boottime)
            $uptime_days = [int]$uptime.days
            Write-Host $server
            Write-Host  $boottime
            Write-Host  $uptime_days
            Echo ''
        }
    }
}
