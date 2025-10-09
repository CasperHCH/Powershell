# Set alias for updating PowerShell using winget
Set-Alias update-powershell "winget install --id Microsoft.Powershell --source winget"

# Get the PS root path dynamically
$PSRootPath = Split-Path -Parent $PSScriptRoot

# Ensure PS drive exists and change location to PS drive
if (!(Test-Path ps:)) {
    New-PSDrive -PSProvider FileSystem -Name "PS" -Root $PSRootPath | Out-Null
}
Set-Location $PSRootPath

# Define a function to list the content of a function/script file
function def {
    (Get-Command $args).Definition
}

# Directory of scripts to auto-load in PS
$psdir = "$PSRootPath\autoload"

# Load all 'autoload' scripts with error handling
Get-ChildItem "${psdir}\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { 
    try { . $_ } catch { Write-Warning "Failed to load $_`: $($_.Exception.Message)" } 
} | Out-Null

# Load scripts from the following locations
$CustomScripts = Get-ChildItem -Path $PSRootPath -Directory -Recurse | ForEach-Object { $_.FullName }
foreach ($s in $CustomScripts) {
    $env:Path += ";$s"
}

# Credential Manager
$KeyPath = "$PSRootPath\Tools\PScreds\"

# Test if creds exist, if not create
$TestCredsPath = Get-ChildItem $KeyPath | Measure-Object
if ($TestCredsPath.Count -eq 0) {
    $creds = Get-Credential -Message "Please provide the domain\username and password of the service account going to run this script" | New-StoredCredential -Target $KeyPath
} else {
    $creds = Get-StoredCredential -UserName "chcadmin"
}

# Persistent History
$HistFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) ".ps_history"
Register-EngineEvent PowerShell.Exiting -Action { Get-History | Export-Clixml $HistFile } | Out-Null
if (Test-Path $HistFile) { Import-Clixml $HistFile | Add-History }

# Function to load modules and snap-ins
function Import-ModuleIfAvailable {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Host "Module $ModuleName not found, installing..."
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    }
    Import-Module $ModuleName
}

# Example usage of Load-Module function
# Load-Module -ModuleName "ModuleName"