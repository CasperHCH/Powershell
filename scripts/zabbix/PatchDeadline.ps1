# Original string
$string = (Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate -Filter "NOT Name like '%Edge%'").Deadline | select -First 1

# Default to blank
$formatted = ""

try {
    # Extract the first 14 characters (YYYYMMDDHHMMSS)
    $datetimeString = $string.Substring(0,14)

    # Try to parse the date
    $dt = [datetime]::ParseExact($datetimeString, "yyyyMMddHHmmss", $null)

    # Format the result
    $formatted = $dt.ToString("dd-MM-yyyy HH:mm:ss")
}
catch {
    # If parsing fails, $formatted stays blank
}

Write-Output $formatted