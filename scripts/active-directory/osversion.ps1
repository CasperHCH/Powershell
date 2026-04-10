<#
.SYNOPSIS
Returns the local operating system version.

.DESCRIPTION
Provides a small helper function that reads the Win32_OperatingSystem CIM class
and returns the current machine's operating system version string.
#>

Function Get-OperatingSystemVersion
{
 (Get-CimInstance -Class Win32_OperatingSystem).Version
} #end Get-OperatingSystemVersion
