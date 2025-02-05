<#
.SYNOPSIS
	Translates text files
.DESCRIPTION
	This PowerShell script translates text files into multiple languages.
.PARAMETER filePattern
	Specifies the file pattern of the text file(s) to be translated
.EXAMPLE
	PS> ./translate-files C:\Temp\*.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filePattern = )


	if ( -like )  { return  }
	if ( -like )  { return  }
	if ( -like ) { return  }
	if ( -like ) { return  }
	return 
}


	if ($SourceLang -eq ) { $SourceLanguage =  }
	if ($SourceLang -eq ) { $SourceLanguage =  }
	if ($SourceLang -eq ) { $SourceLanguage =  }
	if ($SourceLang -eq ) { $SourceLanguage =  }
	[string]$TargetLanguage = 
	if ($TargetLang -eq ) { $TargetLanguage =  }
	if ($TargetLang -eq ) { $TargetLanguage =  }
	if ($TargetLang -eq ) { $TargetLanguage =  }
	if ($TargetLang -eq ) { $TargetLanguage =  }
	if ($TargetLang -eq ) { $TargetLanguage =  }
	if ($TargetLang -eq ) { $TargetLanguage =  }
	return $Filename.replace($SourceLanguage, $TargetLanguage)
}

try {
	if ($filePattern -eq  ) { $filePattern = Read-Host  }

	$TargetLanguages = ,,,,,,,,,,,
	$SourceFiles = Get-ChildItem -path 
	foreach($SourceFile in $SourceFiles) {
		$SourceLang = DetectSourceLang $SourceFile
		foreach($TargetLang in $TargetLanguages) {
			if ($SourceLang -eq $TargetLang) { continue }
			Write-Host 
			$TargetFile = TranslateFilename $SourceFile $SourceLang $TargetLang
			Write-Host 
			&  $SourceFile $SourceLang $TargetLang > $TargetFile
		}
	}
	exit 0 # success
} catch {
	
	exit 1
}
