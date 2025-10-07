<#
.SYNOPSIS
    Transfer files from a remote server to local machine
.DESCRIPTION
    This script transfers files from a remote server to the local machine using PowerShell remoting.
.NOTES
    Requires PowerShell remoting to be enabled on the target server.
#>

try {
    $ComputerName = read-host "Enter remote computer name or IP address"
    if (-not $ComputerName) { throw "Computer name is required" }

    Write-Host "Connecting to $ComputerName..." -ForegroundColor Cyan
    $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

    $container = read-host "Enter source path on remote server (e.g., C:\\Temp\\MyFiles)"
    if (-not $container) { throw "Source path is required" }

    $Destination = read-host "Enter local destination path (e.g., C:\\LocalTemp)"
    if (-not $Destination) { throw "Destination path is required" }

    # Ensure destination directory exists
    if (!(Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Host "Transferring files from $ComputerName:$container to $Destination..." -ForegroundColor Cyan
    Copy-Item $container -Recurse -Destination $destination -FromSession $session -ErrorAction Stop

    Write-Host "✅ File transfer completed successfully" -ForegroundColor Green

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($session) {
        Remove-PSSession $session
        Write-Host "Session closed" -ForegroundColor Yellow
    }
}
