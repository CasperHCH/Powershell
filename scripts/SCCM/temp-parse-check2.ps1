$path = 'c:\Users\cach91\Desktop\Powershell-main\scripts\SCCM\SCCMSoftwareCollectionConsolidation.ps1'
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$errors, [ref]$tokens) | Out-Null
if ($errors -and $errors.Count -gt 0) {
    foreach ($e in $errors) {
        Write-Output "Type: $($e.GetType().FullName)"
        Write-Output "Message: $($e.Message)"
        Write-Output "ErrorId: $($e.ErrorId)"
        Write-Output "Category: $($e.CategoryInfo.Category)"
        Write-Output "Reason: $($e.CategoryInfo.Reason)"
        Write-Output "Line: $($e.Extent.StartLineNumber) Col: $($e.Extent.StartColumnNumber)"
        Write-Output "Text: $($e.Extent.Text)"
        Write-Output '-----'
    }
} else {
    Write-Output 'PARSE_OK'
}
