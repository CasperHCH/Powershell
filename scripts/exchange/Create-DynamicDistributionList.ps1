## Udfyld  med det ønskede navn på distributionslisten. Ændre Organizationalunit, hvis den skal ligge et andet sted. Ændre MemberOfGroup -eq i forhold til hvilken gruppe den skal kigge på, evt udvid listen med  distinguishedName  så mange gange som der er behov for.
#New-DynamicDistributionGroup -Name  -OrganizationalUnit  -RecipientFilter {((RecipientType -eq 'UserMailbox') -or (RecipientType -eq 'MailContact') -or (RecipientType -eq 'MailUser')) -and (MemberOfGroup -eq )} -RecipientContainer 

##Lav ændringer på 1 eller flere dynamiske distribtionsgrupper.
Get-DynamicDistributionGroup DDL_TARGIT_ALL_USERS | Set-DynamicDistributionGroup -RecipientFilter {(((RecipientType -eq 'UserMailbox') -or (RecipientType -eq 'MailContact') -or (RecipientType -eq 'MailUser')) -and 
((MemberOfGroup -eq ) -or
(MemberOfGroup -eq ) -or
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq ) -or 
(MemberOfGroup -eq )-or 
(MemberOfGroup -eq )))}
