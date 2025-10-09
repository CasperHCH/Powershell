##
######## Powershell Script for Restoring User Data ########
##
######## v4.0 4/19/19 ########
##
######## By Aaron Zercher ########
##
######## Script will restore all data in Desktop, Documents, Downloads, Favorites, Pictures, Chrome, and Mozilla Data ########
##
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    [string]$Technician,
    [switch]$WhatIf
)

######## Declares the values and prompts for Technician and Username information ########
if (-not $Technician) {
    $Technician = Read-Host -Prompt "Enter Technician Name"
}

######## Calls Environment Variables for the local user and data location ########
$username = $env:username                 #@Motox80 modified
$userprofile = $env:userprofile           #@Motox80 modified

Write-Host "Restore Script v4.0 - Technician: $Technician, User: $username" -ForegroundColor Green

######## Declares the Restore location ########
$source = $SourcePath
If ((Test-Path -Path $source) -eq $false) {                               # Begin @Motox80 modified
    Write-Host "Source path not found: $source" -ForegroundColor Red
    return
}                                                                         # End @Motox80 modified

Write-Host "Source verified: $source" -ForegroundColor Green

######## Declares the data to be restored ########
$folder = @(
    "Desktop",
    "Documents",
    "Downloads",
    "Favorites",
    "Pictures",
    "Chrome",
    "Mozilla"
)

#endregion DeclaringDataBackupSources

###### Backup Data section ########

Write-Host "Starting backup data restore..." -ForegroundColor Green

foreach ($f in $folder)
{
	$currentLocalFolder = $userprofile +  + $f          #@Motox80 modified
	$currentRemoteFolder = $source +  + $f
	$currentFolderSize = (Get-ChildItem -ErrorAction silentlyContinue $currentRemoteFolder -Recurse -Force | Measure-Object -ErrorAction Inquire -Property Length -Sum ).Sum / 1MB
	$currentFolderSizeRounded = [System.Math]::Round($currentFolderSize)
	write-host -ForegroundColor Magenta
	Copy-Item -Force -recurse $currentRemoteFolder $currentLocalFolder
}

######## Begin Registry Restore ########
$RegistryRestore = Join-Path -Path $Source -ChildPath
If (Test-Path -Path $RegistryRestore) {
    Try {
        & Reg import
        If ($LastExitCode -NE 0) {
            Break
            # See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/reg-import#remarks
        } # END If LastExistCode NE 0
    } # END Try Reg Import
    Catch {
        Write-Warning -Message
    } # END Catch Reg Import
} # END If Test-Path RegistryBackup
Else {
    Write-Warning -Message $($RegistryRestore)
} # END Else Test-Path RegistryBackup

Write-Host "Restore process complete." -ForegroundColor Green

Restart-Computer -confirm
