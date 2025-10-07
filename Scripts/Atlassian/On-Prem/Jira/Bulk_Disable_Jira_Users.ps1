<#
.SYNOPSIS
    Bulk disables and anonymizes Jira users from a CSV file using the Jira REST API.
.DESCRIPTION
    Reads a CSV file containing user information (username).
    For each user, disables the account and then anonymizes it using Jira's REST API.
    Logs all actions and outputs progress and warnings to the console.
.PARAMETER csvPath
    Path to the CSV file containing user data.
.PARAMETER jiraUrl
    Base URL of the Jira server (e.g., https://your-jira-server).
.PARAMETER username
    Jira admin username.
.PARAMETER apiToken
    Jira admin API token or password.
.NOTES
    The CSV file should have a column: username.
    Requires Jira administrator permissions and REST API access.
#>

# --- Parameters ---
$csvPath  = "C:\Path\To\users.csv"           # Path to the CSV file with user data
$jiraUrl  = "https://your-jira-server"       # Base URL of your Jira server
$username = "jira-admin"                     # Jira admin username
$apiToken = "your-api-token-or-password"     # Jira admin API token or password

# --- Prompt for missing parameters ---
if (-not $csvPath -or -not (Test-Path $csvPath)) {
    do {
        $csvPath = Read-Host "Enter the path to the CSV file"
    } until (Test-Path $csvPath)
}
if (-not $jiraUrl -or $jiraUrl -eq "https://your-jira-server") {
    $jiraUrl = Read-Host "Enter the base URL of your Jira server (e.g., https://your-jira-server)"
}
if (-not $username -or $username -eq "jira-admin") {
    $username = Read-Host "Enter your Jira admin username"
}
if (-not $apiToken -or $apiToken -eq "your-api-token-or-password") {
    $apiToken = Read-Host "Enter your Jira admin API token or password"
}

# --- Log File Setup ---
$logFile = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath "Bulk_Disable_Jira_Users.log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
}

# --- Read CSV ---
$users = Import-Csv $csvPath

if (-not $users) {
    Write-Error "No users found in CSV file."
    Write-Log "No users found in CSV file." "ERROR"
    return
}

# --- Prepare authentication header (Basic Auth) ---
$pair = "$username:$apiToken"
$encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $encodedCreds"
    Accept        = "application/json"
    "Content-Type"= "application/json"
}

foreach ($user in $users) {
    # Step 1: Validate required fields (username must be present)
    if ([string]::IsNullOrWhiteSpace($user.username)) {
        $msg = "Skipping row with missing username: $($user | ConvertTo-Json -Compress)"
        Write-Warning $msg
        Write-Log $msg "WARNING"
        continue
    }

    # Step 2: Prepare request body to disable the user (set 'active' to $false)
    $disableBody = @{
        name   = $user.username
        active = $false
    } | ConvertTo-Json

    # Step 3: Attempt to disable the user via Jira REST API
    try {
        Invoke-RestMethod -Uri "$jiraUrl/rest/api/2/user" -Method Put -Headers $headers -Body $disableBody
        $msg = "Disabled user: $($user.username)"
        Write-Host $msg -ForegroundColor Yellow
        Write-Log $msg "INFO"
    } catch {
        $msg = "Failed to disable user: $($user.username) - $($_.Exception.Message)"
        Write-Warning $msg
        Write-Log $msg "ERROR"
        continue
    }

    # Step 4: Wait for any previous anonymization task to complete before starting a new one
    $progressUri = "$jiraUrl/rest/api/2/user/anonymization/progress"
    $maxWaitSeconds = 600
    $waitIntervalSeconds = 5
    $elapsed = 0

    while ($true) {
        try {
            $progress = Invoke-RestMethod -Uri $progressUri -Method Get -Headers $headers
            if (-not $progress.inProgress) {
                break
            }
            Write-Host "Waiting for previous anonymization task to complete..." -ForegroundColor Cyan
            Start-Sleep -Seconds $waitIntervalSeconds
            $elapsed += $waitIntervalSeconds
            if ($elapsed -ge $maxWaitSeconds) {
                Write-Warning "Timeout waiting for previous anonymization task. Skipping user: $($user.username)"
                Write-Log "Timeout waiting for previous anonymization task. Skipping user: $($user.username)" "WARNING"
                continue 2
            }
        } catch {
            Write-Warning "Failed to check anonymization progress: $($_.Exception.Message)"
            Write-Log "Failed to check anonymization progress: $($_.Exception.Message)" "WARNING"
            Start-Sleep -Seconds $waitIntervalSeconds
            $elapsed += $waitIntervalSeconds
            if ($elapsed -ge $maxWaitSeconds) {
                Write-Warning "Timeout waiting for anonymization progress API. Skipping user: $($user.username)"
                Write-Log "Timeout waiting for anonymization progress API. Skipping user: $($user.username)" "WARNING"
                continue 2
            }
        }
    }

    # Step 5: Prepare request body to anonymize the user (using userKey = username)
    $anonymizeBody = @{
        userKey = $user.username
    } | ConvertTo-Json

    # Step 6: Attempt to anonymize the user via Jira REST API
    try {
        Invoke-RestMethod -Uri "$jiraUrl/rest/api/2/user/anonymization" -Method Post -Headers $headers -Body $anonymizeBody
        $msg = "Anonymized user: $($user.username)"
        Write-Host $msg -ForegroundColor Green
        Write-Log $msg "INFO"
    } catch {
        $msg = "Failed to anonymize user: $($user.username) - $($_.Exception.Message)"
        Write-Warning $msg
        Write-Log $msg "ERROR"
    }
}