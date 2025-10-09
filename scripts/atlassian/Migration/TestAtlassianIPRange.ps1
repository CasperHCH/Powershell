# Test connectivity to Atlassian IP ranges
param(
    [int]$TimeoutSeconds = 5,
    [switch]$ShowSuccessOnly,
    [switch]$ShowFailureOnly
)

Write-Host "Fetching Atlassian IP ranges..." -ForegroundColor Cyan
try {
    $range = Invoke-RestMethod https://ip-ranges.atlassian.com -TimeoutSec 30
    Write-Host "Found $($range.items.Count) IP ranges to test" -ForegroundColor Green
} catch {
    Write-Error "Failed to fetch Atlassian IP ranges: $($_.Exception.Message)"
    exit 1
}

$results = @()
$successCount = 0
$failureCount = 0

foreach($r in $range.items.network) {
    Write-Progress -Activity "Testing IP Ranges" -Status "Testing $r" -PercentComplete (($results.Count / $range.items.Count) * 100)

    $testResult = @{
        IPRange = $r
        Reachable = $false
        ResponseTime = $null
    }

    if(Test-Connection $r -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        $testResult.Reachable = $true
        $successCount++
        if (-not $ShowFailureOnly) {
            Write-Host "✓ $r is reachable" -ForegroundColor Green
        }
    } else {
        $failureCount++
        if (-not $ShowSuccessOnly) {
            Write-Host "✗ $r is not reachable" -ForegroundColor Red
        }
    }

    $results += New-Object PSObject -Property $testResult
}

Write-Progress -Activity "Testing IP Ranges" -Completed

# Summary
Write-Host "\n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total IP ranges tested: $($results.Count)" -ForegroundColor Cyan
Write-Host "Reachable: $successCount" -ForegroundColor Green
Write-Host "Not reachable: $failureCount" -ForegroundColor Red
Write-Host "Success rate: $([math]::Round(($successCount / $results.Count) * 100, 2))%" -ForegroundColor Cyan

# Export results
$results | Export-Csv -Path "AtlassianIPRangeTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
Write-Host "\nResults exported to AtlassianIPRangeTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -ForegroundColor Yellow
