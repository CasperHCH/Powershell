<#
.SYNOPSIS
	Closes the OneCalendar app 
.DESCRIPTION
	This PowerShell script closes the OneCalendar application gracefully.
.EXAMPLE
	PS> ./close-one-calendar.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

TaskKill /f /im CalendarApp.Gui.Win10.exe
if ($lastExitCode -ne ) {
	&  
	exit 1
}
exit 0 # success
