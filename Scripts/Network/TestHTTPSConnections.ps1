<#
.SYNOPSIS
    Test HTTPS connectivity to multiple endpoints with detailed reporting
.DESCRIPTION
    This script tests HTTPS connections to a predefined set of common endpoints
    and optionally custom URLs provided by the user. It provides detailed 
    connection status, response times, and generates reports.
.PARAMETER CustomUris
    Additional URLs to test beyond the default set
.PARAMETER TimeoutSeconds
    Timeout in seconds for each connection test (default: 30)
.PARAMETER ExportResults
    Export results to CSV file
.PARAMETER ExportPath
    Path for CSV export (default: script directory)
.PARAMETER Verbose
    Enable verbose output with detailed timing information
.EXAMPLE
    .\TestHTTPSConnections.ps1
.EXAMPLE
    .\TestHTTPSConnections.ps1 -CustomUris @("https://mysite.com", "https://api.example.com") -ExportResults
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="Additional URLs to test (array of strings)")]
    [ValidateScript({
        foreach ($uri in $_) {
            if ($uri -notmatch '^https?://') {
                throw "Invalid URL format: $uri. URLs must start with http:// or https://"
            }
        }
        return $true
    })]
    [string[]]$CustomUris = @(),

    [Parameter(Mandatory=$false, HelpMessage="Connection timeout in seconds (1-300)")]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30,

    [Parameter(Mandatory=$false, HelpMessage="Export results to CSV file")]
    [switch]$ExportResults,

    [Parameter(Mandatory=$false, HelpMessage="Path for CSV export")]
    [string]$ExportPath,

    [Parameter(Mandatory=$false, HelpMessage="Enable detailed verbose output")]
    [switch]$Verbose
)

Write-Host "🌐 HTTPS Connection Tester v2.0" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "⏱️  Timeout: $TimeoutSeconds seconds" -ForegroundColor Gray
Write-Host ""

# Enhanced endpoint categories
$EndpointCategories = @{
    "Search Engines" = @(
        "https://www.google.com",
        "https://www.bing.com",
        "https://duckduckgo.com"
    )
    "Technology & Development" = @(
        "https://github.com",
        "https://stackoverflow.com",
        "https://docs.microsoft.com"
    )
    "Microsoft Services" = @(
        "https://www.microsoft.com",
        "https://portal.azure.com",
        "https://admin.microsoft.com",
        "https://outlook.office365.com"
    )
    "Social Media" = @(
        "https://www.linkedin.com",
        "https://www.facebook.com",
        "https://twitter.com"
    )
}

# Combine all default endpoints
$defaultUris = @()
foreach ($category in $EndpointCategories.Values) {
    $defaultUris += $category
}

# Add custom URIs if provided
$allUris = $defaultUris + $CustomUris

if ($CustomUris.Count -gt 0) {
    Write-Host "🔧 Testing $($defaultUris.Count) default + $($CustomUris.Count) custom endpoints" -ForegroundColor Yellow
} else {
    Write-Host "🔧 Testing $($allUris.Count) default endpoints" -ForegroundColor Yellow
}

Write-Host ""

$results = @()
$totalTests = $allUris.Count
$currentTest = 0

foreach ($uri in $allUris) {
    $currentTest++
    $percentComplete = [math]::Round(($currentTest / $totalTests) * 100)
    
    Write-Progress -Activity "Testing HTTPS Connections" -Status "Testing $uri" -PercentComplete $percentComplete
    
    $testStart = Get-Date
    $testResult = [PSCustomObject]@{
        URI = $uri
        StatusCode = $null
        StatusDescription = $null
        ResponseTime = $null
        FinalUri = $null
        Category = "Custom"
        Success = $false
        ErrorMessage = $null
    }
    
    # Determine category for default URIs
    foreach ($categoryName in $EndpointCategories.Keys) {
        if ($EndpointCategories[$categoryName] -contains $uri) {
            $testResult.Category = $categoryName
            break
        }
    }
    
    try {
        Write-Host "[$currentTest/$totalTests] 🔗 Testing: " -NoNewline -ForegroundColor Gray
        Write-Host "$uri" -ForegroundColor White
        
        $Response = Invoke-WebRequest -Uri $uri -ErrorAction Stop -UseBasicParsing -DisableKeepAlive -TimeoutSec $TimeoutSeconds
        $testEnd = Get-Date
        $responseTime = ($testEnd - $testStart).TotalMilliseconds
        
        $testResult.StatusCode = $Response.StatusCode
        $testResult.StatusDescription = $Response.StatusDescription
        $testResult.ResponseTime = [math]::Round($responseTime, 0)
        $testResult.FinalUri = $Response.BaseResponse.ResponseUri.ToString()
        $testResult.Success = $true
        
        Write-Host "  ✅ SUCCESS: " -NoNewline -ForegroundColor Green
        Write-Host "$($Response.StatusCode) $($Response.StatusDescription) " -NoNewline -ForegroundColor White
        Write-Host "($($testResult.ResponseTime)ms)" -ForegroundColor Yellow
        
        if ($Verbose -and $testResult.FinalUri -ne $uri) {
            Write-Host "     🔄 Redirected to: $($testResult.FinalUri)" -ForegroundColor Cyan
        }
        
    } catch {
        $testEnd = Get-Date
        $responseTime = ($testEnd - $testStart).TotalMilliseconds
        
        $testResult.StatusCode = "ERROR"
        $testResult.StatusDescription = "Connection Failed"
        $testResult.ResponseTime = [math]::Round($responseTime, 0)
        $testResult.FinalUri = $uri
        $testResult.Success = $false
        $testResult.ErrorMessage = $_.Exception.Message
        
        Write-Host "  ❌ FAILED: " -NoNewline -ForegroundColor Red
        Write-Host "$($_.Exception.Message)" -ForegroundColor White
        Write-Host "     ⏱️  Timeout after $($testResult.ResponseTime)ms" -ForegroundColor Gray
    }
    
    $results += $testResult
    if ($Verbose) { Write-Host "" }
}

Write-Progress -Activity "Testing HTTPS Connections" -Completed

# Results Analysis
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_.Success }).Count
$failureCount = $results.Count - $successCount
$avgResponseTime = [math]::Round(($results | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Average).Average, 0)

Write-Host "✅ Successful: " -NoNewline -ForegroundColor Green
Write-Host "$successCount" -ForegroundColor White
Write-Host "❌ Failed: " -NoNewline -ForegroundColor Red  
Write-Host "$failureCount" -ForegroundColor White
Write-Host "📈 Success Rate: " -NoNewline -ForegroundColor Cyan
$successRate = [math]::Round(($successCount / $results.Count) * 100, 1)
Write-Host "$successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })
if ($successCount -gt 0) {
    Write-Host "⚡ Average Response Time: " -NoNewline -ForegroundColor Cyan
    Write-Host "${avgResponseTime}ms" -ForegroundColor White
}

# Category breakdown
Write-Host "`n📂 Results by Category:" -ForegroundColor Yellow
$categoryResults = $results | Group-Object -Property Category | Sort-Object Name
foreach ($category in $categoryResults) {
    $catSuccess = ($category.Group | Where-Object { $_.Success }).Count
    $catTotal = $category.Group.Count
    $catRate = [math]::Round(($catSuccess / $catTotal) * 100, 0)
    Write-Host "  $($category.Name): " -NoNewline -ForegroundColor White
    Write-Host "$catSuccess/$catTotal " -NoNewline -ForegroundColor Gray
    Write-Host "($catRate%)" -ForegroundColor $(if ($catRate -eq 100) { "Green" } elseif ($catRate -ge 50) { "Yellow" } else { "Red" })
}

# Detailed table
if ($Verbose) {
    Write-Host "`n📋 Detailed Results:" -ForegroundColor Yellow
    $results | Format-Table -Property URI, StatusCode, StatusDescription, ResponseTime, Category -AutoSize
}

# Export results if requested
if ($ExportResults) {
    try {
        $exportFile = if ($ExportPath) { 
            Join-Path $ExportPath "HTTPS_Test_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        } else { 
            "HTTPS_Test_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        }
        
        $results | Export-Csv -Path $exportFile -NoTypeInformation
        Write-Host "`n📄 Results exported to: $exportFile" -ForegroundColor Green
    } catch {
        Write-Host "`n⚠️  Failed to export results: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Final status
Write-Host ""
if ($failureCount -eq 0) {
    Write-Host "🎉 All connections successful!" -ForegroundColor Green
} elseif ($successCount -gt $failureCount) {
    Write-Host "⚠️  Most connections successful, but some issues detected" -ForegroundColor Yellow
} else {
    Write-Host "🚨 Significant connectivity issues detected" -ForegroundColor Red
}
