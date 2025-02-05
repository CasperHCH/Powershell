<#
.SYNOPSIS
	Lists the latest headlines
.DESCRIPTION
	This PowerShell script lists the latest RSS feed news.
.PARAMETER RSS_URL
	Specifies the URL to the RSS feed
.PARAMETER maxCount
	Specifies the number of news to list
.EXAMPLE
	PS> ./list-headlines.ps1
	❇️ Niger coup: Ecowas deadline sparks anxiety in northern Nigeria
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RSS_URL = , [int]$maxCount = 20)

try {
	[xml]$content = (Invoke-WebRequest -uri $RSS_URL -useBasicParsing).Content
	[int]$count = 0
	foreach ($item in $content.rss.channel.item) {
		
		$count++
		if ($count -eq $maxCount) { break }
	}
        $source = $Content.rss.channel.title
        $date = $Content.rss.channel.pubDate
	
	exit 0 # success
} catch {
	
	exit 1
}
