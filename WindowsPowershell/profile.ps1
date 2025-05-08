# Set alias for updating PowerShell using winget
Set-Alias update-powershell "winget install --id Microsoft.Powershell --source winget"

# Update the git-auto-push alias to check if on a branch before pushing
Set-Alias git-auto-push "if (git rev-parse --abbrev-ref HEAD) { git add .; git commit -m 'Auto commit'; git push } else { Write-Host 'Not on a branch. Please switch to a branch before pushing.' }"

# Ensure PS drive exists and change location to PS drive
if (!(Test-Path ps:)) {
    New-PSDrive -PSProvider FileSystem -Name "PS" -Root "C:\PS\Scripts" | Out-Null
}
Set-Location C:\PS\Scripts

# Define a function to list the content of a function/script file
function def {
    (Get-Command $args).Definition
}

# Directory of scripts to auto-load in PS
$psdir = "C:\PS\autoload"

# Load all 'autoload' scripts
Get-ChildItem "${psdir}\*.ps1" | ForEach-Object { . $_ } | Out-Null

# Load scripts from the following locations
$CustomScripts = Get-ChildItem -Path "C:\PS" -Directory -Recurse | ForEach-Object { $_.FullName }
foreach ($s in $CustomScripts) {
    if (-not ($env:Path -like "*;$s;*")) {
        $env:Path += ";$s"
    }
}

# Credential Manager
$KeyPath = "C:\PS\Tools\PScreds\"

# Test if creds exist, if not create
if (!(Test-Path $KeyPath)) {
    New-Item -ItemType Directory -Path $KeyPath | Out-Null
}

$TestCredsPath = Get-ChildItem $KeyPath | Measure-Object
if ($TestCredsPath.Count -eq 0) {
    try {
        $creds = Get-Credential -Message "Please provide the domain\username and password of the service account going to run this script" | New-StoredCredential -Target $KeyPath
    } catch {
        Write-Error "Failed to create credentials: $_"
    }
} else {
    try {
        $creds = Get-StoredCredential -UserName "chcadmin"
    } catch {
        Write-Error "Failed to retrieve stored credentials: $_"
    }
}

# Persistent History
$HistFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) ".ps_history"
Register-EngineEvent PowerShell.Exiting -Action {
    try {
        Get-History | Export-Clixml $HistFile
    } catch {
        Write-Error "Failed to save history: $_"
    }
} | Out-Null

if (Test-Path $HistFile) {
    try {
        Import-Clixml $HistFile | Add-History
    } catch {
        Write-Error "Failed to load history: $_"
    }
}

# Function to load modules and snap-ins
function Load-Module {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Host "Module $ModuleName not found, installing..."
        try {
            Install-Module -Name $ModuleName -Force -Scope CurrentUser
        } catch {
            Write-Error "Failed to install module $ModuleName: $_"
            return
        }
    }
    try {
        Import-Module $ModuleName
    } catch {
        Write-Error "Failed to import module $ModuleName: $_"
    }
}

# Example usage of Load-Module function
# Load-Module -ModuleName "ModuleName"