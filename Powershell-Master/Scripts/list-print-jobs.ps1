<#
.SYNOPSIS
	Lists all print jobs
.DESCRIPTION
	This PowerShell script lists all print jobs of all printer devices.
.EXAMPLE
	PS> ./list-print-jobs.ps1

	Printer                       Jobs
	-------                       ----
	ET-2810 Series 		      none
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -Version 4



	foreach ($printer in $printers) {
		$PrinterName = $printer.Name
		$printjobs = Get-PrintJob -PrinterObject $printer
		if ($printjobs.Count -eq 0) {
			$PrintJobs = 
		} else {
			$PrintJobs = 
		}
		New-Object PSObject -Property @{ Printer=$PrinterName; Jobs=$PrintJobs }
	}
}

try {
	if ($IsLinux) {
		# TODO
	} else {
		ListPrintJobs | Format-Table -property Printer,Jobs
	}
	exit 0 # success
} catch {
	
	exit 1
}
