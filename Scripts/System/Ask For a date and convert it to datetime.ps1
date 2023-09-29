while(1){
	$d = read-host "Provide the date, the User Account should be disabled, in the format DD-MM-YYYY"
	Try{

        # Extract the default Date/Time formatting from the local computer's "Culture" settings, and then create the format to use when parsing the date/time information pull from AD.
        $CultureDateTimeFormat = (Get-Culture).DateTimeFormat
        $DateFormat = $CultureDateTimeFormat.ShortDatePattern
        $TimeFormat = $CultureDateTimeFormat.LongTimePattern
        $DateTimeFormat = "$DateFormat $TimeFormat"
        $DisableUserOnDate = [DateTime]::ParseExact($d,$DateFormat,[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
		break
    }
	Catch{
		Write-Host "Not a valid date, try again, use '-' between the numbers" -fore red
    }
}



