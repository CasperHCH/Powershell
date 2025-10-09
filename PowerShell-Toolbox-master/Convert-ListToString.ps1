<#
.SYNOPSIS
    Converts an array of objects to a single concatenated string.
.DESCRIPTION
    This function takes an array of objects and concatenates them into a single string
    using StringBuilder for efficient string operations.
.PARAMETER InputArray
    The array of objects to convert to a string.
.EXAMPLE
    Convert-ListToString -InputArray @("Hello", " ", "World", "!")
    Returns: "Hello World!"
.EXAMPLE
    @(1, 2, 3, 4, 5) | Convert-ListToString
    Returns: "12345"
.NOTES
    Uses StringBuilder for efficient string concatenation with large arrays.
#>
function Convert-ListToString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    begin {
        $string = New-Object -TypeName System.Text.StringBuilder
    }

    process {
        [void]$string.Append($InputObject.ToString())
    }

    end {
        return $string.ToString()
    }
}
