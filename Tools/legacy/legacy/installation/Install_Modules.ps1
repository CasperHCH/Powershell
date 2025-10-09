function Import-ModuleIfAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $ModuleName}) {
        Write-Verbose "Module $ModuleName is already imported" -Verbose
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $ModuleName}) {
            Import-Module $ModuleName
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $ModuleName | Where-Object {$_.Name -eq $ModuleName}) {
                Install-Module -Name $ModuleName -Force -Scope AllUsers
                Import-Module $ModuleName
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                Write-Warning "Module $ModuleName not found in gallery. Cannot install."

            }
        }
    }
}

Import-ModuleIfAvailable -ModuleName AADRM
Import-ModuleIfAvailable -ModuleName AzureAD
Import-ModuleIfAvailable -ModuleName AzureADPreview
Import-ModuleIfAvailable -ModuleName MSOnline
Import-ModuleIfAvailable -ModuleName JiraPS
Import-ModuleIfAvailable -ModuleName MicrosoftTeams
