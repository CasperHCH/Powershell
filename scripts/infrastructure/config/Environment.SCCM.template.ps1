<#
.SYNOPSIS
    Variable-driven SCCM-focused infrastructure manifest template.

.DESCRIPTION
    Edit the variables in the first section of this file, then use the file as the
    manifest input for SCCM infrastructure scripts. The script returns a hashtable,
    which is supported by Import-InfrastructureManifest.
#>

$organizationName = 'Contoso'
$organizationDomain = 'contoso.com'
$netBiosName = 'CONTOSO'

$environmentName = 'Lab'
$changeTicket = 'CHG-000000'
$outputRoot = 'C:\InfrastructureAutomation\SCCM'
$regionName = 'PrimaryLab'
$timeZone = 'UTC'

$siteCode = 'P01'
$siteServerHost = 'sccm01'
$sqlServerHost = 'sql01'
$managementPointHost = 'sccm01'
$softwareUpdatePointHost = 'sccm01'
$distributionPointHosts = @('sccm01', 'sccm-dp01')

$hqSubnet = '192.168.10.0/24'
$branchSubnet = '192.168.20.0/24'

$siteServerFqdn = "$siteServerHost.$organizationDomain"
$sqlServerFqdn = "$sqlServerHost.$organizationDomain"
$managementPointFqdn = "$managementPointHost.$organizationDomain"
$softwareUpdatePointFqdn = "$softwareUpdatePointHost.$organizationDomain"
$distributionPointFqdns = @($distributionPointHosts | ForEach-Object { "$_.$organizationDomain" })

$distinguishedName = 'DC=contoso,DC=com'
$contentShareRoot = "\\$siteServerFqdn"

@{
    Organization = @{
        Name = $organizationName
        Domain = $organizationDomain
        NetBIOSName = $netBiosName
    }

    Environment = @{
        Name = $environmentName
        ChangeTicket = $changeTicket
        OutputRoot = $outputRoot
        Region = $regionName
        TimeZone = $timeZone
    }

    Network = @{
        DnsServers = @('192.168.10.10', '192.168.10.11')
        DnsForwarders = @('1.1.1.1', '8.8.8.8')
        NtpServers = @('time.windows.com', 'pool.ntp.org')
        Sites = @(
            @{
                Name = 'HQ'
                Subnets = @($hqSubnet)
            },
            @{
                Name = 'Branch01'
                Subnets = @($branchSubnet)
            }
        )
    }

    ServiceAccounts = @{
        SccmSqlService = "$netBiosName\\svc-sccm-sql"
        SccmNetworkAccess = "$netBiosName\\svc-sccm-naa"
        PkiEnrollment = "$netBiosName\\svc-pki-enroll"
    }

    ActiveDirectory = @{
        ForestMode = 'WinThreshold'
        DomainMode = 'WinThreshold'
        InstallDns = $true
        CreateDnsDelegation = $false
        DatabasePath = 'C:\Windows\NTDS'
        LogPath = 'C:\Windows\NTDS'
        SysvolPath = 'C:\Windows\SYSVOL'
        DomainDistinguishedName = $distinguishedName
        DomainControllers = @(
            @{
                ServerName = "dc01.$organizationDomain"
                SiteName = 'HQ'
                IpAddress = '192.168.10.10'
            }
        )
        OrganizationalUnits = @()
        BaselineGroups = @()
        GpoBaselines = @()
    }

    PKI = @{
        RootCACommonName = "$organizationName Root CA"
        IssuingCACommonName = "$organizationName Issuing CA 01"
        RootCAServer = "pkiroot01.$organizationDomain"
        IssuingCAServer = "pkica01.$organizationDomain"
        CdpUrl = "http://pki.$organizationDomain/pki/<CaName><CRLNameSuffix>.crl"
        AiaUrl = "http://pki.$organizationDomain/pki/<ServerDNSName>_<CaName><CertificateName>.crt"
        ValidityYears = 10
        KeyLength = 4096
        PublishUrls = @(
            "http://pki.$organizationDomain/pki/"
        )
        CertificateTemplates = @(
            'WebServer',
            'Computer',
            'User'
        )
    }

    SCCM = @{
        SiteCode = $siteCode
        SiteServer = $siteServerFqdn
        SqlServer = $sqlServerFqdn
        SqlInstance = 'MSSQLSERVER'
        DatabaseName = "CM_$siteCode"
        SoftwareUpdatePoint = $softwareUpdatePointFqdn
        ManagementPoint = $managementPointFqdn
        Roles = @(
            'ManagementPoint',
            'DistributionPoint',
            'SoftwareUpdatePoint'
        )
        DistributionPoints = @(
            @{
                ServerName = $distributionPointFqdns[0]
                SiteSystemRoles = @('DistributionPoint', 'ManagementPoint', 'SoftwareUpdatePoint')
            },
            @{
                ServerName = $distributionPointFqdns[1]
                SiteSystemRoles = @('DistributionPoint')
            }
        )
        BoundaryGroups = @(
            @{
                Name = 'BG-HQ'
                SiteAssignment = $true
                SiteSystems = @($distributionPointFqdns[0])
                BoundaryNames = @('HQ-Subnet')
            },
            @{
                Name = 'BG-Branch01'
                SiteAssignment = $true
                SiteSystems = @($distributionPointFqdns[1])
                BoundaryNames = @('Branch01-Subnet')
            }
        )
        Boundaries = @(
            @{
                Name = 'HQ-Subnet'
                Type = 'IPSubnet'
                Value = $hqSubnet
            },
            @{
                Name = 'Branch01-Subnet'
                Type = 'IPSubnet'
                Value = $branchSubnet
            }
        )
        StandardCollections = @(
            @{
                Name = 'All Workstations - Managed'
                LimitingCollection = 'All Systems'
                Comment = 'Baseline workstation collection'
                MembershipRules = @{
                    QueryRules = @(
                        @{
                            Name = 'Workstations by Operating System'
                            QueryExpression = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like '%Workstation%'"
                        }
                    )
                    IncludeCollections = @()
                    ExcludeCollections = @()
                }
            },
            @{
                Name = 'All Servers - Managed'
                LimitingCollection = 'All Systems'
                Comment = 'Baseline server collection'
                MembershipRules = @{
                    QueryRules = @(
                        @{
                            Name = 'Servers by Operating System'
                            QueryExpression = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like '%Server%'"
                        }
                    )
                    IncludeCollections = @()
                    ExcludeCollections = @()
                }
            },
            @{
                Name = 'Pilot - Workstations'
                LimitingCollection = 'All Workstations - Managed'
                Comment = 'Pilot deployment ring'
                MembershipRules = @{
                    QueryRules = @(
                        @{
                            Name = 'Pilot Workstations by Name'
                            QueryExpression = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Name like 'PILOT-%'"
                        }
                    )
                    IncludeCollections = @()
                    ExcludeCollections = @('All Servers - Managed')
                }
            }
        )
        SourcePaths = @{
            ContentLibrary = "$contentShareRoot\Sources$"
            DriverSource = "$contentShareRoot\DriverSources$"
            UpdateSource = "$contentShareRoot\Updates$"
        }
    }
}