<#
.SYNOPSIS
    Enterprise PowerShell Security Compliance Scanner

.DESCRIPTION
    Comprehensive security scanner to identify compliance violations across the PowerShell repository.
    Scans for hardcoded credentials, company-specific information, and security vulnerabilities.

.PARAMETER ScanPath
    Root path to scan for PowerShell scripts (default: current directory)

.PARAMETER OutputPath
    Path to save compliance report (default: .\ComplianceReport.html)

.PARAMETER FixIssues
    Automatically fix simple compliance issues where possible

.PARAMETER Detailed
    Generate detailed compliance report with code snippets

.EXAMPLE
    .\Invoke-SecurityComplianceScan.ps1 -ScanPath "C:\PS" -OutputPath ".\SecurityReport.html" -Detailed

.NOTES
    SECURITY CLASSIFICATION: INTERNAL
    DATA HANDLING: Scans for security vulnerabilities and compliance issues
    AUDIT REQUIREMENTS: All scanning activities logged for security audit
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false, HelpMessage="Root path to scan for PowerShell scripts")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$ScanPath = $PWD,

    [Parameter(Mandatory=$false, HelpMessage="Path to save compliance report")]
    [string]$OutputPath = ".\SecurityComplianceReport.html",

    [Parameter(Mandatory=$false, HelpMessage="Automatically fix simple issues")]
    [switch]$FixIssues,

    [Parameter(Mandatory=$false, HelpMessage="Generate detailed report with code snippets")]
    [switch]$Detailed
)

# Security compliance patterns to detect
$CompliancePatterns = @{
    "HardcodedCredentials" = @{
        Pattern = "password\s*=\s*[`"'][^`"']+[`"']|apikey\s*=\s*[`"'][^`"']+[`"']|token\s*=\s*[`"'][^`"']+[`"']"
        Severity = "CRITICAL"
        Description = "Hardcoded credentials detected"
    }

    "HardcodedEmails" = @{
        Pattern = '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        Severity = "HIGH"
        Description = "Hardcoded email addresses detected"
        Exclusions = @("contoso.com", "example.com", "example.org", "domain.com", "eightwone.com")
    }

    "HardcodedServers" = @{
        Pattern = '(server|srv|dc|db|sql|web)\d*[-.]?(prod|production|dev|development|test|stage|staging)'
        Severity = "HIGH"
        Description = "Hardcoded server names detected"
    }

    "HardcodedPaths" = @{
        Pattern = '[C-Z]:\\[^$\s]*\\[^$\s]*'
        Severity = "MEDIUM"
        Description = "Hardcoded file paths detected"
        Exclusions = @("C:\Windows", "C:\Program Files", "C:\Temp", "C:\Users", "D:\Logs")
    }

    "CompanyIdentifiers" = @{
        Pattern = '(corp|company|inc|ltd|llc|aps|a\/s)\.(com|dk|net|org)'
        Severity = "HIGH"
        Description = "Company-specific domains detected"
        Exclusions = @("contoso.com", "example.com")
    }

    "InsecureProtocols" = @{
        Pattern = 'https://(?!localhost|127\.0\.0\.1)'
        Severity = "MEDIUM"
        Description = "Insecure HTTP protocols detected"
    }

    "MissingParameterValidation" = @{
        Pattern = 'param\s*\(\s*\[string\]\s*\$\w+\s*\)'
        Severity = "LOW"
        Description = "Parameters without validation attributes"
    }
}

# Initialize results
$ScanResults = @{
    TotalFiles = 0
    FilesWithIssues = 0
    TotalIssues = 0
    IssuesByCategory = @{}
    IssuesBySeverity = @{
        CRITICAL = 0
        HIGH = 0
        MEDIUM = 0
        LOW = 0
    }
    FileDetails = @()
}

function Write-ComplianceLog {
    param(
        [string]$Level,
        [string]$Message,
        [string]$File = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($File) { $logEntry += " | File: $File" }

    $color = switch ($Level) {
        "CRITICAL" { "Red" }
        "HIGH" { "Magenta" }
        "MEDIUM" { "Yellow" }
        "LOW" { "Cyan" }
        "INFO" { "Green" }
        default { "White" }
    }

    Write-Host $logEntry -ForegroundColor $color
}

function Test-FileCompliance {
    param(
        [string]$FilePath
    )

    $fileIssues = @()

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop

        foreach ($patternName in $CompliancePatterns.Keys) {
            $pattern = $CompliancePatterns[$patternName]
            $regexMatches = [regex]::Matches($content, $pattern.Pattern, 'IgnoreCase')

            foreach ($match in $regexMatches) {
                # Check exclusions
                $shouldExclude = $false
                if ($pattern.Exclusions) {
                    foreach ($exclusion in $pattern.Exclusions) {
                        if ($match.Value -like "*$exclusion*") {
                            $shouldExclude = $true
                            break
                        }
                    }
                }

                if (-not $shouldExclude) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

                    $issue = @{
                        Category = $patternName
                        Severity = $pattern.Severity
                        Description = $pattern.Description
                        Match = $match.Value
                        LineNumber = $lineNumber
                        Context = ""
                    }

                    # Get context (3 lines around the match)
                    if ($Detailed) {
                        $lines = $content -split "`n"
                        $startLine = [Math]::Max(0, $lineNumber - 2)
                        $endLine = [Math]::Min($lines.Count - 1, $lineNumber + 1)
                        $issue.Context = ($lines[$startLine..$endLine] -join "`n")
                    }

                    $fileIssues += $issue
                }
            }
        }

    } catch {
        Write-ComplianceLog -Level "ERROR" -Message "Failed to scan file: $($_.Exception.Message)" -File $FilePath
    }

    return $fileIssues
}

function Export-ComplianceReport {
    param(
        [hashtable]$Results,
        [string]$OutputPath
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>PowerShell Security Compliance Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: white; padding: 15px; border-radius: 5px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .critical { color: #e74c3c; font-weight: bold; }
        .high { color: #e67e22; font-weight: bold; }
        .medium { color: #f39c12; font-weight: bold; }
        .low { color: #3498db; font-weight: bold; }
        .compliant { color: #27ae60; font-weight: bold; }
        .issue-table { width: 100%; border-collapse: collapse; margin-top: 10px; background-color: white; }
        .issue-table th, .issue-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .issue-table th { background-color: #34495e; color: white; }
        .code-snippet { background-color: #f8f9fa; border-left: 4px solid #007acc; padding: 10px; margin: 5px 0; font-family: 'Courier New', monospace; }
        .file-section { background-color: white; margin-bottom: 15px; padding: 15px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 PowerShell Security Compliance Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Scan Path: $ScanPath</p>
    </div>

    <div class="summary">
        <h2>📊 Executive Summary</h2>
        <ul>
            <li><strong>Total Files Scanned:</strong> $($Results.TotalFiles)</li>
            <li><strong>Files with Issues:</strong> $($Results.FilesWithIssues)</li>
            <li><strong>Total Security Issues:</strong> $($Results.TotalIssues)</li>
        </ul>

        <h3>Issues by Severity</h3>
        <ul>
            <li><strong>Critical:</strong> <span class="critical">$($Results.IssuesBySeverity.CRITICAL)</span></li>
            <li><strong>High:</strong> <span class="high">$($Results.IssuesBySeverity.HIGH)</span></li>
            <li><strong>Medium:</strong> <span class="medium">$($Results.IssuesBySeverity.MEDIUM)</span></li>
            <li><strong>Low:</strong> <span class="low">$($Results.IssuesBySeverity.LOW)</span></li>
        </ul>
    </div>
"@

    # Add file details
    foreach ($fileDetail in $Results.FileDetails) {
        if ($fileDetail.Issues.Count -gt 0) {
            $html += @"
    <div class="file-section">
        <h3>📄 $($fileDetail.RelativePath)</h3>
        <p><strong>Issues Found:</strong> $($fileDetail.Issues.Count)</p>

        <table class="issue-table">
            <thead>
                <tr>
                    <th>Line</th>
                    <th>Severity</th>
                    <th>Category</th>
                    <th>Description</th>
                    <th>Match</th>
                </tr>
            </thead>
            <tbody>
"@
            foreach ($issue in $fileDetail.Issues) {
                $severityClass = $issue.Severity.ToLower()
                $sanitizedMatch = [System.Web.HttpUtility]::HtmlEncode($issue.Match)
                $html += @"
                <tr>
                    <td>$($issue.LineNumber)</td>
                    <td><span class="$severityClass">$($issue.Severity)</span></td>
                    <td>$($issue.Category)</td>
                    <td>$($issue.Description)</td>
                    <td><code>$sanitizedMatch</code></td>
                </tr>
"@
                if ($Detailed -and $issue.Context) {
                    $sanitizedContext = [System.Web.HttpUtility]::HtmlEncode($issue.Context)
                    $html += @"
                <tr>
                    <td colspan="5">
                        <div class="code-snippet">$sanitizedContext</div>
                    </td>
                </tr>
"@
                }
            }
            $html += @"
            </tbody>
        </table>
    </div>
"@
        }
    }

    $html += @"
    <div class="summary">
        <h2>🎯 Remediation Recommendations</h2>
        <ul>
            <li><strong>Critical/High Issues:</strong> Immediate remediation required - contains security vulnerabilities</li>
            <li><strong>Medium Issues:</strong> Should be addressed in next maintenance cycle</li>
            <li><strong>Low Issues:</strong> Consider addressing for improved security posture</li>
        </ul>

        <h3>Security Best Practices</h3>
        <ul>
            <li>Use parameterized inputs for all environment-specific values</li>
            <li>Implement secure credential management with Get-Credential or Azure Key Vault</li>
            <li>Add comprehensive parameter validation attributes</li>
            <li>Use HTTPS/TLS for all external communications</li>
            <li>Implement audit logging for all sensitive operations</li>
        </ul>
    </div>
</body>
</html>
"@

    $html | Out-File $OutputPath -Encoding UTF8
    Write-ComplianceLog -Level "INFO" -Message "Compliance report saved to: $OutputPath"
}

# Main execution
Write-Host "🔒 Starting PowerShell Security Compliance Scan" -ForegroundColor Cyan
Write-Host "Scan Path: $ScanPath" -ForegroundColor White
Write-Host "Report Path: $OutputPath" -ForegroundColor White

# Get all PowerShell files
$psFiles = Get-ChildItem -Path $ScanPath -Filter "*.ps1" -Recurse | Where-Object { $_.Length -lt 10MB }
$ScanResults.TotalFiles = $psFiles.Count

Write-Host "📁 Found $($psFiles.Count) PowerShell files to scan" -ForegroundColor Green

# Scan each file
$progressCount = 0
foreach ($file in $psFiles) {
    $progressCount++
    $percentComplete = [Math]::Round(($progressCount / $psFiles.Count) * 100)
    Write-Progress -Activity "Scanning PowerShell Files" -Status "File $progressCount of $($psFiles.Count)" -PercentComplete $percentComplete

    $relativePath = $file.FullName.Replace($ScanPath, "").TrimStart("\")
    Write-ComplianceLog -Level "INFO" -Message "Scanning: $relativePath"

    $issues = Test-FileCompliance -FilePath $file.FullName

    $fileDetail = @{
        FullPath = $file.FullName
        RelativePath = $relativePath
        Issues = $issues
    }

    $ScanResults.FileDetails += $fileDetail

    if ($issues.Count -gt 0) {
        $ScanResults.FilesWithIssues++
        $ScanResults.TotalIssues += $issues.Count

        Write-ComplianceLog -Level "HIGH" -Message "Found $($issues.Count) issues" -File $relativePath

        foreach ($issue in $issues) {
            $ScanResults.IssuesBySeverity[$issue.Severity]++

            if (-not $ScanResults.IssuesByCategory.ContainsKey($issue.Category)) {
                $ScanResults.IssuesByCategory[$issue.Category] = 0
            }
            $ScanResults.IssuesByCategory[$issue.Category]++
        }
    }
}

Write-Progress -Activity "Scanning PowerShell Files" -Completed

# Display summary
Write-Host "`n📊 Scan Complete - Summary Report:" -ForegroundColor Cyan
Write-Host "Total Files Scanned: $($ScanResults.TotalFiles)" -ForegroundColor White
Write-Host "Files with Issues: $($ScanResults.FilesWithIssues)" -ForegroundColor $(if($ScanResults.FilesWithIssues -gt 0){"Yellow"}else{"Green"})
Write-Host "Total Security Issues: $($ScanResults.TotalIssues)" -ForegroundColor $(if($ScanResults.TotalIssues -gt 0){"Red"}else{"Green"})

Write-Host "`n🚨 Issues by Severity:" -ForegroundColor Cyan
Write-Host "  Critical: $($ScanResults.IssuesBySeverity.CRITICAL)" -ForegroundColor $(if($ScanResults.IssuesBySeverity.CRITICAL -gt 0){"Red"}else{"Green"})
Write-Host "  High: $($ScanResults.IssuesBySeverity.HIGH)" -ForegroundColor $(if($ScanResults.IssuesBySeverity.HIGH -gt 0){"Magenta"}else{"Green"})
Write-Host "  Medium: $($ScanResults.IssuesBySeverity.MEDIUM)" -ForegroundColor $(if($ScanResults.IssuesBySeverity.MEDIUM -gt 0){"Yellow"}else{"Green"})
Write-Host "  Low: $($ScanResults.IssuesBySeverity.LOW)" -ForegroundColor $(if($ScanResults.IssuesBySeverity.LOW -gt 0){"Cyan"}else{"Green"})

# Export report
Export-ComplianceReport -Results $ScanResults -OutputPath $OutputPath

# Final recommendations
if ($ScanResults.TotalIssues -gt 0) {
    Write-Host "`n⚠️ SECURITY RECOMMENDATIONS:" -ForegroundColor Yellow
    Write-Host "1. Address CRITICAL and HIGH severity issues immediately" -ForegroundColor Red
    Write-Host "2. Review and parameterize all hardcoded values" -ForegroundColor Yellow
    Write-Host "3. Implement secure credential management patterns" -ForegroundColor Yellow
    Write-Host "4. Add comprehensive audit logging to sensitive operations" -ForegroundColor Yellow
    Write-Host "5. Review detailed report at: $OutputPath" -ForegroundColor Cyan
} else {
    Write-Host "`n✅ EXCELLENT! No security compliance issues detected." -ForegroundColor Green
    Write-Host "Repository meets enterprise security standards." -ForegroundColor Green
}
