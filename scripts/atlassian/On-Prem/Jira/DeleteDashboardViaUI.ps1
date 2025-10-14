# This script simulates the UI-based deletion of Jira dashboards by sending a POST request to the DeleteSharedDashboard endpoint.

param(
    [Parameter(Mandatory=$true, HelpMessage="Base URL of the Jira instance (e.g., https://jira-ks.norlys.dk)")]
    [string]$JiraBaseUrl,

    [Parameter(Mandatory=$true, HelpMessage="Jira username")]
    [string]$Username,

    [Parameter(Mandatory=$true, HelpMessage="Jira password")]
    [string]$Password
)

# Function to log in to Jira and retrieve the atl_token
function Get-AtlToken {
    param(
        [string]$BaseUrl,
        [string]$User,
        [string]$Pass
    )

    $loginUrl = "$BaseUrl/login.jsp"
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    # Perform login
    try {
        $response = Invoke-WebRequest -Uri $loginUrl -Method POST -WebSession $session -UseBasicParsing -Body @{
            os_username = $User
            os_password = $Pass
            login = "Log In"
        }

        # Extract atl_token from the response HTML
        $atlToken = ($response.Content -match '<meta id="atlassian-token" name="atlassian-token" content="(.*?)"') | Out-Null
        $atlToken = $matches[1]

        if (-not $atlToken) {
            Write-Host "❌ Failed to retrieve atl_token. Debugging login response..." -ForegroundColor Yellow
            Write-Host "🔍 Login Response: $($response.Content)" -ForegroundColor Cyan
            throw "Failed to retrieve atl_token. Ensure credentials are correct."
        }

        return $atlToken, $session
    } catch {
        Write-Host "❌ Error during login: $_" -ForegroundColor Red
        throw
    }
}

# Function to fetch all dashboard IDs
function Get-DashboardIds {
    param(
        [string]$BaseUrl,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $dashboardsUrl = "$BaseUrl/rest/api/2/dashboard"

    try {
        $response = Invoke-WebRequest -Uri $dashboardsUrl -Method GET -WebSession $Session -UseBasicParsing -ErrorAction Stop
        $dashboards = ($response.Content | ConvertFrom-Json).dashboards
        return $dashboards | ForEach-Object { $_.id }
    } catch {
        throw "Failed to fetch dashboard IDs: $_"
    }
}

# Function to fetch all inactive users
function Get-InactiveUsers {
    param(
        [string]$BaseUrl,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $usersUrl = "$BaseUrl/rest/api/2/user/search?username=*&includeInactive=true"

    try {
        # Replace Invoke-WebRequest with Invoke-RestMethod for the inactive users API call
        $responseInactiveUsers = Invoke-RestMethod -Uri "$JiraBaseUrl/rest/api/2/user/search?username=*&includeInactive=true" -Method GET -WebSession $session -ErrorAction Stop

        # Log the full response object for debugging
        Write-Host "[DEBUG] Full Response Object: $($responseInactiveUsers | Out-String)" -ForegroundColor Yellow

        $users = $responseInactiveUsers
        return $users | Where-Object { $_.active -eq $false } | ForEach-Object { $_.key }
    } catch {
        Write-Host "❌ Failed to fetch inactive users. Debugging response..." -ForegroundColor Yellow
        Write-Host "🔍 Response Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Cyan
        Write-Host "🔍 Response Content: $($_.Exception.Response.GetResponseStream() | %{ [System.IO.StreamReader]::new($_).ReadToEnd() })" -ForegroundColor Cyan
        throw "Failed to fetch inactive users: $_"
    }
}

# Function to fetch all dashboards with their owners
function Get-DashboardsWithOwners {
    param(
        [string]$BaseUrl,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $dashboardsUrl = "$BaseUrl/rest/api/2/dashboard"

    try {
        $response = Invoke-WebRequest -Uri $dashboardsUrl -Method GET -WebSession $Session -UseBasicParsing -ErrorAction Stop
        $dashboards = ($response.Content | ConvertFrom-Json).dashboards
        return $dashboards | ForEach-Object {
            [PSCustomObject]@{
                Id = $_.id
                Owner = $_.owner.name
            }
        }
    } catch {
        throw "Failed to fetch dashboards: $_"
    }
}

# Main script logic
try {
    # Retrieve atl_token and session
    $atlToken, $session = Get-AtlToken -BaseUrl $JiraBaseUrl -User $Username -Pass $Password

    # Additional Debugging: Log atlToken and session
    Write-Host "[DEBUG] atlToken: $atlToken" -ForegroundColor Yellow
    Write-Host "[DEBUG] Session: $session" -ForegroundColor Yellow

    # Fetch inactive users
    $inactiveUsers = Get-InactiveUsers -BaseUrl $JiraBaseUrl -Session $session
    Write-Host "🔍 Inactive Users: $($inactiveUsers -join ', ')" -ForegroundColor Cyan

    # Corrected Debugging: Log full request details for inactive users API call
    $responseInactiveUsers = Invoke-WebRequest -Uri "$JiraBaseUrl/rest/api/2/user/search?username=*&includeInactive=true" -Method GET -WebSession $session -UseBasicParsing -ErrorAction Stop
    Write-Host "[DEBUG] Inactive Users API Request URI: $($responseInactiveUsers.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)" -ForegroundColor Yellow
    Write-Host "[DEBUG] Inactive Users API Request Method: $($responseInactiveUsers.BaseResponse.RequestMessage.Method.Method)" -ForegroundColor Yellow

    # Fallback Debugging: Log raw request and response objects as strings
    $responseInactiveUsers = Invoke-WebRequest -Uri "$JiraBaseUrl/rest/api/2/user/search?username=*&includeInactive=true" -Method GET -WebSession $session -UseBasicParsing -ErrorAction Stop
    Write-Host "[DEBUG] Raw Request Object (String): $($responseInactiveUsers.BaseResponse.RequestMessage.ToString())" -ForegroundColor Yellow
    Write-Host "[DEBUG] Raw Response Object (String): $($responseInactiveUsers.ToString())" -ForegroundColor Yellow

    # Enhanced Debugging: Add null checks and log full response object
    $responseInactiveUsers = Invoke-WebRequest -Uri "$JiraBaseUrl/rest/api/2/user/search?username=*&includeInactive=true" -Method GET -WebSession $session -UseBasicParsing -ErrorAction Stop

    if ($responseInactiveUsers.BaseResponse -and $responseInactiveUsers.BaseResponse.RequestMessage) {
        Write-Host "[DEBUG] Inactive Users API Request URI: $($responseInactiveUsers.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)" -ForegroundColor Yellow
        Write-Host "[DEBUG] Inactive Users API Request Method: $($responseInactiveUsers.BaseResponse.RequestMessage.Method.Method)" -ForegroundColor Yellow
    } else {
        Write-Host "[WARNING] RequestMessage is null. Skipping request details logging." -ForegroundColor Yellow
    }

    # Log the raw response object for debugging
    Write-Host "[DEBUG] Raw Response Object: $($responseInactiveUsers | Out-String)" -ForegroundColor Yellow

    # Fallback Handling: Skip logging if RequestMessage is null
    if ($responseInactiveUsers.BaseResponse -and $responseInactiveUsers.BaseResponse.RequestMessage) {
        Write-Host "[DEBUG] Inactive Users API Request URI: $($responseInactiveUsers.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)" -ForegroundColor Yellow
        Write-Host "[DEBUG] Inactive Users API Request Method: $($responseInactiveUsers.BaseResponse.RequestMessage.Method.Method)" -ForegroundColor Yellow
    } else {
        Write-Host "[WARNING] RequestMessage is null. Skipping request details logging." -ForegroundColor Yellow
    }

    # Fallback Handling: Check if inactive users are empty
    if (-not $inactiveUsers -or $inactiveUsers.Count -eq 0) {
        Write-Host "[WARNING] No inactive users found. Skipping dashboard deletion." -ForegroundColor Yellow
        return
    }

    # Validate `-join` usage
    if ($inactiveUsers -is [System.Array]) {
        Write-Host "[DEBUG] Inactive Users is an array. Proceeding with -join." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Inactive Users is not an array. Cannot use -join." -ForegroundColor Red
        throw "Invalid data type for -join operator."
    }

    # Fetch dashboards with their owners
    $dashboards = Get-DashboardsWithOwners -BaseUrl $JiraBaseUrl -Session $session
    Write-Host "🔍 Dashboards Retrieved: $($dashboards | ForEach-Object { "Id: $($_.Id), Owner: $($_.Owner)" } -join '; ')" -ForegroundColor Cyan

    # Additional Debugging: Log response content for dashboards
    $responseDashboards = Invoke-WebRequest -Uri "$JiraBaseUrl/rest/api/2/dashboard" -Method GET -WebSession $session -UseBasicParsing -ErrorAction Stop
    Write-Host "[DEBUG] Dashboards Response Content: $($responseDashboards.Content)" -ForegroundColor Yellow

    # Debugging: Log types of variables
    Write-Host "[DEBUG] Type of inactiveUsers: $($inactiveUsers.GetType().Name)" -ForegroundColor Yellow
    Write-Host "[DEBUG] Type of dashboards: $($dashboards.GetType().Name)" -ForegroundColor Yellow

    # Debugging: Log content of variables
    Write-Host "[DEBUG] Content of inactiveUsers: $inactiveUsers" -ForegroundColor Yellow
    Write-Host "[DEBUG] Content of dashboards: $dashboards" -ForegroundColor Yellow

    # Filter dashboards owned by inactive users
    $dashboardsToDelete = $dashboards | Where-Object { $inactiveUsers -contains $_.Owner }
    Write-Host "🔍 Dashboards to Delete: $($dashboardsToDelete | ForEach-Object { "Id: $($_.Id), Owner: $($_.Owner)" } -join '; ')" -ForegroundColor Cyan

    # Additional Debugging: Log filtered dashboards before deletion
    Write-Host "[DEBUG] Filtered Dashboards to Delete: $($dashboardsToDelete | ForEach-Object { "Id: $($_.Id), Owner: $($_.Owner)" })" -ForegroundColor Yellow

    # Debugging: Log type and content of dashboardsToDelete after filtering
    Write-Host "[DEBUG] Type of dashboardsToDelete: $($dashboardsToDelete.GetType().Name)" -ForegroundColor Yellow
    Write-Host "[DEBUG] Content of dashboardsToDelete: $dashboardsToDelete" -ForegroundColor Yellow

    foreach ($dashboard in $dashboardsToDelete) {
        # Construct the deletion URL
        $deleteUrl = "$JiraBaseUrl/secure/admin/dashboards/DeleteSharedDashboard!default.jspa"

        # Send the POST request to delete the dashboard
        try {
            $response = Invoke-WebRequest -Uri $deleteUrl -Method POST -WebSession $session -Body @{
                dashboardId = $dashboard.Id
                atl_token = $atlToken
            }

            Write-Host "✅ Dashboard [$($dashboard.Id)] deleted successfully." -ForegroundColor Green
        } catch {
            Write-Host "❌ Error deleting dashboard [$($dashboard.Id)]: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Script failed: $_" -ForegroundColor Red
}