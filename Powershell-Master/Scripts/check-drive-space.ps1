<#
.SYNOPSIS
	Checks a drive for free space left 
.DESCRIPTION
	This PowerShell script checks a drive for free space left (20 GB by default).
.PARAMETER Drive
	Specifies the drive to check
.PARAMETER MinLevel
	Specifies the minimum level in Gigabyte
.EXAMPLE
	PS> ./check-drive-space C
	✔️ 172 GB left on drive C (61 of 233 GB used)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Drive = , [int]$MinLevel = 20) # minimum level in GB

try {
	if ($Drive -eq  ) { $Drive = read-host  }

	$DriveDetails = (get-psdrive $Drive)
	[int]$Free = (($DriveDetails.Free / 1024) / 1024) / 1024
	[int]$Used = (($DriveDetails.Used / 1024) / 1024) / 1024
	[int]$Total = ($Used + $Free)

	if ($Free -lt $MinLevel) {
        	write-warning 
		exit 1
	}

	&  
	exit 0 # success
} catch {
	
	exit 1
}
