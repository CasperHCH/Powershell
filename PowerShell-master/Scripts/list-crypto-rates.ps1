<#
.SYNOPSIS
	List crypto rates
.DESCRIPTION
	This PowerShell script queries cryptocompare.com and lists the current crypto exchange rates in USD/EUR/RUB/CNY.
.EXAMPLE
	PS> ./list-crypto-rates.ps1

	Cryptocurrency               USD                    EUR                    RUB                    CNY
	--------------               ---                    ---                    ---                    ---
	1 Bitcoin (BTC) =            29054.01               26552.23               2786627.84             172521.27
	...
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>


}



try {
	ListCryptoRates | Format-Table -property @{e='Cryptocurrency';width=28},USD,EUR,RUB,CNY
	Write-Host 
	exit 0 # success
} catch {
	
	exit 1
}
