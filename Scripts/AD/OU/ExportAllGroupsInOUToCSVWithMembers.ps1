#exports all groups in a OU to a seperate file for each group with the group name and description.

$distinguishedName = Read-Host -Prompt 'Please input the  of the desired OU you want to list users and the group they come from'
$groups = Get-ADGroup -filter * -SearchBase 

$PathExist = 
Write-Host 
    If(!(test-path $PathExist))
    {
          New-Item -ItemType Directory -Force -Path $PathExist
    }

ForEach ($g in $groups) 
    {

    New-Item -ItemType Directory -Force -Path 

    $path =  + $g.Name + 
    Get-ADGroup -Identity $g.Name -Properties * | select name,description | Out-File $path -Append
    
    $results = Get-ADGroupMember -Identity $g.Name -Recursive | Get-ADUser -Properties displayname, name 
    
    ForEach ($r in $results){
    New-Object PSObject -Property @{       
                                        DisplayName = $r.displayname | Out-File $path -Append
                                    }
                            }   
    }
