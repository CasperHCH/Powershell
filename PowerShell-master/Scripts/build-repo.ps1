<#
.SYNOPSIS
	Builds a repository 
.DESCRIPTION
	This PowerShell script builds a repository by supporting: cmake, configure, autogen, Imakefile, and Makefile.
.PARAMETER RepoDir
	Specifies the path to the Git repository
.EXAMPLE
	PS> ./build-repo.ps1 C:\MyRepo
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$RepoDir = )


		Set-Location 

		& cmake ..
		if ($lastExitCode -ne ) { throw  }

		& make -j4
		if ($lastExitCode -ne ) { throw  }

		& make test
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) { 
		
		Set-Location 

		& ./configure
		#if ($lastExitCode -ne ) { throw  }

		& make -j4
		if ($lastExitCode -ne ) { throw  }

		& make test
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) { 
		
		Set-Location 

		& ./autogen.sh
		if ($lastExitCode -ne ) { throw  }

		& make -j4
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) {
		
		Set-Location 

		& gradle build
		if ($lastExitCode -ne ) { throw  }

		& gradle test
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) {
		
		Set-Location 

		& xmkmf 
		if ($lastExitCode -ne ) { throw  }

		& make -j4
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) {
		
		Set-Location 

		& make -j4
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) {
		
		Set-Location 

		& make -j4
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) { 
		
		Set-Location 

		& ./compile.sh
		if ($lastExitCode -ne ) { throw  }

		& make -j4
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType leaf) {
		
		Set-Location 

		& ./build.bat build-all-release
		if ($lastExitCode -ne ) { throw  }

	} elseif (Test-Path  -pathType container) {
		
		BuildInDir 
	} else {
		Write-Warning 
		exit 0 # success
	}
}

try {
	$StopWatch = [system.diagnostics.stopwatch]::startNew()

	if (-not(Test-Path  -pathType container)) { throw  }
	$RepoDirName = (Get-Item ).Name

	$PreviousPath = Get-Location
	BuildInDir 
	Set-Location 

	[int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
	
	exit 0 # success
} catch {
	
	exit 1
}
