$Groups = Get-ADGroup -Properties * -Filter * -SearchBase  
Foreach($G In $Groups)
{
    Write-Host $G.Name
    Write-Host 
    $G.Members
}
