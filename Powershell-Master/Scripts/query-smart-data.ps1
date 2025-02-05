<#
.SYNOPSIS
	Queries and saves the S.M.A.R.T. data of your HDD's/SSD's
.DESCRIPTION
	Queries the S.M.A.R.T. data of your HDD/SSD's and saves it to the current/given directory.
	(use smart-data2csv.ps1 to generate a CSV table for analysis).
        Requires smartctl (smartmontools) and admin rights. For automation copy this script to /etc/cron.daily 
.PARAMETER Directory
	Specifies the path to the target directory
.EXAMPLE
	PS> ./query-smart-data
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -RunAsAdministrator

param([string]$Directory = )


 catch {
		write-error 
		exit 1
	}
}

try {
	if ($Directory -eq ) {
		$Directory = 
	}

	write-output 
	CheckIfInstalled

	write-output 
	$Devices = $(smartctl --scan-open)

	[int]$DevNo = 1
	foreach($Device in $Devices) {
		write-output 

		$Time = (Get-Date)
		$Filename = 
		write-output 

		$Cmd =  + $Device 

		Invoke-Expression $Cmd > $Filename
		$DevNo++
	}

	
	exit 0 # success
} catch {
	
	exit 1
}
