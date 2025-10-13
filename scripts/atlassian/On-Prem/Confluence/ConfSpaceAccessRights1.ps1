<#
.SYNOPSIS
    Securely assigns Confluence space access rights by reading CSV data and using the Confluence API

.DESCRIPTION
    This script reads a CSV file with space access assignments and applies them to Confluence
    using secure authentication and comprehensive audit logging. Supports dry-run mode,
    retry logic, and proper error handling.

    CSV Format: SpaceKey;Permission;User/Group;E-mail;Name

.PARAMETER fileName
    Path to the CSV file containing access assignments

.PARAMETER baseURL
    Confluence base URL (must use HTTPS)

.PARAMETER Credential
    PSCredential object for Confluence authentication

.PARAMETER StoredCredentialTarget
    Target name for retrieving stored credentials from Windows Credential Manager

.PARAMETER DryRun
    If specified, performs validation but does not execute API calls

.PARAMETER MaxRetries
    Number of retry attempts for transient failures (1-10, default: 3)

.PARAMETER Parallel
    Enable parallel processing for large datasets (experimental)

.EXAMPLE
    .\ConfSpaceAccessRights1.ps1 -fileName "access.csv" -baseURL "https://confluence.example.com" -DryRun

.EXAMPLE
    .\ConfSpaceAccessRights1.ps1 -fileName "access.csv" -StoredCredentialTarget "ConfluenceService" -baseURL "https://confluence.example.com"

.NOTES
    Author: IT Security Team
    Version: 2.0 (Security Enhanced)
    Security Classification: Confidential
    Requires: PowerShell 5.1+, Network connectivity to Confluence

    SECURITY FEATURES:
    - Secure credential management
    - HTTPS-only connections
    - Comprehensive audit logging
    - Input validation and sanitization
    - Retry logic with exponential backoff
#>

# --- SECURE CONFIGURATION ---
$logFile = Join-Path $PSScriptRoot "access_rights_log.txt"

param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to CSV file containing space access assignments")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$fileName,

    [Parameter(Mandatory = $false, HelpMessage = "Confluence base URL (e.g., https://confluence.example.com)")]
    [ValidateScript({ $_ -match '^https://' })]
    [string]$baseURL,

    [Parameter(Mandatory = $false, HelpMessage = "Confluence service account credentials")]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "Use stored credentials from credential manager")]
    [string]$StoredCredentialTarget,

    [Parameter(Mandatory = $false, HelpMessage = "Dry run mode - no actual API calls")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Number of retries for transient errors")]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false, HelpMessage = "Process entries in parallel (experimental)")]
    [switch]$Parallel
)

# --- SECURITY INITIALIZATION ---
$script:securityAudit = @{
    ScriptStart  = Get-Date -Format "o"
    User         = $env:USERNAME
    ComputerName = $env:COMPUTERNAME
    ScriptName   = $MyInvocation.MyCommand.Name
    Parameters   = $PSBoundParameters.Keys -join ", "
    ProcessId    = $PID
}

# Initialize logging
Write-Host "🔒 Confluence Space Access Rights Management - Security Enhanced v2.0" -ForegroundColor Cyan
Write-Host "Security Audit ID: $($script:securityAudit.ScriptStart)" -ForegroundColor Yellow

if (-not $fileName) {
    $fileName = Read-Host "Enter the path to the CSV file"
}
# --- SECURE INPUT VALIDATION ---
if (-not $fileName) {
    do {
        $fileName = Read-Host "Enter the path to the CSV file"
    } while (-not (Test-Path $fileName -PathType Leaf))
}

if (-not $baseURL) {
    do {
        $baseURL = Read-Host "Enter the Confluence base URL (e.g., https://confluence.example.com)"
    } while (-not ($baseURL -match '^https://'))
}

# --- SECURE CREDENTIAL MANAGEMENT ---
$confluenceCredentials = $null

if ($StoredCredentialTarget) {
    # Try to retrieve stored credentials
    try {
        $confluenceCredentials = Get-StoredCredential -Target $StoredCredentialTarget -ErrorAction Stop
        Write-Log "Using stored credentials for target: $StoredCredentialTarget"
    }
    catch {
        Write-Warning "Failed to retrieve stored credentials: $($_.Exception.Message)"
    }
}

if (-not $confluenceCredentials -and $Credential) {
    $confluenceCredentials = $Credential
    Write-Log "Using provided PSCredential object"
}

if (-not $confluenceCredentials) {
    Write-Host "Confluence authentication required" -ForegroundColor Yellow
    $confluenceCredentials = Get-Credential -Message "Enter Confluence service account credentials" -UserName "confluence-service"
    if (-not $confluenceCredentials) {
        Write-Error "Authentication is required to proceed"
        exit 1
    }
}

# --- SECURE CONNECTION SETUP ---
$uri = "$($baseURL.TrimEnd('/'))/rpc/json-rpc/confluenceservice-v2?os_authType=basic"

# Create secure authorization header
$encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($confluenceCredentials.UserName):$($confluenceCredentials.GetNetworkCredential().Password)"))
$headers = @{
    Authorization  = "Basic $encodedCredentials"
    Accept         = 'application/json'
    'Content-Type' = 'application/json'
    'User-Agent'   = 'PowerShell-ConfluenceAccessRights/2.0'
}

# --- CSV HEADERS ---
$csvHeaders = @("SpaceKey", "Permission", "User/Group", "Norlys mail", "Name")

# --- AUDIT LOGGING FUNCTION ---
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Security")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{}
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = @{
        Timestamp    = $timestamp
        Level        = $Level
        Message      = $Message
        User         = $env:USERNAME
        ComputerName = $env:COMPUTERNAME
        ScriptName   = $MyInvocation.ScriptName
        Properties   = $Properties
    }

    $logLine = "$timestamp`t[$Level]`t$Message"
    Add-Content -Path $logFile -Value $logLine

    # Also output to console with appropriate coloring
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Security" { "Magenta" }
        default { "White" }
    }
    Write-Host $logLine -ForegroundColor $color
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
        }
        catch {
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
    $perm = $row.Permission.Trim()
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
        return @{Result = "DryRun" }
    }

    try {
        Invoke-WithRetry -Retries $using:MaxRetries -Script {
            $response = Invoke-WebRequest -Uri $using:uri -Headers $using:headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json" -UseBasicParsing
            Write-Log "Response for $userMail in $($spacekey): $($response.StatusCode)"
            return @{Result = "Success" }
        }
    }
    catch {
        Write-Log "ERROR for $userMail in $($spacekey): $_"
        return @{Result = "Fail" }
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
                }
                catch {
                    if ($attempt -eq $Retries) { throw }
                    Start-Sleep -Seconds ([math]::Pow(2, $attempt))
                }
            }
        }
        $spacekey = $row.SpaceKey.Trim()
        $perm = $row.Permission.Trim()
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
            return @{Result = "DryRun" }
        }
        try {
            Invoke-WithRetry -Retries $MaxRetries -Script {
                $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json" -UseBasicParsing
                Write-Log "Response for $userMail in $($spacekey): $($response.StatusCode)"
                return @{Result = "Success" }
            }
        }
        catch {
            Write-Log "ERROR for $userMail in $($spacekey): $_"
            return @{Result = "Fail" }
        }
    } -ArgumentList $_, ++$ix, $uri, $headers, $DryRun, $MaxRetries, $logFile
    $success = ($results | Where-Object { $_.Result -eq "Success" }).Count
    $fail = ($results | Where-Object { $_.Result -eq "Fail" }).Count
    $skipped = ($results | Where-Object { $_.Result -eq "DryRun" }).Count
}
else {
    foreach ($row in $csv) {
        $ix++
        $result = & $processEntry $row $ix
        switch ($result.Result) {
            "Success" { $success++ }
            "Fail" { $fail++ }
            "DryRun" { $skipped++ }
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