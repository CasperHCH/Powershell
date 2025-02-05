<#
.SYNOPSIS
	Writes the message of the day
.DESCRIPTION
	This PowerShell script writes the message of the day (MOTD).
.EXAMPLE
	PS> ./write-motd
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param ()

# Retrieve information:
[system.threading.thread]::currentThread.currentCulture = [system.globalization.cultureInfo]
$dt = [datetime]::Now
$day = $dt.ToLongDateString().split(',')[1].trim()
if ($day.EndsWith('1')) { $day += 'st' } elseif ($day.EndsWith('2')) { $day += 'nd' } elseif ($day.EndsWith('3')) { $day += 'rd' } else { $day += 'th' }
$CurrentTime = 
$TimeZone = (Get-TimeZone).id

$UserName = [Environment]::USERNAME
$ComputerName = [System.Net.Dns]::GetHostName().ToLower()
$OSName = 
$Kernel =  # todo
$Kernel_Info =  # todo

$BootTime = Get-WinEvent -ProviderName eventlog | Where-Object {$_.Id -eq 6005} | Select-Object TimeCreated -First 1
$TimeSpan = New-TimeSpan -Start $BootTime.TimeCreated.Date -End (Get-Date)
$Uptime = 
$PowerShellVersion = $PSVersionTable.PSVersion
$PowerShellEdition = $PSVersionTable.PSEdition

$CPU_Info = $env:PROCESSOR_IDENTIFIER + ' Rev: ' + $env:PROCESSOR_REVISION
$NumberOfProcesses = (Get-Process).Count
$CurrentLoad =  -f $(Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average)
# $Logical_Disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DeviceID -eq $OS.SystemDrive
# $Processor = Get-CimInstance -ClassName Win32_Processor
# $Memory_Size =  -f (([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB)) - ([math]::round($ReturnedValues.Operating_System.FreePhysicalMemory / 1KB))), ([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB))    
$DriveDetails = Get-PSDrive C
$DiskSize =  -f (([math]::round($DriveDetails.Free / 1GB), ([math]::round(($DriveDetails.Used + $DriveDetails.Free) / 1GB))))

# Print results:
[Environment]::NewLine
Write-Host  -ForegroundColor Red
Write-Host  -ForegroundColor Red
Write-Host  -ForegroundColor Red -NoNewline
Write-Host  -ForegroundColor green -NoNewline
Write-Host  -ForegroundColor DarkGray -NoNewline
Write-Host  -ForegroundColor Cyan
Write-Host  -ForegroundColor Red -NoNewline
Write-Host  -ForegroundColor Green -NoNewline
Write-Host  -ForegroundColor DarkGray -NoNewline
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Red
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Red
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Red
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Red
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor Green
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Cyan
Write-Host  -NoNewline -ForegroundColor Yellow
Write-Host  -NoNewline -ForegroundColor DarkGray
Write-Host  -ForegroundColor Cyan
Write-Host  -ForegroundColor Yellow
[Environment]::NewLine
exit 0 # success
