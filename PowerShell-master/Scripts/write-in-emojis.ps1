<#
.SYNOPSIS
        Writes text in Emojis
.DESCRIPTION
        This PowerShell script replaces certain words in the given text by Emojis and writes it to the console.
.PARAMETER text
        Specifies the text
.EXAMPLE
        PS> ./write-in-emojis.ps1 
        I💘️my📂
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

try {
	if ($text -eq )  { $text = Read-Host  }
	
	$table = Import-CSV 
	foreach($row in $table) {
		$text = $text -Replace ,
	}
	Write-Output $text
	exit 0 # success
} catch {
	
	exit 1
}
