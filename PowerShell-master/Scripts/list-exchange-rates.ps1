<#
.SYNOPSIS
	Lists the exchange rates for a currency
.DESCRIPTION
	This PowerShell script lists the current exchange rates for the given currency (USD per default).
.PARAMETER currency
	Specifies the base currency
.EXAMPLE
	PS> ./list-exchange-rates.ps1 EUR

	Current Exchange Rates for 1 EUR (source: http://www.floatrates.com)
	================================

	Rate           Currency                        Inverse    Date
	----           --------                        -------    ----
	1.09489154     USD - U.S. Dollar               0.91333248 Sun, 6 Aug 2023 11:55:02 GMT
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$currency = )


	}
}

try {
	
	
	

	ListExchangeRates $currency | format-table -property Rate,Currency,Inverse,Date
	exit 0 # success
} catch {
	
	exit 1
}
