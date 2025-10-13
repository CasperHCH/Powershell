# Simple PowerShell syntax checker - dynamic path resolution
$ScanPath = $PSScriptRoot -or (Get-Location).Path
$psFiles = Get-ChildItem -Path $ScanPath -Recurse -Include "*.ps1", "*.psm1", "*.psd1" -File -ErrorAction SilentlyContinue
$results = @()

Write-Output "Checking $($psFiles.Count) PowerShell files in $ScanPath..."
Write-Output ""

foreach ($file in $psFiles) {
    $relativePath = $file.FullName.Replace("$ScanPath\", "")

    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            $results += [PSCustomObject]@{
                File = $relativePath
                Status = "Empty"
                Errors = 0
                Messages = @()
            }
            continue
        }

        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)

        $errorMessages = @()
        if ($parseErrors.Count -gt 0) {
            foreach ($parseError in $parseErrors) {
                $errorMessages += "Line $($parseError.Extent.StartLineNumber): $($parseError.Message)"
            }
        }

        $results += [PSCustomObject]@{
            File = $relativePath
            Status = if ($parseErrors.Count -eq 0) { "OK" } else { "ERROR" }
            Errors = $parseErrors.Count
            Messages = $errorMessages
        }

    } catch {
        $results += [PSCustomObject]@{
            File = $relativePath
            Status = "READ_ERROR"
            Errors = 1
            Messages = @("Could not read file: $($_.Exception.Message)")
        }
    }
}

# Output results
Write-Output "RESULTS:"
Write-Output "========"

$errorFiles = $results | Where-Object { $_.Status -eq "ERROR" }
$readErrors = $results | Where-Object { $_.Status -eq "READ_ERROR" }
$okFiles = $results | Where-Object { $_.Status -eq "OK" }
$emptyFiles = $results | Where-Object { $_.Status -eq "Empty" }

Write-Output "Files with syntax errors: $($errorFiles.Count)"
Write-Output "Files with read errors: $($readErrors.Count)"
Write-Output "Files with valid syntax: $($okFiles.Count)"
Write-Output "Empty files: $($emptyFiles.Count)"
Write-Output "Total files checked: $($results.Count)"
Write-Output ""

if ($errorFiles.Count -gt 0) {
    Write-Output "FILES WITH SYNTAX ERRORS:"
    Write-Output "========================="
    foreach ($file in $errorFiles) {
        Write-Output "File: $($file.File)"
        foreach ($msg in $file.Messages) {
            Write-Output "  $msg"
        }
        Write-Output ""
    }
}

if ($readErrors.Count -gt 0) {
    Write-Output "FILES WITH READ ERRORS:"
    Write-Output "======================="
    foreach ($file in $readErrors) {
        Write-Output "File: $($file.File)"
        foreach ($msg in $file.Messages) {
            Write-Output "  $msg"
        }
        Write-Output ""
    }
}