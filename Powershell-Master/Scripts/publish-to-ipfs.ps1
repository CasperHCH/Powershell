<#
.SYNOPSIS
	Publishes files & folders to IPFS
.DESCRIPTION
	This script publishes the given files and folders to IPFS.
.PARAMETER FilePattern
	Specifies the file pattern
.PARAMETER HashList
	Specifies the path to the resulting hash list
.PARAMETER DF_Hashes
	Specifies the path to the resulting digital forensic hashes
.EXAMPLE
	PS> ./publish-to-ipfs C:\MyFile.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$FilePattern = , [string]$HashList = , [string]$DF_Hashes = )

try {
	if ($FilePattern -eq ) { $FilePattern = read-host  }

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	Write-Host  -NoNewline
	& ipfs --version
	if ($lastExitCode -ne ) { throw  }

	if (test-path  -pathType container) {
		
		& ipfs add -r  > $HashList
		[int]$Count = 1
		
		
		& nice hashdeep -c md5,sha1,sha256 -r -d -l -j 1  > $DF_Hashes
	} else {
		$FileList = (get-childItem )
		foreach ($File in $FileList) {
			if (test-path  -pathType container) {
				
				& ipfs add -r  >> $HashList
			} else {
				
				& ipfs add  >> $HashList
			}
		}
		[int]$Count = $FileList.Count
	}

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	
	exit 0 # success
} catch {
	
	exit 1
}
