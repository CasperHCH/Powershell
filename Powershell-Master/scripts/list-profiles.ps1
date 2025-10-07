<#
.SYNOPSIS
	Lists the user's PowerShell profiles
.DESCRIPTION
	This PowerShell script lists the user's PowerShell profiles.
.EXAMPLE
	PS> ./list-profiles.ps1
	
	Level Profile                Location                                                         Existent
	----- -------                --------                                                         --------
	1     AllUsersAllHosts       /opt/PowerShell/profile.ps1                                      no
	2     AllUsersCurrentHost    /opt/PowerShell/Microsoft.PowerShell_profile.ps1                 no
	3     CurrentUserAllHosts    /home/markus/.config/powershell/profile.ps1                      no
	4     CurrentUserCurrentHost /home/markus/.config/powershell/Microsoft.PowerShell_profile.ps1 yes
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

 else { $Existent =  }
	New-Object PSObject -Property @{ 'Level'=; 'Profile'=; 'Location'=; 'Existent'=	}
}



try {
	ListProfiles | format-table -property Level,Profile,Location,Existent
	exit 0 # success
} catch {
	
	exit 1
}
