<#
.SYNOPSIS
    Script to optimize all PowerShell scripts in a specified folder and its subfolders.
.DESCRIPTION
    This script reads all PowerShell scripts in a specified folder and its subfolders, optimizes them, and saves the changes back to the folder.
.PARAMETER FolderPath
    The path to the folder containing the PowerShell scripts to be optimized.
.INPUTS
    None
.OUTPUTS
    Optimized PowerShell scripts saved back to the specified folder and its subfolders.
.NOTES
  Version:        1.0
  Author:         GitHub Copilot
  Creation Date:  <Date>
  Purpose/Change: Initial script development
.EXAMPLE
    .\OptimizeScripts.ps1 -FolderPath "C:\Scripts"
    Optimizes all PowerShell scripts in the "C:\Scripts" folder and its subfolders.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

# Function to optimize a single script
function Optimize-Script {
    param (
        [string]$scriptContent
    )

    # Remove unnecessary comments
    $optimizedContent = $scriptContent -replace '^\s*#.*$', ''

    # Remove extra blank lines
    $optimizedContent = $optimizedContent -replace '^\s*$', ''

    # Ensure consistent indentation (4 spaces)
    $optimizedContent = $optimizedContent -replace '^\s+', { param($matchInfo) (' ' * 4 * ($matchInfo[0].Length / 4)) }

    # Remove trailing spaces
    $optimizedContent = $optimizedContent -replace '\s+$', ''

    # Remove unused variables (simple heuristic)
    $optimizedContent = $optimizedContent -replace '^\s*\$[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*.*$', { param($matchInfo) if ($optimizedContent -notmatch "\b$($matchInfo[0].TrimStart().Split('=')[0].Trim())\b") { '' } else { $matchInfo[0] } }

    # Remove unused functions (simple heuristic)
    $optimizedContent = $optimizedContent -replace 'function\s+[a-zA-Z_][a-zA-Z0-9_]*\s*{[^}]*}', { param($matchInfo) if ($optimizedContent -notmatch "\b$($matchInfo[0].Split(' ')[1])\b") { '' } else { $matchInfo[0] } }

    # Simplify if statements
    $optimizedContent = $optimizedContent -replace 'if\s*\(\s*\$true\s*\)\s*{([^}]*)}', '$1'
    $optimizedContent = $optimizedContent -replace 'if\s*\(\s*\$false\s*\)\s*{[^}]*}', ''

    # Combine consecutive Write-Host calls
    $optimizedContent = $optimizedContent -replace 'Write-Host\s+"([^"]*)"\s*Write-Host\s+"([^"]*)"', 'Write-Host "$1 $2"'

    # Ensure consistent quoting (use single quotes where possible)
    $optimizedContent = $optimizedContent -replace '"([^"]*)"', { param($matchInfo) if ($matchInfo[1] -notmatch '[\$`]') { "'$($matchInfo[1])'" } else { $matchInfo[0] } }

    # Remove redundant code (simple heuristic)
    $optimizedContent = $optimizedContent -replace '^\s*return\s*$', ''

    return $optimizedContent
}

# Function to process all scripts in a folder recursively
function Invoke-FolderProcessing {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$folderPath
    )

    Write-Information "Processing folder: $folderPath" -InformationAction Continue

    # Get all PowerShell scripts in the current folder
    $scripts = Get-ChildItem -Path $folderPath -Filter *.ps1 -File

    foreach ($script in $scripts) {
        Write-Information "Processing script: $($script.FullName)" -InformationAction Continue
        try {
            # Read the content of the script
            $scriptContent = Get-Content -Path $script.FullName -Raw
            # Optimize the script content
            $optimizedContent = Optimize-Script -scriptContent $scriptContent
            # Save the optimized content back to the script file
            Set-Content -Path $script.FullName -Value $optimizedContent
            Write-Information "Optimized script: $($script.FullName)" -InformationAction Continue
        } catch {
            Write-Error "Error processing script: $($script.FullName)"
            Write-Error $_.Exception.Message
        }
    }

    # Recursively process subfolders
    $subfolders = Get-ChildItem -Path $folderPath -Directory
    foreach ($subfolder in $subfolders) {
        Invoke-FolderProcessing -folderPath $subfolder.FullName
    }
}

# Start processing the specified folder
try {
    Invoke-FolderProcessing -folderPath $FolderPath
    Write-Information "All scripts in the folder and its subfolders have been optimized." -InformationAction Continue
} catch {
    Write-Error "An error occurred while processing the folder: $FolderPath"
    Write-Error $_.Exception.Message
}