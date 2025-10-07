<#
.SYNOPSIS
	Creates a new PowerShell script file
.DESCRIPTION
	This PowerShell script creates a new PowerShell script file (by using template file ../Data/template.ps1).
.PARAMETER filename
	Specifies the path to the resulting file
.EXAMPLE
	PS> ./new-script myscript.ps1
	✔️ created new PowerShell script: myscript.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filename = "")

try {
	if ($filename -eq "") { $filename = Read-Host "Enter filename for new script" }
	if ($filename -eq "") { throw "No filename provided" }

	$templatePath = "$PSScriptRoot\..\data\template.ps1"
	if (!(Test-Path $templatePath)) {
		# Create a basic template if it doesn't exist
		$basicTemplate = @'
<#
.SYNOPSIS
	Describe the script here
.DESCRIPTION
	Describe the script in more detail here
.EXAMPLE
	PS> .\{0}
.NOTES
	Author: Your Name | License: Your License
#>

try {{
	# Your code here
	Write-Host "Hello from {0}" -ForegroundColor Green
	exit 0 # success
}} catch {{
	Write-Host "Error: $($Error[0])" -ForegroundColor Red
	exit 1
}}
'@ -f $filename
		$basicTemplate | Out-File -FilePath $filename -Encoding UTF8
	} else {
		Copy-Item $templatePath $filename
	}

	Write-Host "✅ Created new PowerShell script: $filename" -ForegroundColor Green
	exit 0 # success
} catch {
	Write-Host "❌ Error: $($Error[0])" -ForegroundColor Red
	exit 1
}
