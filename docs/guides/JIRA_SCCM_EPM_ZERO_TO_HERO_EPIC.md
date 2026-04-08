# Jira Epic: SCCM/MECM Endpoint Manager Zero-to-Hero

Purpose: Provide a Jira-ready epic and child-task series for an Endpoint Manager responsible for Microsoft Endpoint Configuration Manager (SCCM/MECM). The tasks are ordered so a new or growing Endpoint Manager can move from foundational understanding to operational ownership, governance, and service maturity.

Audience: Endpoint Managers, SCCM administrators, service owners, operational leads, and team managers building a structured backlog.

How to use this document:
1. Create the epic first.
2. Create the child tasks in the order shown.
3. Keep the description text mostly intact so each Jira item remains actionable.
4. Tailor site codes, report names, collection names, and stakeholder references for your environment.
5. Add labels such as `sccm`, `mecm`, `endpoint-management`, `reporting`, and `governance` as needed.

---

## Epic

**Epic Name:** SCCM/MECM Endpoint Manager Enablement and Operational Maturity

**Epic Goal:**
Establish full operational ownership of the SCCM/MECM estate, including inventory accuracy, client health, software deployment governance, update compliance, reporting, change control, and automation. This epic should take an Endpoint Manager from environment familiarization to repeatable service management.

**Epic Description:**
This epic covers the complete operating model expected of an Endpoint Manager working in an SCCM/MECM environment. It includes foundational platform understanding, health monitoring, collections, deployments, software updates, reporting, audit evidence, cleanup, and process maturity.

The outcome is not only technical competence, but also the ability to explain service health to stakeholders, produce useful operational reports, reduce avoidable risk, and maintain the platform in a controlled and measurable way.

**Suggested Epic Labels:**
- `sccm`
- `mecm`
- `endpoint-management`
- `operations`
- `governance`
- `zero-to-hero`

**Suggested Epic Definition of Done:**
- Core SCCM operational areas are understood and documented.
- Recurring health and compliance reporting is in place.
- Standard runbooks exist for common failure and change scenarios.
- Cleanup and governance processes are defined and scheduled.
- The Endpoint Manager can independently assess service health and explain risk, impact, and required actions.

---

## Phase 1: Foundations and Environment Orientation

### Task 1: Foundation - Confirm SCCM access, roles, and working context
**Description:**
Validate that the Endpoint Manager has the correct console access, RBAC scope, remote administration access, and visibility into the site hierarchy. Confirm whether the environment is a standalone primary site or part of a larger hierarchy. Document site codes, major site systems, distribution points, management points, software update points, and supporting teams.

This task matters because every later activity depends on knowing what can be accessed, who owns what, and where escalation boundaries exist.

**Suggested data sources:**
- SCCM console: Administration > Security > Administrative Users
- SCCM console: Administration > Site Configuration > Sites
- SCCM console: Administration > Site Configuration > Servers and Site System Roles
- Existing support documentation and access request records

**Suggested reporting or evidence:**
- Create a simple access matrix in Excel or CSV listing role, scope, and system access
- Export site system inventory and keep it with onboarding documentation
- Capture screenshots of console access and role scope for evidence

**Acceptance criteria:**
- Access dependencies and administrative boundaries are documented
- Site hierarchy and core roles are identified
- Escalation contacts are listed for SCCM, server, database, and networking support

### Task 2: Foundation - Build an SCCM service map and terminology guide
**Description:**
Create a beginner-friendly service map that explains how discovery, boundaries, collections, content distribution, client policy, application deployment, and software update compliance fit together. Include a short terminology guide for common SCCM concepts such as boundaries, deployment types, collections, content source, supersedence, ADRs, and compliance states.

This task matters because new Endpoint Managers often know the tools only in fragments. A service map makes troubleshooting and reporting far more accurate.

**Suggested data sources:**
- SCCM console navigation paths
- Internal runbooks and onboarding notes
- [scripts/SCCM/README.md](scripts/SCCM/README.md)

**Suggested reporting or evidence:**
- Produce a Visio, PowerPoint, or Markdown architecture diagram
- Add a one-page terminology sheet to the team knowledge base
- Include examples of where each concept appears in the console

**Acceptance criteria:**
- Service map exists and is understandable to a new team member
- Core SCCM terms are documented with plain-language definitions
- Dependencies between collections, deployments, and content are clear

### Task 3: Foundation - Document standard operating folders, outputs, and evidence paths
**Description:**
Define where reports, exports, logs, scripts, and audit evidence should be stored for routine SCCM work. Include guidance on where timestamped outputs are written, how long they should be retained, and who should have access.

This task matters because an Endpoint Manager quickly accumulates evidence from deployments, compliance checks, and cleanup tasks. Without a structure, trend analysis becomes unreliable.

**Suggested data sources:**
- Existing team share or documentation repository
- [scripts/SCCM/output](scripts/SCCM/output)
- Current file retention or audit requirements

**Suggested reporting or evidence:**
- Create a folder standard for monthly outputs
- Define a naming convention for CSV, JSON, and log files
- Record the standard in a team guide or wiki page

**Acceptance criteria:**
- Standard output locations are documented
- Naming and retention rules are agreed
- Operational evidence can be found without tribal knowledge

### Task 4: Foundation - Establish the baseline operational calendar
**Description:**
Create a recurring operational calendar covering weekly health reviews, monthly patch compliance checks, quarterly cleanup, major change windows, and stakeholder reporting cadence. Distinguish one-time onboarding work from recurring service ownership work.

This task matters because SCCM becomes reactive when there is no cadence for review, validation, and cleanup.

**Suggested data sources:**
- Change calendar
- Patch cycle schedule
- Existing service review meetings
- Maintenance window documentation

**Suggested reporting or evidence:**
- Publish a recurring calendar in Outlook, Teams, Planner, or Jira
- Define report due dates and audiences
- Maintain a checklist for weekly, monthly, and quarterly tasks

**Acceptance criteria:**
- Weekly, monthly, and quarterly operational checkpoints are defined
- Report owners and audiences are assigned
- Regular SCCM service review cadence is visible to the team

---

## Phase 2: Estate Visibility, Inventory, and Collections

### Task 5: Inventory - Build a baseline endpoint estate inventory
**Description:**
Create a baseline view of the managed estate: total devices, device classes, active clients, stale clients, server versus workstation split, and any known gaps in management coverage. Record how many endpoints are expected versus how many are currently represented in SCCM.

This task matters because every later KPI, compliance metric, and remediation plan depends on a trusted denominator.

**Suggested data sources:**
- SCCM console: Assets and Compliance > Devices
- Hardware inventory classes
- Discovery data and active client status
- CMDB or asset repository exports if available

**Suggested reporting or evidence:**
- Export device inventory to CSV and group by device type, domain, client activity, and last logon
- Produce a baseline dashboard in Excel or Power BI
- Save a monthly snapshot for trend comparison

**Acceptance criteria:**
- A usable managed-device baseline exists
- Device count assumptions are documented
- Major data gaps are identified for follow-up

### Task 6: Inventory - Reconcile SCCM inventory with external sources
**Description:**
Compare SCCM inventory with other sources such as CMDB, monitoring tools, or endpoint protection systems. Identify devices that appear in one source but not another, and separate expected exceptions from real drift.

This task matters because unmanaged or mismatched devices introduce security, compliance, and reporting risk.

**Suggested data sources:**
- SCCM inventory exports
- CMDB exports
- Monitoring platform host lists
- [scripts/epm-automation/endpoint-management/README.md](scripts/epm-automation/endpoint-management/README.md)

**Suggested reporting or evidence:**
- Create a drift report showing SCCM-only, CMDB-only, and fully matched devices
- Publish a summary with counts, percentages, and top exception reasons
- Track improvement month over month

**Acceptance criteria:**
- Reconciliation method is documented
- Drift categories are defined
- An actionable exception list exists for remediation

### Task 7: Collections - Review collection design and naming standards
**Description:**
Audit device and user collections to understand how they are structured, named, limited, and used. Identify legacy collections, overlapping collections, test collections, and collections with unclear purpose. Document which collections are considered production-critical.

This task matters because poor collection design creates deployment risk, inaccurate targeting, and reporting confusion.

**Suggested data sources:**
- SCCM console: Assets and Compliance > Device Collections
- Collection query rules and direct membership rules
- Collection update schedules
- [scripts/SCCM/SCCM-CollectionAnalyse.ps1](scripts/SCCM/SCCM-CollectionAnalyse.ps1)

**Suggested reporting or evidence:**
- Export collections with member counts, refresh schedules, and limiting collections
- Create a report showing unused, overlapping, or stale collections
- Categorize collections as pilot, production, staging, or obsolete

**Acceptance criteria:**
- Collection naming and design issues are documented
- Priority collections are identified
- A follow-up backlog exists for cleanup and standardization

### Task 8: Boundaries - Audit boundary groups and site assignment coverage
**Description:**
Review boundaries and boundary groups to confirm that endpoint location, content location, and site assignment behavior are correct. Look for missing subnets, overlapping definitions, or site systems that are not logically aligned to the network design.

This task matters because boundary mistakes can break client assignment, content retrieval, and update performance.

**Suggested data sources:**
- SCCM console: Administration > Hierarchy Configuration > Boundaries
- SCCM console: Administration > Hierarchy Configuration > Boundary Groups
- Network documentation and subnet allocations
- [scripts/SCCM/SCCM-BoundaryGroupAudit.ps1](scripts/SCCM/SCCM-BoundaryGroupAudit.ps1)

**Suggested reporting or evidence:**
- Export boundary groups and associated site systems
- Produce a gap report for missing or suspect boundary definitions
- Create a simple network-to-boundary mapping sheet

**Acceptance criteria:**
- Boundary coverage has been reviewed against network reality
- Suspect or missing entries are logged
- Distribution point and site assignment dependencies are understood

---

## Phase 3: Client Health and Operational Diagnostics

### Task 9: Client Health - Build a baseline client health dashboard
**Description:**
Define what healthy SCCM client behavior looks like in your environment and establish a baseline view for client activity, policy success, heartbeat recency, inventory currency, and obvious failure patterns.

This task matters because client health underpins software deployment, patch compliance, and endpoint visibility.

**Suggested data sources:**
- SCCM client status views in Monitoring
- Client online status and last active time
- Inventory and policy timestamps
- [scripts/SCCM/SCCM-TestClientHealth.ps1](scripts/SCCM/SCCM-TestClientHealth.ps1)

**Suggested reporting or evidence:**
- Produce a CSV and Excel dashboard of healthy versus unhealthy devices
- Group issues by failure type, site, OU, or subnet
- Establish a weekly trend chart for unhealthy client count

**Acceptance criteria:**
- Client health baseline exists
- Health categories are defined in plain language
- The team can identify the top recurring client issues

### Task 10: Client Health - Learn the key client logs and what they mean
**Description:**
Create a troubleshooting reference for the most important client logs such as `ccmexec`, policy, content transfer, application enforcement, and software update evaluation logs. Explain what each log is for, common failure indicators, and when to use each one.

This task matters because effective Endpoint Managers need to move from surface symptoms to actual evidence quickly.

**Suggested data sources:**
- Local client logs in `C:\Windows\CCM\Logs`
- Existing incident examples
- [scripts/SCCM/SCCM-CollectClientLogs.ps1](scripts/SCCM/SCCM-CollectClientLogs.ps1)
- [scripts/SCCM/SCCM-RunClientActionsLocal.ps1](scripts/SCCM/SCCM-RunClientActionsLocal.ps1)

**Suggested reporting or evidence:**
- Build a log-to-symptom matrix in Markdown or Excel
- Include sample error patterns and likely next steps
- Capture a standard log bundle for future troubleshooting examples

**Acceptance criteria:**
- Key client logs are documented with purpose and common use cases
- The Endpoint Manager can map symptoms to likely logs
- A reusable troubleshooting reference exists

### Task 11: Client Health - Define a standard remediation workflow
**Description:**
Document a repeatable remediation workflow for unhealthy clients, including policy trigger steps, service restart logic, repair actions, and escalation thresholds. Separate low-risk repeatable actions from cases that require infrastructure or packaging support.

This task matters because ad hoc remediation wastes time and makes outcomes hard to measure.

**Suggested data sources:**
- Incident history for common failures
- [scripts/SCCM/SCCM-RepairClientHealth.ps1](scripts/SCCM/SCCM-RepairClientHealth.ps1)
- [scripts/SCCM/SCCM-TestClientHealth.ps1](scripts/SCCM/SCCM-TestClientHealth.ps1)

**Suggested reporting or evidence:**
- Record remediation categories and success rates
- Build a small runbook with decision points
- Maintain a weekly list of top recurring client health faults

**Acceptance criteria:**
- Standard client remediation steps are documented
- Success and failure outcomes can be tracked
- Escalation points are clear

### Task 12: Client Health - Create recurring client health reporting
**Description:**
Create a recurring health report that shows unhealthy clients, top error types, repeat offenders, and remediation progress. Define who receives the report and what actions are expected from it.

This task matters because client health must be managed as a service, not as isolated incidents.

**Suggested data sources:**
- SCCM Monitoring workspace
- Client health script outputs
- Incident records and service desk trends

**Suggested reporting or evidence:**
- Weekly CSV export and stakeholder summary
- Trend chart of unhealthy client count and closure rate
- Highlight top impacted business units or locations if known

**Acceptance criteria:**
- Recurring client health report exists
- Audience and action owners are defined
- Trend reporting is possible across multiple reporting periods

---

## Phase 4: Application Packaging, Deployment, and Content Distribution

### Task 13: Applications - Document the application intake and packaging workflow
**Description:**
Define the end-to-end workflow for a new application request, including intake, source validation, packaging, detection logic, testing, pilot deployment, production release, and retirement. Explain which stages the Endpoint Manager owns directly and where dependencies exist.

This task matters because unmanaged packaging demand causes failed deployments, weak detection logic, and audit gaps.

**Suggested data sources:**
- Existing request forms and change tickets
- Current application objects in SCCM
- Packaging standards and install command examples

**Suggested reporting or evidence:**
- Create a swimlane workflow or checklist
- Track packaging lead time and rejection reasons
- Publish a standard request template for software intake

**Acceptance criteria:**
- Application intake path is documented
- Packaging checkpoints are clearly defined
- Requestors know what information must be supplied

### Task 14: Applications - Review deployment types, detection methods, and return codes
**Description:**
Audit a representative sample of applications to confirm that deployment types, detection methods, uninstall commands, user experience settings, and return code handling are correct and consistent.

This task matters because unreliable detection and weak return-code handling are common causes of false compliance and repeated failure.

**Suggested data sources:**
- SCCM console: Software Library > Applications
- Application deployment type properties
- Installer documentation from vendors
- Historical failed deployment details

**Suggested reporting or evidence:**
- Build a packaging quality review sheet
- Flag applications with weak or missing detection logic
- Report common standards violations for remediation planning

**Acceptance criteria:**
- Application quality review sample is complete
- Common packaging issues are categorized
- A remediation list exists for the most critical apps

### Task 15: Deployments - Define pilot, pre-production, and production deployment rings
**Description:**
Create a controlled deployment model using pilot, limited production, and broad production collections. Document approval gates, rollback expectations, and which success metrics must be checked before each stage.

This task matters because broad deployments without controlled rings increase business impact when packages or content are wrong.

**Suggested data sources:**
- Existing deployment collections
- Change approval process
- Support team structure and business criticality information

**Suggested reporting or evidence:**
- Build a deployment ring matrix with collection names and purpose
- Define exit criteria for each ring
- Track ring progression in Jira or a release tracker

**Acceptance criteria:**
- Deployment rings are defined and documented
- Approval and rollback logic is visible
- Pilot-to-production progression can be evidenced

### Task 16: Deployments - Build a deployment failure reporting process
**Description:**
Create a repeatable method to review failed deployments, separate true package problems from client-side issues, and prioritize remediation. Include guidance on when to retry versus when to fix packaging or content.

This task matters because failed deployment counts without analysis rarely lead to useful action.

**Suggested data sources:**
- Deployment monitoring nodes in SCCM
- Error code breakdowns
- [scripts/SCCM/SCCM-DeploymentFailureReport.ps1](scripts/SCCM/SCCM-DeploymentFailureReport.ps1)
- Client logs such as AppEnforce and ExecMgr

**Suggested reporting or evidence:**
- Produce a weekly top-failure report by application and error code
- Include asset detail for the most critical failures
- Classify causes as packaging, content, client health, dependency, or environmental

**Acceptance criteria:**
- Failure reporting process is documented
- Failure categories are defined
- A prioritization method exists for remediation work

### Task 17: Content Distribution - Monitor and validate content health
**Description:**
Review how package and application content is distributed to distribution points, how failures are detected, and how long problem content is allowed to remain unresolved. Build a method to validate content health before broad deployments.

This task matters because good packaging still fails in production when content is not properly distributed.

**Suggested data sources:**
- SCCM console: Monitoring > Distribution Status
- Distribution point status messages
- [scripts/SCCM/SCCM-ValidateContentDistribution.ps1](scripts/SCCM/SCCM-ValidateContentDistribution.ps1)
- [scripts/SCCM/SCCM-RedistributeFailedContent.ps1](scripts/SCCM/SCCM-RedistributeFailedContent.ps1)

**Suggested reporting or evidence:**
- Create a failed and in-progress content report by package and DP
- Track oldest unresolved distribution problems
- Keep pre-deployment validation output with the change record

**Acceptance criteria:**
- Content validation process is documented
- Problem content can be identified quickly
- Distribution health can be evidenced before major releases

### Task 18: Applications - Review supersedence and uninstall governance
**Description:**
Assess whether application supersedence chains, uninstall behavior, and implicit uninstall settings are correctly designed for version replacement and cleanup scenarios. Identify applications that need better retirement planning.

This task matters because unmanaged supersedence and uninstall behavior creates version sprawl, user confusion, and failed cleanup.

**Suggested data sources:**
- SCCM application properties
- Historical versioned application families
- [scripts/SCCM/SCCM-AuditApplicationSupersedence.ps1](scripts/SCCM/SCCM-AuditApplicationSupersedence.ps1)
- [scripts/SCCM/SCCM-AuditImplicitUninstallReadiness.ps1](scripts/SCCM/SCCM-AuditImplicitUninstallReadiness.ps1)

**Suggested reporting or evidence:**
- Produce a report of application families with version sprawl
- Identify missing uninstall or supersedence logic
- Use CSV output to prioritize remediation by business impact

**Acceptance criteria:**
- Supersedence and uninstall gaps are identified
- High-risk application families are prioritized
- A retirement and replacement approach is documented

---

## Phase 5: Software Updates, Compliance, and Remediation

### Task 19: Updates - Map the software update servicing model
**Description:**
Document how software updates are currently selected, synchronized, deployed, and monitored. Include update rings, maintenance windows, emergency deployment flow, and the relationship between ADRs, collections, and compliance reporting.

This task matters because patching often spans multiple teams, and unclear ownership leads to weak compliance outcomes.

**Suggested data sources:**
- SCCM console: Software Library > Software Updates
- Automatic Deployment Rules
- Deployment packages and maintenance windows
- Existing monthly patching documentation

**Suggested reporting or evidence:**
- Produce a flowchart of the patching lifecycle
- Record collection and ring structure for monthly patching
- Document approval and exception handling paths

**Acceptance criteria:**
- Update lifecycle is documented end to end
- Patch rings and schedules are understood
- Roles and dependencies are clear

### Task 20: Updates - Build a monthly update compliance report
**Description:**
Create a standardized monthly compliance report showing compliant, non-compliant, unknown, and in-progress device counts across key collections. Include clear narrative on what changed since the last cycle.

This task matters because compliance percentages without context are rarely enough for leadership or audit use.

**Suggested data sources:**
- SCCM monitoring and update compliance views
- [scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1](scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1)
- Collection-based deployment status

**Suggested reporting or evidence:**
- Export collection-based compliance to CSV and summarize in Excel or Power BI
- Add month-over-month trend lines and top failure categories
- Separate executive summary from technical detail appendix

**Acceptance criteria:**
- Monthly compliance report template exists
- Report distinguishes summary metrics from technical detail
- Trend comparison is built into the reporting process

### Task 21: Updates - Define a remediation workflow for non-compliant devices
**Description:**
Create a decision tree for devices that remain non-compliant after the normal patch cycle. Include checks for client health, content access, restart state, maintenance windows, scan issues, and user-impact constraints.

This task matters because remediation is where patching results are won or lost.

**Suggested data sources:**
- Compliance exception lists
- Client logs for software updates
- Incident and problem management records
- Maintenance window configuration

**Suggested reporting or evidence:**
- Track non-compliant devices by remediation reason
- Build a backlog of repeat failure patterns
- Report aging of non-compliance exceptions weekly until closure

**Acceptance criteria:**
- Non-compliance remediation path is documented
- Escalation thresholds are defined
- Exception aging can be reported consistently

### Task 22: Updates - Create patching KPI and stakeholder communications
**Description:**
Define which patch KPIs should be reported to operations, management, and audit stakeholders. Typical examples include deployment success rate, compliance by ring, reboot backlog, exception count, and aging of unresolved non-compliance.

This task matters because patching work is often measured differently by technical and leadership audiences.

**Suggested data sources:**
- Update compliance output
- Incident volume during patch week
- Change records and outage data
- Device restart status where available

**Suggested reporting or evidence:**
- Create a monthly patch status pack with one executive slide and one analyst appendix
- Use graphs for ring-by-ring performance
- Add a short narrative for risks and follow-up actions

**Acceptance criteria:**
- Patch KPIs are defined per audience
- Reporting format is agreed
- Monthly communication can be sent with minimal rework

---

## Phase 6: Governance, Cleanup, and Risk Reduction

### Task 23: Governance - Identify stale devices and inactive client records
**Description:**
Define how stale devices are identified, reviewed, and either remediated or retired. Separate temporarily inactive endpoints from obsolete records. Document business approvals needed before deletion or exclusion.

This task matters because stale records distort compliance, deployment targeting, and management coverage reporting.

**Suggested data sources:**
- Device last active time
- Heartbeat discovery timestamps
- Inventory timestamps
- CMDB lifecycle state if available

**Suggested reporting or evidence:**
- Produce a stale device report by age band
- Group results by business owner, location, or device type
- Track how many stale records are removed per quarter

**Acceptance criteria:**
- Stale device logic is documented
- Review and approval path exists
- Cleanup candidates can be reported consistently

### Task 24: Governance - Review stale collections and deployments
**Description:**
Audit collections and deployments that appear inactive, obsolete, duplicated, or no longer operationally justified. Identify what can be retired safely and what needs dependency review before action.

This task matters because stale objects increase targeting errors, console clutter, and support overhead.

**Suggested data sources:**
- Collection refresh and member counts
- Deployment last modified dates
- [scripts/SCCM/SCCM-AnalyzeStaleCollectionsAndDeployments.ps1](scripts/SCCM/SCCM-AnalyzeStaleCollectionsAndDeployments.ps1)

**Suggested reporting or evidence:**
- Export stale objects by age tier and category
- Highlight objects with zero members, no recent changes, or no business owner
- Maintain a quarterly retirement candidate register

**Acceptance criteria:**
- Stale object review process exists
- Retirement candidates are prioritized
- Quarterly governance review can be repeated

### Task 25: Governance - Perform reference impact analysis before cleanup or change
**Description:**
Define a mandatory pre-change review for applications, packages, and collections before deletion, consolidation, or redesign. Check references, dependencies, and downstream impacts before any cleanup action.

This task matters because careless cleanup can silently break deployments, task sequences, or business-critical targeting.

**Suggested data sources:**
- Object references in SCCM
- Deployment and collection relationships
- [scripts/SCCM/SCCM-ReferenceImpactAnalysis.ps1](scripts/SCCM/SCCM-ReferenceImpactAnalysis.ps1)

**Suggested reporting or evidence:**
- Attach impact analysis output to change records
- Create a risk rating per proposed cleanup action
- Record whether rollback is possible and how it would be done

**Acceptance criteria:**
- Impact analysis is part of change readiness
- Cleanup decisions are evidence-based
- High-risk changes require explicit review

### Task 26: Governance - Define change-window validation and rollback expectations
**Description:**
Create a validation checklist for significant SCCM changes such as hierarchy upgrades, large deployment model changes, or boundary redesign. Include evidence capture, decision gates, and rollback triggers.

This task matters because platform changes need a repeatable control model, not improvised validation.

**Suggested data sources:**
- Existing change records
- [docs/guides/SCCM_2509_Post-Upgrade_Change_Window_Checklist.md](docs/guides/SCCM_2509_Post-Upgrade_Change_Window_Checklist.md)
- Service review findings and previous incidents

**Suggested reporting or evidence:**
- Use a formal pre-, during-, and post-change checklist
- Record screenshots, timestamps, and validation outputs
- Attach all evidence to the change ticket or Jira task

**Acceptance criteria:**
- Change validation checklist exists
- Go or no-go criteria are documented
- Rollback triggers are defined for major changes

### Task 27: Software Governance - Audit application versions and metadata quality
**Description:**
Review whether applications have accurate publisher, version, and related metadata, and identify software families where outdated versions remain active without a clear support rationale.

This task matters because version ambiguity weakens deployment decisions, vulnerability response, and software rationalization.

**Suggested data sources:**
- SCCM application metadata
- Vendor release information
- [scripts/SCCM/SCCM-SoftwareVersionAudit.ps1](scripts/SCCM/SCCM-SoftwareVersionAudit.ps1)
- [scripts/SCCM/SCCM-EnrichSoftwareMetadata.ps1](scripts/SCCM/SCCM-EnrichSoftwareMetadata.ps1)

**Suggested reporting or evidence:**
- Produce a report of current versus latest known versions
- Highlight unresolved vendor or version mapping gaps
- Use the results to plan version cleanup and standardization

**Acceptance criteria:**
- Metadata quality gaps are visible
- Version review report exists
- A prioritized list of outdated or unclear application objects is available

---

## Phase 7: Reporting, Service Reviews, and Stakeholder Management

### Task 28: Reporting - Create an operational SCCM dashboard
**Description:**
Create a single operational dashboard that brings together device baseline, client health, deployment failures, content issues, patch compliance, and stale object counts. The dashboard should support both daily triage and weekly service reviews.

This task matters because service ownership depends on seeing platform health in one place rather than hunting through console nodes.

**Suggested data sources:**
- Monthly and weekly SCCM exports
- Outputs from client health, deployment failure, update compliance, and stale object reporting
- Manual KPI collection where automation does not yet exist

**Suggested reporting or evidence:**
- Build the first version in Excel or Power BI
- Include a summary tab for service health and a detail tab per domain
- Save snapshots monthly to show trend movement

**Acceptance criteria:**
- Dashboard exists and can be updated reliably
- Core SCCM service indicators are represented
- Weekly service review can be driven from the dashboard

### Task 29: Reporting - Establish a weekly service review pack
**Description:**
Define a recurring weekly report pack that summarizes open operational risks, top failures, patching posture, content issues, client health concerns, and upcoming changes. Tailor the report so it is useful for both engineers and service owners.

This task matters because good operations need a disciplined review rhythm, not just dashboards that nobody reads.

**Suggested data sources:**
- Dashboard outputs
- Open incidents and problem records
- Current change calendar
- Deployment and compliance exceptions

**Suggested reporting or evidence:**
- Produce a one-page weekly summary and attach detail exports as needed
- Track action owners against the top five issues each week
- Keep prior weeks for trend and accountability review

**Acceptance criteria:**
- Weekly service review pack format is defined
- Inputs and owners are clear
- Actions can be tracked from one review to the next

### Task 30: Reporting - Define SCCM KPIs, thresholds, and audience-specific views
**Description:**
Create a KPI catalogue that defines what the Endpoint Manager measures, why each metric matters, what threshold is acceptable, who consumes it, and what action should follow if the threshold is breached.

This task matters because raw numbers are not management information until they have context and thresholds.

**Suggested data sources:**
- Existing operational reports
- Service level expectations
- Audit or compliance reporting needs
- Leadership reporting preferences

**Suggested reporting or evidence:**
- Build a KPI register with owner, metric formula, data source, and review frequency
- Define RAG thresholds for each KPI
- Maintain both technical and executive views of the same metrics

**Acceptance criteria:**
- KPI catalogue is documented
- Thresholds and audience mappings are agreed
- Breach handling expectations are clear

### Task 31: Reporting - Build audit evidence and compliance reporting standards
**Description:**
Define what evidence must be retained for deployment decisions, patch compliance, cleanup, and major changes. Include where the evidence lives, how long it is retained, and what minimum proof is required for audit or service assurance reviews.

This task matters because evidence quality often determines whether operational claims are trusted.

**Suggested data sources:**
- Change records
- Compliance reviews
- Security or audit requirements
- Existing report outputs and logs

**Suggested reporting or evidence:**
- Create an evidence checklist for recurring SCCM activities
- Record which CSV, JSON, screenshots, logs, and approval notes must be stored
- Align evidence collection with the output conventions used by the script repository

**Acceptance criteria:**
- Evidence standard exists for routine and major activities
- Retention expectations are documented
- Reports and change records can be backed by traceable evidence

---

## Phase 8: Automation, Knowledge Management, and Service Maturity

### Task 32: Automation - Identify recurring SCCM activities suitable for scripting
**Description:**
Review recurring reporting, validation, and cleanup activities to identify which ones should be automated first. Focus on low-risk, high-frequency tasks such as exporting compliance, collecting client health evidence, validating content distribution, and producing stale object reports.

This task matters because Endpoint Managers become more effective when they spend less time on repetitive extraction and more time on analysis and decision-making.

**Suggested data sources:**
- Operational calendar
- Weekly service review actions
- Existing scripts in [scripts/SCCM](scripts/SCCM)
- Current manual reporting steps

**Suggested reporting or evidence:**
- Build an automation opportunity register with effort and value scoring
- Prioritize candidates by time saved and operational risk reduction
- Track whether automation reduced manual effort in subsequent cycles

**Acceptance criteria:**
- An automation backlog exists
- Candidates are prioritized logically
- Early automation targets support recurring reporting and validation

### Task 33: Automation - Implement scheduled report generation for key service views
**Description:**
Select the most valuable recurring reports and define how they should be generated automatically, where they will run, where outputs will be stored, and who receives them. Prefer report automation that improves visibility without making changes to endpoint state.

This task matters because consistent reporting is a prerequisite for service maturity and trend analysis.

**Suggested data sources:**
- Existing script outputs in [scripts/SCCM/output](scripts/SCCM/output)
- Operational dashboard requirements
- Team scheduling standards such as Task Scheduler or orchestrators

**Suggested reporting or evidence:**
- Create a schedule matrix listing report, frequency, runtime host, output path, and recipients
- Validate one or two reports end to end before scaling further
- Keep logs and sample outputs for each automated job

**Acceptance criteria:**
- At least one high-value report is automatable end to end
- Scheduling, output location, and ownership are documented
- Automation logs and outputs are retained for review

### Task 34: Knowledge - Create a runbook set for top operational scenarios
**Description:**
Write practical runbooks for common SCCM scenarios such as failed software deployment triage, unhealthy client remediation, update compliance follow-up, content distribution failures, and safe cleanup preparation.

This task matters because operational maturity depends on repeatable actions that do not rely on a single expert.

**Suggested data sources:**
- Incident history
- Existing script usage patterns
- Weekly service review outcomes
- Change validation checklists

**Suggested reporting or evidence:**
- Produce one runbook per high-frequency scenario
- Include screenshots, expected evidence, and escalation triggers
- Store runbooks in the team knowledge base and review them quarterly

**Acceptance criteria:**
- Core operational runbooks exist
- Each runbook includes evidence and escalation guidance
- A new team member can use the runbooks without hidden assumptions

### Task 35: Knowledge - Build an Endpoint Manager onboarding pack
**Description:**
Create a condensed onboarding pack for future Endpoint Managers containing environment overview, console navigation tips, critical reports, common failure paths, key contacts, and the expected operational calendar.

This task matters because service continuity improves when new ownership can start from documented reality rather than oral history.

**Suggested data sources:**
- Outputs from earlier foundation and runbook tasks
- KPI catalogue and service review pack
- Core architecture diagrams and terminology guide

**Suggested reporting or evidence:**
- Assemble a short handbook in Markdown, Word, or wiki format
- Include links to the most important reports and runbooks
- Review onboarding usefulness with another engineer or team lead

**Acceptance criteria:**
- Onboarding pack exists and is understandable
- It points to the correct reports, systems, and runbooks
- Another engineer can validate its usefulness

### Task 36: Maturity - Define the quarterly improvement roadmap for the SCCM service
**Description:**
Create a rolling quarterly roadmap covering technical debt, cleanup targets, automation candidates, reporting improvements, packaging standards, and reliability improvements. Separate urgent risk reduction from longer-term service maturity investments.

This task matters because a capable Endpoint Manager should continuously improve the platform rather than only maintain it.

**Suggested data sources:**
- Service review trends
- Failure and compliance reports
- Governance backlog and stale object findings
- Stakeholder feedback and audit recommendations

**Suggested reporting or evidence:**
- Produce a quarterly roadmap with objectives, owners, and success metrics
- Include effort, value, and risk-reduction rationale
- Review roadmap status during monthly or quarterly governance meetings

**Acceptance criteria:**
- Quarterly roadmap exists and is prioritized
- Improvement items are linked to evidence and service pain points
- Progress can be tracked over time

---

## Suggested Jira Field Conventions

**Issue Type:** Task

**Priority guidance:**
- High: Client health, patch compliance, content failures, high-risk cleanup, or critical reporting gaps
- Medium: Documentation, KPI definition, automation planning, packaging standards
- Low: Nice-to-have dashboard enhancements or long-range improvements without immediate risk reduction

**Suggested labels by category:**
- `foundation`
- `inventory`
- `collections`
- `client-health`
- `applications`
- `deployments`
- `software-updates`
- `governance`
- `reporting`
- `automation`

**Suggested custom fields if available:**
- Service area
- Reporting cadence
- Operational owner
- Evidence location
- Review frequency

---

## Suggested First-Wave Prioritization

If the full backlog is too large to create at once, start with these first 10 tasks:
1. Task 1: Confirm SCCM access, roles, and working context
2. Task 4: Establish the baseline operational calendar
3. Task 5: Build a baseline endpoint estate inventory
4. Task 7: Review collection design and naming standards
5. Task 8: Audit boundary groups and site assignment coverage
6. Task 9: Build a baseline client health dashboard
7. Task 12: Create recurring client health reporting
8. Task 16: Build a deployment failure reporting process
9. Task 20: Build a monthly update compliance report
10. Task 28: Create an operational SCCM dashboard

These 10 tasks create visibility first, then improve control.