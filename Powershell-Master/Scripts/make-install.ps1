<#
.SYNOPSIS
	Copies newer EXE's + DLL's from the build directory to the installation directory
.DESCRIPTION
	This PowerShell script copies newer EXE's + DLL's from the build directory to the installation directory.
.EXAMPLE
	PS> ./make-install.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

set SRC_DIR=%1
set 
set FILTER=*.exe *.dll
set OPTIONS=/E /njh /np

try {
	title Syncing to %DST_DIR% ...
	robocopy %SRC_DIR% %DST_DIR% %FILTER% %OPTIONS%

	echo ------------------------------------------------------------------------------
	echo.

	
	exit 0 # success
} catch {
	
	exit 1
}
