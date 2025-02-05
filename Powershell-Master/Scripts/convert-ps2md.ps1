<#
.SYNOPSIS
	Converts a PowerShell script to Markdown
.DESCRIPTION
	This PowerShell script converts the comment-based help of a PowerShell script to Markdown.
.PARAMETER filename
	Specifies the path to the PowerShell script
.EXAMPLE
	PS> ./convert-ps2md.ps1 myscript.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$filename = )




        if ($codeAndRemarks[$i] -eq '' -and $codeAndRemarks[$i + 1] -eq '') { continue }
        if (1 -le $i -and $i -le 2) { continue }
    	$codeAndRemarks[$i] = ($codeAndRemarks[$i] | Out-String) -replace ,
        $code.Add($codeAndRemarks[$i])
    }

    $code -join 
}


        $isSkipped = $true
        $remark.Add($codeAndRemarks[$i])
    }

    $remark -join 
}

try {
	if ($filename -eq ) { $filename = Read-Host  }
	$ScriptName = (Get-Item ).Name

	$full = Get-Help $filename -Full 

	
	

	$Description = ($full.description | Out-String).Trim()
	if ($Description -ne ) {
		
		
	} else {
		
		
	}
	
	
	
	
	$Syntax = (($full.syntax | Out-String) -replace , ).Trim()
	$Syntax = (($Syntax | Out-String) -replace , )
	if ($Syntax -ne ) {
		
	}

	foreach($parameter in $full.parameters.parameter) {
		`r`n`r`n
		
	}
	
	
	
	

	foreach($input in $full.inputTypes.inputType) {
		
		
		
		
	}

	foreach($output in $full.outputTypes.outputType) {
		
		
		
		
	}

	foreach($example in $full.examples.example) {
		
		
		
		
		
		
	}

	$Notes = ($full.alertSet.alert | Out-String).Trim()
	if ($Notes -ne ) {
		
		
		
		
	}

	$Links = ($full.relatedlinks | Out-String).Trim()
	if ($Links -ne ) {
		
		
		
		
	}

	
	
	
	
	$Lines = Get-Content -path 
        foreach($Line in $Lines) {
		
	}
	
	
	$now = [datetime]::Now
	
} catch {
	
        exit 1
}
