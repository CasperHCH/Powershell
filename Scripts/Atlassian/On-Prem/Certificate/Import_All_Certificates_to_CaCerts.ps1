param{$CertificatePassword}
Set-Location C:\Atlassian\jira\jre\bin
$certs = get-childitem -path C:\apache24\conf\ssl\* -Include *.crt, *.key, *.pfx
foreach ($c in $certs){
		if ([IO.Path]::GetExtension() -eq ) {
			.\keytool.exe -import -file  -destkeystore D:\Atlassian\Confluence\jre\lib\security\cacerts -srcstorepass  -deststorepass changeit -trustcacerts -alias  -deststoretype pkcs12
		} else{
	.\keytool.exe -import -file $c -destkeystore D:\Atlassian\Confluence\jre\lib\security\cacerts -deststorepass changeit -trustcacerts -alias  -deststoretype pkcs12
		}
}
$backupCacerts = dir -Path C:\Atlassian\backup -Filter cacerts -Recurse | %{$_.FullName}
.\keytool.exe -importkeystore -srckeystore  -destkeystore C:\Atlassian\jira\jre\lib\security\cacerts -srcstorepass changeit -deststorepass changeit -v -noprompt
