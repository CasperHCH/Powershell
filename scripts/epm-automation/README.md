# EPM Automation Suite

**Enterprise Project Management Automation Scripts for Jira**

A comprehensive collection of PowerShell scripts designed for Enterprise Project Managers to automate reporting, analysis, and portfolio management tasks across Jira projects.

---

## 📋 Overview

This suite provides production-ready automation scripts for EPM professionals to:
- Generate executive dashboards and reports
- Track resource capacity and utilization
- Monitor project health across portfolios
- Analyze risks and issues
- Automate stakeholder communications

**Key Features:**
- ✅ Jira Cloud & On-Premise support
- ✅ Service Account authentication
- ✅ Beautiful HTML reports
- ✅ Secure credential handling
- ✅ Comprehensive audit logging
- ✅ Parameterized and reusable

---

## 🚀 Scripts Included

### 1. **Get-PortfolioHealthDashboard.ps1**
Generate executive-level portfolio health insights with RAG (Red/Amber/Green) status indicators.

**Features:**
- Aggregates metrics across multiple projects
- Identifies at-risk projects
- Tracks completion rates
- Highlights high-priority issues
- Executive summary dashboard

**Use Case:** Weekly executive reviews, portfolio governance meetings

**Example:**
```powershell
.\Get-PortfolioHealthDashboard.ps1 `
    -JiraBaseUrl "https://company.atlassian.net" `
    -ProjectKeys @("PROJ1", "PROJ2", "PROJ3") `
    -CloudId "51cabb76-ca9b-4fff-864e-c806cd5cdcf3" `
    -ServiceAccountEmail "bot@serviceaccount.atlassian.com"
```

---

### 2. **Get-ResourceCapacityReport.ps1**
Analyze team resource allocation and capacity utilization across projects.

**Features:**
- Workload distribution analysis
- Identifies over/under-utilized resources
- Multi-project tracking per person
- Priority-based workload breakdown
- Capacity planning insights

**Use Case:** Resource planning, workload balancing, hiring decisions

**Example:**
```powershell
.\Get-ResourceCapacityReport.ps1 `
    -JiraBaseUrl "https://company.atlassian.net" `
    -ProjectKeys @("PROJ1", "PROJ2") `
    -CloudId "51cabb76-ca9b-4fff-864e-c806cd5cdcf3" `
    -ServiceAccountEmail "bot@serviceaccount.atlassian.com"
```

---

### 3. **New-AutomatedStatusReport.ps1**
Generate automated weekly or monthly status reports for stakeholders.

**Features:**
- Accomplishments tracking
- Work in progress visibility
- Blocker identification
- Upcoming work preview
- Ready for email distribution

**Use Case:** Weekly team updates, monthly stakeholder reports, sprint reviews

**Example:**
```powershell
.\New-AutomatedStatusReport.ps1 `
    -JiraBaseUrl "https://company.atlassian.net" `
    -ProjectKeys @("PROJ1") `
    -ReportPeriod "Weekly" `
    -CloudId "51cabb76-ca9b-4fff-864e-c806cd5cdcf3" `
    -ServiceAccountEmail "bot@serviceaccount.atlassian.com"
```

---

### 4. **Get-RiskIssueAnalysis.ps1**
Track and analyze portfolio-level risks and aging issues.

**Features:**
- Risk level classification (Critical/High/Medium/Low)
- Aging analysis for open issues
- Trend identification
- Priority-based filtering
- Risk register generation

**Use Case:** Risk reviews, governance meetings, escalation management

**Example:**
```powershell
.\Get-RiskIssueAnalysis.ps1 `
    -JiraBaseUrl "https://company.atlassian.net" `
    -ProjectKeys @("PROJ1", "PROJ2") `
    -CloudId "51cabb76-ca9b-4fff-864e-c806cd5cdcf3" `
    -ServiceAccountEmail "bot@serviceaccount.atlassian.com"
```

---

## 🔧 Setup & Configuration

### Prerequisites
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Jira Cloud or On-Premise** instance
- **API Token or Service Account** with appropriate permissions
- **Internet connectivity** for Jira API access

### Authentication Setup

#### Option 1: Service Account (Recommended for Automation)

1. **Create Service Account** in Atlassian Admin Console
2. **Generate API Token** with appropriate scopes:
   - `read:jira-work`
   - `read:jira-user` (for resource reports)
3. **Get Cloud ID:**
   ```powershell
   $response = Invoke-RestMethod -Uri "https://your-domain.atlassian.net/_edge/tenant_info"
   $response.cloudId
   ```

4. **Use in scripts:**
   ```powershell
   -JiraBaseUrl "https://your-domain.atlassian.net" `
   -CloudId "your-cloud-id" `
   -ServiceAccountEmail "bot@serviceaccount.atlassian.com"
   ```

#### Option 2: Personal API Token

1. Generate token from: https://id.atlassian.com/manage-profile/security/api-tokens
2. Use with `-JiraBaseUrl` parameter only (omit CloudId and ServiceAccountEmail)

---

## 📊 Report Outputs

All scripts generate professional HTML reports with:
- 📈 **Visual metrics** and KPIs
- 🎨 **Color-coded status** indicators
- 📋 **Detailed data tables**
- 📱 **Mobile-responsive** design
- 🖨️ **Print-friendly** formatting

Reports can also be exported as:
- JSON (machine-readable)
- CSV (Excel-compatible)
- HTML (presentation-ready)

---

## 🔒 Security Features

✅ **Secure credential handling** - No hardcoded passwords
✅ **Audit logging** - All actions logged with timestamps
✅ **Data sanitization** - Sensitive information masked in logs
✅ **SecureString support** - Token input via secure prompt
✅ **Session isolation** - Unique session IDs per execution

All scripts follow enterprise security best practices and are compliant with the repository's security guidelines.

---

## 📅 Automation & Scheduling

### Schedule Weekly Reports
```powershell
# Windows Task Scheduler
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File C:\Scripts\New-AutomatedStatusReport.ps1 -JiraBaseUrl 'https://company.atlassian.net' -ProjectKeys @('PROJ1') -ReportPeriod 'Weekly'"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8am
Register-ScheduledTask -TaskName "Weekly Jira Status Report" -Action $action -Trigger $trigger
```

### Email Distribution
Combine with PowerShell email functions to automatically distribute reports:
```powershell
Send-MailMessage -To "stakeholders@company.com" `
    -From "epm@company.com" `
    -Subject "Weekly Status Report - $(Get-Date -Format 'yyyy-MM-dd')" `
    -Body "Please find attached the weekly status report." `
    -Attachments $OutputPath `
    -SmtpServer "smtp.company.com"
```

---

## 💼 EPM Use Cases

### Portfolio Management
- **Weekly Executive Reviews**: Use Portfolio Health Dashboard
- **Quarterly Planning**: Combine Resource Capacity + Risk Analysis
- **Board Presentations**: Generate all reports for comprehensive view

### Resource Management
- **Sprint Planning**: Resource Capacity Report shows availability
- **Hiring Decisions**: Identify sustained over-utilization
- **Team Rebalancing**: Cross-project allocation insights

### Risk Management
- **Risk Reviews**: Automated risk register with aging analysis
- **Escalation Management**: Critical issue identification
- **Trend Analysis**: Historical comparison capabilities

### Stakeholder Communication
- **Status Updates**: Automated weekly/monthly reports
- **Executive Summaries**: Portfolio health dashboards
- **Team Updates**: Resource and progress visibility

---

## 🎓 Learning & Development

These scripts demonstrate:
- **API Integration** - RESTful API consumption
- **Data Analysis** - Metrics calculation and aggregation
- **Report Generation** - HTML/CSS report creation
- **Automation** - Scheduled task execution
- **Security** - Credential management and audit logging
- **Best Practices** - Parameterization, error handling, logging

Perfect for showcasing technical capabilities in EPM interviews and onboarding.

---

## 📈 Metrics & KPIs Tracked

| Metric | Description | Scripts |
|--------|-------------|---------|
| **Portfolio Health** | RAG status across projects | Portfolio Health Dashboard |
| **Completion Rate** | % of issues completed | Portfolio Health, Status Report |
| **Resource Utilization** | Workload per team member | Resource Capacity |
| **Risk Exposure** | High-priority aging issues | Risk Analysis |
| **Blocker Count** | Issues preventing progress | Status Report, Risk Analysis |
| **Velocity** | Issues completed per period | Status Report |
| **Capacity** | Available vs. allocated resources | Resource Capacity |

---

## 🔍 Troubleshooting

### Common Issues

**Authentication Errors (401/403)**
- Verify API token is valid and not expired
- Check service account has project access
- Ensure correct Cloud ID is used

**404 Errors**
- Verify Cloud ID is correct (not Organization ID)
- Check project keys are valid
- Ensure API endpoints are accessible

**Slow Performance**
- Reduce number of projects analyzed
- Filter by date range for large datasets
- Increase `-TimeoutSeconds` parameter

**No Data Returned**
- Verify JQL queries match your issue structure
- Check status names match your workflow
- Ensure priority names are correct

---

## 🤝 Contributing

This is a personal portfolio repository, but suggestions and improvements are welcome!

### Enhancement Ideas
- Power BI integration
- Confluence export support
- Budget tracking integration
- Dependency mapping
- Team velocity tracking
- Predictive analytics

---

## 📞 Support

For questions or issues:
1. Check script help: `Get-Help .\ScriptName.ps1 -Full`
2. Review audit logs in script directory
3. Enable verbose logging: `-Verbose`

---

## 📝 License

Personal use and portfolio demonstration. Please respect intellectual property when adapting for commercial use.

---

## 🎯 Next Steps

1. **Test with your Jira instance**
2. **Customize reports** to match your organization's needs
3. **Schedule automation** for regular report generation
4. **Integrate with existing tools** (Power BI, SharePoint, etc.)
5. **Expand functionality** based on specific EPM requirements

---

## 📚 Additional Resources

- [Atlassian Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Service Account Setup Guide](https://support.atlassian.com/user-management/docs/manage-api-tokens-for-service-accounts/)
- [PowerShell Gallery](https://www.powershellgallery.com/)

---

**Last Updated:** November 2025
**Author:** EPM Automation Suite
**Version:** 1.0.0

---

*These scripts are designed to demonstrate EPM automation capabilities and can be customized for specific organizational needs.*
