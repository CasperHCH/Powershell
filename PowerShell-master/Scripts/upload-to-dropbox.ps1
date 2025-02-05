<#
.SYNOPSIS
	Uploads a file to Dropbox
.DESCRIPTION
	This PowerShell script uploads a local file to Dropbox.
.PARAMETER Path
	Specifies the path to the local file
.EXAMPLE
	PS> .\upload-to-dropbox.ps1 my.txt
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([Parameter (Mandatory = $True, ValueFromPipeline = $True)] [Alias()] [string]$SourceFilePath) 

try {
	$DropBoxAccessToken =    # Replace with your DropBox Access Token
	$outputFile = Split-Path $SourceFilePath -leaf
	$TargetFilePath=
	$arg = '{ : , : , : true, : false }'
	$authorization =  + $DropBoxAccessToken
	$headers = New-Object 
	$headers.Add(, $authorization)
	$headers.Add(, $arg)
	$headers.Add(, 'application/octet-stream')
	Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
	exit 0 # success
} catch {
	
	exit 1
}
