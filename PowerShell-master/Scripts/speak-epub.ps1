<#
.SYNOPSIS
	Speaks an Epub file by text-to-speech (TTS).
.DESCRIPTION
	This PowerShell script speaks the content of the given Epub file by text-to-speech (TTS).
.PARAMETER Filename
	Specifies the path to the Epub file
.EXAMPLE
	PS> ./speak-epub C:\MyBook.epub
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Filename = )


	}
	[void]$Voice.Speak($Text)
}
 
function ReadBook() { param([string]$book, [string]$bookPath, [int]$lineNumber = 0)
	$data = Get-Content $book
	for([int]$i=$lineNumber;$i -lt $data.Count;$i++) {
		Set-Content -Path $bookPath -Value ($book++$i)
		$line = $data[$i]
		if ($line.Contains()) {
			$line = $line -Replace ,
		 	Speak $line
		}
		if ($line.contains()) {
			$line = $line -Replace ,
			Speak $line
		}
	 }
	 Set-Content -Path $bookPath -Value ()
}

function UnzipFile() { param([string]$file, [string]$dest)
	$shell = new-object -com shell.application
	$zip = $shell.NameSpace($file)
	foreach($item in $zip.items()) {
		$shell.Namespace($dest).copyhere($item)
	}
}
 
if ($Filename -eq ) {
	$Filename = Read-Host 
}
write-output 
$file = get-item $Filename
if (-not(Test-Path $file.DirectoryName++$file.Name+)) {
	$zipFile = $file.DirectoryName++$file.Name+
	$file.CopyTo($zipFile)
}

$destination = $file.DirectoryName++$file.Name.Replace($file.Extension,)
if (-not(Test-Path $destination)) {
	md $destination
	UnzipFile -file $zipFile -dest $destination
}
 
[xml]$container = Get-Content $destination
$contentFilePath = $container.container.rootfiles.rootfile.
[xml]$content = Get-Content $destination$contentFilePath
$tmpPath = Get-Item $destination$contentFilePath
$bookPath = $tmpPath.DirectoryName
$progress = $null
 
foreach($item in $content.package.manifest.Item) {
	if ($item. -eq ) {
		if (Test-Path $bookPath+) {
			$progress = Get-Content $bookPath
			$progress = $progress.Split()
		}
		$bookFileName = $item.href
		if ($progress.Count -eq 2) {
			if ($progress[0] -eq $bookPath++$bookFileName) {
				ReadBook -book $bookPath$bookFileName -bookPath $bookPath -lineNumber $progress[1]
			}
		}
		else {
			ReadBook -book $bookPath$bookFileName -bookPath $bookPath
		}
	}
}
exit 0 # success
