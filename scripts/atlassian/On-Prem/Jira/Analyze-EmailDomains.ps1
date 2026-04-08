<#
.SYNOPSIS
    Secure JIRA email domain analysis with enterprise authentication

.DESCRIPTION
    Enterprise-grade script to analyze email domains across JIRA users with secure authentication.
    All credentials are parameterized and support secure credential management.

.PARAMETER JiraBaseUrl
    Base URL of the JIRA instance (e.g., "https://jira.contoso.com")

.PARAMETER PersonalAccessToken
    JIRA Personal Access Token (secure string recommended)

.PARAMETER UseStoredCredentials
    Use stored encrypted credentials instead of token

.PARAMETER CredentialPath
    Path to stored credential file

.PARAMETER SearchDomain
    Optional wildcard domain pattern to highlight in results (e.g., "*contoso.com" or "*telia*")

.EXAMPLE
    .\Analyze-EmailDomains.ps1 -JiraBaseUrl "https://jira.contoso.com" -UseStoredCredentials

.NOTES
    SECURITY CLASSIFICATION: CONFIDENTIAL
    DATA HANDLING: JIRA user email analysis operations
    AUDIT REQUIREMENTS: All API operations logged
    CREDENTIALS REQUIRED: JIRA administrative access
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="JIRA base URL (e.g., https://jira.contoso.com)")]
    [ValidatePattern('^https://.*')]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory=$false, HelpMessage="JIRA Personal Access Token")]
    [ValidateNotNullOrEmpty()]
    [string]$PersonalAccessToken,

    [Parameter(Mandatory=$false, HelpMessage="Use stored encrypted credentials")]
    [switch]$UseStoredCredentials,

    [Parameter(Mandatory=$false, HelpMessage="Path to stored credential file")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CredentialPath,

    [Parameter(Mandatory=$false, HelpMessage="Optional wildcard domain pattern to highlight (e.g., *contoso.com or *telia*)")]
    [ValidateNotNullOrEmpty()]
    [string]$SearchDomain
)

# 🔐 Secure credential management
if ($UseStoredCredentials) {
    $credPath = if ($CredentialPath) { $CredentialPath } else { "$env:USERPROFILE\.credentials\jira.xml" }

    if (Test-Path $credPath) {
        Write-Host "🔑 Loading stored credentials from $credPath" -ForegroundColor Yellow
        $credential = Import-Clixml -Path $credPath
        $PersonalAccessToken = $credential.GetNetworkCredential().Password
    } else {
        Write-Host "⚠️ No stored credentials found, prompting for token" -ForegroundColor Yellow
        $PersonalAccessToken = Read-Host "Enter JIRA Personal Access Token" -AsSecureString
        $PersonalAccessToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PersonalAccessToken))
    }
} elseif (-not $PersonalAccessToken) {
    Write-Host "🔑 No token provided, prompting for authentication" -ForegroundColor Yellow
    $PersonalAccessToken = Read-Host "Enter JIRA Personal Access Token" -AsSecureString
    $PersonalAccessToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PersonalAccessToken))
}

# Setup authentication headers
$apiHeaders = @{
    'Authorization' = "Bearer $PersonalAccessToken"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

Write-Host "🔒 Starting JIRA email domain analysis" -ForegroundColor Cyan
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
        $listOfUsers = @()

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

                    if ($SearchDomain -and ($domain -like $SearchDomain)) {
                        $listOfUsers += [PSCustomObject]@{
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

        if ($SearchDomain) {
            Write-Host ""
            Write-Host "=== MATCHING USERS: $SearchDomain ===" -ForegroundColor Yellow
            if ($listOfUsers.Count -gt 0) {
                foreach ($user in $listOfUsers) {
                    $status = if ($user.Active) { "ACTIVE" } else { "INACTIVE" }
                    Write-Host "  [$status] $($user.Username) - $($user.DisplayName)" -ForegroundColor $(if ($user.Active) { "Red" } else { "Gray" })
                    Write-Host "    Email: $($user.Email)" -ForegroundColor White
                    Write-Host "    Domain: $($user.Domain)" -ForegroundColor Cyan
                    Write-Host ""
                }
            } else {
                Write-Host "  No users found matching domain pattern '$SearchDomain'" -ForegroundColor Gray
            }
        }

        # Domain-specific analysis (parameterize target domain)
        $targetDomain = Read-Host "Enter specific domain to analyze (e.g., contoso.com) or press Enter to skip"
        if ($targetDomain) {
            Write-Host "=== DOMAIN ANALYSIS: $($targetDomain.ToUpper()) ===" -ForegroundColor Yellow
            $domainUsers = $response | Where-Object { $_.emailAddress -and $_.emailAddress.ToLower().EndsWith("@$($targetDomain.ToLower())") }
            if ($domainUsers) {
                Write-Host "Found $($domainUsers.Count) users with @$targetDomain domain:" -ForegroundColor Green
                foreach ($user in $domainUsers) {
                    $status = if ($user.active) { "ACTIVE" } else { "INACTIVE" }
                    Write-Host "  [$status] $($user.name) - $($user.displayName) - $($user.emailAddress)" -ForegroundColor $(if ($user.active) { "Green" } else { "Gray" })
                }
            } else {
                Write-Host "No users found with @$targetDomain domain" -ForegroundColor Yellow
            }
        }

    } else {
        Write-Host "No users returned from search" -ForegroundColor Red
    }

} catch {
    Write-Host "Error analyzing domains: $($_.Exception.Message)" -ForegroundColor Red
}