<#
.SYNOPSIS
    Assigns Confluence space access rights by reading a CSV and posting permissions via the Confluence API.
.DESCRIPTION
    Reads a CSV file with the format: SpaceKey;Permission;User/Group;Norlys mail;Name
    For each entry, generates a JSON payload and sends it to the Confluence API to assign permissions.
    Logs all actions and responses to a log file.
#>

# --- CONFIGURATION ---
$logFile   = Join-Path $PSScriptRoot "access_rights_log.txt"

param(
    [string]$fileName,
    [string]$baseURL = "your_confluence_base_url",  # Replace with your Confluence base URL
    [switch]$DryRun,                                # If set, do not perform API calls
    [int]$MaxRetries = 3,                           # Number of retries for transient errors
    [switch]$Parallel                              # If set, process entries in parallel (experimental)
)

if (-not $fileName) {
    $fileName = Read-Host "Enter the path to the CSV file"
}
if (-not $baseURL -or $baseURL -eq "your_confluence_base_url") {
    $baseURL = Read-Host "Enter the Confluence base URL (e.g., https://confluence.example.com)"
}
$uri       = "$($baseURL.TrimEnd('/'))/rpc/json-rpc/confluenceservice-v2?os_authType=basic"
$user      = ""
$pass      = ""

# --- AUTH HEADER ---
$pair = "${user}:${pass}"
$encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    Authorization = "Basic $encodedCredentials"
    Accept        = 'application/json'
}

# --- CSV HEADERS ---
$csvHeaders = @("SpaceKey","Permission","User/Group", "Norlys mail", "Name")

# --- LOG FUNCTION ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp`t$Message"
}

# --- RETRY FUNCTION ---
function Invoke-WithRetry {
    param(
        [scriptblock]$Script,
        [int]$Retries = 3
    )
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        try {
            return & $Script
        } catch {
            if ($attempt -eq $Retries) { throw }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt)) # Exponential backoff
        }
    }
}

# --- PROCESS CSV AND POST TO API ---
$ix = 0
$success = 0
$fail = 0
$skipped = 0

$csv = Import-Csv $fileName -Header $csvHeaders -Delimiter ";" | Select-Object -Skip 1

$processEntry = {
    param($row, $index)
    $spacekey = $row.SpaceKey.Trim()
    $perm     = $row.Permission.Trim()
    $userMail = $row."Norlys mail".Trim()

    $json = @{
        jsonrpc = "2.0"
        method  = "addPermissionToSpace"
        params  = @($perm, $userMail, $spacekey)
        id      = $index
    } | ConvertTo-Json -Compress

    Write-Log "Posting permission: $spacekey | $perm | $userMail"

    if ($using:DryRun) {
        Write-Log "DRY-RUN: Would post for $userMail in $spacekey"
        return @{Result="DryRun"}
    }

    try {
        Invoke-WithRetry -Retries $using:MaxRetries -Script {
            $response = Invoke-WebRequest -Uri $using:uri -Headers $using:headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json" -UseBasicParsing
            Write-Log "Response for $userMail in $spacekey: $($response.StatusCode)"
            return @{Result="Success"}
        }
    } catch {
        Write-Log "ERROR for $userMail in $spacekey: $_"
        return @{Result="Fail"}
    }
}

if ($Parallel) {
    # Experimental: Parallel processing
    $results = $csv | ForEach-Object -Parallel {
        param($row, $ix, $uri, $headers, $DryRun, $MaxRetries, $logFile)
        function Write-Log {
            param([string]$Message)
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $logFile -Value "$timestamp`t$Message"
        }
        function Invoke-WithRetry {
            param(
                [scriptblock]$Script,
                [int]$Retries = 3
            )
            for ($attempt = 1; $attempt -le $Retries; $attempt++) {
                try {
                    return & $Script
                } catch {
                    if ($attempt -eq $Retries) { throw }
                    Start-Sleep -Seconds ([math]::Pow(2, $attempt))
                }
            }
        }
        $spacekey = $row.SpaceKey.Trim()
        $perm     = $row.Permission.Trim()
        $userMail = $row."Norlys mail".Trim()
        $json = @{
            jsonrpc = "2.0"
            method  = "addPermissionToSpace"
            params  = @($perm, $userMail, $spacekey)
            id      = $ix
        } | ConvertTo-Json -Compress
        Write-Log "Posting permission: $spacekey | $perm | $userMail"
        if ($DryRun) {
            Write-Log "DRY-RUN: Would post for $userMail in $spacekey"
            return @{Result="DryRun"}
        }
        try {
            Invoke-WithRetry -Retries $MaxRetries -Script {
                $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json" -UseBasicParsing
                Write-Log "Response for $userMail in $spacekey: $($response.StatusCode)"
                return @{Result="Success"}
            }
        } catch {
            Write-Log "ERROR for $userMail in $spacekey: $_"
            return @{Result="Fail"}
        }
    } -ArgumentList $_, ++$ix, $uri, $headers, $DryRun, $MaxRetries, $logFile
    $success = ($results | Where-Object { $_.Result -eq "Success" }).Count
    $fail    = ($results | Where-Object { $_.Result -eq "Fail" }).Count
    $skipped = ($results | Where-Object { $_.Result -eq "DryRun" }).Count
} else {
    foreach ($row in $csv) {
        $ix++
        $result = & $processEntry $row $ix
        switch ($result.Result) {
            "Success" { $success++ }
            "Fail"    { $fail++ }
            "DryRun"  { $skipped++ }
        }
    }
}

# --- SUMMARY OUTPUT ---
Write-Host "Completed processing $ix entries." -ForegroundColor Cyan
Write-Host "Success: $success" -ForegroundColor Green
Write-Host "Failed: $fail" -ForegroundColor Red
if ($DryRun) {
    Write-Host "Dry-run (not posted): $skipped" -ForegroundColor Yellow
}
Write-Log "Completed processing $ix entries. Success: $success, Failed: $fail, DryRun: $skipped"
# --- END OF SCRIPT ---