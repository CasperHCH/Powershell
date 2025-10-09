#requires -version 2
<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  Find the process which is blocking a file
.PARAMETER $FileOrFolderPath
    Insert the full path of the  file
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         CHC
  Creation Date:  08/11/2022
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

Param (
    [Parameter(
        Mandatory=$false, 
        Position=0,
        HelpMessage="Enter the full path of the file or folder to check for processes using it"
    )]
    [ValidateScript({
        if (-not $_ -or $_ -eq "") { 
            return $true  # Allow empty to prompt later
        }
        if (-not (Test-Path $_ -PathType Any)) {
            throw "File or folder not found: $_"
        }
        return $true
    })]
    [string]$FileOrFolderPath,

    [Parameter(Mandatory=$false, HelpMessage="Enable verbose output for detailed process information")]
    [switch]$Verbose,

    [Parameter(Mandatory=$false, HelpMessage="Export results to CSV file")]
    [switch]$ExportToCSV,

    [Parameter(Mandatory=$false, HelpMessage="Path for CSV export (default: script directory)")]
    [string]$ExportPath
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Script Version
$sScriptVersion = '2.0'

Write-Host "🔍 Find Process for File in Use v$sScriptVersion" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

#Log File Info
$sLogName = $MyInvocation.MyCommand.Name
$sLogPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$sLogFile = Join-Path $sLogPath "$($sLogName -replace '\.ps1$','')_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Enhanced parameter validation with user-friendly prompts
if ([string]::IsNullOrEmpty($FileOrFolderPath)) {
    Write-Host "`n📁 File/Folder Path Required" -ForegroundColor Yellow
    Write-Host "Please enter the full path of the file or folder to check:" -ForegroundColor White
    Write-Host "Example: C:\temp\myfile.txt or C:\MyFolder" -ForegroundColor Gray
    
    do {
        $FileOrFolderPath = Read-Host "`nPath"
        if ([string]::IsNullOrEmpty($FileOrFolderPath)) {
            Write-Host "Path cannot be empty. Please try again." -ForegroundColor Red
            continue
        }
        if (-not (Test-Path $FileOrFolderPath -PathType Any)) {
            Write-Host "❌ File or folder not found: $FileOrFolderPath" -ForegroundColor Red
            Write-Host "Please check the path and try again." -ForegroundColor Yellow
            $FileOrFolderPath = $null
        }
    } while ([string]::IsNullOrEmpty($FileOrFolderPath))
}

# Resolve to full path for consistency
try {
    $FileOrFolderPath = Resolve-Path $FileOrFolderPath -ErrorAction Stop
    Write-Host "✅ Target: $FileOrFolderPath" -ForegroundColor Green
} catch {
    Write-Host "❌ Error resolving path: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Simple logging function if Write-LogInfo is not available
if (-not (Get-Command Write-LogInfo -ErrorAction SilentlyContinue)) {
    function Write-LogInfo {
        param([string]$LogPath, [switch]$TimeStamp, [string]$Message)
        $logEntry = if ($TimeStamp) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" } else { $Message }
        Write-Host $logEntry
        Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
}

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Initialisations started for: $FileOrFolderPath"
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#Set Error Action to Continue
$ErrorActionPreference = 'Continue'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Process detection started'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '


#Import Modules & Snap-ins
function Import-ModuleIfAvailable ($m) {
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Import Modules'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported." -ForegroundColor Green
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Module $m is already imported."
		Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Module not found, install started'
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting." -ForegroundColor Red
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message "Module $m not imported, not available and not in an online gallery, exiting."
				Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
                EXIT 1
            }
        }
    }
}

Load-Module PSLogging

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Initialisations completed'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#----------------------------------------------------------[Declarations]----------------------------------------------------------
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Declarations started'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '

Write-LogInfo -LogPath $sLogFile -TimeStamp -Message 'Declarations completed'
Write-LogInfo -LogPath $sLogFile -TimeStamp -Message ' '
#-----------------------------------------------------------[Functions]------------------------------------------------------------
<#Function <FunctionName>{
  Param()

  Begin{
    Write-Log -Entry
  }

  Process{
    Try{
      <code goes here>
    }

    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }

  End{
    If($?){
      Write-Log -Entry
      Write-Log -Entry
    }
  }
}
#>
Function Write-Log {
    param (
        [Parameter(Mandatory=$False, Position=0)]
        [String]$Entry
    )

    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Entry" | Out-File -FilePath $sLogFile -Append
}

Function FindProcess {
    [CmdletBinding()]
    Param()
    
    Begin {
        Write-Host "`n🚀 Starting Process Detection" -ForegroundColor Green
        Write-Log -Entry "FindProcess function started"
    }

  Process{
    Try{
        Write-Host "`n🔍 Searching for processes using: $FileOrFolderPath" -ForegroundColor Cyan
        Write-Log -Entry "Starting process detection for: $FileOrFolderPath"
        
        $results = @()
        $foundProcesses = $false

        # Method 1: Try using handle.exe (Sysinternals)
        $handlePath = Get-Command handle.exe -ErrorAction SilentlyContinue
        if ($handlePath) {
            Write-Host "📊 Using handle.exe for detailed analysis..." -ForegroundColor Yellow
            try {
                $handleOutput = & handle.exe $FileOrFolderPath 2>$null
                if ($handleOutput -and $handleOutput.Count -gt 1) {
                    Write-Host "✅ Found processes using handle.exe:" -ForegroundColor Green
                    foreach ($line in $handleOutput) {
                        if ($line -match "^\s*(\w+\.exe)\s+pid:\s*(\d+)") {
                            $processName = $matches[1]
                            $processId = $matches[2]
                            try {
                                $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                                if ($process) {
                                    $results += [PSCustomObject]@{
                                        ProcessName = $processName
                                        ProcessId = $processId
                                        ProcessPath = $process.Path
                                        WindowTitle = $process.MainWindowTitle
                                        StartTime = if($process.StartTime) { $process.StartTime.ToString() } else { "N/A" }
                                        Method = "handle.exe"
                                    }
                                    Write-Host "  🔹 $processName (PID: $processId)" -ForegroundColor White
                                    if ($Verbose) {
                                        Write-Host "    📁 Path: $($process.Path)" -ForegroundColor Gray
                                        Write-Host "    🕐 Started: $(if($process.StartTime) { $process.StartTime } else { 'N/A' })" -ForegroundColor Gray
                                    }
                                    $foundProcesses = $true
                                }
                            } catch {
                                Write-Host "    ⚠️  Could not get details for PID $processId" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            } catch {
                Write-Host "⚠️  Error running handle.exe: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  handle.exe not found in PATH. Download from: https://docs.microsoft.com/sysinternals/" -ForegroundColor Yellow
        }

        # Method 2: PowerShell-native approach using Get-Process and file handles
        Write-Host "`n🔧 Using PowerShell native methods..." -ForegroundColor Yellow
        try {
            $allProcesses = Get-Process | Where-Object { $_.ProcessName -ne "Idle" }
            foreach ($process in $allProcesses) {
                try {
                    # Check if process has file handles (this is a basic check)
                    if ($process.Modules -and $process.Modules.FileName -contains $FileOrFolderPath) {
                        $results += [PSCustomObject]@{
                            ProcessName = $process.ProcessName
                            ProcessId = $process.Id
                            ProcessPath = $process.Path
                            WindowTitle = $process.MainWindowTitle
                            StartTime = if($process.StartTime) { $process.StartTime.ToString() } else { "N/A" }
                            Method = "PowerShell"
                        }
                        Write-Host "  🔹 $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor White
                        $foundProcesses = $true
                    }
                } catch {
                    # Silently continue - some processes can't be accessed
                }
            }
        } catch {
            Write-Host "⚠️  Error scanning processes: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Results summary
        Write-Host "`n📊 Results Summary" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        
        if ($foundProcesses) {
            Write-Host "✅ Found $($results.Count) process(es) using the file/folder" -ForegroundColor Green
            
            # Export to CSV if requested
            if ($ExportToCSV) {
                $csvPath = if ($ExportPath) { 
                    Join-Path $ExportPath "ProcessLocks_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                } else { 
                    Join-Path $sLogPath "ProcessLocks_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                try {
                    $results | Export-Csv -Path $csvPath -NoTypeInformation
                    Write-Host "📄 Results exported to: $csvPath" -ForegroundColor Green
                } catch {
                    Write-Host "⚠️  Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "ℹ️  No processes found using the specified file/folder" -ForegroundColor Blue
            Write-Host "   This could mean:" -ForegroundColor Gray
            Write-Host "   • The file is not currently in use" -ForegroundColor Gray
            Write-Host "   • The process has sufficient privileges to hide its handles" -ForegroundColor Gray
            Write-Host "   • The file is locked at a lower level (driver, system service)" -ForegroundColor Gray
        }
        
        Write-Log -Entry "Process detection completed. Found: $($results.Count) processes"
        
    } Catch {
        Write-Host "❌ Error during process detection: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Entry "Error: $($_.Exception.Message)"
        throw
    }
  }

  End{
    If($?){
      Write-Host "`n✅ Process detection completed successfully." -ForegroundColor Green
      Write-Log -Entry "Process detection completed successfully."
      Write-Log -Entry "Script execution finished."
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

try {
    Write-Log -Entry "Script started - Version $sScriptVersion"
    FindProcess
    Write-Log -Entry "Script completed successfully"
} catch {
    Write-Host "❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log -Entry "Script failed: $($_.Exception.Message)"
    exit 1
}
