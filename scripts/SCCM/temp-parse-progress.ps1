$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$lines = Get-Content -Path $path
for ($count = 100; $count -le $lines.Count; $count += 100) {
    $text = ($lines[0..($count-1)] | Out-String)
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$errors, [ref]$tokens) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "Parse failed at chunk $count"
        foreach ($e in $errors) {
            Write-Host "MESSAGE: $($e.Message)"
            Write-Host "LINE: $($e.Extent.StartLineNumber) COL: $($e.Extent.StartColumnNumber)"
            Write-Host "TEXT: $($e.Extent.Text)"
            Write-Host '---'
        }
        break
    }
}
if (-not $errors -or $errors.Count -eq 0) { Write-Host 'No parse errors in chunked increments' }
