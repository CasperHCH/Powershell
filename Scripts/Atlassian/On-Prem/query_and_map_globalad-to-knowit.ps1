#requires -version 4
<#
.SYNOPSIS
	<Overview of script>
.DESCRIPTION
	<Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
	<Inputs if any, otherwise state None>
.OUTPUTS
	<Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        unknown
  Author:         mira.ojamo@knowit.fi
  Creation Date:  unknown
  Purpose/Change: rename usernames within on-prem atlassian app, but match KnowIT UPN
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
#---------------------------------------------------------[Script Parameters]------------------------------------------------------

[CmdletBinding(SupportsShouldProcess)]
param(
    [PSCredential]
    $knowit,
    [PSCredential]
    $globalad,
    [PSCredential]
    $adware,
    $jirapat,
    $confluencepat,
    $adwareGroupOU = ,
    $knowitlocalPrefix = ,
    [switch]
    $VeryVerbose,
    [switch]
    $UsersAndGroupsCache,
    [switch]
    $MappingCache,
    [switch]
    $createAdwareGroups,
    [switch]
    $populateKnowitGroups,
    [switch]
    $changeJiraUsernames,
    [switch]
    $onlyLocalPrep,
    [switch]
    $skipDataProcessing,
    [switch]
    $skipArchivalCheck,
    $PreviousData,
    $jirabaseurl = , 				#Jira URL
    $confluencebaseurl = , 	#Confluence URL
    $knowitdc = @(, ), 			#KnowIT Domain controllers
    $adwaredc = @(, ), 		#Customer AD's
    $globaladdc = @(, , ), 			#Old-on-prem AD's
    $transcriptpath = 
)
$Host.PrivateData.WarningForegroundColor = 
# We want info outputs always as it won't get passed to return values
$InformationPreference = 
$VerbosePreference = 
if ($host.UI.RawUI.WindowSize.Width -lt 170) {
    Write-Information 
}
#region Lazy parameter validation
while ($null -eq $knowit) {
    $knowit = Get-Credential -Message 
}
while ($null -eq $globalad) {
    $globalad = Get-Credential -Message 
}
while ($null -eq $adware) {
    $adware = Get-Credential -Message 
}
while ($null -eq $jirapat) {
    Write-Host 
    $jirapat = Read-Host 
}
while ($null -eq $confluencepat) {
    Write-Host 
    $confluencepat = Read-Host 
}
#endregion
Start-Transcript -Path yyyy-MM-dd_HH.mm.ss | out-null
$starttime = Get-Date
Write-Information yyyy-MM-dd HH:mm:ss.fff


#If group naming is longer than 63 characters, they need to be added here;
$longGroupNameMap = @{
     = 
     = 
            = 
            = 
        = 
           = 
           = 
                  = 
                  = 
              = 
}

#needs clarification
$specialgroups = @(, , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , , )

#Removal of nested groups / Flatening the group tree
Function Get-ADUserNestedGroups {
    [CmdletBinding()]
    Param
    (
        $group,
        [System.Collections.ArrayList]$Groups,
        $filter,
        $session,
        $intent = ,
        [switch]$dnonly,
        [switch]$VeryVerbose
    )
    if ($group.GetType().Name -eq ) {
        if ($group -match ) {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose 
            }
            $group = invoke-command -session $session -ScriptBlock { Get-ADgroup ($Using:group) -Properties memberOf, DistinguishedName }
        }
        else {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose 
            }
            $group = invoke-command -session $session -ScriptBlock { Get-ADgroup -identity ($Using:group) -Properties memberOf, DistinguishedName }
        }
    }
    Write-Verbose , - filter $filter, match $( -f ($group.DistinguishedName -match $filter))
    if ($null -ne $filter) {
        if ($group.DistinguishedName -match $filter) {
            if ($Group.DistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
                $Groups.Add($group) | Out-Null
            }
        }
    }
    else {
        if ($Group.DistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
            $Groups.Add($group) | Out-Null
        }
    }

    if ($null -ne $group.memberOf -or $group.memberOf.count -gt 0) {
        #Enummurate through each of the groups.
        Foreach ($GroupDistinguishedName in $group.memberOf) {
            if ($VeryVerbose.IsPresent) {
                Write-Verbose ,
            }
            if ($GroupDistinguishedName -notin $(if ($dnonly.IsPresent) { $Groups }else { $Groups.DistinguishedName })) {
                #Get member of groups from the enummerated group.
                $ThisGroup = invoke-command -session $session -ScriptBlock { Get-ADgroup $Using:GroupDistinguishedName -Properties memberOf, DistinguishedName }
                if ($VeryVerbose.IsPresent) {
                    Write-Verbose 
                }
                #Get recursive groups.
                $ThisGroup.memberOf | foreach-object {
                    if ($VeryVerbose.IsPresent) {
                        Write-Verbose ,
                    }
                    Get-ADUserNestedGroups -group $_ -Groups $Groups -session $session -filter $filter -intent  -VeryVerbose:$($VeryVerbose.IsPresent) -Verbose:$($VerbosePreference -eq ) -dnonly:$dnonly.IsPresent | ForEach-Object -Process { if (-not $Groups.Contains($_)) { $Groups.Add($_) } } | Out-Null
                    if ($VeryVerbose.IsPresent) {
                        Write-Verbose ,
                    }
                }
            }
            else {
                if ($VeryVerbose.IsPresent) {
                    Write-Verbose 
                }
            }
            if ($VeryVerbose.IsPresent) {
                Write-Verbose ,
            }
        }
    }

    if ($dnonly.IsPresent) {
        $ret = $Groups.DistinguishedName
    }
    else {
        $ret = $Groups
    }
    Return $ret
}


            elseif ($pipe.$field -in $array) {
                $pipe
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq  -and $pipe.$field -eq $string) {
            $pipe
        }
        elseif ($multidimensional.IsPresent -and $pipe.$array.$field -eq $string) {
            $pipe
        }
    }
}

#region Preparation & Connectivity tests
$pssessionoptions = new-pssessionoption -OpenTimeout 10000 -CancelTimeout 10000 -OperationTimeout 10000 -MaxConnectionRetryCount 3 -NoCompression -NoMachineProfile


$dcsok = @{
    knowit   = [system.Collections.ArrayList]@()
    globalad = [system.collections.ArrayList]@()
    adware   = [system.collections.ArrayList]@()
}
$connectivityerrors = [System.Collections.ArrayList]@()

Write-Information yyyy-MM-dd HH:mm:ss.fff
foreach ($dc in $knowitdc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser -Filter  -Server $ip -Credential $knowit
        }
        catch {
            $connectivityerrors.Add() | Out-Null
        }
        if ($null -ne $test) {
            Write-Information 
            $dcsok.knowit.Add($ip) | Out-Null
        }
        else {
            Write-Warning 
        }
        $test = $null
    }
}
foreach ($dc in $globaladdc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser ($globalad.UserName -split )[1] -Server $ip -Credential $globalad
        }
        catch {
            $connectivityerrors.Add() | Out-Null
        }
        if ($null -ne $test) {
            Write-Information 
            $dcsok.globalad.Add($ip) | Out-Null
        }
        else {
            Write-Warning 
        }
        $test = $null
    }
}
foreach ($dc in $adwaredc) {
    try {
        $dcip = [array][System.Net.Dns]::GetHostEntry($dc).addresslist.ipaddresstostring
    }
    catch {
        $dcip = @($dc)
    }
    foreach ($ip in $dcip) {
        try {
            $test = Get-ADUser ($adware.UserName -split )[1] -Server $ip -Credential $adware
        }
        catch {
            $connectivityerrors.Add() | Out-Null
        }
        if ($null -ne $test) {
            Write-Information 
            $dcsok.adware.Add($ip) | Out-Null
        }
        else {
            Write-Warning 
        }
        $test = $null
    }
}
try {
    $jiratokentest = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Get -ErrorAction Stop -verbose:$false
}
catch {
    $connectivityerrors.Add() | Out-Null
}

if ($dcsok.knowit.count -gt 0 -and $dcsok.globalad.count -gt 0 -and $dcsok.adware.count -gt 0 -and $null -ne $jiratokentest) {
    Write-Information yyyy-MM-dd HH:mm:ss.fff`nCatched connectivity issues:`n- $($connectivityerrors -join )`n`n
    Write-Information yyyy-MM-dd HH:mm:ss.fff
}
else {
    Write-Error 
    Write-Information yyyy-MM-dd HH:mm:ss.fff`nCatched connectivity issues:`n- $($connectivityerrors -join )`n`n
    exit
}
#endregion

$gaserver = $dcsok.globalad[0]
$knowitserver = $dcsok.knowit[0]
Write-Verbose yyyy-MM-dd HH:mm:ss.fff
$gadsession = new-pssession -ComputerName $gaserver -Credential $globalad -EnableNetworkAccess -SessionOption $pssessionoptions
$knowitsession = new-pssession -ComputerName $knowitserver -Credential $knowit -EnableNetworkAccess -SessionOption $pssessionoptions

$perfmetrics = @{
    GroupDiscovery     = $null
    MemberDiscovery    = $null
    UPNDiscovery       = $null
    GroupMapping       = $null
    DataCombine        = $null
    JiraUsernameChange = $null
    DataCoherencyCheck = $null
    PopulateGroups     = $null
}

#region Query group and user data separately
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $UsersAndGroupsCache.IsPresent) {
    $g = [System.Collections.ArrayList]@()
    #region Discover global.ad groups and recursive memberships
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $stopwatch.Restart()
    $gad = [System.Collections.ArrayList]@()
    invoke-command -session $gadsession -ScriptBlock { Get-ADGroup -SearchBase  -filter  } | Where-Object { $_.DistinguishedName -match  } | ForEach-Object -process { Get-ADUserNestedGroups -group $_ -session $gadsession -intent  -Groups $gad -dnonly -Verbose:$($VerbosePreference -eq ) -VeryVerbose:$($VeryVerbose.IsPresent) | ForEach-Object -Process { if (-not $gad.Contains($_)) { $gad.Add($_) } } } | Out-Null
    # Handling oddities by hand - These groups are used in various places
    invoke-command -session $gadsession -ScriptBlock { $Using:specialgroups | Foreach-Object -Process { Get-ADGroup $_ } } | ForEach-Object -process { Get-ADUserNestedGroups -group $_ -session $gadsession -intent  -Groups $gad -dnonly -Verbose:$($VerbosePreference -eq ) -VeryVerbose:$($VeryVerbose.IsPresent) | ForEach-Object -Process { if (-not $gad.Contains($_)) { $gad.Add($_) } } } | Out-Null
    $gad = $gad | Where-Object { $_ -notmatch  } | Sort-Object -Unique
    $perfmetrics.GroupDiscovery = $stopwatch.Elapsed
    Write-verbose yyyy-MM-dd HH:mm:ss.fff
    $stopwatch.Restart()
    $groupcount = $gad.Count
    $groupmembermap = @{}
    $groupmemberships = $gad | Foreach-Object {
        $g.Add([PSCustomObject]@{
                Name        = ((([string]$_).substring(3) -split )[0])
                Description = (invoke-command -session $gadsession -ScriptBlock { Get-ADGroup ([string]$Using:_) -Properties Description }).Description
            }) | Out-Null
        $groupquerystart = $stopwatch.ElapsedMilliseconds
        $groupdata = invoke-command -session $gadsession -ScriptBlock { Get-ADGroupMember -identity ([string]$Using:_) -Recursive }
        $groupquery = $stopwatch.ElapsedMilliseconds - $groupquerystart
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f (([string]$_).substring(3) -split )[0], @($groupdata).count, $gad.IndexOf($_), $groupcount, ($null -eq $groupdata), $groupquery)
        [PSCustomObject]@{
            Group   = $((([string]$_).substring(3) -split )[0])
            members = $groupdata
        }
        if ($null -eq $groupmembermap.((([string]$_).substring(3) -split )[0])) {
            $groupmembermap += @{((([string]$_).substring(3) -split )[0]) = $groupdata }
        }
    }
    $stopwatch.Stop()
    $perfmetrics.MemberDiscovery = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
    #endregion
    $allusers = $groupmemberships.members | Sort-Object SAMAccountName -Unique
    $membercount = $allusers.count
    $usermap = @{}
    $i = 0
    $stopwatch.Restart()
    $users = $allusers | `
        Foreach-Object -process {
        $i++
        $userquerystart = $stopwatch.ElapsedMilliseconds
        $user = invoke-command -session $gadsession -ScriptBlock { get-aduser ($Using:_).DistinguishedName -Properties proxyaddresses, memberOf, mail }
        $userquery = $stopwatch.ElapsedMilliseconds - $userquerystart
        if ($user.enabled -eq $false) {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $_.samaccountname, , $i, $membercount, $userquery)
        }
        elseif ($user.Name -match ) {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $_.samaccountname, $user.Name, , $i, $membercount, $userquery)
        }
        else {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $_.samaccountname, $user.Name, , $i, $membercount, $userquery)
            [PSCustomObject]@{
                User = $user
                smtp = 
            }
        }
    } | ForEach-Object -process {
        #region Try to query and match global.ad user to knowit.local user using various methods
        $userdiscoverystart = $stopwatch.ElapsedMilliseconds
        if (-not $onlyLocalPrep.IsPresent) {
            $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
            $foundwith = 
            if ($null -ne $knowituser) {
                # ~80% can be found with proxy. But not all.
                $foundwith = 
            }
            # It was part of the ~20%? Alright, time for freaking brute forcing >_<
            if ($null -eq $knowituser -and $null -ne $_.user.mail -and $_.user.mail -match ) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.samaccountname) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            # Apparently the old email gets stored into this attribute in some instances
            if ($null -eq $knowituser -and $null -ne $_.user.mail) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            # As a last resort, try with name. There isn't that many people with same name in the size of our group, right? Right?!
            if ($null -eq $knowituser) {
                $knowituser = invoke-command -session $knowitsession -ScriptBlock { get-aduser -filter  -Properties mail, manager }
                if ($null -ne $knowituser) {
                    $foundwith = 
                }
            }
            if ($knowituser.count -gt 1) {
                # This might do incorrect mappings but duplicates doesn't map anything
                $knowituser = $knowituser[0]
            }
        }
        else {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff)
            $knowituser = $null
        }
        $userdiscovery = $stopwatch.ElapsedMilliseconds - $userdiscoverystart
        #endregion
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f , $_.User.UserPrincipalName, $knowituser.UserPrincipalName, $knowituser.samaccountname, $($null -ne $knowituser), $foundwith, $userdiscovery)
        [PSCustomObject]@{
            GAUser     = $_.User
            GAsmtp     = $_.smtp
            KnowitUser = $knowituser
            KnowitSam  = $knowituser.samaccountname
            KnowitUPN  = $knowituser.UserPrincipalName
            Foundwith  = $foundwith
        }
        if ($null -ne $knowituser) {
            $usermap.($_.User.DistinguishedName) = $knowituser.UserPrincipalName
        }

    }
    $stopwatch.Stop()
    $perfmetrics.UPNDiscovery = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
}
else {
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $users = $PreviousData.UserData
    $groupmemberships = $PreviousData.GroupData
    $g = $PreviousData.G
    $groupmembermap = $PreviousData.GroupMemberMap
    $usermap = $PreviousData.UserMap
}
#endregion
#region Map the group and user data together
if (-not $MappingCache.IsPresent) {
    Write-verbose yyyy-MM-dd HH:mm:ss.fff
    $stopwatch.Restart()
    try {
        $userswithgroups = foreach ($user in $users) {
            #$groups = $($_.GAUser.memberof | foreach-object { Get-ADUserNestedGroups -group $_ -filter  -session $gadsession -intent ( -f $_.gauser.samaccountname) -Verbose:$VerboseGroupSearch.IsPresent }).Name
            $start = $stopwatch.ElapsedMilliseconds
            $groups = ($groupmemberships | FilterUPN -string $user.gauser.DistinguishedName -field distinguishedname -array members -multidimensional).group # Where-Object { $_.members.Distinguishedname -contains $user.gauser.DistinguishedName }).group
            $filterperf = $stopwatch.ElapsedMilliseconds - $start
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $user.GAUser.Name, $groups.count, $filterperf)
            [PSCustomObject]@{
                GAUser     = $user.GAUser
                GAGroups   = $groups
                GAsmtp     = $user.GAsmtp
                KnowitUser = $user.KnowitUser
                KnowitSam  = $user.KnowitSam
                KnowitUPN  = $user.KnowitUPN
                Foundwith  = $user.Foundwith
            }
        }
    }
    catch {
        Write-error -ErrorAction continue -Message yyyy-MM-dd HH:mm:ss.fff
    }
    $stopwatch.Stop()
    $perfmetrics.GroupMapping = $stopwatch.Elapsed
    $stopwatch.Restart(); $stopwatch.Stop()
}
else {
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $userswithgroups = $PreviousData.UserDataWithGroups
}
#endregion

#region Main data parsing
$noKnowit = $users | Where-Object { $_.KnowitUser -eq $null }
$newemployees = $users | Where-Object { $_.GAUser.proxyaddresses -eq $null }

$createdAdwaregroups = [System.Collections.ArrayList]@()
$groupnamemax = ($g.name | Measure-Object -Maximum -Property Length).Maximum
$adwserver = ($dcsok.adware[0])
Write-Verbose yyyy-MM-dd HH:mm:ss.fff
$adwaresession = new-pssession -ComputerName $adwserver -Credential $adware -EnableNetworkAccess -SessionOption $pssessionoptions
$CSVs = [System.Collections.ArrayList]@()
Write-verbose yyyy-MM-dd HH:mm:ss.fff
$lookup = @{}
$cache = @{
    Jira       = @{}
    Confluence = @{}
    Bitbucket  = @{}
    Insight    = @{}
}
$stopwatch.Restart()
if (-not $skipDataProcessing.IsPresent) {
    foreach ($gagroup in $g) {
        $usedDefaultOwners = $false
        $isOwnerGroup = $false
        if ($gagroup.name -match ) {
            $newname = ($matches[] -replace , ) -replace , 
            $isOwnerGroup = $true
        }
        else {
            $newname = ($gagroup.name -replace , $knowitlocalPrefix) -replace , 
        }
        if ($newname -notmatch ) {
            # Special group, handling now
            $charreplace = $gagroup.name -replace '[ /_]', '-' -replace ,  -replace ,  -replace '[()]', '' -replace ,
            $newname = 
        }
        if ($newname -match ) {
            $newname = $newname -replace , 
        }
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $gagroup.Name, $newname)
        #region Check archival status from relevant system
        $archivalstart = $stopwatch.ElapsedMilliseconds
        if (-not $skipArchivalCheck.IsPresent -and $gagroup.name -match ) {
            if ($gagroup.name -match ) {
                Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                $projectinfo = $null
                $roledata = $null
                $project = ($gagroup.name -split )[2]
                if ($null -eq $cache.Jira.$project) {
                    Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                    $success = $true
                    try {
                        $projectinfo = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Get -verbose:$false
                    }
                    catch {
                        $success = $false
                    }
                    if ($success) {
                        $roledata = $projectinfo.roles. | ForEach-Object {
                            Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                            try {
                                Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Get -verbose:$false
                            }
                            catch {}
                        }
                    }
                    $cache.Jira += @{
                        $project = @{
                            archived    = (-not $success)
                            projectinfo = $projectinfo
                            roleinfo    = $roledata
                        }
                    }
                }
                if ($cache.Jira.$project.archived) {
                    Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                }
                if ($null -ne $cache.Jira.$project.roleinfo.actors -and $gagroup.name -notin $cache.Jira.$project.roleinfo.actors.displayname) {
                    Write-Warning (yyyy-MM-dd HH:mm:ss.fff -f , $gagroup.name)
                }
            }
            elseif ($gagroup.name -match ) {
                Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                $spaceinfo = $null
                #$roledata = $null
                $space = ($gagroup.name -split )[2]
                if ($null -eq $cache.Confluence.$space) {
                    Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                    $success = $true
                    try {
                        $spaceinfo = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Get -verbose:$false
                    }
                    catch {
                        $success = $false
                    }
                    $cache.Confluence.$space += @{
                        $space = @{
                            archived  = (-not $success)
                            spaceinfo = $spaceinfo
                        }
                    }
                }
                if ($cache.Confluence.$space.archived) {
                    Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
                }
            }
            elseif ($gagroup.name -match ) {
                Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )

            }
            elseif ($gagroup.name -match ) {
                Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )

            }
            else {
                Write-verbose (yyyy-MM-dd HH:mm:ss.fff -f )
            }
        }
        $archivalstop = $stopwatch.ElapsedMilliseconds
        #endregion

        #TODO: Add project lead to owner group. If user is not valid, check if all the project users have same manager and if they do, add that manager as owner. Otherwise, don't process.

        $adwarestart = $stopwatch.ElapsedMilliseconds
        if ($createAdwareGroups.IsPresent) {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $newname)
            If ($PSCmdlet.ShouldProcess(yyyy-MM-dd HH:mm:ss.fff, $gagroup.name, )) {
                $createdAdwaregroups.Add($(invoke-command -session $adwaresession -ScriptBlock {
                            if ($null -eq $(Get-ADGroup -SearchBase $Using:adwareGroupOU -Filter )) {
                                try {
                                    New-ADGroup -Name $Using:newname -SamAccountName ($Using:gagroup).name -DisplayName ($Using:gagroup).name -GroupCategory Security -GroupScope Global -Description  -Path $Using:adwareGroupOU -PassThru
                                }
                                catch {}
                            }
                        })) | Out-Null
            }
        }
        $adwarestop = $stopwatch.ElapsedMilliseconds
        #region Populate variables: group membership lookup table and CSVs
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f )
        $memberpopulatestart = $stopwatch.ElapsedMilliseconds
        $members = $groupmembermap.($gagroup.name) | ` # The hashtable key is global.ad group name
        Foreach-Object -Process {
            # It's values are output of Get-ADGroupMember - Distinguishedname is the best available field
            # Usermap is another hashtable, which has Global.ad distinguihedname as key and Knowit UPN as value
            if ($null -ne $usermap.($_.DistinguishedName)) {
                [PSCustomObject]@{
                    name   = $newname
                    member = $usermap.($_.DistinguishedName)
                }
            }
        }
        $memberpopulatestop = $stopwatch.ElapsedMilliseconds
        <# Default owners not in use currently
        # Handle default owners
        if ($members.count -eq 0 -and $newname -match ) {
            $usedDefaultOwners = $true
            $members = $defaultOwnersMembers | Foreach-Object {
                [PSCustomObject]@{
                    name   = $newname
                    member = $_
                }
            }
        }
        # #>
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f )
        $groups = [PSCustomObject]@{
            Name        = $newname
            Description = $gagroup.description
        }
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f )
        $lookup.$newname = $members.member
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f )
        $CSVs.Add([PSCustomObject]@{
                NewGroup   = $groups
                NewMembers = $members
            }) | Out-Null
        if ($gagroup.name -notmatch ) {
            Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f )
            # Dirty hack for special groups
            $hackmembers = $groupmembermap.($gagroup.name) | `
                Foreach-Object -Process {
                if ($null -ne $usermap.($_.DistinguishedName)) {
                    [PSCustomObject]@{
                        name   = 
                        member = $usermap.($_.DistinguishedName)
                    }
                }
            }
            $hackgroups = [PSCustomObject]@{
                Name        = $newname
                Description = $gagroup.description
            }
            $lookup. = $hackmembers.member
            $CSVs.Add([PSCustomObject]@{
                    NewGroup   = $hackgroups
                    NewMembers = $hackmembers
                }) | Out-Null
        }
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff[Used default owner? $($usedDefaultOwners -eq $true)] -f , ($archivalstop - $archivalstart), ($adwarestop - $adwarestart), ($memberpopulatestop - $memberpopulatestart))
        #endregion
    }
}
$stopwatch.Stop()
$perfmetrics.DataCombine = $stopwatch.Elapsed
$stopwatch.Restart()
#endregion

#region Handle Jira username changing
$jiraOverlap = [System.Collections.ArrayList]@()
if ($changeJiraUsernames.IsPresent) {
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $users | Where-Object { $_.KnowitUPN -ne $null } | ForEach-Object -Process {
        Write-Verbose yyyy-MM-dd HH:mm:ss.fff
        If ($PSCmdlet.ShouldProcess(yyyy-MM-dd HH:mm:ss.fff, $_.GAUser.SamAccountName, )) {
            $result = $exists = $overlapped = 
            $tries = 0
            do {
                $failed = $false

                #region Handle overlap - check if destination user exists already and rename if it is. And if there's something super odd and even renamed user exists already, do some tricks until renamed or tired 3 times.
                $overlap = $_.KnowitUPN
                $innertries = 0
                do {
                    $innerfailed = $false
                    try {
                        $exists = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Get -ContentType  -ErrorVariable checkerror -verbose:$false
                    }
                    catch {
                        if ($_.exception.response.StatusCode -eq ) {
                            # Expected, continue
                            $exists = $null
                        }
                        else {
                            if ($null -eq $(try { $checkerror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                Write-Warning 
                            }
                            else {
                                $errmsg = $checkerror.message | ConvertFrom-Json
                                if ($errmsg.errormessages -match ) {
                                    # This is expexted
                                    $exists = $null
                                }
                                else {
                                    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                                }
                            }
                        }
                    }
                    if ($null -ne $exists) {
                        if ($exists.key -eq $_.GAUser.SamAccountName) {
                            Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                            return
                        }
                        else {
                            $overlap = 
                            try {
                                $overlapped = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Put -Body $(@{ = $overlap;  = $overlap } | ConvertTo-Json) -ContentType  -ErrorVariable overlaperror -verbose:$false
                            }
                            catch {
                                if ($null -eq $(try { $overlaperror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                                    $innerfailed = $true
                                    Write-Warning 
                                }
                                else {
                                    $errmsg = $overlaperror.message | ConvertFrom-Json
                                    if ($errmsg.errors.username -eq ) {
                                        # Silent retry
                                        $innerfailed = $true
                                        if ($innertries -ge 3) {
                                            Write-Verbose yyyy-MM-dd HH:mm:ss.fff, , 
                                        }
                                    }
                                    else {
                                        Write-Verbose yyyy-MM-dd HH:mm:ss.fff, , 
                                    }
                                }
                            }
                            if ($null -ne $overlapped.name) {
                                $jiraOverlap.Add($overlap) | Out-Null
                            }
                        }
                    }
                    $innertries++
                }while ($innerfailed -and $innertries -lt 4)
                if ($innerfailed) {
                    Write-Warning 
                }
                #endregion

                try {
                    $result = Invoke-RestMethod -Uri  -Headers @{Authorization =  } -Method Put -Body $(@{name = $_.KnowitUPN;  = $_.KnowitUser.mail } | ConvertTo-Json) -ContentType  -ErrorVariable changeerror -verbose:$false
                }
                catch {
                    if ($_.exception.response.StatusCode -eq ) {
                        Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                    }
                    else {
                        # UPN might have been changed to incorrect one already so double-checking
                        $failed = $true
                        if ($null -eq $(try { $changeerror.message | ConvertFrom-Json -ErrorAction stop }catch {})) {
                            Write-Warning 
                        }
                        else {
                            $chngerrmsg = $changeerror.message | ConvertFrom-Json
                            Write-Verbose yyyy-MM-dd HH:mm:ss.fff, , 
                        }
                    }
                }
                if ($null -ne $result -and $result.name -ne $_.KnowitUPN) {
                    Write-Warning 
                }
                $tries++
            }while ($failed -and $tries -lt 4)
            if ($failed) {
                Write-Warning 
            }
        }
    }
}
$perfmetrics.JiraUsernameChange = $stopwatch.Elapsed
#endregion

#region Check the data coherency
Write-information yyyy-MM-dd HH:mm:ss.fff
$stopwatch.Restart()
# This *SHOULD* be empty, as it's handled in the main data processor already, hence, just passing this info to output array
$emptyowners = $CSVs.newgroup | ForEach-Object -Process {
    if ($_.name -match ) {
        Write-Verbose yyyy-MM-dd HH:mm:ss.fff
        if ($lookup.($_.name).count -eq 0) {
            Write-information yyyy-MM-dd HH:mm:ss.fff
            $_.name
        }
    }
}

Write-Verbose yyyy-MM-dd HH:mm:ss.fff
$missingowner = $CSVs.newgroup.name | ForEach-Object -Process { if ($_ -notmatch  -and  -notin $CSVs.newgroup.name) { $_ } }

if ($null -eq $DefaultOwnersMembers) {
    $DefaultOwnersMembers = $defaultOwners.members | Foreach-Object {
        $user = $_
        $userobj = $users | FilterUPN -field DistinguishedName -array GAUser -string $user.DistinguishedName -multidimensional #Where-Object { $_.GAUser.DistinguishedName -eq $user.DistinguishedName }
        if ($null -ne $userobj.KnowitUser) {
            $userobj.KnowitUPN
        }
    }
}

foreach ($missing in $missingowner) {
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $members = $defaultOwnersMembers | Foreach-Object {
        [PSCustomObject]@{
            name   = 
            member = $_
        }
    }
    $lookup. = $members.member
    $groups = [PSCustomObject]@{
        Name        = 
        Description = 
    }
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $CSVs.Add([PSCustomObject]@{
            NewGroup   = $groups
            NewMembers = $members
        }) | Out-Null
}
$stopwatch.Stop()
$perfmetrics.DataCoherencyCheck = $stopwatch.Elapsed
$stopwatch.Restart(); $stopwatch.Stop()
#endregion


Write-Verbose yyyy-MM-dd HH:mm:ss.fff
Remove-PSSession -Session $gadsession -WhatIf:$false | Out-Null
Remove-PSSession -Session $adwaresession -WhatIf:$false | Out-Null

#region Ensure knowit.local group existence and memberships
if ($populateKnowitGroups.IsPresent) {
    Start-Sleep -Seconds 3
    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
    $stopwatch.Restart()
    $createdKnowitGroups = [System.Collections.ArrayList]@()
    $extra = @{}
    # Apparently foreach is actually faster than Where-Object
    $ownergroups = $CSVs.NewGroup | Foreach-Object -Process { if ($_.name -match ) { $_ } }
    $normalgroups = $CSVs.NewGroup | Foreach-Object -Process { if ($_.name -notin $ownergroups.name) { $_ } }
    $orderedgroups = $ownergroups + $normalgroups
    :grouploop foreach ($group in $orderedgroups) {
        Write-Verbose yyyy-MM-dd HH:mm:ss.fff (Shortened to $($longGroupNameMap.($group.name)))
        if ($group.name -notmatch $knowitlocalPrefix) {
            Write-Warning yyyy-MM-dd HH:mm:ss.fff
            continue
        }
        $outertries = 1
        :outercreate do {
            $outerfail = $false
            $groupfound = $true
            $membersfound = $true
            # Handle too long group names
            if ((($group.name -match  -and $group.name.length -gt 64) -or ($group.name -notmatch  -and $group.name.length -gt 58)) -and $null -eq $longGroupNameMap.($group.name)) {
                Write-Warning yyyy-MM-dd HH:mm:ss.fff
                $groupname = $false
                continue grouploop
            }
            elseif ($null -ne $longGroupNameMap.($group.name)) {
                $groupname = $longGroupNameMap.($group.name)
            }
            else {
                $groupname = $group.name
            }
            # Check existence and query members if exists
            $knowitgroupquerystart = $stopwatch.ElapsedMilliseconds
            $adgroupquery = invoke-command -session $knowitsession -ScriptBlock {
                $err = $false
                try {
                    $group = Get-ADGroup ($using:groupname) -ErrorAction Stop
                }
                catch {
                    $err = $_
                }
                return [PSCustomObject]@{Group = $group; Error = $err }
            }

            if ($adgroupquery.Error -ne $false) {
                $groupfound = $false
            }
            else {
                $adgroup = $adgroupquery.Group
            }

            if ($groupfound) {
                $groupmemberquery = invoke-command -session $knowitsession -ScriptBlock {
                    $err = $false
                    try {
                        $members = Get-ADGroupMember ([string]$using:adgroup) -ErrorAction Stop | ForEach-Object { Get-ADUser $_ -ErrorAction Stop }
                    }
                    catch {
                        $err = $_
                    }
                    return [PSCustomObject]@{GroupMembers = $members; Error = $err }
                }
                if ($groupmemberquery.Error -ne $false) {
                    $membersfound = $false
                }
                else {
                    $groupmembers = $groupmemberquery.GroupMembers
                }
            }
            $knowitgroupquery = $stopwatch.ElapsedMilliseconds - $knowitgroupquerystart
            # Yeah, bit clunky way, I know.
            if (-not $groupfound) {
                #region Create and populate missing group
                Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                $innertries = 1
                $adgroup = $null
                :innercreate do {
                    $innerfail = $false
                    if ($groupname -notmatch ) {
                        $ownergroupquery = invoke-command -session $knowitsession -ScriptBlock {
                            $err = $false
                            try {
                                $group = Get-ADGroup  -ErrorAction Stop
                            }
                            catch {
                                $err = $_
                            }
                            return [PSCustomObject]@{Group = $group; Error = $err }
                        }
                        if ($ownergroupquery.Error -ne $false) {
                            Write-Warning yyyy-MM-dd HH:mm:ss.fff
                            $innerfail = $true
                            $adgroupowner = $null
                        }
                        else {
                            $adgroupowner = $ownergroupquery.Group
                        }

                        if ($null -ne $adgroupowner) {
                            $adgroupcreate = invoke-command -session $knowitsession -ScriptBlock {
                                $err = $false
                                try {
                                    $ownergroup = Get-ADGroup ($using:adgroupowner).DistinguishedName -ErrorAction Stop
                                    $newgroup = New-ADGroup -Name $using:groupname -Description ($using:group).Description -Path  -ManagedBy $ownergroup -GroupScope Global -GroupCategory Security -PassThru  -ErrorAction Stop
                                }
                                catch {
                                    $err = $_
                                }
                                return [PSCustomObject]@{NewGroup = $newgroup; Error = $err }
                            }
                        }
                        else {
                            Write-Warning yyyy-MM-dd HH:mm:ss.fff
                        }

                        if ($adgroupcreate.Error -ne $false) {
                            Write-Warning yyyy-MM-dd HH:mm:ss.fff
                            $innerfail = $true
                            $adgroup = $null
                        }
                        else {
                            $adgroup = $adgroupcreate.NewGroup
                        }
                    }
                    else {
                        $adgroupcreate = invoke-command -session $knowitsession -ScriptBlock {
                            $err = $false
                            try {
                                $newgroup = New-ADGroup -Name $using:groupname -Description ($using:group).Description -Path  -GroupScope Global -GroupCategory Security -PassThru -ErrorAction Stop
                            }
                            catch {
                                $err = $_
                            }
                            return [PSCustomObject]@{NewGroup = $newgroup; Error = $err }
                        }
                        if ($adgroupcreate.Error -ne $false) {
                            Write-Warning yyyy-MM-dd HH:mm:ss.fff
                            $innerfail = $true
                            $adgroup = $null
                        }
                        else {
                            $adgroup = $adgroupcreate.NewGroup
                        }
                    }
                    $innertries++
                }while ($innerfail -and $innertries -lt 4)

                if ($null -ne $adgroup.name) {
                    $createdKnowitGroups.Add($adgroup.name) | Out-Null
                    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                    # NOTE: $lookup.($group.name) on lines above and below with dot between group and name is intentional! The lookup doesn't take the too long group names into account, which $groupname does!
                    $start = $stopwatch.ElapsedMilliseconds
                    $queriedusers = $users | FilterUPN -field KnowitUPN -array $lookup.($group.name) #Where-Object { $_.KnowitUPN -in $lookup.($group.name) }
                    $queryperf = $stopwatch.ElapsedMilliseconds - $start
                    Write-verbose yyyy-MM-dd HH:mm:ss.fff
                    if ($queriedusers.count -gt 0) {
                        $grouppopulating = invoke-command -session $knowitsession -ScriptBlock {
                            $VerbosePreference = $using:verbosepreference
                            Write-verbose yyyy-MM-dd HH:mm:ss.fff
                            $localgroup = Get-ADGroup -Identity ($Using:adgroup).DistinguishedName -ErrorVariable groupqueryerror
                            $adderrors = @{UsersNotFound = [System.Collections.ArrayList]@(); GroupError = $groupqueryerror; UserAddError =  }
                            if ($null -eq $localgroup) {
                                Write-Warning yyyy-MM-dd HH:mm:ss.fff
                            }
                            else {
                                Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                $localusers = foreach ($user in ($using:queriedusers).KnowitUser) {
                                    Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                    try {
                                        Get-ADUser -Identity $user.DistinguishedName -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning yyyy-MM-dd HH:mm:ss.fff
                                        $null = $adderrors.UsersNotFound.Add([PSCustomObject]@{User = $user; Error = $_ })
                                    }
                                }
                                Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                if (@($localusers).count -gt 0) {
                                    try {
                                        Add-ADGroupMember -Identity $localgroup -Members $localusers -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning yyyy-MM-dd HH:mm:ss.fff
                                        $adderrors.UserAddError = $_
                                    }
                                }
                            }
                            return [PSCustomObject]@{UsersAdded = @($localusers).count; Errors = $adderrors }
                        }
                    }
                }
                if (-not [string]::IsNullOrWhiteSpace($grouppopulating.Errors.GroupError) -or @($grouppopulating.Errors.UsersNotFound).count -ne 0 -or -not [string]::IsNullOrWhiteSpace($grouppopulating.Errors.UserAddErrors)) {
                    Write-Warning yyyy-MM-dd HH:mm:ss.fff
                    $outerfail = $true
                }
                #endregion
            }
            else {
                #region Populate missing members of existing group
                Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                $missingadded = 0
                $start = $stopwatch.ElapsedMilliseconds
                $queriedusers = foreach ($user in $lookup.($group.name)) {
                    if (-not $membersfound -or $user -notin $groupmembers.UserPrincipalName) {
                        $users | FilterUPN -field KnowitUPN -string $user #Where-Object { $_.KnowitUPN -eq $user }
                    }
                }
                $queryperf = $stopwatch.ElapsedMilliseconds - $start
                if ($queriedusers.count -gt 0) {
                    Write-verbose yyyy-MM-dd HH:mm:ss.fff
                    $addtries = 0
                    do {
                        $addfail = $false
                        $missingadded = invoke-command -session $knowitsession -ScriptBlock {
                            $VerbosePreference = $using:verbosepreference
                            Write-verbose yyyy-MM-dd HH:mm:ss.fff
                            $localgroup = Get-ADGroup -Identity ($Using:adgroup).DistinguishedName -ErrorVariable groupqueryerror
                            $adderrors = @{UsersNotFound = [System.Collections.ArrayList]@(); GroupError = $groupqueryerror; UserAddError =  }
                            if ($null -eq $localgroup) {
                                Write-Warning yyyy-MM-dd HH:mm:ss.fff
                            }
                            else {
                                Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                $localusers = foreach ($user in ($using:queriedusers).KnowitUser) {
                                    Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                    try {
                                        Get-ADUser -Identity $user.DistinguishedName -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning yyyy-MM-dd HH:mm:ss.fff
                                        $null = $adderrors.UsersNotFound.Add([PSCustomObject]@{User = $user; Error = $_ })
                                    }
                                }
                                Write-verbose yyyy-MM-dd HH:mm:ss.fff
                                if (@($localusers).count -gt 0) {
                                    try {
                                        Add-ADGroupMember -Identity $localgroup -Members $localusers -ErrorAction Stop
                                    }
                                    catch {
                                        Write-Warning yyyy-MM-dd HH:mm:ss.fff
                                        $adderrors.UserAddError = $_
                                    }
                                }
                            }

                            return [PSCustomObject]@{UsersAdded = @($localusers).count; Errors = $adderrors }
                        }
                        if (-not [string]::IsNullOrWhiteSpace($missingadded.Errors.GroupError) -or @($missingadded.Errors.UsersNotFound).count -ne 0 -or -not [string]::IsNullOrWhiteSpace($missingadded.Errors.UserAddErrors)) {
                            Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                            $addfail = $true
                        }
                        $addtries++
                        Write-Debug 
                    }while ($addfail -and $addtries -lt 4)
                    Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                }
                $extramembers = [System.Collections.ArrayList]@()
                foreach ($user in $groupmembers) {
                    if ($user.UserPrincipalName -notin $lookup.($group.name)) {
                        $extramembers.Add($user.UserPrincipalName) | Out-Null
                    }
                }
                if ($null -eq $extra.($group.name)) {
                    $extra += @{$group.name = $extramembers }
                }
                else {
                    $extra.($group.name) = $extramembers
                }
                Write-Verbose yyyy-MM-dd HH:mm:ss.fff
                #endregion
            }
            $outertries++
        }while ($outerfail -and $innerfail -and $outertries -lt 4)
        Write-Verbose (yyyy-MM-dd HH:mm:ss.fff -f $knowitgroupquery, $queryperf)
    }
}
$perfmetrics.PopulateGroups = $stopwatch.Elapsed
$stopwatch.Stop()
#endregion

$returndata = [PSCustomObject]@{
    CSVs                = $CSVs
    UserData            = $users
    UserDataWithGroups  = $userswithgroups
    GroupData           = $groupmemberships
    NoKnowit            = $noKnowit
    CreatedAdwaregroups = $createdAdwaregroups
    CreatedKnowitGroups = $createdKnowitGroups
    ExtraMembers        = $extra
    NewEmployees        = $newemployees
    LookupTable         = $lookup
    EmptyOwnersGroup    = $emptyowners
    MissingOwnersGroup  = $missingowner
    Cache               = $cache
    PerfMetrics         = $perfmetrics
    G                   = $g
    GroupMemberMap      = $groupmembermap
    UserMap             = $usermap
}

Remove-PSSession $knowitsession -WhatIf:$false | Out-Null

Write-Information yyyy-MM-dd HH:mm:ss.fff

Stop-Transcript | out-null

return $returndata
