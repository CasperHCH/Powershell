<#
.SYNOPSIS
	Closes a program's processes 
.DESCRIPTION
	This PowerShell script closes a program's processes gracefully.
.PARAMETER FullProgramName
	Specifies the full program name
.PARAMETER ProgramName
	Specifies the program name
.PARAMETER ProgramAliasName
	Specifies the program alias name
.EXAMPLE
	PS> ./close-program  
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$FullProgramName = , [string]$ProgramName = , [string]$ProgramAliasName = )

try {
	if ($ProgramName -eq ) {
		get-process | where-object {$_.mainWindowTitle} | format-table Id, Name, mainWindowtitle -AutoSize
		$ProgramName = read-host 
	}
	if ($FullProgramName -eq ) {
		$FullProgramName = $ProgramName
	}

	$Processes = get-process -name $ProgramName -errorAction 'silentlycontinue'
	if ($Processes.Count -ne 0) {
		foreach ($Process in $Processes) {
			$Process.CloseMainWindow() | Out-Null
		} 
		Start-Sleep -milliseconds 100
		stop-process -name $ProgramName -force -errorAction 'silentlycontinue'
	} else {
		$Processes = get-process -name $ProgramAliasName -errorAction 'silentlycontinue'
		if ($Processes.Count -eq 0) {
			throw 
		}
		foreach ($Process in $Processes) {
			$_.CloseMainWindow() | Out-Null
		} 
		Start-Sleep -milliseconds 100
		stop-process -name $ProgramName -force -errorAction 'silentlycontinue'
	}
	if ($($Processes.Count) -eq 1) {
		
	} else {
		
	}
	exit 0 # success
} catch {
	
	exit 1
}
