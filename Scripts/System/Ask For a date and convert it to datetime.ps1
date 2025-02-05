while(1){
	$d = read-host 
	Try{

        # Extract the default Date/Time formatting from the local computer's  settings, and then create the format to use when parsing the date/time information pull from AD.
        $CultureDateTimeFormat = (Get-Culture).DateTimeFormat
        $DateFormat = $CultureDateTimeFormat.ShortDatePattern
        $TimeFormat = $CultureDateTimeFormat.LongTimePattern
        $DateTimeFormat = 
        $DisableUserOnDate = [DateTime]::ParseExact($d,$DateFormat,[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
		break
    }
	Catch{
		Write-Host  -fore red
    }
}
