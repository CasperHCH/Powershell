#ARRAY of Items to check for
$Items = "Var1", "Var2", "Var3", "etc"

#Variable to check Items against
$CheckItems = "What are the items checked against?"

#Check All Items in the Array $Items
foreach ($I in $Items)
{#Start Foreach
Write-Host "Current Item we are checking for is: $I"
    if($CheckItems.Name -eq $I)
    {
        Write-Host "The Item $I is equal to what we are checking for: $Network.Name"

        #Because the Item is equal to what we are checking for, list all files in a new array ($VMS) with the extension .vmx within the folder C:\Users
        $vms = Get-ChildItem -Path C:\Users -Filter "*.vmx" -Exclude *.vmxf -Recurse | select FullName, Name


        #For each VM ($V) in the Array ($VMS) Suspend the VM
        foreach ($v in $vms)
        {#Start Foreach

            #Suspend the VM $V
            &"C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" suspend ($v.FullName).ToString()
        }#End ForEach

    }# End IF
}#End Foreach

 