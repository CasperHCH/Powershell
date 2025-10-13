# Quick Security Compliance Check for BulkChangeEmails.ps1
param(
    [string]$FilePath = "c:\PS\scripts\atlassian\On-Prem\Jira\BulkChangeEmails.ps1"
)

Write-Host "🔒 Security Compliance Check for BulkChangeEmails.ps1" -ForegroundColor Cyan

$violations = @()

# Check for hardcoded credentials
$credentialPatterns = @(
    'password\s*=\s*"[^"]+"|password\s*=\s*''[^'']+''',
    'pwd\s*=\s*"[^"]+"|pwd\s*=\s*''[^'']+''',
    'secret\s*=\s*"[^"]+"|secret\s*=\s*''[^'']+''',
    'key\s*=\s*"[^"]+"|key\s*=\s*''[^'']+''"',
    'token\s*=\s*"[^"]+"|token\s*=\s*''[^'']+''"'
)

# Check for company-specific references
$companyPatterns = @(
    '@company\.com(?!\.contoso\.com)',
    '\.company\.com(?!\.contoso\.com)',
    'teliacompany\.com',
    'ajn4901',
    'kenneth\.hargett'
)

# Check for hardcoded server/path references
$infrastructurePatterns = @(
    'server-?name\s*=\s*"[^"]+"|server-?name\s*=\s*''[^'']+''',
    'hostname\s*=\s*"[^"]+"|hostname\s*=\s*''[^'']+''',
    'C:\[a-z]+'
)

Write-Host "Checking for hardcoded credentials..." -ForegroundColor Yellow
foreach ($pattern in $credentialPatterns) {
    $results = Select-String -Path $FilePath -Pattern $pattern -AllMatches
    if ($results) {
        $violations += @{
            Type = "CRITICAL - Hardcoded Credentials"
            Pattern = $pattern
            Matches = $results.Count
            Lines = $results.LineNumber -join ", "
        }
    }
}

Write-Host "Checking for company-specific references..." -ForegroundColor Yellow
foreach ($pattern in $companyPatterns) {
    $results = Select-String -Path $FilePath -Pattern $pattern -AllMatches
    if ($results) {
        $violations += @{
            Type = "HIGH - Company-Specific References"
            Pattern = $pattern
            Matches = $results.Count
            Lines = $results.LineNumber -join ", "
        }
    }
}

Write-Host "Checking for hardcoded infrastructure..." -ForegroundColor Yellow
foreach ($pattern in $infrastructurePatterns) {
    $results = Select-String -Path $FilePath -Pattern $pattern -AllMatches
    if ($results) {
        $violations += @{
            Type = "MEDIUM - Hardcoded Infrastructure"
            Pattern = $pattern
            Matches = $results.Count
            Lines = $results.LineNumber -join ", "
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "✅ SUCCESS: BulkChangeEmails.ps1 is now security compliant!" -ForegroundColor Green
    Write-Host "   - No hardcoded credentials found" -ForegroundColor Green
    Write-Host "   - No company-specific references found" -ForegroundColor Green
    Write-Host "   - Infrastructure properly parameterized" -ForegroundColor Green
} else {
    Write-Host "❌ VIOLATIONS FOUND: $($violations.Count) security issues detected" -ForegroundColor Red
    foreach ($violation in $violations) {
        Write-Host "   $($violation.Type): $($violation.Matches) matches on lines $($violation.Lines)" -ForegroundColor Red
    }
}

Write-Host "`nCompliance check completed." -ForegroundColor Cyan
