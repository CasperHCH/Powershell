function Get-ADGroupMembers {
    <#
    .SYNOPSIS
        Gets all members of an Active Directory group with detailed information.

    .DESCRIPTION
        This function retrieves all members of an Active Directory group and displays
        their basic information including name, title, and other properties.

    .PARAMETER Identity
        The name or distinguished name of the AD group to query.

    .EXAMPLE
        Get-ADGroupMembers -Identity "Domain Admins"

    .EXAMPLE
        Get-ADGroupMembers -Identity "CN=IT Support,OU=Groups,DC=domain,DC=com"
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, Position=0)]
        [String]$Identity
    )

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $GroupMembers = Get-ADGroupMember -Identity $Identity -ErrorAction Stop

        $Results = foreach ($Member in $GroupMembers) {
            if ($Member.objectClass -eq "user") {
                $UserDetails = Get-ADUser $Member.distinguishedName -Properties Title, Department, EmailAddress -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    Name = $Member.Name
                    SamAccountName = $Member.SamAccountName
                    Title = $UserDetails.Title
                    Department = $UserDetails.Department
                    EmailAddress = $UserDetails.EmailAddress
                    ObjectClass = $Member.objectClass
                    DistinguishedName = $Member.distinguishedName
                }
            } else {
                [PSCustomObject]@{
                    Name = $Member.Name
                    SamAccountName = $Member.SamAccountName
                    Title = "N/A (Not User)"
                    Department = "N/A"
                    EmailAddress = "N/A"
                    ObjectClass = $Member.objectClass
                    DistinguishedName = $Member.distinguishedName
                }
            }
        }

        return $Results | Sort-Object Name

    } catch {
        Write-Error "Failed to get group members for '$Identity': $($_.Exception.Message)"
    }
}

# If running as script (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Get-ADGroupMembers @PSBoundParameters
}
