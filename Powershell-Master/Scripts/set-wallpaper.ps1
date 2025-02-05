<#
.SYNOPSIS
	Sets the given image file as desktop wallpaper
.DESCRIPTION
	This PowerShell script sets the given image file as desktop wallpaper (.JPG or .PNG supported)
.PARAMETER ImageFile
	Specifies the path to the image file
.PARAMETER Style
        Specifies either Fill, Fit, Stretch, Tile, Center, or Span (default)
.EXAMPLE
	PS> ./set-wallpaper C:\ocean.jpg
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$ImageFile = , [string]$Style = )


	     {}
	 {}
	    {}
	  {}
	    {}
	}
 
	if ($Style -eq ) {
		New-ItemProperty -Path  -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force
		New-ItemProperty -Path  -Name TileWallpaper -PropertyType String -Value 1 -Force
	} else {
		New-ItemProperty -Path  -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force
		New-ItemProperty -Path  -Name TileWallpaper -PropertyType String -Value 0 -Force
	}
	Add-Type -TypeDefinition @User32.dll@ 
  
	$SPI_SETDESKWALLPAPER = 0x0014
	$UpdateIniFile = 0x01
	$SendChangeEvent = 0x02
  
	$fWinIni = $UpdateIniFile -bor $SendChangeEvent
  
	$ret = [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $Image, $fWinIni)
}
 
try {
	if ($ImageFile -eq  ) { $ImageFile = read-host  }

	SetWallPaper -Image $ImageFile -Style $Style
	
	exit 0 # success
} catch {
	
	exit 1
}
