<#
.SYNOPSIS
	Removes all jobs from all printers
.DESCRIPTION
	This PowerShell script removes all print jobs from all printer devices.
.EXAMPLE
	PS> ./remove-print-jobs
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -Version 4

try {
	$printers = Get-Printer
	if ($printers.Count -eq 0) { throw  }
		
	foreach ($printer in $printers) {
		$printjobs = Get-PrintJob -PrinterObject $printer
		foreach ($printjob in $printjobs) {
			Remove-PrintJob -InputObject $printjob
		}
	}

	
	exit 0 # success
} catch {
	
	exit 1
}
