<#
.SYNOPSIS
	Converts PowerShell scripts to batch files
.DESCRIPTION
	This PowerShell script converts one or more PowerShell scripts to .bat batch files.
.PARAMETER Filepattern
	Specifies the file pattern
.EXAMPLE
	PS> ./convert-ps2bat.ps1 *.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Filepattern = )

function Convert-PowerShellToBatch
{
    param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]
        [Alias()]
        $Path
    )
 
    process
    {
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes((Get-Content -Path $Path -Raw -Encoding UTF8)))
        $newPath = [Io.Path]::ChangeExtension($Path, )
         | Set-Content -Path $newPath -Encoding Ascii
    }
}
 
try {
	if ($Filepattern -eq ) { $Filepattern = Read-Host  }

	$Files = Get-ChildItem -path 
	foreach ($File in $Files) {
		Convert-PowerShellToBatch 
	}
	exit 0 # success
} catch {
	
	exit 1
}
