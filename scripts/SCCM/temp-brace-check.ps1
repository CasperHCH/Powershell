$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$lines = Get-Content -Path $path
$openBrace = 0
$closeBrace = 0
$openParen = 0
$closeParen = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($c in $line.ToCharArray()) {
        if ($c -eq '{') { $openBrace++ }
        elseif ($c -eq '}') { $closeBrace++ }
        elseif ($c -eq '(') { $openParen++ }
        elseif ($c -eq ')') { $closeParen++ }
    }
    if (($i + 1) % 100 -eq 0) {
        Write-Host ('Line {0}: Braces {1}/{2}, Parens {3}/{4}' -f ($i + 1), $openBrace, $closeBrace, $openParen, $closeParen)
    }
}
Write-Host ('Total: Braces {0}/{1}, Parens {2}/{3}' -f $openBrace, $closeBrace, $openParen, $closeParen)
