param{$CertificatePassword}
cd C:\Atlassian\jira\jre\bin
$certs = get-childitem -path C:\apache24\conf\ssl\* -Include *.crt, *.key, *.pfx
foreach ($c in $certs){
		if ([IO.Path]::GetExtension("$c") -eq ".pfx") {
			.\keytool.exe -import -file "$c" -destkeystore D:\Atlassian\Confluence\jre\lib\security\cacerts -srcstorepass "$CertificatePassword" -deststorepass changeit -trustcacerts -alias "$c.name" -deststoretype pkcs12
		} else{
	.\keytool.exe -import -file $certs -destkeystore D:\Atlassian\Confluence\jre\lib\security\cacerts -deststorepass changeit -trustcacerts -alias $certs.name -deststoretype pkcs12
		}
}
$backupCacerts = dir -Path C:\Atlassian\backup -Filter cacerts -Recurse | %{$_.FullName}
.\keytool.exe -importkeystore -srckeystore "$backupCacerts" -destkeystore C:\Atlassian\jira\jre\lib\security\cacerts -srcstorepass changeit -deststorepass changeit -v -noprompt

