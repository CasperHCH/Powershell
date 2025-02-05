#ARRAY of Items to check for
$Items = , , , 

#Variable to check Items against
$CheckItems = 

#Check All Items in the Array $Items
foreach ($I in $Items)
{#Start Foreach
Write-Host 
    if($CheckItems.Name -eq $I)
    {
        Write-Host 

        #Because the Item is equal to what we are checking for, list all files in a new array ($VMS) with the extension .vmx within the folder C:\Users
        $vms = Get-ChildItem -Path C:\Users -Filter  -Exclude *.vmxf -Recurse | select FullName, Name


        #For each VM ($V) in the Array ($VMS) Suspend the VM
        foreach ($v in $vms)
        {#Start Foreach

            #Suspend the VM $V
            & suspend ($v.FullName).ToString()
        }#End ForEach

    }# End IF
}#End Foreach
