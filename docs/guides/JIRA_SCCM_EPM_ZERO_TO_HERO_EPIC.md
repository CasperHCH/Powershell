# Jira Epic: SCCM/MECM Endpoint Manager Zero-to-Hero

Purpose: Provide a Jira-ready epic and child-task series for building operational ownership of an SCCM/MECM environment.

Audience: Endpoint Managers, SCCM administrators, service owners, team leads, and operational managers.

How to use this document:
1. Create the epic first.
2. Create child tasks in the order shown or adapt them to your team's maturity level.
3. Replace placeholders such as site codes, collection names, and report audiences with real values.
4. Link each task to evidence in the repository, ticketing system, or knowledge base.

Repository support material:

- scripts/SCCM/README.md
- docs/guides/SCCM_SERVICE_MAP_AND_TERMINOLOGY.md
- docs/guides/SCCM_COLLECTION_DESIGN_AND_NAMING_REVIEW.md
- docs/guides/SCCM_SOFTWARE_UPDATE_SERVICING_MODEL.md

---

## Epic

**Epic Name:** SCCM/MECM Endpoint Manager Enablement and Operational Maturity

**Epic Goal:**
Establish operational ownership of the SCCM/MECM estate, including inventory accuracy, client health, collection governance, software deployment, patching, reporting, change control, and automation.

**Suggested Definition of Done:**
- Core SCCM areas are documented and understood.
- Recurring health and compliance reporting is in place.
- Standard runbooks exist for common failure and change scenarios.
- Cleanup and governance processes are defined.
- The Endpoint Manager can explain current health, risks, and required actions using evidence.

---

## Phase 1: Foundations and Environment Orientation

### Task 1: Confirm access, scope, and support boundaries

Document console access, RBAC scope, site hierarchy visibility, support ownership, and escalation paths.

Evidence:
- access matrix
- site-system export
- screenshots of role scope where appropriate

### Task 2: Build an SCCM service map and terminology guide

Explain discovery, assignment, collections, content, deployments, updates, and monitoring in plain language.

Evidence:
- completed local copy of docs/guides/SCCM_SERVICE_MAP_AND_TERMINOLOGY.md
- screenshots, exports, or diagrams proving the local topology

### Task 3: Standardize outputs and evidence storage

Define where exports, logs, reports, and change evidence are stored and retained.

Evidence:
- agreed folder standard
- sample monthly output path
- retention note

### Task 4: Establish the operational calendar

Create a recurring cadence for weekly checks, monthly patching, quarterly cleanup, and change windows.

Evidence:
- calendar or Jira recurring tasks
- owner list and due dates

---

## Phase 2: Estate Visibility and Collections

### Task 5: Build a baseline endpoint inventory

Establish a trusted denominator for managed endpoints, stale devices, and device-class breakdown.

Evidence:
- baseline CSV or dashboard
- summary of known data gaps

### Task 6: Reconcile SCCM with external sources

Compare SCCM with CMDB, monitoring, or security platforms and categorize the drift.

Evidence:
- drift report
- remediation backlog

### Task 7: Review collection design and naming

Audit collection purpose, naming, limiting collections, and deployment risk.

Evidence:
- completed local copy of docs/guides/SCCM_COLLECTION_DESIGN_AND_NAMING_REVIEW.md
- supporting exports from scripts/SCCM/SCCM-CollectionAnalyse.ps1

### Task 8: Audit boundaries and boundary groups

Confirm site assignment and content location are aligned with network reality.

Evidence:
- output from scripts/SCCM/SCCM-BoundaryGroupAudit.ps1
- gap list for suspect or missing entries

---

## Phase 3: Client Health and Deployment Operations

### Task 9: Build a client-health baseline

Define healthy client behavior and publish a baseline view.

Evidence:
- outputs from scripts/SCCM/SCCM-TestClientHealth.ps1
- grouped trend view of recurring failures

### Task 10: Learn the key client logs and failure patterns

Create a troubleshooting reference for policy, content, app-enforcement, and software-update logs.

Evidence:
- log reference sheet
- example incidents mapped to log evidence

### Task 11: Build deployment-failure reporting and retry flow

Create a repeatable process for summarizing failed deployments and performing safe retries.

Evidence:
- output from scripts/SCCM/SCCM-DeploymentFailureReport.ps1
- retry workflow using scripts/SCCM/SCCM-RetryFailedDeployments.ps1

---

## Phase 4: Software Updates and Governance

### Task 12: Document the software update servicing model

Describe cadence, targeting, restart behavior, compliance review, and exception handling.

Evidence:
- completed local copy of docs/guides/SCCM_SOFTWARE_UPDATE_SERVICING_MODEL.md
- compliance exports from scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1

### Task 13: Validate content-distribution health

Review failed and in-progress content distribution before it becomes deployment impact.

Evidence:
- validation output from scripts/SCCM/SCCM-ValidateContentDistribution.ps1
- remediation results from scripts/SCCM/SCCM-RedistributeFailedContent.ps1

### Task 14: Review stale collections, stale devices, and cleanup candidates

Build a cleanup backlog for collections and deployments that are no longer active or safe to keep unreviewed.

Evidence:
- outputs from scripts/SCCM/SCCM-AnalyzeStaleCollectionsAndDeployments.ps1
- approval-backed cleanup list

---

## Phase 5: Change, Improvement, and Resilience

### Task 15: Create upgrade and migration runbooks

Document how the environment validates upgrades and site moves.

Evidence:
- local copies of docs/guides/SCCM_PRIMARY_SITE_SERVER_MIGRATION_GUIDE.md and docs/guides/SCCM_2509_Post-Upgrade_Change_Window_Checklist.md

### Task 16: Identify automation opportunities and guardrails

Decide which recurring activities should be automated and what approval or WhatIf patterns are required.

Evidence:
- prioritized automation backlog
- review of scripts already present in scripts/SCCM/README.md

### Task 17: Publish the operating model

Consolidate the service map, collection standards, patching model, and change runbooks into a team-owned operating model.

Evidence:
- one index page or knowledge-base hub linking the validated guides and reports
