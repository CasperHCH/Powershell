param{$CertificatePassword}
$AtlassianFolder = "C:\Atlassian\confluence\"
$certs = get-childitem -path C:\apache24\conf\ssl\* -Include *.crt, *.key, *.pfx
foreach ($c in $certs){
		if ([IO.Path]::GetExtension("$c") -eq ".pfx") {
			& "$($AtlassianFolder)jre\bin\keytool.exe" -import -file "$c" -destkeystore "$($AtlassianFolder)jre\lib\security\cacerts" -srcstorepas "$CertificatePassword" -deststorepass changeit -trustcacerts -alias "$c.name" -deststoretype pkcs12
		} else{
	& "$($AtlassianFolder)jre\bin\keytool.exe" -import -file $certs -destkeystore "$($AtlassianFolder)jre\lib\security\cacerts" -deststorepass changeit -trustcacerts -alias $certs.name -deststoretype pkcs12
		}
}


$backupCacerts = dir -Path C:\Atlassian\backup -Filter cacerts -Recurse | %{$_.FullName}
& "$($AtlassianFolder)jre\bin\keytool.exe" -importkeystore -srckeystore "$backupCacerts" -destkeystore "$($AtlassianFolder)jre\lib\security\cacerts" -srcstorepass changeit -deststorepass changeit -v -noprompt

