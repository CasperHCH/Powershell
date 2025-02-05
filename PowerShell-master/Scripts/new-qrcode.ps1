<#
.SYNOPSIS
	Generates a QR code
.DESCRIPTION
	This PowerShell script generates a new QR code image file.
.PARAMETER Text
	Specifies the text to use
.PARAMETER ImageSize
	Specifies the image size (width x height)
.EXAMPLE
	PS> ./new-qrcode.ps1  500x500
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Text = , [string]$ImageSize = )

try {
	if ($Text -eq ) { $Text = read-host  }
	if ($ImageSize -eq ) { $ImageSize = read-host  }

	$ECC =  # can be L, M, Q, H
	$QuietZone = 1
	$ForegroundColor = 
	$BackgroundColor = 
	$FileFormat = 
        if ($IsLinux) {
                $PathToPics = Resolve-Path 
        } else {
                $PathToPics = [Environment]::GetFolderPath('MyPictures')
        }
        if (-not(Test-Path  -pathType container)) {
                throw 
        }
	$NewFile = 

	$WebClient = new-object System.Net.WebClient
	$WebClient.DownloadFile(( + $Text +  + $ECC +`
		 + $ImageSize +  + $QuietZone + `
		 + $ForegroundColor +  + $BackgroundColor.Text + `
		 + $FileFormat), $NewFile)

	
	exit 0 # success
} catch {
	
	exit 1
}
