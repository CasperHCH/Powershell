<#
.SYNOPSIS
	Translates text into other languages
.DESCRIPTION
	This PowerShell script translates text into other languages.
.PARAMETER Text
	Specifies the text to translate
.PARAMETER SourceLang
	Specifies the source language (English by default)
.PARAMETER TargetLang
	Specifies the target language (all by default)
.EXAMPLE
	PS> ./translate-text  en all
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Text = , [string]$SourceLangCode = , [string]$TargetLangCode = )


	$Result = (Invoke-WebRequest -Uri https://libretranslate.de/translate -Method POST -Body ($Parameters|ConvertTo-Json) -ContentType  -useBasicParsing).content | ConvertFrom-Json
	return $Result.translatedText
}

try {
	if ($Text -eq  ) { $Text = Read-Host  }

	if ($TargetLangCode -eq ) {
		$TargetLangCodes = ,,,,,,,,,,,
		foreach($TargetLangCode in $TargetLangCodes) {
			$Translation = UseLibreTranslate $Text $SourceLangCode $TargetLangCode
			Write-Output 
			Start-Sleep -seconds 6 # 10 requests maximum per minute
		}
	} else {
		$Translation = UseLibreTranslate $Text $SourceLangCode $TargetLangCode
		Write-Output 
	}
	exit 0 # success
} catch {
	
	exit 1
}
