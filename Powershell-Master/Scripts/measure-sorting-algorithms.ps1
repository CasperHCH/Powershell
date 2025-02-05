<#
.SYNOPSIS
	Measures the speed of sorting algorithms
.DESCRIPTION
	This PowerShell script measures the speed of several sorting algorithms and prints it.
.PARAMETER numIntegers
	Specifies the number of integers to sort (3000 by default)
.EXAMPLE
	PS> ./measure-sorting-algorithms.ps1
	🧭 6.041 sec to sort 3000 integers by BubbleSort
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([int]$numIntegers = 3000)


&  $numIntegers
&  $numIntegers
&  $numIntegers
&  $numIntegers
&  $numIntegers
&  $numIntegers
&  $numIntegers
&  $numIntegers
exit 0 # success
