<#
.SYNOPSIS
    Transfer files from local machine to a remote server using PowerShell remoting
.DESCRIPTION
    This enhanced script transfers files/folders from the local machine to a remote server 
    with comprehensive error handling, progress tracking, and credential management.
.PARAMETER ComputerName
    Remote computer name or IP address
.PARAMETER SourcePath
    Local source path containing files to transfer
.PARAMETER DestinationPath
    Destination path on the remote server
.PARAMETER Credential
    PSCredential object for remote authentication
.PARAMETER Recurse
    Include subdirectories in the transfer
.PARAMETER WhatIf
    Show what would be transferred without actually copying
.EXAMPLE
    .\TransferFilesToServer.ps1 -ComputerName "SERVER01" -SourcePath "C:\LocalFiles" -DestinationPath "C:\RemoteTemp"
.EXAMPLE
    .\TransferFilesToServer.ps1 -ComputerName "192.168.1.100" -SourcePath "C:\Data" -DestinationPath "D:\Backup" -Recurse
.NOTES
    Requires PowerShell remoting to be enabled on the target server.
    Run 'Enable-PSRemoting -Force' on the target server to enable remoting.
#>

param(
    [Parameter(Mandatory=$false, HelpMessage="Remote computer name or IP address")]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName,

    [Parameter(Mandatory=$false, HelpMessage="Local source path containing files to transfer")]
    [ValidateScript({
        if (-not $_ -or $_ -eq "") { return $true }  # Allow empty to prompt later
        if (-not (Test-Path $_ -PathType Any)) {
            throw "Source path does not exist: $_"
        }
        return $true
    })]
    [string]$SourcePath,

    [Parameter(Mandatory=$false, HelpMessage="Destination path on the remote server")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,

    [Parameter(Mandatory=$false, HelpMessage="Credentials for remote server authentication")]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory=$false, HelpMessage="Include subdirectories in the transfer")]
    [switch]$Recurse,

    [Parameter(Mandatory=$false, HelpMessage="Show what would be transferred without copying")]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false, HelpMessage="Enable verbose output with detailed progress")]
    [switch]$Verbose
)

Write-Host "📁 PowerShell File Transfer Utility v2.0" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$session = $null
$transferStats = @{
    FilesTransferred = 0
    BytesTransferred = 0
    StartTime = Get-Date
    Errors = @()
}

try {
    # Get remote computer name
    if ([string]::IsNullOrEmpty($ComputerName)) {
        Write-Host "`n🌐 Remote Server Configuration" -ForegroundColor Yellow
        do {
            $ComputerName = Read-Host "Enter remote computer name or IP address"
            if ([string]::IsNullOrEmpty($ComputerName)) {
                Write-Host "Computer name cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrEmpty($ComputerName))
    }

    # Get source path
    if ([string]::IsNullOrEmpty($SourcePath)) {
        Write-Host "`n📂 Source Configuration" -ForegroundColor Yellow
        Write-Host "Enter the local source path containing files to transfer:" -ForegroundColor White
        Write-Host "Example: C:\MyFiles or C:\Documents\Project" -ForegroundColor Gray
        
        do {
            $SourcePath = Read-Host "`nLocal source path"
            if ([string]::IsNullOrEmpty($SourcePath)) {
                Write-Host "Source path cannot be empty. Please try again." -ForegroundColor Red
                continue
            }
            if (-not (Test-Path $SourcePath -PathType Any)) {
                Write-Host "❌ Source path does not exist: $SourcePath" -ForegroundColor Red
                Write-Host "Please check the path and try again." -ForegroundColor Yellow
                $SourcePath = $null
            }
        } while ([string]::IsNullOrEmpty($SourcePath))
    }

    # Get destination path
    if ([string]::IsNullOrEmpty($DestinationPath)) {
        Write-Host "`n📁 Destination Configuration" -ForegroundColor Yellow
        Write-Host "Enter the destination path on the remote server:" -ForegroundColor White
        Write-Host "Example: C:\RemoteFiles or D:\Backup\Project" -ForegroundColor Gray
        
        do {
            $DestinationPath = Read-Host "`nRemote destination path"
            if ([string]::IsNullOrEmpty($DestinationPath)) {
                Write-Host "Destination path cannot be empty. Please try again." -ForegroundColor Red
            }
        } while ([string]::IsNullOrEmpty($DestinationPath))
    }

    # Validate and prepare source
    $sourceInfo = Get-Item $SourcePath
    $isDirectory = $sourceInfo -is [System.IO.DirectoryInfo]
    
    if ($isDirectory) {
        $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse:$Recurse -File
        $totalSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
        Write-Host "📊 Source Analysis:" -ForegroundColor Cyan
        Write-Host "  📁 Type: Directory" -ForegroundColor White
        Write-Host "  📄 Files: $($sourceFiles.Count)" -ForegroundColor White
        Write-Host "  💾 Total Size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "  🔄 Recursive: $Recurse" -ForegroundColor White
    } else {
        Write-Host "📊 Source Analysis:" -ForegroundColor Cyan
        Write-Host "  📄 Type: Single File" -ForegroundColor White
        Write-Host "  💾 Size: $([math]::Round($sourceInfo.Length / 1MB, 2)) MB" -ForegroundColor White
        $totalSize = $sourceInfo.Length
    }

    if ($WhatIf) {
        Write-Host "`n🔍 WhatIf Mode - No files will be transferred" -ForegroundColor Yellow
        Write-Host "Would transfer from: $SourcePath" -ForegroundColor Gray
        Write-Host "Would transfer to: $ComputerName`:$DestinationPath" -ForegroundColor Gray
        return
    }

    # Establish remote session
    Write-Host "`n🔗 Establishing Remote Connection" -ForegroundColor Cyan
    Write-Host "Connecting to: $ComputerName..." -ForegroundColor White
    
    $sessionParams = @{
        ComputerName = $ComputerName
        ErrorAction = "Stop"
    }
    
    if ($Credential) {
        $sessionParams.Credential = $Credential
    }
    
    $session = New-PSSession @sessionParams
    Write-Host "✅ Remote session established successfully" -ForegroundColor Green

    # Test remote destination
    $remoteTest = Invoke-Command -Session $session -ScriptBlock {
        param($destPath)
        try {
            $parentPath = Split-Path $destPath -Parent
            if ($parentPath -and (-not (Test-Path $parentPath))) {
                New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
            }
            return @{ Success = $true; Message = "Path accessible" }
        } catch {
            return @{ Success = $false; Message = $_.Exception.Message }
        }
    } -ArgumentList $DestinationPath

    if (-not $remoteTest.Success) {
        throw "Remote destination error: $($remoteTest.Message)"
    }

    # Perform transfer
    Write-Host "`n🚀 Starting File Transfer" -ForegroundColor Green
    Write-Host "From: $SourcePath" -ForegroundColor White
    Write-Host "To: $ComputerName`:$DestinationPath" -ForegroundColor White
    
    $transferParams = @{
        Path = $SourcePath
        Destination = $DestinationPath
        ToSession = $session
        ErrorAction = "Stop"
        Force = $true
    }
    
    if ($isDirectory -and $Recurse) {
        $transferParams.Recurse = $true
    }

    $transferStart = Get-Date
    Copy-Item @transferParams
    $transferEnd = Get-Date
    
    $duration = $transferEnd - $transferStart
    $transferRate = if ($duration.TotalSeconds -gt 0) { 
        [math]::Round($totalSize / $duration.TotalSeconds / 1MB, 2) 
    } else { 0 }

    Write-Host "`n✅ File Transfer Completed Successfully!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "⏱️  Duration: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor White
    Write-Host "📈 Transfer Rate: $transferRate MB/s" -ForegroundColor White
    Write-Host "💾 Total Size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor White

} catch {
    Write-Host "`n❌ Transfer Failed: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -match "WinRM cannot complete the operation") {
        Write-Host "`n💡 Troubleshooting Tips:" -ForegroundColor Yellow
        Write-Host "• Ensure PowerShell remoting is enabled on target: Enable-PSRemoting -Force" -ForegroundColor Gray
        Write-Host "• Check if WinRM service is running on target server" -ForegroundColor Gray
        Write-Host "• Verify firewall allows WinRM traffic (port 5985/5986)" -ForegroundColor Gray
        Write-Host "• Ensure you have administrative privileges on target server" -ForegroundColor Gray
    }
    
    exit 1
} finally {
    if ($session) {
        Remove-PSSession $session -ErrorAction SilentlyContinue
        Write-Host "`n🔌 Remote session closed" -ForegroundColor Yellow
    }
}
