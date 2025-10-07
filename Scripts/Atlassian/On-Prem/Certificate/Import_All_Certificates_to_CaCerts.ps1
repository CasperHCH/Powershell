param(
    [Parameter(Mandatory=$false)]
    [string]$CertificatePassword = "changeit"
)

Set-Location C:\Atlassian\jira\jre\bin
$certs = Get-ChildItem -path "C:\apache24\conf\ssl\*" -Include *.crt, *.key, *.pfx

foreach ($c in $certs){
    $alias = [IO.Path]::GetFileNameWithoutExtension($c.Name)
    Write-Host "Processing certificate: $($c.Name)" -ForegroundColor Yellow

    if ([IO.Path]::GetExtension($c.Name) -eq ".pfx") {
        .\keytool.exe -import -file "$($c.FullName)" -destkeystore "D:\Atlassian\Confluence\jre\lib\security\cacerts" -srcstorepass $CertificatePassword -deststorepass changeit -trustcacerts -alias $alias -deststoretype pkcs12 -noprompt
    } else {
        .\keytool.exe -import -file "$($c.FullName)" -destkeystore "D:\Atlassian\Confluence\jre\lib\security\cacerts" -deststorepass changeit -trustcacerts -alias $alias -deststoretype pkcs12 -noprompt
    }
}

$backupCacerts = Get-ChildItem -Path "C:\Atlassian\backup" -Filter "cacerts" -Recurse | Select-Object -First 1
if ($backupCacerts) {
    Write-Host "Importing backup cacerts: $($backupCacerts.FullName)" -ForegroundColor Green
    .\keytool.exe -importkeystore -srckeystore "$($backupCacerts.FullName)" -destkeystore "C:\Atlassian\jira\jre\lib\security\cacerts" -srcstorepass changeit -deststorepass changeit -v -noprompt
}
