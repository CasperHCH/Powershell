<#
.SYNOPSIS
    Advanced Date/Time Conversion and Formatting Utility
.DESCRIPTION
    A comprehensive PowerShell script for parsing, converting, and formatting dates/times
    with support for multiple input formats, time zones, and output options.
.PARAMETER InputDate
    Input date string to convert (supports various formats)
.PARAMETER OutputFormat
    Output date format (default: yyyy-MM-dd HH:mm:ss)
.PARAMETER TimeZone
    Convert to specific time zone (e.g., 'UTC', 'Eastern Standard Time')
.PARAMETER ShowExamples
    Display example date formats and usage
.PARAMETER ExportToFile
    Export results to a file
.EXAMPLE
    .\Ask For a date and convert it to datetime.ps1 -InputDate "12/25/2023" -OutputFormat "MM/dd/yyyy"
.EXAMPLE
    .\Ask For a date and convert it to datetime.ps1 -InputDate "2023-12-25T15:30:00" -TimeZone "UTC"
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="Input date string in various formats")]
    [string]$InputDate,

    [Parameter(Mandatory=$false, HelpMessage="Output format pattern (e.g., yyyy-MM-dd, MM/dd/yyyy HH:mm)")]
    [ValidateScript({
        try {
            # Test the format string with a sample date
            $testDate = Get-Date
            $testDate.ToString($_) | Out-Null
            return $true
        } catch {
            throw "Invalid date format pattern: $_"
        }
    })]
    [string]$OutputFormat = "yyyy-MM-dd HH:mm:ss",

    [Parameter(Mandatory=$false, HelpMessage="Target timezone for conversion")]
    [string]$TimeZone,

    [Parameter(Mandatory=$false, HelpMessage="Show example formats and usage")]
    [switch]$ShowExamples,

    [Parameter(Mandatory=$false, HelpMessage="Export results to a file")]
    [switch]$ExportToFile,

    [Parameter(Mandatory=$false, HelpMessage="Enable batch processing of multiple dates")]
    [switch]$BatchMode
)

Write-Host "📅 Advanced Date/Time Converter v2.0" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Show examples if requested
if ($ShowExamples) {
    Write-Host "`n📋 Supported Input Formats:" -ForegroundColor Yellow
    @(
        "MM/dd/yyyy (e.g., 12/25/2023)",
        "yyyy-MM-dd (e.g., 2023-12-25)",  
        "dd/MM/yyyy (e.g., 25/12/2023)",
        "yyyy-MM-dd HH:mm:ss (e.g., 2023-12-25 15:30:45)",
        "MM/dd/yyyy h:mm tt (e.g., 12/25/2023 3:30 PM)",
        "dddd, MMMM dd, yyyy (e.g., Monday, December 25, 2023)",
        "ISO 8601 (e.g., 2023-12-25T15:30:00Z)",
        "Unix timestamp (e.g., 1703520600)"
    ) | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
    
    Write-Host "`n🎯 Output Format Patterns:" -ForegroundColor Yellow
    @(
        "yyyy-MM-dd HH:mm:ss → 2023-12-25 15:30:45",
        "MM/dd/yyyy → 12/25/2023",
        "dddd, MMMM dd, yyyy → Monday, December 25, 2023",
        "yyyy-MM-ddTHH:mm:ssZ → 2023-12-25T15:30:45Z",
        "HH:mm:ss → 15:30:45"
    ) | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
    Write-Host ""
}

function Convert-DateTimeAdvanced {
    param(
        [string]$DateString,
        [string]$Format,
        [string]$TargetTimeZone,
        [switch]$ShowDetails
    )

    $result = @{
        Success = $false
        OriginalInput = $DateString
        ParsedDateTime = $null
        FormattedOutput = $null
        TimeZoneInfo = $null
        ErrorMessage = $null
        ParseMethod = $null
    }

    try {
        $parsedDate = $null
        
        # Try different parsing methods
        $parsingMethods = @(
            { [DateTime]::Parse($DateString) },
            { [DateTime]::ParseExact($DateString, "yyyy-MM-dd", $null) },
            { [DateTime]::ParseExact($DateString, "MM/dd/yyyy", $null) },
            { [DateTime]::ParseExact($DateString, "dd/MM/yyyy", $null) },
            { [DateTime]::ParseExact($DateString, "yyyy-MM-dd HH:mm:ss", $null) },
            { [DateTime]::ParseExact($DateString, "MM/dd/yyyy HH:mm:ss", $null) },
            { [DateTime]::ParseExact($DateString, "yyyy-MM-ddTHH:mm:ss", $null) },
            { [DateTime]::ParseExact($DateString, "yyyy-MM-ddTHH:mm:ssZ", $null) }
        )

        # Try Unix timestamp conversion
        if ($DateString -match '^\d{10}$') {
            try {
                $unixEpoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
                $parsedDate = $unixEpoch.AddSeconds([long]$DateString)
                $result.ParseMethod = "Unix Timestamp"
            } catch {}
        }

        # Try standard parsing methods if Unix timestamp failed
        if (-not $parsedDate) {
            for ($i = 0; $i -lt $parsingMethods.Count; $i++) {
                try {
                    $parsedDate = & $parsingMethods[$i]
                    $result.ParseMethod = "Method $($i + 1)"
                    break
                } catch {}
            }
        }

        if (-not $parsedDate) {
            throw "Unable to parse date string: $DateString"
        }

        $result.ParsedDateTime = $parsedDate
        
        # Handle timezone conversion
        if ($TargetTimeZone) {
            try {
                $timeZoneInfo = [System.TimeZoneInfo]::FindSystemTimeZoneById($TargetTimeZone)
                $convertedDate = [System.TimeZoneInfo]::ConvertTime($parsedDate, $timeZoneInfo)
                $result.ParsedDateTime = $convertedDate
                $result.TimeZoneInfo = $timeZoneInfo.DisplayName
            } catch {
                Write-Host "⚠️  Warning: Could not convert to timezone '$TargetTimeZone'. Using original time." -ForegroundColor Yellow
            }
        }
        
        $result.FormattedOutput = $result.ParsedDateTime.ToString($Format)
        $result.Success = $true
        
    } catch {
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

function Show-ConversionResult {
    param($ConversionResult, [switch]$Detailed)
    
    if ($ConversionResult.Success) {
        Write-Host "✅ Conversion Successful!" -ForegroundColor Green
        Write-Host "📅 Result: " -NoNewline -ForegroundColor Cyan
        Write-Host $ConversionResult.FormattedOutput -ForegroundColor White
        
        if ($Detailed) {
            Write-Host "`n📊 Conversion Details:" -ForegroundColor Yellow
            Write-Host "  📝 Original Input: $($ConversionResult.OriginalInput)" -ForegroundColor Gray
            Write-Host "  🔧 Parse Method: $($ConversionResult.ParseMethod)" -ForegroundColor Gray
            Write-Host "  📅 Parsed DateTime: $($ConversionResult.ParsedDateTime)" -ForegroundColor Gray
            if ($ConversionResult.TimeZoneInfo) {
                Write-Host "  🌍 Time Zone: $($ConversionResult.TimeZoneInfo)" -ForegroundColor Gray
            }
        }
        
        return $ConversionResult.FormattedOutput
    } else {
        Write-Host "❌ Conversion Failed: $($ConversionResult.ErrorMessage)" -ForegroundColor Red
        return $null
    }
}

# Main execution logic
$results = @()

if ($BatchMode) {
    Write-Host "`n📊 Batch Processing Mode" -ForegroundColor Yellow
    Write-Host "Enter dates one by one (empty line to finish):" -ForegroundColor White
    
    $batchResults = @()
    do {
        $inputDate = Read-Host "Date"
        if (![string]::IsNullOrEmpty($inputDate)) {
            $result = Convert-DateTimeAdvanced -DateString $inputDate -Format $OutputFormat -TargetTimeZone $TimeZone
            $batchResults += $result
            Show-ConversionResult -ConversionResult $result
            Write-Host ""
        }
    } while (![string]::IsNullOrEmpty($inputDate))
    
    $results = $batchResults
    
} elseif ($InputDate) {
    # Single date conversion
    Write-Host "🔄 Converting single date..." -ForegroundColor Cyan
    $result = Convert-DateTimeAdvanced -DateString $InputDate -Format $OutputFormat -TargetTimeZone $TimeZone
    $output = Show-ConversionResult -ConversionResult $result -Detailed
    $results = @($result)
    
} else {
    # Interactive mode
    Write-Host "`n🔧 Interactive Mode" -ForegroundColor Yellow
    Write-Host "Current system culture: $((Get-Culture).DisplayName)" -ForegroundColor Gray
    Write-Host "Current time zone: $([System.TimeZoneInfo]::Local.DisplayName)" -ForegroundColor Gray
    
    while ($true) {
        Write-Host "`nEnter a date to convert (or 'quit' to exit):" -ForegroundColor White
        $inputDate = Read-Host "Date"
        
        if ($inputDate -eq 'quit' -or [string]::IsNullOrEmpty($inputDate)) {
            break
        }
        
        $result = Convert-DateTimeAdvanced -DateString $inputDate -Format $OutputFormat -TargetTimeZone $TimeZone
        $results += $result
        Show-ConversionResult -ConversionResult $result -Detailed
    }
}

# Export results if requested
if ($ExportToFile -and $results.Count -gt 0) {
    try {
        $exportPath = "DateConversion_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $exportData = $results | Select-Object OriginalInput, FormattedOutput, ParseMethod, TimeZoneInfo, Success, ErrorMessage
        $exportData | Export-Csv -Path $exportPath -NoTypeInformation
        Write-Host "`n📄 Results exported to: $exportPath" -ForegroundColor Green
    } catch {
        Write-Host "`n⚠️  Failed to export results: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Summary
if ($results.Count -gt 0) {
    $successCount = ($results | Where-Object { $_.Success }).Count
    Write-Host "`n📈 Summary: $successCount of $($results.Count) conversions successful" -ForegroundColor Cyan
}
