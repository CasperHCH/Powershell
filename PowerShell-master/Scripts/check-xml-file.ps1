<#
.SYNOPSIS
	Checks the given XML file for validity
.DESCRIPTION
	This PowerShell script checks the given XML file for validity.
.PARAMETER file
	Specifies the path to the XML file to check
.EXAMPLE
	PS> ./check-xml-file myfile.xml
	✔️ XML file is valid
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

param([string]$file = )

try {
	if ($file -eq  ) { $file = read-host  }

	$XmlFile = Get-Item $file
	
	$script:ErrorCount = 0
	
	# Perform the XSD Validation
	$ReaderSettings = New-Object -TypeName System.Xml.XmlReaderSettings
	$ReaderSettings.ValidationType = [System.Xml.ValidationType]::Schema
	$ReaderSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation
	$ReaderSettings.add_ValidationEventHandler({ $script:ErrorCount++ })
	$Reader = [System.Xml.XmlReader]::Create($XmlFile.FullName, $ReaderSettings)
	while ($Reader.Read()) { }
	$Reader.Close()
	
	if ($script:ErrorCount -gt 0) {
		write-warning 
		exit 1
	} 

	
	exit 0 # success
} catch {
	
	exit 1
}
