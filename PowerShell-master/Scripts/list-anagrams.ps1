<#
.SYNOPSIS
	Lists all anagrams of the given word
.DESCRIPTION
	This PowerShell script lists all anagrams of the given word.
.PARAMETER Word
	Specifies the word to use
.PARAMETER Columns
	Specifies the number of columns
.EXAMPLE
	PS> ./list-anagrams Baby
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Word = , [int]$Columns = 8)


            for ($i=0;$i -lt $NewSize; $i++) { 
                NewAnagram  -NewSize ($NewSize - 1)
                if ($NewSize -eq 2) {
                    New-Object PSObject -Property @{
                        Permutation = $stringBuilder.ToString()                  
                    }
                }
                MoveLeft -NewSize $NewSize
            }
        }
        
            $stringBuilder[($z-1)] = $temp
        }
    }
    Process {
        $size = $String.length
        $stringBuilder = New-Object System.Text.StringBuilder -ArgumentList $String
        NewAnagram -NewSize $Size
    }
    End {}
}

try {
	if ($Word -eq  ) {
		$Word = read-host 
		$Columns = read-host 
	}
	GetPermutations -String $Word | Format-Wide -Column $Columns
	exit 0 # success
} catch {
	
	exit 1
}
