<#
.SYNOPSIS
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
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Specify the file name or part of the file name to query.")]
        [ValidateNotNullOrEmpty()]
        [string]$File,

        [Parameter(Mandatory = $false, HelpMessage = "Specify the file server to query. Default is 'HQ-FIL-01'.")]
        [ValidateNotNullOrEmpty()]
        [string]$Server = 'HQ-FIL-01'
    )

    # Query the file server for open files
    $openFiles = OPENFILES.EXE /QUERY /S $Server /FO CSV | ConvertFrom-Csv | Where-Object { $_.OpenFile -match $File }

    # Prepare the report
    $Report = foreach ($file in $openFiles) {
        $user = Get-ADUser -Filter { SamAccountName -eq $file.AccessedBy } -Properties Name | Select-Object -ExpandProperty Name
        [PSCustomObject]@{
            Directory = $file.OpenFile
            Name      = $user
            UserName  = $file.AccessedBy
        }
    }

    # Output the report
    $Report | Select-Object Name, UserName, Directory | Sort-Object Name
}

# Example usage:
# Get-OpenFiles -File "example"
# Get-OpenFiles -Server "srv-fil-01" -File "example"