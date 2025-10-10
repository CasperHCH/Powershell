# Quick script to analyze all email domains in JIRA
param(
    [string]$JiraBaseUrl = "https://jira-ks.norlys.dk",
    [string]$PersonalAccessToken = "MDE0MjQ0MTI5MDY4Ot0gdXFHBkZqfZJD4UeNbhdc18J4"
)

# Setup authentication
$apiHeaders = @{
    'Authorization' = "Bearer $PersonalAccessToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

Write-Host "=== Analyzing Email Domains in JIRA ===" -ForegroundColor Cyan
Write-Host ""

# Get all users using the same method as the main script
try {
    $searchUri = "$JiraBaseUrl/rest/api/2/user/search?username=.&query=@&maxResults=1000"
    Write-Host "Fetching all users from: $searchUri" -ForegroundColor Yellow

    $response = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $apiHeaders -UseBasicParsing

    if ($response -and $response.Count -gt 0) {
        Write-Host "Found $($response.Count) total users" -ForegroundColor Green
        Write-Host ""

        # Analyze email domains
        $emailDomains = @{}
        $usersWithEmails = 0
        $teliaUsers = @()

        foreach ($user in $response) {
            if ($user.emailAddress) {
                $usersWithEmails++
                $email = $user.emailAddress.ToLower()

                # Extract domain
                if ($email -match "@(.+)$") {
                    $domain = $matches[1]
                    if ($emailDomains.ContainsKey($domain)) {
                        $emailDomains[$domain]++
                    } else {
                        $emailDomains[$domain] = 1
                    }

                    # Check for Telia-related domains
                    if ($domain -like "*telia*") {
                        $teliaUsers += [PSCustomObject]@{
                            Username = $user.name
                            DisplayName = $user.displayName
                            Email = $user.emailAddress
                            Domain = $domain
                            Active = $user.active
                        }
                    }
                }
            }
        }

        Write-Host "Users with email addresses: $usersWithEmails out of $($response.Count)" -ForegroundColor Green
        Write-Host ""

        Write-Host "=== TOP EMAIL DOMAINS ===" -ForegroundColor Yellow
        $sortedDomains = $emailDomains.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
        foreach ($domain in $sortedDomains) {
            Write-Host "  $($domain.Name): $($domain.Value) users" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "=== TELIA-RELATED USERS ===" -ForegroundColor Yellow
        if ($teliaUsers.Count -gt 0) {
            foreach ($user in $teliaUsers) {
                $status = if ($user.Active) { "ACTIVE" } else { "INACTIVE" }
                Write-Host "  [$status] $($user.Username) - $($user.DisplayName)" -ForegroundColor $(if ($user.Active) { "Red" } else { "Gray" })
                Write-Host "    Email: $($user.Email)" -ForegroundColor White
                Write-Host "    Domain: $($user.Domain)" -ForegroundColor Cyan
                Write-Host ""
            }
        } else {
            Write-Host "  No Telia-related users found" -ForegroundColor Gray
        }

        # Check specifically for teliacompany.com
        Write-Host "=== TELIACOMPANY.COM ANALYSIS ===" -ForegroundColor Yellow
        $teliacompanyUsers = $response | Where-Object { $_.emailAddress -and $_.emailAddress.ToLower().EndsWith("@teliacompany.com") }
        if ($teliacompanyUsers) {
            Write-Host "Found $($teliacompanyUsers.Count) users with @teliacompany.com domain:" -ForegroundColor Green
            foreach ($user in $teliacompanyUsers) {
                $status = if ($user.active) { "ACTIVE" } else { "INACTIVE" }
                Write-Host "  [$status] $($user.name) - $($user.displayName) - $($user.emailAddress)" -ForegroundColor $(if ($user.active) { "Red" } else { "Gray" })
            }
        } else {
            Write-Host "No users found with @teliacompany.com domain" -ForegroundColor Red
        }

    } else {
        Write-Host "No users returned from search" -ForegroundColor Red
    }

} catch {
    Write-Host "Error analyzing domains: $($_.Exception.Message)" -ForegroundColor Red
}