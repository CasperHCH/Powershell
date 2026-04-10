@{
    Organization = @{
        Name = 'Contoso'
        Domain = 'contoso.com'
        NetBIOSName = 'CONTOSO'
    }

    Environment = @{
        Name = 'Lab'
        ChangeTicket = 'CHG-000000'
        OutputRoot = 'C:\InfrastructureAutomation\Output'
        Region = 'PrimaryLab'
        TimeZone = 'UTC'
    }

    Network = @{
        DnsServers = @('192.168.10.10', '192.168.10.11')
        DnsForwarders = @('1.1.1.1', '8.8.8.8')
        NtpServers = @('time.windows.com', 'pool.ntp.org')
        Sites = @(
            @{
                Name = 'HQ'
                Subnets = @('192.168.10.0/24')
            }
        )
    }

    ServiceAccounts = @{
        SccmSqlService = 'CONTOSO\\svc-sccm-sql'
        SccmNetworkAccess = 'CONTOSO\\svc-sccm-naa'
        PkiEnrollment = 'CONTOSO\\svc-pki-enroll'
    }

    ActiveDirectory = @{
        ForestMode = 'WinThreshold'
        DomainMode = 'WinThreshold'
        InstallDns = $true
        CreateDnsDelegation = $false
        DatabasePath = 'C:\Windows\NTDS'
        LogPath = 'C:\Windows\NTDS'
        SysvolPath = 'C:\Windows\SYSVOL'
        DomainDistinguishedName = 'DC=contoso,DC=com'
        DomainControllers = @(
            @{
                ServerName = 'dc01.contoso.com'
                SiteName = 'Default-First-Site-Name'
                IpAddress = '192.168.10.10'
            },
            @{
                ServerName = 'dc02.contoso.com'
                SiteName = 'Default-First-Site-Name'
                IpAddress = '192.168.10.11'
            }
        )
        OrganizationalUnits = @(
            @{
                Name = 'Tier 0'
                Path = 'DC=contoso,DC=com'
                Description = 'Privileged administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Tier 1'
                Path = 'DC=contoso,DC=com'
                Description = 'Server administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Tier 2'
                Path = 'DC=contoso,DC=com'
                Description = 'Endpoint and user administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Administrative Groups'
                Path = 'OU=Tier 0,DC=contoso,DC=com'
                Description = 'Administrative security groups'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Domain Controllers'
                Path = 'OU=Tier 0,DC=contoso,DC=com'
                Description = 'Domain controller related objects'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Servers'
                Path = 'OU=Tier 1,DC=contoso,DC=com'
                Description = 'Server computer accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Service Accounts'
                Path = 'OU=Tier 1,DC=contoso,DC=com'
                Description = 'Managed service accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Workstations'
                Path = 'OU=Tier 2,DC=contoso,DC=com'
                Description = 'Workstation computer accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Users'
                Path = 'OU=Tier 2,DC=contoso,DC=com'
                Description = 'Standard user accounts'
                ProtectedFromAccidentalDeletion = $true
            }
        )
        BaselineGroups = @(
            @{
                Name = 'GG-T0-Domain-Admins'
                SamAccountName = 'GG-T0-Domain-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 0 domain administration group'
            },
            @{
                Name = 'GG-T1-Server-Admins'
                SamAccountName = 'GG-T1-Server-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 1 server administration group'
            },
            @{
                Name = 'GG-T2-Workstation-Admins'
                SamAccountName = 'GG-T2-Workstation-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 2 workstation administration group'
            },
            @{
                Name = 'GG-SCCM-Admins'
                SamAccountName = 'GG-SCCM-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Configuration Manager administrative group'
            }
        )
        GpoBaselines = @(
            @{
                Name = 'GPO-T0-Domain-Controllers-Baseline'
                TargetPath = 'OU=Domain Controllers,OU=Tier 0,DC=contoso,DC=com'
                Description = 'Security baseline for domain controllers'
            },
            @{
                Name = 'GPO-T1-Servers-Baseline'
                TargetPath = 'OU=Servers,OU=Tier 1,DC=contoso,DC=com'
                Description = 'Security baseline for servers'
            },
            @{
                Name = 'GPO-T2-Workstations-Baseline'
                TargetPath = 'OU=Workstations,OU=Tier 2,DC=contoso,DC=com'
                Description = 'Security baseline for workstations'
            }
        )
    }

    PKI = @{
        RootCACommonName = 'Contoso Root CA'
        IssuingCACommonName = 'Contoso Issuing CA 01'
        RootCAServer = 'pkiroot01.contoso.com'
        IssuingCAServer = 'pkica01.contoso.com'
        CdpUrl = 'http://pki.contoso.com/pki/<CaName><CRLNameSuffix>.crl'
        AiaUrl = 'http://pki.contoso.com/pki/<ServerDNSName>_<CaName><CertificateName>.crt'
        ValidityYears = 10
        KeyLength = 4096
        PublishUrls = @(
            'http://pki.contoso.com/pki/'
        )
        CertificateTemplates = @(
            'WebServer',
            'Computer',
            'User'
        )
    }

    SCCM = @{
        SiteCode = 'P01'
        SiteServer = 'sccm01.contoso.com'
        SqlServer = 'sql01.contoso.com'
        SqlInstance = 'MSSQLSERVER'
        DatabaseName = 'CM_P01'
        SoftwareUpdatePoint = 'sccm01.contoso.com'
        ManagementPoint = 'sccm01.contoso.com'
        Roles = @(
            'ManagementPoint',
            'DistributionPoint',
            'SoftwareUpdatePoint'
        )
        DistributionPoints = @(
            @{
                ServerName = 'sccm01.contoso.com'
                SiteSystemRoles = @('DistributionPoint', 'ManagementPoint', 'SoftwareUpdatePoint')
            }
        )
        BoundaryGroups = @(
            @{
                Name = 'BG-HQ'
                SiteAssignment = $true
                SiteSystems = @('sccm01.contoso.com')
                BoundaryNames = @('HeadOfficeSubnet')
            }
        )
        Boundaries = @(
            @{
                Name = 'HeadOfficeSubnet'
                Type = 'IPSubnet'
                Value = '192.168.10.0/24'
            }
        )
        StandardCollections = @(
            @{
                Name = 'All Workstations - Managed'
                LimitingCollection = 'All Systems'
                Comment = 'Baseline workstation collection'
            },
            @{
                Name = 'All Servers - Managed'
                LimitingCollection = 'All Systems'
                Comment = 'Baseline server collection'
            }
        )
        SourcePaths = @{
            ContentLibrary = '\\sccm01.contoso.com\Sources$'
            DriverSource = '\\sccm01.contoso.com\DriverSources$'
            UpdateSource = '\\sccm01.contoso.com\Updates$'
        }
    }
}