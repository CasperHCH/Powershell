<#
.SYNOPSIS
	Writes text in Braille
.DESCRIPTION
	This PowerShell script writes text in Braille.
.PARAMETER text
	Specifies the text to write
.EXAMPLE
	PS> ./write-braille 
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$text = )


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
}


	2 { return  }
	3 { return  }
	}
} 


	2 { return  }
	3 { return  }
	}
} 


	2 { return  }
	3 { return  }
	}
} 


	2 { return  }
	3 { return  }
	}
}


	'B' { return BrailleB $Row }
	'C' { return BrailleC $Row }
	'D' { return BrailleD $Row }
	'E' { return BrailleE $Row }
	'F' { return BrailleF $Row }
	'G' { return BrailleG $Row }
	'H' { return BrailleH $Row }
	'I' { return BrailleI $Row }
	'J' { return BrailleJ $Row }
	'K' { return BrailleK $Row }
	'L' { return BrailleL $Row }
	'M' { return BrailleM $Row }
	'N' { return BrailleN $Row }
	'O' { return BrailleO $Row }
	'P' { return BrailleP $Row }
	'Q' { return BrailleQ $Row }
	'R' { return BrailleR $Row }
	'S' { return BrailleS $Row }
	'T' { return BrailleT $Row }
	'U' { return BrailleU $Row }
	'V' { return BrailleV $Row }
	'W' { return BrailleW $Row }
	'X' { return BrailleX $Row }
	'Y' { return BrailleY $Row }
	'Z' { return BrailleZ $Row }
	'1' { return Braille1 $Row }
	'2' { return Braille2 $Row }
	'3' { return Braille3 $Row }
	'4' { return Braille4 $Row }
	'5' { return Braille5 $Row }
	'6' { return Braille6 $Row }
	'7' { return Braille7 $Row }
	'8' { return Braille8 $Row }
	'9' { return Braille9 $Row }
	'0' { return Braille0 $Row }
	}
	return 
}

try {
	if ($text -eq  ) { $text = read-host  }

	[char[]]$ArrayOfChars = $text.ToUpper()
	write-output 
	for ($Row = 1; $Row -lt 4; $Row++) {
		$Line = 
		foreach($Char in $ArrayOfChars) {
			$Line += BrailleChar $Char $Row
			$Line += 
		}
		write-output $Line
	}
	write-output 
	exit 0 # success
} catch {
	
	exit 1
}
