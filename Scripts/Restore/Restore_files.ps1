##
######## Powershell Script for Restoring User Data ########
##
######## v4.0 4/19/19 ########
##
######## By Aaron Zercher ########
##
######## Script will restore all data in Desktop, Documents, Downloads, Favorites, Pictures, Chrome, and Mozilla Data ########
##
######## Declares the values and prompts for Technician and Username information ########
$Technician = Read-Host -Prompt "What Technician is auditing this computer (First name only)"

######## Calls Eviroment Variables for the local user and data location ########
$username = $env:username                 #@Motox80 modified
$userprofile = $env:userprofile           #@Motox80 modified

######## Declares the Restore location ########
$source = "\\TB-WDS01\Techdrive$\$Technician\$username"
If ((Test-Path -Path $source) -eq $false) {                               # Begin @Motox80 modified
    write-host -ForegroundColor red "Source drive not found. $source"   
    return                                                              
}                                                                         # End @Motox80 modified  
return 
######## Declares the data to be restored ########
$folder = "Desktop",
"Downloads",
"Favorites",
"Documents",
"Pictures",
"AppData\Local\Google\Chrome",
"AppData\Local\Mozilla",
"AppData\Roaming\Mozilla"
#endregion DeclaringDataBackupSources

###### Backup Data section ########

write-host -ForegroundColor green "Restoring data to local machine for $username"

foreach ($f in $folder)
{
	$currentLocalFolder = $userprofile + "\" + $f          #@Motox80 modified
	$currentRemoteFolder = $source + "\" + $f
	$currentFolderSize = (Get-ChildItem -ErrorAction silentlyContinue $currentRemoteFolder -Recurse -Force | Measure-Object -ErrorAction Inquire -Property Length -Sum ).Sum / 1MB
	$currentFolderSizeRounded = [System.Math]::Round($currentFolderSize)
	write-host -ForegroundColor Magenta "  $f... ($currentFolderSizeRounded MB)"
	Copy-Item -Force -recurse $currentRemoteFolder $currentLocalFolder
}

######## Begin Registry Restore ########
$RegistryRestore = Join-Path -Path $Source -ChildPath "RegistryInformation\RegBackup.reg"
If (Test-Path -Path $RegistryRestore) {
    Try {
        & Reg import "$RegistryRestore"
        If ($LastExitCode -NE "0") {
            Break
            # See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/reg-import#remarks
        } # END If LastExistCode NE 0
    } # END Try Reg Import
    Catch {
        Write-Warning -Message "Critical error/failure when attempting to import registry-backup!"
    } # END Catch Reg Import
} # END If Test-Path RegistryBackup
Else {
    Write-Warning -Message "Registry Backup not found at "$($RegistryRestore)"!"
} # END Else Test-Path RegistryBackup

write-host -ForegroundColor green "Restore complete! Select Yes to Reboot the Computer"

Restart-Computer -confirm