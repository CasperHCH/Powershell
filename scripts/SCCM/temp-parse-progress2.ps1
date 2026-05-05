$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$lines = Get-Content -Path $path
foreach ($count in 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500, 8000, 8425) {
    if ($count -gt $lines.Count) { break }
    $text = ($lines[0..($count-1)] | Out-String)
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$errors, [ref]$tokens) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        $output += "Parse failed at chunk $count"
        foreach ($e in $errors) {
            $output += "MESSAGE: $($e.Message)"
            $output += "LINE: $($e.Extent.StartLineNumber) COL: $($e.Extent.StartColumnNumber)"
            $output += "TEXT: $($e.Extent.Text)"
            $output += '---'
        }
        break
    } else {
        $output += "Chunk $count OK"
    }
}
$output += 'No parse errors in chunked increments'
Set-Content -Path 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\temp-parse-progress2-output.txt' -Value $output

