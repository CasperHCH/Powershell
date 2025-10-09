param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath = "C:\Reports",
    [Parameter(Mandatory=$true)]
    [string]$FileExtension = ".txt",
    [Parameter(Mandatory=$true)]
    [string]$Summary = "Automated Report Upload",
    [Parameter(Mandatory=$true)]
    [string]$IssueKey
)

# Rename files to have consistent extension
Get-ChildItem -path $SourcePath | Rename-Item -newname { [io.path]::ChangeExtension($_.name, $FileExtension) }

# Get the most recent file
$file = Get-ChildItem $SourcePath | Sort-Object LastWriteTime | Select-Object -Last 1
$currentDate = Get-Date -Format "yyyy-MM-dd"

$Description = "Automated upload on $currentDate - File: $($file.Name)"

Write-Host "Uploading file: $($file.FullName) to issue: $IssueKey" -ForegroundColor Green

# Execute ACLI command
$aCliCommand = "acli Miracle_Jira --action addAttachment --issue $IssueKey --file `"$($file.FullName)`""
Invoke-Expression $aCliCommand
