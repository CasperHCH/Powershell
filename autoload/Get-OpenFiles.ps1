<#
.Synopsis
   A quick function to search for open network shared file(s).
.DESCRIPTION
   This function is designed to quickly search for open network shared file(s).
.NOTES
	Created by: Nicolai Graakær
	Modified: 04.06.2018 12.30
	Version: 1.0
	
	Changelog: 
	* Code created
.EXAMPLE
   Get-OpenFiles
   Query for open file(s) on fileserver and returns who has the file(s) open.
.EXAMPLE
   Get-OpenFiles test
   Query for file(s) where filename includes test is open and returns the username of who has the file open.
   Default FileServer to query: HQ-FIL-01
.EXAMPLE
   Get-OpenFiles -Server srv-fil-01 -File example
   Query FileServer srv-fil-01 for file(s) where example is part of filename and returns the username of who has the file open.

   Name      UserName Directory
   ----      -------- ---------
   Test User TUR-DK   E:\lunch_example-week2.XLSX
#>

Function Get-OpenFiles {
	Param(
        [Parameter(Mandatory=$True)]
        [String]$File,
	    [Parameter(Mandatory=$False)]
        [String]$Server = 'HQ-FIL-01'
    )

	$var = OPENFILES.EXE /QUERY /S $Server /FO CSV  | ConvertFrom-Csv | ? { $_ -match $File }
	$Report = foreach ($v in $var) {
		$LDAP = Get-ADUser $v."accessed by" | Select Name
		New-Object psobject -Property @{
		    Directory = $v."Open File (Path\executable)"
		    Name = $LDAP.name
		    UserName = $v."accessed by"
	    }
	}

	$Report | Select Name, Username, Directory | Sort-Object Name | Format-Table -AutoSize
}