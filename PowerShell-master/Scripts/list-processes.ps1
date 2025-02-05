<#
.SYNOPSIS
	Lists all local computer processes
.DESCRIPTION
	This PowerShell script lists all local computer processes.
.EXAMPLE
	PS> ./list-processes.ps1

	   Id  CPU(s) ProcessName
	   --  ------ -----------
	 9712   0,39% 64DriverLoad
	 ...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

try {
	Get-Process | Format-Table -Property Id, @{Label=;Expression={$_.CPU.ToString()+};Alignment=}, ProcessName -AutoSize
	exit 0 # success
} catch {
	
	exit 1
}
