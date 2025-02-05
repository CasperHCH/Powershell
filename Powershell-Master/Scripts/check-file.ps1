<#
.SYNOPSIS
        Checks a file
.DESCRIPTION
        This PowerShell script determines and prints the file type of the given file.
.PARAMETER Path
        Specifies the path to the file
.EXAMPLE
        PS> ./check-file C:\my.exe
.LINK
        https://github.com/fleschutz/PowerShell
.NOTES
        Author: Markus Fleschutz | License: CC0
#>

param([string]$Path = )


function Check-Header { param( $path )
    $path = Resolve-Path $path

    # Hexidecimal signatures for expected files
    $known = @'
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
,
'@ | ConvertFrom-Csv | sort {$_.header.length} -Descending
    
    $known | % {$_.header = $_.header -replace '\s'}
    
    try {
        # Get content of each file (up to 4 bytes) for analysis
        $HeaderAsHexString = New-Object System.Text.StringBuilder
        [Byte[]](Get-Content -Path $path -TotalCount 4 -Encoding Byte -ea Stop) | % {
            if (( -f $_).length -eq 1) {
                $null = $HeaderAsHexString.Append('0{0:X}' -f $_)
            } else {
                $null = $HeaderAsHexString.Append('{0:X}' -f $_)
            }
        }
      
        # Validate file header
        # might change .startswith() to -match.
        # might remove 'select -f 1' to get all possible matching extensions, or just somehow make it a better match.
        $known | ? {$_.header.startswith($HeaderAsHexString.ToString())} | select -f 1 | % {$_.extension}
    } catch {}
}

Check-Header $Path
