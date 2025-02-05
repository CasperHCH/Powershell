<#
.SYNOPSIS
	Writes animated text
.DESCRIPTION
	This PowerShell script writes animated text to the console.
.EXAMPLE
	PS> ./write-animated 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param($Line1 = , $Line2 = , $Line3 = , $Line4 = , $Line5 = , $Line6 = , $Line7 = , $Line8 = , $Line9 = , [int]$Speed = 30) # 30 ms pause

$TerminalWidth = 120 # characters


	[int]$End = $Line.Length
	$StartPosition = $HOST.UI.RawUI.CursorPosition
	$Spaces = 
	foreach($Pos in 1 .. $End) {
		$TextToDisplay = $Spaces.Substring(0, $TerminalWidth / 2 - $pos / 2) + $Line.Substring(0, $Pos)
		Write-Host $TextToDisplay -noNewline
		Start-Sleep -milliseconds $Speed
		$HOST.UI.RawUI.CursorPosition = $StartPosition
	}
	Write-Host 
}

try {
	if ($Line1 -eq ) {
		$Line1 = 
		$Line2 = 
		$Line3 = 
		$Line4 = 
		$Line5 = 
		$Line6 = 
	}
	WriteLine $Line1 
	WriteLine $Line2 
	WriteLine $Line3 
	WriteLine $Line4 
	WriteLine $Line5 
	WriteLine $Line6 
	WriteLine $Line7
	WriteLine $Line8
	WriteLine $Line9
	exit 0 # success
} catch {
        
        exit 1
}
