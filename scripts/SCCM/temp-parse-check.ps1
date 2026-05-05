$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$errs = $null
$toks = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$errs, [ref]$toks) | Out-Null
if ($errs -and $errs.Count -gt 0) {
    foreach ($e in $errs) {
        Write-Host "MESSAGE: $($e.Message)"
        Write-Host "LINE: $($e.Extent.StartLineNumber) COL: $($e.Extent.StartColumnNumber)"
        Write-Host "TEXT: $($e.Extent.Text)"
        Write-Host '---'
    }
    exit 2
}
Write-Host 'PARSE_OK'
