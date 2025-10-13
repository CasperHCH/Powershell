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

param(
	[Parameter (Mandatory = $True, ValueFromPipeline = $True)]
	[Alias("f")]
	[string]$SourceFilePath,

	[Parameter(Mandatory = $True)]
	[SecureString]$DropBoxAccessToken
)

try {
	# Convert SecureString to plain text for API call (kept in memory briefly)
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DropBoxAccessToken)
	$PlainAccessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
	[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

	Write-AuditLog -Message "Dropbox upload initiated for file: $SourceFilePath" -Severity "Info"
	$outputFile = Split-Path $SourceFilePath -Leaf
	$TargetFilePath = "/$outputFile"
	$arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
	$authorization = "Bearer " + $PlainAccessToken
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", $authorization)
	$headers.Add("Dropbox-API-Arg", $arg)
	$headers.Add("Content-Type", 'application/octet-stream')
	Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
	Write-AuditLog -Message "Dropbox upload completed successfully for file: $SourceFilePath" -Severity "Info"
	exit 0 # success
}
catch {
	Write-AuditLog -Message "Dropbox upload failed for file: $SourceFilePath - Error: $($_.Exception.Message)" -Severity "Error"
	"⚠️ ERROR: $($Error[0]) (script line $($_.InvocationInfo.ScriptLineNumber))"
	exit 1
}
finally {
	# Clear sensitive variables from memory
	if ($PlainAccessToken) {
		$PlainAccessToken = $null
		[System.GC]::Collect()
	}
	if ($authorization) {
		$authorization = $null
	}
}
