param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath1,
    [Parameter(Mandatory=$true)]
    [string]$TaskName1,
    [string]$XmlPath2,
    [string]$TaskName2,
    [string]$DestinationPath = 'C:\Program Files\PowerShell Scripts'
)

# Create scheduled tasks from XML files
if (Test-Path $XmlPath1) {
    Write-Host "Creating scheduled task: $TaskName1" -ForegroundColor Green
    schtasks.exe /create /xml $XmlPath1 /tn $TaskName1
} else {
    Write-Error "XML file not found: $XmlPath1"
}

if ($XmlPath2 -and $TaskName2 -and (Test-Path $XmlPath2)) {
    Write-Host "Creating scheduled task: $TaskName2" -ForegroundColor Green
    schtasks.exe /create /xml $XmlPath2 /tn $TaskName2
}

# Create destination directory if it doesn't exist
if(-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory $DestinationPath -Force
    Write-Host "Created directory: $DestinationPath" -ForegroundColor Green
}

# Copy PowerShell files to destination (examples)
# Copy-Item "C:\Source\Script1.ps1" -Destination $DestinationPath
# Copy-Item "C:\Source\Script2.ps1" -Destination $DestinationPath

#if(-not (Test-Path 'C:\Program Files\VM Workstation')){New-Item -ItemType dir 'C:\Program Files\VM Workstation'}
#
#Copy-Item  -Destination 'C:\Program Files\VM Workstation'
#Copy-Item  -Destination 'C:\Program Files\VM Workstation'
