<#
.SYNOPSIS
Displays all current PowerShell profile paths.

.DESCRIPTION
Expands and outputs the profile object to show the CurrentUser/AllUsers and
CurrentHost/AllHosts profile file locations available in the current session.

.EXAMPLE
.\Profiles.ps1

.NOTES
This script is read-only and does not modify any profile files.
#>

$PROFILE | Format-List -Force
