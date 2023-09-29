## Udfyld "Name" med det ønskede navn på distributionslisten. Ændre Organizationalunit, hvis den skal ligge et andet sted. Ændre MemberOfGroup -eq i forhold til hvilken gruppe den skal kigge på, evt udvid listen med " -or (MemberOfGroup -eq " distinguishedName ") " så mange gange som der er behov for.
#New-DynamicDistributionGroup -Name "DDL_TARGIT_BUSINESSMANAGER" -OrganizationalUnit "OU=Dynamic Distribution Lists,OU=Mail Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net" -RecipientFilter {((RecipientType -eq 'UserMailbox') -or (RecipientType -eq 'MailContact') -or (RecipientType -eq 'MailUser')) -and (MemberOfGroup -eq "CN=GG_TARGIT_ROLE_BUSINESSMANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net")} -RecipientContainer "eetnordic.net\EET_Nordic"

##Lav ændringer på 1 eller flere dynamiske distribtionsgrupper.
Get-DynamicDistributionGroup DDL_TARGIT_ALL_USERS | Set-DynamicDistributionGroup -RecipientFilter {(((RecipientType -eq 'UserMailbox') -or (RecipientType -eq 'MailContact') -or (RecipientType -eq 'MailUser')) -and 
((MemberOfGroup -eq "CN=GG_TARGIT_ROLE_BUSINESSMANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_COUNTRY_ADM,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_COUNTRY_SALES_MANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_COUNTRYMANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_FULLACCESS,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_GROUP_ADM,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_GROUPMANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_PRODUCT_MANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net") -or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_PURCHASER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net")-or 
(MemberOfGroup -eq "CN=GG_TARGIT_ROLE_REGION_SALES_MANAGER,OU=Targit,OU=Application Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net")))}