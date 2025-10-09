while($true){
    $d = Read-Host "Enter a date (MM/dd/yyyy format)"
    Try{
        # Extract the default Date/Time formatting from the local computer's regional settings, and then create the format to use when parsing the date/time information pull from AD.
        $CultureDateTimeFormat = (Get-Culture).DateTimeFormat
        $DateFormat = $CultureDateTimeFormat.ShortDatePattern
        $TimeFormat = $CultureDateTimeFormat.LongTimePattern
        $DateTimeFormat = "$DateFormat $TimeFormat"
        $DisableUserOnDate = [DateTime]::ParseExact($d,$DateFormat,[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
        Write-Host "Successfully parsed date: $DisableUserOnDate" -ForegroundColor Green
        break
    }
    Catch{
        Write-Host "Invalid date format. Please use the format: $DateFormat" -ForegroundColor Red
    }
}
