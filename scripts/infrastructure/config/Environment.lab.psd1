@{
    Organization = @{
        Name = 'Contoso Lab'
        Domain = 'lab.contoso.com'
        NetBIOSName = 'LAB'
    }

    Environment = @{
        Name = 'Lab'
        ChangeTicket = 'CHG-LAB-0001'
        OutputRoot = 'C:\InfrastructureAutomation\LabOutput'
        Region = 'PrimaryLab'
        TimeZone = 'W. Europe Standard Time'
    }

    Network = @{
        DnsServers = @('10.20.0.10', '10.20.0.11')
        DnsForwarders = @('1.1.1.1', '8.8.8.8')
        NtpServers = @('time.windows.com', 'pool.ntp.org')
        Sites = @(
            @{
                Name = 'LAB-HQ'
                Subnets = @('10.20.0.0/24', '10.20.1.0/24')
            },
            @{
                Name = 'LAB-Branch01'
                Subnets = @('10.21.0.0/24')
            }
        )
    }

    ServiceAccounts = @{
        SccmSqlService = 'LAB\\svc-sccm-sql'
        SccmNetworkAccess = 'LAB\\svc-sccm-naa'
        PkiEnrollment = 'LAB\\svc-pki-enroll'
    }

    ActiveDirectory = @{
        ForestMode = 'WinThreshold'
        DomainMode = 'WinThreshold'
        InstallDns = $true
        CreateDnsDelegation = $false
        DatabasePath = 'D:\NTDS'
        LogPath = 'E:\NTDS-Logs'
        SysvolPath = 'F:\SYSVOL'
        DomainDistinguishedName = 'DC=lab,DC=contoso,DC=com'
        DomainControllers = @(
            @{
                ServerName = 'dc01.lab.contoso.com'
                SiteName = 'LAB-HQ'
                IpAddress = '10.20.0.10'
            },
            @{
                ServerName = 'dc02.lab.contoso.com'
                SiteName = 'LAB-HQ'
                IpAddress = '10.20.0.11'
            }
        )
        OrganizationalUnits = @(
            @{
                Name = 'Tier 0'
                Path = 'DC=lab,DC=contoso,DC=com'
                Description = 'Privileged administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Tier 1'
                Path = 'DC=lab,DC=contoso,DC=com'
                Description = 'Server administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Tier 2'
                Path = 'DC=lab,DC=contoso,DC=com'
                Description = 'Endpoint and user administration tier'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Administrative Groups'
                Path = 'OU=Tier 0,DC=lab,DC=contoso,DC=com'
                Description = 'Administrative security groups'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Domain Controllers'
                Path = 'OU=Tier 0,DC=lab,DC=contoso,DC=com'
                Description = 'Domain controller related objects'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Servers'
                Path = 'OU=Tier 1,DC=lab,DC=contoso,DC=com'
                Description = 'Server computer accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Service Accounts'
                Path = 'OU=Tier 1,DC=lab,DC=contoso,DC=com'
                Description = 'Managed service accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Workstations'
                Path = 'OU=Tier 2,DC=lab,DC=contoso,DC=com'
                Description = 'Workstation computer accounts'
                ProtectedFromAccidentalDeletion = $true
            },
            @{
                Name = 'Users'
                Path = 'OU=Tier 2,DC=lab,DC=contoso,DC=com'
                Description = 'Standard user accounts'
                ProtectedFromAccidentalDeletion = $true
            }
        )
        BaselineGroups = @(
            @{
                Name = 'GG-T0-Domain-Admins'
                SamAccountName = 'GG-T0-Domain-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 0 domain administration group'
            },
            @{
                Name = 'GG-T1-Server-Admins'
                SamAccountName = 'GG-T1-Server-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 1 server administration group'
            },
            @{
                Name = 'GG-T2-Workstation-Admins'
                SamAccountName = 'GG-T2-Workstation-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Tier 2 workstation administration group'
            },
            @{
                Name = 'GG-SCCM-Admins'
                SamAccountName = 'GG-SCCM-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'Configuration Manager administrative group'
            },
            @{
                Name = 'GG-PKI-Admins'
                SamAccountName = 'GG-PKI-Admins'
                Path = 'OU=Administrative Groups,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                GroupScope = 'Global'
                GroupCategory = 'Security'
                Description = 'PKI administrative group'
            }
        )
        GpoBaselines = @(
            @{
                Name = 'GPO-T0-Domain-Controllers-Baseline'
                TargetPath = 'OU=Domain Controllers,OU=Tier 0,DC=lab,DC=contoso,DC=com'
                Description = 'Security baseline for domain controllers'
            },
            @{
                Name = 'GPO-T1-Servers-Baseline'
                TargetPath = 'OU=Servers,OU=Tier 1,DC=lab,DC=contoso,DC=com'
                Description = 'Security baseline for servers'
            },
            @{
                Name = 'GPO-T2-Workstations-Baseline'
                TargetPath = 'OU=Workstations,OU=Tier 2,DC=lab,DC=contoso,DC=com'
                Description = 'Security baseline for workstations'
            }
        )
    }

    PKI = @{
        RootCACommonName = 'Contoso Lab Root CA'
        IssuingCACommonName = 'Contoso Lab Issuing CA 01'
        RootCAServer = 'pkiroot01.lab.contoso.com'
        IssuingCAServer = 'pkica01.lab.contoso.com'
        CdpUrl = 'http://pki.lab.contoso.com/pki/<CaName><CRLNameSuffix>.crl'
        AiaUrl = 'http://pki.lab.contoso.com/pki/<ServerDNSName>_<CaName><CertificateName>.crt'
        ValidityYears = 5
        KeyLength = 4096
        PublishUrls = @(
            'http://pki.lab.contoso.com/pki/'
        )
        CertificateTemplates = @(
            'WebServer',
            'Computer',
            'User',
            'KerberosAuthentication'
        )
    }

    SCCM = @{
        SiteCode = 'L01'
        SiteServer = 'sccm01.lab.contoso.com'
        SqlServer = 'sql01.lab.contoso.com'
        SqlInstance = 'MSSQLSERVER'
        DatabaseName = 'CM_L01'
        SoftwareUpdatePoint = 'sccm01.lab.contoso.com'
        ManagementPoint = 'sccm01.lab.contoso.com'
        Roles = @(
            'ManagementPoint',
            'DistributionPoint',
            'SoftwareUpdatePoint'
        )
        DistributionPoints = @(
            @{
                ServerName = 'sccm01.lab.contoso.com'
                SiteSystemRoles = @('DistributionPoint', 'ManagementPoint', 'SoftwareUpdatePoint')
            },
            @{
                ServerName = 'sccm-dp01.lab.contoso.com'
                SiteSystemRoles = @('DistributionPoint')
            }
        )
        BoundaryGroups = @(
            @{
                Name = 'BG-LAB-HQ'
                SiteAssignment = $true
                SiteSystems = @('sccm01.lab.contoso.com')
                BoundaryNames = @('LAB-HQ-Subnet')
            },
            @{
                Name = 'BG-LAB-Branch01'
                SiteAssignment = $true
                SiteSystems = @('sccm-dp01.lab.contoso.com')
                BoundaryNames = @('LAB-Branch01-Subnet')
            }
        )
        Boundaries = @(
            @{
                Name = 'LAB-HQ-Subnet'
                Type = 'IPSubnet'
                Value = '10.20.0.0/24'
            },
            @{
                Name = 'LAB-Branch01-Subnet'
                Type = 'IPSubnet'
                Value = '10.21.0.0/24'
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
            ContentLibrary = '\\sccm01.lab.contoso.com\Sources$'
            DriverSource = '\\sccm01.lab.contoso.com\DriverSources$'
            UpdateSource = '\\sccm01.lab.contoso.com\Updates$'
        }
    }
}