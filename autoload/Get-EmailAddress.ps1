Function Get-EmailAddress {

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage = 'What e-mail address would you like to find?')]
		[string[]]$EmailAddress
	)

	process {
        foreach ($Address in $EmailAddress) {
            Write-Host "Searching for email address: $Address" -ForegroundColor Cyan
            $results = Get-ADObject -Properties mail, proxyAddresses -Filter {mail -eq $Address -or proxyAddresses -like $Address} -ErrorAction SilentlyContinue

            if ($results) {
                Write-Host "Found matching AD objects:" -ForegroundColor Green
                $results | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        DistinguishedName = $_.DistinguishedName
                        ObjectClass = $_.ObjectClass
                        Mail = $_.mail
                        ProxyAddresses = $_.proxyAddresses -join '; '
                    }
                }
            } else {
                Write-Host "No AD objects found with email address: $Address" -ForegroundColor Yellow
            }
		}
	}
}
