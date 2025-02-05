<#
.SYNOPSIS
	Writes text encoded or decoded with ROT13
.DESCRIPTION
	This PowerShell script writes text encoded or decoded with ROT13.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-rot13 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

 elseif ((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90))) {
			$Result += [char] ([int] $_ - 13);
		} else {
			$Result += $_
		}        
	}
	return $Result
}

try {
	if ($text -eq  ) { $text = read-host  }

	$Result = ROT13 $text
	write-output $Result
	exit 0 # success
} catch {
	
	exit 1
}
