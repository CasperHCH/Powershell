# Comprehensive PowerShell syntax test for entire c:\PS folder
Write-Host "🔍 Scanning c:\PS for PowerShell files..." -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Gray

# Get all PowerShell files recursively
$psFiles = Get-ChildItem -Path "c:\PS" -Recurse -Include "*.ps1", "*.psm1", "*.psd1" -File -ErrorAction SilentlyContinue

$totalFiles = $psFiles.Count
$errorFiles = 0
$totalErrors = 0
$checkedFiles = 0

Write-Host "Found $totalFiles PowerShell files to check..." -ForegroundColor Cyan
Write-Host ""

foreach ($file in $psFiles) {
    $checkedFiles++
    $relativePath = $file.FullName.Replace("c:\PS\", "")

    Write-Host "[$checkedFiles/$totalFiles] Checking: $relativePath" -ForegroundColor Gray

    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop

        # Skip empty files
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  ⚠️  Empty file - skipped" -ForegroundColor Yellow
            continue
        }

        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors.Count -eq 0) {
            Write-Host "  ✅ Syntax OK" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $($parseErrors.Count) syntax error(s) found:" -ForegroundColor Red
            $errorFiles++
            $totalErrors += $parseErrors.Count

            foreach ($parseError in $parseErrors) {
                Write-Host "    Line $($parseError.Extent.StartLineNumber): $($parseError.Message)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  ⚠️  Could not read file: $($_.Exception.Message)" -ForegroundColor Magenta
    }

    Write-Host ""
}

# Summary
Write-Host "=" * 80 -ForegroundColor Gray
Write-Host "📊 SYNTAX CHECK SUMMARY" -ForegroundColor White
Write-Host "=" * 80 -ForegroundColor Gray
Write-Host "Total files checked: $checkedFiles" -ForegroundColor Cyan
Write-Host "Files with syntax errors: $errorFiles" -ForegroundColor $(if ($errorFiles -eq 0) { "Green" } else { "Red" })
Write-Host "Total syntax errors: $totalErrors" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })

if ($errorFiles -eq 0) {
    Write-Host "🎉 All PowerShell files have valid syntax!" -ForegroundColor Green
} else {
    Write-Host "⚠️  $errorFiles file(s) need attention" -ForegroundColor Yellow
}
Write-Host "=" * 80 -ForegroundColor Gray