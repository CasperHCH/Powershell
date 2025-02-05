Function Get-EmailAddress {

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage = 'What e-mail address would you like to find?')]
		[string[]]$EmailAddress
	)

	process {
        foreach ($Address in $EmailAddress) {
            Get-ADObject -Properties mail, proxyAddresses -Filter 
		}
	}
}
