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
$Technician = Read-Host -Prompt 

######## Calls Eviroment Variables for the local user and data location ########
$username = $env:username                 #@Motox80 modified
$userprofile = $env:userprofile           #@Motox80 modified

######## Declares the Restore location ########
$source = 
If ((Test-Path -Path $source) -eq $false) {                               # Begin @Motox80 modified
    write-host -ForegroundColor red    
    return                                                              
}                                                                         # End @Motox80 modified  
return 
######## Declares the data to be restored ########
$folder = ,
,
,
,
,
,
,

#endregion DeclaringDataBackupSources

###### Backup Data section ########

write-host -ForegroundColor green 

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
        If ($LastExitCode -NE ) {
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

write-host -ForegroundColor green 

Restart-Computer -confirm
