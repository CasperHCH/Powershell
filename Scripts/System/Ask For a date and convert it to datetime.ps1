# Date/Time Conversion Utility
param(
    [string]$InputDate,
    [string]$OutputFormat = "yyyy-MM-dd HH:mm:ss"
)

function Convert-DateString {
    param(
        [string]$DateString,
        [string]$Format = "yyyy-MM-dd HH:mm:ss"
    )

    if ($DateString) {
        try {
            $parsedDate = [DateTime]::Parse($DateString)
            return $parsedDate.ToString($Format)
        } catch {
            Write-Error "Failed to parse date: $DateString"
            return $null
        }
    }

    while($true) {
        $d = Read-Host "Please enter a date (e.g., 12/25/2023 or 2023-12-25)"
        Try {
            # Extract the default Date/Time formatting from the local computer's culture settings
            $CultureDateTimeFormat = (Get-Culture).DateTimeFormat
            $DateFormat = $CultureDateTimeFormat.ShortDatePattern
            $TimeFormat = $CultureDateTimeFormat.LongTimePattern
            $DateTimeFormat = "$DateFormat $TimeFormat"

            # Try multiple parsing methods
            $DisableUserOnDate = $null
            try {
                $DisableUserOnDate = [DateTime]::ParseExact($d, $DateFormat, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, [System.Globalization.DateTimeStyles]::None)
            } catch {
                $DisableUserOnDate = [DateTime]::Parse($d)
            }

            Write-Host "Parsed date: $($DisableUserOnDate.ToString($Format))" -ForegroundColor Green
            return $DisableUserOnDate.ToString($Format)
        }
        Catch {
            Write-Host "Invalid date format. Please try again (e.g., MM/dd/yyyy or yyyy-MM-dd)" -ForegroundColor Red
        }
    }
}

if ($InputDate) {
    Convert-DateString -DateString $InputDate -Format $OutputFormat
} else {
    Convert-DateString -Format $OutputFormat
}
