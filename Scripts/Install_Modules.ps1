function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host 
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Scope AllUsers
                Import-Module $m
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host 

            }
        }
    }
}

Load-Module AADRM
Load-Module AzureAD
Load-Module AzureADPreview
Load-Module MSOnline
Load-Module JiraPS
Load-Module MicrosoftTeams
