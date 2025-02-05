$ErrorActionPreference = 'Stop';
$toolsDir   = 
$url        = ''
$url64      = ''

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  url           = $url
  url64bit      = $url64

  softwareName  = 'powershell-scripts*'

  checksum      = ''
  checksumType  = 'sha256'
  checksum64    = ''
  checksumType64= 'sha256'

  silentArgs    = $($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
