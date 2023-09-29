#exports all groups in a OU to a seperate file for each group with the group name and description.

$distinguishedName = Read-Host -Prompt 'Please input the "distinguishedName" of the desired OU you want to list users and the group they come from'
$groups = Get-ADGroup -filter * -SearchBase "$distinguishedName"

$PathExist = "c:\temp\script_csv_files\"
Write-Host "the files will be placed here: c:\temp\script_csv_files\"
    If(!(test-path $PathExist))
    {
          New-Item -ItemType Directory -Force -Path $PathExist
    }

ForEach ($g in $groups) 
    {

    New-Item -ItemType Directory -Force -Path "c:\temp\script_csv_files\"

    $path = "c:\temp\script_csv_files\" + $g.Name + ".csv"
    Get-ADGroup -Identity $g.Name -Properties * | select name,description | Out-File $path -Append
    
    $results = Get-ADGroupMember -Identity $g.Name -Recursive | Get-ADUser -Properties displayname, name 
    
    ForEach ($r in $results){
    New-Object PSObject -Property @{       
                                        DisplayName = $r.displayname | Out-File $path -Append
                                    }
                            }   
    }