<#
.SYNOPSIS
	Writes text in big letters
.DESCRIPTION
	This PowerShell script writes the given text in big letters.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-big 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )

Set-StrictMode -Version Latest


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
}


	2 { return  }
	3 { return  }
	4 { return  }
	}
} 


	2 { return  }
	3 { return  }
	4 { return  }
	}
} 


	2 { return  }
	3 { return  }
	4 { return  }
	}
} 


	2 { return  }
	3 { return  }
	4 { return  }
	}
} 


	2 { return  }
	3 { return  }
	4 { return  }
	}
} 


	'B' { return BigB $Row }
	'C' { return BigC $Row }
	'D' { return BigD $Row }
	'E' { return BigE $Row }
	'F' { return BigF $Row }
	'G' { return BigG $Row }
	'H' { return BigH $Row }
	'I' { return BigI $Row }
	'J' { return BigJ $Row }
	'K' { return BigK $Row }
	'L' { return BigL $Row }
	'M' { return BigM $Row }
	'N' { return BigN $Row }
	'O' { return BigO $Row }
	'P' { return BigP $Row }
	'Q' { return BigQ $Row }
	'R' { return BigR $Row }
	'S' { return BigS $Row }
	'T' { return BigT $Row }
	'U' { return BigU $Row }
	'V' { return BigV $Row }
	'W' { return BigW $Row }
	'X' { return BigX $Row }
	'Y' { return BigY $Row }
	'Z' { return BigZ $Row }
	'0' { return Big0 $Row }
	'1' { return Big1 $Row }
	'2' { return Big2 $Row }
	'3' { return Big3 $Row }
	'4' { return Big4 $Row }
	'5' { return Big5 $Row }
	'6' { return Big6 $Row }
	'7' { return Big7 $Row }
	'8' { return Big8 $Row }
	'9' { return Big9 $Row }
	':' { return BigColon $Row }
	'-' { return BigMinus $Row }
	}
	return 
}

try {
	if ($text -eq  ) { [String]$text = read-host  }

	[char[]]$ArrayOfChars = $text.ToUpper()
	write-output 
	for ($Row = 1; $Row -lt 5; $Row++) {
		$Line = 
		foreach($Char in $ArrayOfChars) {
			$Line += BigChar $Char $Row
		}
		write-output $Line
	}
	write-output 
	exit 0 # success
} catch {
	
	exit 1
}
