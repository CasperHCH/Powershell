<#
.SYNOPSIS
	Lists OS updates
.DESCRIPTION
	This PowerShell script lists the latest updates for operating systems.
.PARAMETER RSS_URL
	Specifies the URL to the RSS feed
.PARAMETER MaxCount
	Specifies the number of news to list
.EXAMPLE
	PS> ./list-os-updates.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RSS_URL = , [int]$MaxCount = 30)

try {
	
	
	
	[xml]$Content = (Invoke-WebRequest -URI $RSS_URL -userAgent  -useBasicParsing).Content


	[int]$Count = 0
	foreach ($item in $Content.rss.channel.item) {
		
		$Count++
		if ($Count -eq $MaxCount) { break }
	}
	
	exit 0 # success
} catch {
	
	exit 1
}
