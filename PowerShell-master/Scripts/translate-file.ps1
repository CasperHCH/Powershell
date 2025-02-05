<#
.SYNOPSIS
	Translates a text file into another language 
.DESCRIPTION
	This PowerShell script translates the given text file into another language and writes the output on the console.
.PARAMETER File
	Specifies the path to the file to be translated
.PARAMETER SourceLang
	Specifies the source language
.PARAMETER TargetLang
	Specifies the target language
.EXAMPLE
	PS> ./translate-file C:\Memo.txt en de
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$File = , [string]$SourceLang = , [string]$TargetLang = )


	$Result = (Invoke-WebRequest -Uri https://libretranslate.de/translate -Method POST -Body ($Parameters|ConvertTo-Json) -ContentType  -useBasicParsing).content | ConvertFrom-Json
	Start-Sleep -seconds 6 # 10 requests per minute maximum
	return $Result.translatedText
}

try {
	if ($File -eq  ) { $File = Read-Host  }
	if ($SourceLang -eq  ) { $SourceLang = Read-Host  }
	if ($TargetLang -eq  ) { $TargetLang = Read-Host  }

	$Lines = Get-Content -path $File
	foreach($Line in $Lines) {
		if ( -eq ) { Write-Output ; continue }
		if ( -eq ) { Write-Output ; continue }
		if ( -like ) { Write-Output ; continue }
		if ( -like ) { Write-Output ; continue }
		if ( -like ) { Write-Output ; continue }
		$Result = UseLibreTranslate $Line $SourceLang $TargetLang
		Write-Output $Result
	}
	exit 0 # success
} catch {
	
	exit 1
}
