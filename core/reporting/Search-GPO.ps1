<#
.SYNOPSIS
Searches Group Policy Objects for a text match in their XML reports.

.DESCRIPTION
Imports the GroupPolicy module, enumerates all GPOs in the current user domain,
and returns display names of GPOs whose XML report contains the provided string.

.PARAMETER String
Text to search for inside each GPO XML report.

.EXAMPLE
Search-GPO -String "firewall"

.NOTES
Requires RSAT Group Policy tools and permission to read GPO reports.
#>

#########################################################
#
# Name: Search-GPOs.ps1
# Author: Tony Murray
# Version: 1.0
# Date: 13/07/2016
# Comment: Simple search for GPOs within a domain
# that match a given string
########################################################

Function Search-GPO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, HelpMessage = "Specify the string to search for within the GPOs.")]
        [ValidateNotNullOrEmpty()]
        [string]$String
    )

    Begin {
        # Set the domain to search for GPOs
        $DomainName = $env:USERDNSDOMAIN

        # Import the GroupPolicy module
        Try {
            Import-Module GroupPolicy -ErrorAction Stop
        } Catch {
            Write-Warning "Failed to import GroupPolicy module: $_"
            Break
        }

        # Initialize the matched GPO list
        [string[]]$MatchedGPOList = @()
    }

    Process {
        # Find all GPOs in the current domain
        Write-Verbose "Searching for GPOs in domain: $DomainName" -Verbose
        $allGposInDomain = Get-GPO -All -Domain $DomainName

        # Look through each GPO's XML for the string
        foreach ($gpo in $allGposInDomain) {
            $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml

            if ($report -match $String) {
                Write-Verbose "Match found in GPO: $($gpo.DisplayName)" -Verbose
                $MatchedGPOList += $gpo.DisplayName
            }
        }

        # Output the matched GPOs
        if ($MatchedGPOList.Count -gt 0) {
            Write-Information "Matched GPOs:" -InformationAction Continue
            $MatchedGPOList | ForEach-Object { Write-Information $_ -InformationAction Continue }
        } else {
            Write-Warning "No GPOs matched the search string."
        }
    }

    End {
        Write-Verbose "Search completed." -Verbose
    }
}

# Example usage:
# Search-GPO -String "example"