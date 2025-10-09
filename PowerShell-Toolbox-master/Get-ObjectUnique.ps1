<#
.SYNOPSIS
    Returns unique objects from an input array.
.DESCRIPTION
    This function takes an array of objects and returns only the unique values
    using a HashSet for efficient deduplication.
.PARAMETER InputArray
    The array of objects to filter for unique values.
.EXAMPLE
    Get-ObjectUnique -InputArray @("apple", "banana", "apple", "cherry", "banana")
    Returns: apple, banana, cherry
.NOTES
    Uses .NET HashSet for efficient performance with large datasets.
#>
function Get-ObjectUnique {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )

    begin {
        $uniqueSet = New-Object System.Collections.Generic.HashSet[string]
    }

    process {
        [void]$uniqueSet.Add($InputObject.ToString())
    }

    end {
        return $uniqueSet
    }
}
