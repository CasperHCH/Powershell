<#
.SYNOPSIS
	Lists FRITZ!Box's known devices
.DESCRIPTION
	This PowerShell script lists FRITZ!Box's known devices.
.PARAMETER Username
	Specifies the user name to FRITZ!Box
.PARAMETER Password
	Specifies the password to FRITZ!Box
.EXAMPLE
	PS> ./list-fritzbox-devices.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

#Requires -Version 3

param([string]$Username = , [string]$Password = )

if ($Username -eq ) { $Username = read-host  }
if ($Password -eq ) { $Password = read-host  }

write-progress 
[string]$HostURL = 
[string]$SOAPAction=
[string]$SOAPrequest = @1.0http://schemas.xmlsoap.org/soap/envelope/http://schemas.xmlsoap.org/soap/encoding/urn:dslforum-org:service:Hosts:1@

$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword

$XmlResult = invoke-restMethod `
   -Method POST `
   -Headers @{'SOAPAction'=($SOAPAction)} `
   -Uri ($HostURL+) `
   -Credential $Credentials `
   -ContentType 'text/xml' `
   -Body $SOAPrequest

$HostList = invoke-restMethod -Uri ($HostURL+($XmlResult.Envelope.Body.'X_AVM-DE_GetHostListPathResponse'.'NewX_AVM-DE_HostListPath'))

$HostTable = $HostList.List.Item.GetEnumerator() 

$HostTable | format-table -property Active,IPAddress,MACAddress,HostName,InterfaceType,X_AVM-DE_Speed

exit 0 # success
