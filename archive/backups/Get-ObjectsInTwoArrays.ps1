<#
.SYNOPSIS
    Compares objects between two arrays and returns matches or differences.
.DESCRIPTION
    This function efficiently compares objects in two arrays using HashSet operations
    to find objects that are either present in both arrays or present in one but not the other.
.PARAMETER Array
    The primary array to compare.
.PARAMETER ArrayToCompare
    The second array to compare against the first.
.PARAMETER ComparisonMethod
    Specifies whether to return objects 'In' both arrays or 'NotIn' the second array.
.PARAMETER ObjectType
    The type of objects being compared: 'String', 'int', or 'PSObject'.
.EXAMPLE
    Get-ObjectsInTwoArrays -Array @("a","b","c") -ArrayToCompare @("b","c","d") -ComparisonMethod In -ObjectType String
    Returns objects present in both arrays.
.EXAMPLE
    Get-ObjectsInTwoArrays -Array @("a","b","c") -ArrayToCompare @("b","c","d") -ComparisonMethod NotIn -ObjectType String
    Returns objects from the first array that are not in the second array.
.NOTES
    Uses .NET HashSet for efficient performance with large datasets.
#>
function Get-ObjectsInTwoArrays {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSObject]])]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Array,

        [Parameter(Mandatory = $true)]
        [object[]]$ArrayToCompare,

        [Parameter(Mandatory = $true)]
        [ValidateSet('In', 'NotIn')]
        [string]$ComparisonMethod,

        [Parameter(Mandatory = $true)]
        [ValidateSet('String', 'int', 'PSObject')]
        [string]$ObjectType
    )

    if ($ObjectType -eq 'String') {
        $arrayIndex = [System.Collections.Generic.HashSet[String]]$Array
    } elseif ($ObjectType -eq 'int') {
        $arrayIndex = [System.Collections.Generic.HashSet[int]]$Array
    } elseif ($ObjectType -eq 'PSObject') {
        $arrayIndex = [System.Collections.Generic.HashSet[PSObject]]$Array
    }

    [System.Collections.Generic.List[PSObject]]$res = @()

    if ($ComparisonMethod -eq 'In') {
        foreach ($object in $ArrayToCompare) {
            if ($arrayIndex.Contains($object)) {
                $res.Add($object)
            }
        }
    } elseif ($ComparisonMethod -eq 'NotIn') {
        foreach ($object in $ArrayToCompare) {
            if (-not($arrayIndex.Contains($object))) {
                $res.Add($object)
            }
        }
    }

    Write-Host
    return $res
}
