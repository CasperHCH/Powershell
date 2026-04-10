<#
.SYNOPSIS
    Parses a date string and returns it in the requested format.
.DESCRIPTION
    Converts a supplied date string into a normalized string representation.
    If no input date is supplied, the script prompts for one interactively and
    keeps prompting until a valid date is entered.
.PARAMETER InputDate
    Date text to parse. If omitted, the script prompts for a value.
.PARAMETER OutputFormat
    .NET date and time format string used when returning the parsed date.
.INPUTS
    System.String
.OUTPUTS
    System.String
.NOTES
    Version:        1.1
    Author:         Casper Hjorth Christensen
    Creation Date:  2026-04-10
    Purpose/Change: Added comment-based help and usage examples.
.EXAMPLE
    .\Ask For a date and convert it to datetime.ps1 -InputDate "2026-04-10"

    Returns the parsed date as 2026-04-10 00:00:00 using the default output format.
.EXAMPLE
    .\Ask For a date and convert it to datetime.ps1 -InputDate "10/04/2026 14:30" -OutputFormat "dd-MM-yyyy HH:mm"

    Returns the parsed date as 10-04-2026 14:30.
.EXAMPLE
    .\Ask For a date and convert it to datetime.ps1

    Prompts for a date interactively and continues prompting until a valid date is entered.
#>
# Date/Time Conversion Utility
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Date text to parse. If omitted, the script prompts for one.")]
    [string]$InputDate,

    [Parameter(Mandatory = $false, HelpMessage = "Output format string used for the parsed date.")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFormat = "yyyy-MM-dd HH:mm:ss"
)

function Convert-DateString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DateString,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Format = "yyyy-MM-dd HH:mm:ss"
    )

    $culture = Get-Culture
    $dateTimeStyles = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
    $acceptedFormats = @(
        $culture.DateTimeFormat.ShortDatePattern,
        $culture.DateTimeFormat.LongDatePattern,
        "$($culture.DateTimeFormat.ShortDatePattern) $($culture.DateTimeFormat.ShortTimePattern)",
        "$($culture.DateTimeFormat.ShortDatePattern) $($culture.DateTimeFormat.LongTimePattern)",
        'yyyy-MM-dd',
        'yyyy-MM-dd HH:mm:ss',
        'MM/dd/yyyy',
        'MM/dd/yyyy HH:mm:ss',
        'dd/MM/yyyy',
        'dd/MM/yyyy HH:mm:ss'
    ) | Select-Object -Unique

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($DateString)) {
            $DateString = Read-Host "Please enter a date (for example, 12/25/2023 or 2023-12-25)"
        }

        $parsedDate = [datetime]::MinValue
        $isParsed = [DateTime]::TryParseExact(
            $DateString,
            $acceptedFormats,
            $culture,
            $dateTimeStyles,
            [ref]$parsedDate
        )

        if (-not $isParsed) {
            $isParsed = [DateTime]::TryParse($DateString, $culture, $dateTimeStyles, [ref]$parsedDate)
        }

        if ($isParsed) {
            $formattedDate = $parsedDate.ToString($Format, $culture)
            Write-Host "Parsed date: $formattedDate" -ForegroundColor Green
            return $formattedDate
        }

        if (-not [string]::IsNullOrWhiteSpace($InputDate)) {
            Write-Error "Failed to parse date: $DateString"
            return $null
        }

        Write-Host "Invalid date format. Please try again (for example, MM/dd/yyyy or yyyy-MM-dd)." -ForegroundColor Red
        $DateString = $null
    }
}

Convert-DateString -DateString $InputDate -Format $OutputFormat
