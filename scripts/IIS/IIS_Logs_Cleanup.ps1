<#
.SYNOPSIS
Compresses IIS log files older than the first day of the previous month.

.DESCRIPTION
Groups old IIS log files by month, compresses each month into a zip archive,
optionally stores the archive in a separate destination, and removes the source
log files only after the archive has been created successfully.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$ArchivePath
)

$script:LogFile = Join-Path $PSScriptRoot 'IISLogsCleanup.log'
$firstDayOfPreviousMonth = (Get-Date -Day 1).AddMonths(-1)
$archiveRoot = if ($ArchivePath) { $ArchivePath } else { $LogPath }

function Write-LogFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $script:LogFile -Value "[$timestamp] $Message"
}

if ($ArchivePath -and -not (Test-Path $ArchivePath)) {
    $null = New-Item -Path $ArchivePath -ItemType Directory -Force
}

$logFilesToArchive = @(Get-ChildItem -Path $LogPath -Filter *.log -File | Where-Object { $_.CreationTime -lt $firstDayOfPreviousMonth })
if ($logFilesToArchive.Count -eq 0) {
    Write-LogFile -Message "No IIS log files found for archival in $LogPath"
    Write-Information "No IIS log files require archival." -InformationAction Continue
    return
}

$folderName = Split-Path -Path $LogPath -Leaf
foreach ($group in ($logFilesToArchive | Group-Object { $_.LastWriteTime.ToString('yyyy-MM') })) {
    $zipFileName = '{0}-{1}-{2}.zip' -f $env:COMPUTERNAME, $folderName, $group.Name
    $zipPath = Join-Path -Path $archiveRoot -ChildPath $zipFileName

    Write-LogFile -Message "Preparing archive $zipPath with $($group.Count) files"

    if ($PSCmdlet.ShouldProcess($zipPath, 'Create IIS log archive')) {
        Compress-Archive -Path $group.Group.FullName -DestinationPath $zipPath -CompressionLevel Optimal -Force
    }

    if (-not (Test-Path $zipPath -PathType Leaf)) {
        throw "Archive was not created: $zipPath"
    }

    foreach ($logFile in $group.Group) {
        if ($PSCmdlet.ShouldProcess($logFile.FullName, 'Remove archived IIS log file')) {
            Remove-Item -Path $logFile.FullName -Force
        }
    }

    Write-LogFile -Message "Archived $($group.Count) files to $zipPath"
    Write-Information "Archived $($group.Count) files to $zipPath" -InformationAction Continue
}
