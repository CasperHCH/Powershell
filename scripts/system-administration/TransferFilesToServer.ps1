<#
.SYNOPSIS
    Transfer files from local machine to a remote server
.DESCRIPTION
    This script transfers files from the local machine to a remote server using PowerShell remoting.
.NOTES
    Requires PowerShell remoting to be enabled on the target server.
#>

try {
    $ComputerName = read-host "Enter remote computer name or IP address"
    if (-not $ComputerName) { throw "Computer name is required" }

    Write-Host "Connecting to $ComputerName..." -ForegroundColor Cyan
    $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

    $container = read-host "Enter local source path (e.g., C:\\LocalFiles)"
    if (-not $container) { throw "Source path is required" }
    if (!(Test-Path $container)) { throw "Source path does not exist: $container" }

    $destination = read-host "Enter destination path on remote server (e.g., C:\\RemoteTemp)"
    if (-not $destination) { throw "Destination path is required" }

    Write-Host "Transferring files from $container to $ComputerName:$destination..." -ForegroundColor Cyan
    Copy-Item -path $container -Recurse -Destination $destination -ToSession $session -ErrorAction Stop

    Write-Host "✅ File transfer completed successfully" -ForegroundColor Green

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($session) {
        Remove-PSSession $session
        Write-Host "Session closed" -ForegroundColor Yellow
    }
}
