$Groups = Get-ADGroup -Properties * -Filter * -SearchBase "OU=Signatur Groups,OU=Groups,OU=Global,OU=EET_Nordic,DC=eetnordic,DC=net" 
Foreach($G In $Groups)
{
    Write-Host $G.Name
    Write-Host "-------------"
    $G.Members
}