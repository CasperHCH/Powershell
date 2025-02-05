<#
.SYNOPSIS
	Uploads a local file to a FTP server
.DESCRIPTION
	This PowerShell script uploads a local file to a FTP server.
.PARAMETER File
	Specifies the path to the local file
.PARAMETER URL
	Specifies the FTP server URL
.PARAMETER Username
	Specifies the user name
.PARAMETER Password
	Specifies the password
.EXAMPLE
	PS> .\upload-file.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$File = , [string]$URL = , [string]$Username = , [string]$Password = )

try {
	if ($File -eq ) { $File = read-host  }
	if ($URL -eq ) { $URL = read-host  }
	if ($Username -eq ) { $Username = read-host  }
	if ($Password -eq ) { $Password = read-host  }
	[bool]$EnableSSL = $true
	[bool]$UseBinary = $true
	[bool]$UsePassive = $true
	[bool]$KeepAlive = $true
	[bool]$IgnoreCert = $true

	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	# check local file:
	$FullPath = Resolve-Path 
	if (-not(test-path  -pathType leaf)) { throw  }
	$Filename = (Get-Item $FullPath).Name
	$FileSize = (Get-Item $FullPath).Length
	

	# prepare request:
	$Request = [Net.WebRequest]::Create()
	$Request.Credentials = New-Object System.Net.NetworkCredential(, )
	$Request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile 
	$Request.EnableSSL = $EnableSSL
	$Request.UseBinary = $UseBinary
	$Request.UsePassive = $UsePassive
	$Request.KeepAlive = $KeepAlive
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$IgnoreCert}

	$fileStream = [System.IO.File]::OpenRead()
	$ftpStream = $Request.GetRequestStream()

	$Buf = New-Object Byte[] 32KB
	while (($DataRead = $fileStream.Read($Buf, 0, $Buf.Length)) -gt 0)
	{
	    $ftpStream.Write($Buf, 0, $DataRead)
	    $pct = ($fileStream.Position / $fileStream.Length)
	    Write-Progress -Activity  -Status ( -f $pct) -PercentComplete ($pct * 100)
	}

	# cleanup:
	$ftpStream.Dispose()
	$fileStream.Dispose()

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 1
}
