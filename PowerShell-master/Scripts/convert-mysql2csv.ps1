<#
.SYNOPSIS
	Convert a MySQL database table to a .CSV file
.DESCRIPTION
	This PowerShell script converts a MySQL database table to a .CSV file.
.PARAMETER server
	Specifies the server's hostname or IP address
.PARAMETER database
	Specifies the database name
.PARAMETER username
	Specifies the user name
.PARAMETER password
	Specifies the password
.PARAMETER query
	Specifies the SQL query
.EXAMPLE
	PS> ./convert-mysql2csv.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


param([string]$server = , [string]$database = , [string]$username = , [string]$password = , [string]$query = )

try {
	if ($server -eq ) { $server = read-host  }
	if ($database -eq ) { $database = read-host  }
	if ($username -eq ) { $username = read-host  }
	if ($password -eq ) { $password = read-host  }
	if ($query -eq ) { $query = read-host  }

	$csvfilepath = 
	$result = Invoke-MySqlQuery  -ConnectionString  -Sql $query -CommandTimeout 10000
	$result | Export-Csv $csvfilepath -NoTypeInformation
	exit 0 # success
} catch {
	
	exit 1
}
