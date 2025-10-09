function Import-ModuleIfAvailable ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        Write-Host "Module $m is already imported" -ForegroundColor Green
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
                Write-Host "Module $m not found in gallery. Cannot install." -ForegroundColor Red

            }
        }
    }
}

Import-ModuleIfAvailable AADRM
Import-ModuleIfAvailable AzureAD
Import-ModuleIfAvailable AzureADPreview
Import-ModuleIfAvailable MSOnline
Import-ModuleIfAvailable JiraPS
Import-ModuleIfAvailable MicrosoftTeams
