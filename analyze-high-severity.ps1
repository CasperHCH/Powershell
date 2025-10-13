<#
.SYNOPSIS
    Analyzes HIGH severity security violations from PowerShell compliance reports

.DESCRIPTION
    This script processes security compliance reports to identify and categorize
    HIGH severity violations across PowerShell files in the repository

.PARAMETER ReportPath
    Path to the security compliance report HTML file
    Default: Current directory\SECURITY_COMPLIANCE_STATUS_REPORT.html

.PARAMETER OutputPath
    Optional path to export detailed analysis results

.EXAMPLE
    .\analyze-high-severity.ps1 -ReportPath "c:\PS\SECURITY_COMPLIANCE_STATUS_REPORT.html"

.NOTES
    Author: Security Compliance Team
    Version: 2.0
    Security Classification: Internal
    Requires: PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to the security compliance report HTML file")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ReportPath = ".\SECURITY_COMPLIANCE_STATUS_REPORT.html",

    [Parameter(Mandatory = $false, HelpMessage = "Path to export detailed analysis results")]
    [string]$OutputPath
)

# Security and audit logging
$auditEntry = @{
    Timestamp    = Get-Date -Format "o"
    Action       = "AnalyzeHighSeverityViolations"
    User         = $env:USERNAME
    ComputerName = $env:COMPUTERNAME
    ScriptName   = $MyInvocation.MyCommand.Name
    Parameters   = $PSBoundParameters
}

try {
    Write-Verbose "Loading security compliance report from: $ReportPath"
    $htmlContent = Get-Content $ReportPath -Raw -ErrorAction Stop
    $auditEntry.Status = "Success"
    $auditEntry.FilesAnalyzed = "SecurityReport"

}
catch {
    Write-Error "Failed to load compliance report: $($_.Exception.Message)"
    $auditEntry.Status = "Failed"
    $auditEntry.Error = $_.Exception.Message
    throw
}

# Find all file sections with HIGH severity issues
$filePattern = '<h3>📄\s+([^<]+)</h3>'
$highPattern = '<span class="high">HIGH</span>'

$fileMatches = [regex]::Matches($htmlContent, $filePattern)
$highMatches = [regex]::Matches($htmlContent, $highPattern)

Write-Host "Found $($highMatches.Count) HIGH severity violations across files" -ForegroundColor Yellow

# Create a simple mapping by finding files that contain HIGH violations
$filesWithHigh = @()
$content = $htmlContent
$position = 0

while ($position -lt $content.Length) {
    $nextFile = $content.IndexOf('<h3>📄', $position)
    if ($nextFile -eq -1) { break }

    $endOfFile = $content.IndexOf('<h3>📄', $nextFile + 1)
    if ($endOfFile -eq -1) { $endOfFile = $content.Length }

    $fileSection = $content.Substring($nextFile, $endOfFile - $nextFile)

    # Extract filename
    if ($fileSection -match '<h3>📄\s+([^<]+)</h3>') {
        $fileName = $matches[1]
        $highCount = ([regex]::Matches($fileSection, $highPattern)).Count

        if ($highCount -gt 0) {
            $filesWithHigh += [PSCustomObject]@{
                File              = $fileName
                HighSeverityCount = $highCount
            }
        }
    }

    $position = $nextFile + 1
}

# Display results
$sortedResults = $filesWithHigh | Sort-Object HighSeverityCount -Descending
$sortedResults | Format-Table -AutoSize
Write-Host "Total files with HIGH severity: $($filesWithHigh.Count)" -ForegroundColor Cyan

$auditEntry.ResultCount = $filesWithHigh.Count
$auditEntry.TotalViolations = ($filesWithHigh | Measure-Object HighSeverityCount -Sum).Sum

# Export results if OutputPath specified
if ($OutputPath) {
    try {
        $exportData = @{
            GeneratedOn     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SourceReport    = $ReportPath
            TotalFiles      = $filesWithHigh.Count
            TotalViolations = ($filesWithHigh | Measure-Object HighSeverityCount -Sum).Sum
            Files           = $sortedResults
        }

        $exportData | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
        Write-Host "Analysis exported to: $OutputPath" -ForegroundColor Green
        $auditEntry.ExportPath = $OutputPath

    }
    catch {
        Write-Warning "Failed to export results: $($_.Exception.Message)"
        $auditEntry.ExportError = $_.Exception.Message
    }
}

} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    $auditEntry.Status = "Failed"
    $auditEntry.Error = $_.Exception.Message
    throw
} finally {
    # Audit logging (in production, this would go to a centralized log)
    Write-Verbose "Audit: $($auditEntry | ConvertTo-Json -Compress)"
}