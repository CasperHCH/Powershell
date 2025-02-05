<#
.SYNOPSIS
	Lists a directory tree
.DESCRIPTION
	This PowerShell script lists all files and folders in a neat directory tree (including icon and size).
.PARAMETER Path
	Specifies the path to the directory tree
.EXAMPLE
	PS> ./list-dir-tree.ps1 C:\MyFolder
	├📂Results
	│ ├📄sales.txt (442K)
	(2 folders, 1 file, 442K total)
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$Path = )

function GetFileIcon([string]$suffix) {
	switch ($suffix) {
		{return }
		{return }
	  {return }
		{return }
		{return }
		{return }
		{return }
		{return }
	  {return }
	default {return }
	}
}

function Bytes2String([int64]$bytes) {
	if ($bytes -lt 1000) { return  }
	$bytes /= 1000
	if ($bytes -lt 1000) { return  }
	$bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
        if ($bytes -lt 1000) { return  }
        $bytes /= 1000
	return 
}

function ListDirectory([string]$path, [int]$depth) {
	$depth++
	$items = Get-ChildItem -path $path
	foreach($item in $items) {
		$filename = $item.Name
		for ($i = 1; $i -lt $depth; $i++) { Write-Host  -noNewline }
		if ($item.Mode -like ) {
			Write-Output 
			ListDirectory  $depth
			$global:folders++
		} else {
			$icon = GetFileIcon $item.Extension
			Write-Output 
			$global:files++
			$global:bytes += $item.Length
		}
	}
}

try {
	[int]$global:folders = 1
	[int]$global:files = 0
	[int]$global:bytes = 0
	ListDirectory $Path 0
	Write-Output 
	exit 0 # success
} catch {
	
	exit 1
}
