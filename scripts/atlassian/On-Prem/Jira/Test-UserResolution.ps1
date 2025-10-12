# Test script for JIRA user resolution functionality
# This tests the fix for anonymization failures caused by invalid newOwnerKey

param(
    [string]$JiraBaseUrl = "https://jira-ks.norlys.dk",
    [string]$PersonalAccessToken,
    [string]$TestEmail = "joharg@norlys.dk",
    [string]$TestUsername = "admin"
)

# Import the user resolution function (or you can copy it here for testing)
# For now, let's create a simplified test version

function Test-UserResolution {
    param(
        [string]$UserIdentifier,
        [hashtable]$Headers,
        [string]$BaseUrl
    )

    Write-Host "Testing user resolution for: $UserIdentifier" -ForegroundColor Yellow

    try {
        # If it looks like an email address
        if ($UserIdentifier -match "^[^@]+@[^@]+\.[^@]+$") {
            Write-Host "Detected email address format" -ForegroundColor Cyan

            # Try user picker API
            $searchUri = "$BaseUrl/rest/api/2/user/picker?query=$([System.Web.HttpUtility]::UrlEncode($UserIdentifier))"
            Write-Host "Searching: $searchUri" -ForegroundColor Gray

            $searchResult = Invoke-RestMethod -Uri $searchUri -Method Get -Headers $Headers -UseBasicParsing

            if ($searchResult.users -and $searchResult.users.Count -gt 0) {
                Write-Host "Found $($searchResult.users.Count) users in search results:" -ForegroundColor Green

                foreach ($user in $searchResult.users) {
                    Write-Host "  - Name: $($user.name), Email: $($user.email), Display: $($user.displayName)" -ForegroundColor White
                }

                $matchedUser = $searchResult.users | Where-Object { $_.email -eq $UserIdentifier } | Select-Object -First 1

                if ($matchedUser) {
                    Write-Host "✅ EXACT EMAIL MATCH FOUND:" -ForegroundColor Green
                    Write-Host "  Username: $($matchedUser.name)" -ForegroundColor White
                    Write-Host "  Display Name: $($matchedUser.displayName)" -ForegroundColor White
                    Write-Host "  Email: $($matchedUser.email)" -ForegroundColor White
                    return $matchedUser.name
                } else {
                    Write-Host "❌ No exact email match found" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ No users found in search" -ForegroundColor Red
            }
        } else {
            Write-Host "Detected username format" -ForegroundColor Cyan

            # Try direct lookup
            $directUri = "$BaseUrl/rest/api/2/user?username=$([System.Web.HttpUtility]::UrlEncode($UserIdentifier))"
            Write-Host "Direct lookup: $directUri" -ForegroundColor Gray

            $directResult = Invoke-RestMethod -Uri $directUri -Method Get -Headers $Headers -UseBasicParsing

            Write-Host "✅ USERNAME VERIFIED:" -ForegroundColor Green
            Write-Host "  Username: $($directResult.name)" -ForegroundColor White
            Write-Host "  Display Name: $($directResult.displayName)" -ForegroundColor White
            Write-Host "  Email: $($directResult.emailAddress)" -ForegroundColor White
            return $directResult.name
        }

    } catch {
        Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main test execution
if (-not $PersonalAccessToken) {
    Write-Host "Please provide -PersonalAccessToken parameter" -ForegroundColor Red
    exit 1
}

# Setup headers
$headers = @{
    "Authorization" = "Bearer $PersonalAccessToken"
    "Content-Type" = "application/json"
}

Write-Host "`n=== JIRA User Resolution Test ===" -ForegroundColor Magenta
Write-Host "JIRA URL: $JiraBaseUrl" -ForegroundColor Gray
Write-Host "Testing email resolution and username verification`n" -ForegroundColor Gray

# Test email resolution
Write-Host "Test 1: Email Resolution" -ForegroundColor Yellow
$resolvedUsername = Test-UserResolution -UserIdentifier $TestEmail -Headers $headers -BaseUrl $JiraBaseUrl

if ($resolvedUsername) {
    Write-Host "SUCCESS: Email $TestEmail resolved to username: $resolvedUsername`n" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not resolve email $TestEmail`n" -ForegroundColor Red
}

# Test username verification
Write-Host "Test 2: Username Verification" -ForegroundColor Yellow
$verifiedUsername = Test-UserResolution -UserIdentifier $TestUsername -Headers $headers -BaseUrl $JiraBaseUrl

if ($verifiedUsername) {
    Write-Host "SUCCESS: Username $TestUsername verified`n" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not verify username $TestUsername`n" -ForegroundColor Red
}

Write-Host "=== Test Complete ===" -ForegroundColor Magenta