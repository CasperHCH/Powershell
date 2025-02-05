<#
.SYNOPSIS
	Creates a scheduled task that will display a popup message
.DESCRIPTION
	This PowerShell script creates a scheduled task that will display a popup message.
.EXAMPLE
	PS> ./remind-me  

	TaskPath                                       TaskName                          State
	--------                                       --------                          -----
	\                                              Reminder_451733811                Ready
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#requires -version 4

param([string]$Message = , [datetime]$Time)

try {
	if ($Message -eq ) { $Message = read-host  }

	$Task = New-ScheduledTaskAction -Execute msg -Argument 
	$Trigger = New-ScheduledTaskTrigger -Once -At $Time
	$Random = (Get-Random)
	Register-ScheduledTask -Action $Task -Trigger $Trigger -TaskName  -Description 
	exit 0
} catch {
	
	exit 1
}
