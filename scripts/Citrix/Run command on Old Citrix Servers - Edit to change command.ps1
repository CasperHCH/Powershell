param(
    [Parameter(Mandatory=$true)]
    [string[]]$ComputerNames,
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [PSCredential]$Credentials
)

if (-not $Credentials) {
    $Credentials = Get-Credential -Message "Enter credentials for Citrix servers"
}

# Example computer array - customize as needed
$computers = @(
    "CITRIX-SRV01",
    "CITRIX-SRV02",
    "CITRIX-SRV03"
)

# Use provided computers or default list
if ($ComputerNames) {
    $computers = $ComputerNames
}

foreach($c in $computers) {
    Write-Host "Executing script on $c..." -ForegroundColor Cyan
    try {
        Invoke-Command -FilePath $ScriptPath -ComputerName $c -Credential $Credentials -ErrorAction Stop
        Write-Host "SUCCESS: $c" -ForegroundColor Green
    } catch {
        Write-Host "FAILED: $c - $($_.Exception.Message)" -ForegroundColor Red
    }
}
