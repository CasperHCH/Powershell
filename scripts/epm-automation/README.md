# EPM Automation Suite

Jira-focused reporting and automation scripts for enterprise project and portfolio management workflows.

## Included Scripts

This folder currently contains these primary entry points:

- `Start-EPMAutomation.ps1`
    - interactive launcher for the main reporting scripts
- `Get-PortfolioHealthDashboard.ps1`
    - portfolio summary reporting across multiple Jira projects
- `Get-ResourceCapacityReport.ps1`
    - resource workload and allocation reporting
- `New-AutomatedStatusReport.ps1`
    - periodic stakeholder status reporting
- `Get-RiskIssueAnalysis.ps1`
    - risk, issue, and aging analysis
- `endpoint-management\`
    - endpoint-management-specific automation and reconciliation scripts

## Supported Use Cases

- portfolio health reporting for leadership or PMO reviews
- resource-capacity visibility across Jira projects
- weekly or monthly status reporting
- risk and issue review packs
- endpoint inventory reconciliation when combined with the endpoint-management scripts

## Authentication Model

The scripts support Jira Cloud and Jira environments where API-based access is available.

Typical parameters include:

- `-JiraBaseUrl`
- `-ProjectKeys`
- `-CloudId`
- `-ServiceAccountEmail`
- token input via secure prompt or secure storage pattern

Use generic values in examples and keep tokens out of the script files.

## Example Usage

### Portfolio Health Dashboard

```powershell
.\Get-PortfolioHealthDashboard.ps1 `
        -JiraBaseUrl "https://contoso.atlassian.net" `
        -ProjectKeys @("PROJ1", "PROJ2", "PROJ3") `
        -CloudId "11111111-2222-3333-4444-555555555555" `
        -ServiceAccountEmail "jira-bot@example.org"
```

### Resource Capacity Report

```powershell
.\Get-ResourceCapacityReport.ps1 `
        -JiraBaseUrl "https://contoso.atlassian.net" `
        -ProjectKeys @("PROJ1", "PROJ2") `
        -CloudId "11111111-2222-3333-4444-555555555555" `
        -ServiceAccountEmail "jira-bot@example.org"
```

### Automated Status Report

```powershell
.\New-AutomatedStatusReport.ps1 `
        -JiraBaseUrl "https://contoso.atlassian.net" `
        -ProjectKeys @("PROJ1") `
        -ReportPeriod "Weekly" `
        -CloudId "11111111-2222-3333-4444-555555555555" `
        -ServiceAccountEmail "jira-bot@example.org"
```

### Risk and Issue Analysis

```powershell
.\Get-RiskIssueAnalysis.ps1 `
        -JiraBaseUrl "https://contoso.atlassian.net" `
        -ProjectKeys @("PROJ1", "PROJ2") `
        -CloudId "11111111-2222-3333-4444-555555555555" `
        -ServiceAccountEmail "jira-bot@example.org"
```

## Output Expectations

The current report scripts are designed to generate presentation-friendly output, typically as HTML and in some cases JSON or CSV depending on script parameters.

Expect these common patterns:

- timestamped report output
- local log files beside the script
- summarized console logging
- script-scoped session identifiers for traceability

## Scheduling Guidance

For scheduled execution:

- run the scripts from PowerShell 7 when possible
- use a service account or approved non-interactive credential pattern
- keep output paths on a stable share or reporting folder
- validate API connectivity before the reporting window

## Related Documentation

- `endpoint-management\README.md`
- `..\..\docs\api-references\ATLASSIAN_API_REFERENCE.md`
- `..\..\docs\guides\DEVELOPMENT_STANDARDS.md`

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
