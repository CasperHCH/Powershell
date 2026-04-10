# SCCM Service Map and Terminology Guide

Purpose: Provide a reusable, beginner-friendly service map for SCCM/MECM that can be validated against the local environment without assuming one specific site layout.

Audience: Endpoint Managers, SCCM administrators, service owners, and new team members.

Status: Repository-aligned template. Validate the placeholders and checkpoints below against the live console before treating this as environment truth.

---

## 1. How to Use This Guide

Use this document to explain how the SCCM service works in your environment, then fill in the missing environment-specific details with exports, screenshots, and script output.

Document these items first:

- hierarchy type: standalone primary or CAS hierarchy
- site code and primary administration host
- management points, distribution points, and software update points
- core device collections for production, pilot, exclusions, and governance
- main deployment workflows for applications, updates, and client remediation

Use these repository assets as validation aids:

- scripts/SCCM/README.md
- scripts/SCCM/SCCM-BoundaryGroupAudit.ps1
- scripts/SCCM/SCCM-CollectionAnalyse.ps1
- scripts/SCCM/SCCM-TestClientHealth.ps1
- scripts/SCCM/SCCM-ValidateContentDistribution.ps1

---

## 2. Logical Service Map

### Topology Layer

SCCM is usually organized around one or more site servers and supporting site-system roles.

- Site server
  - hosts the site database connection and central management functions
- Management point
  - receives client requests for policy and location information
- Distribution point
  - stores deployment content for clients
- Software update point
  - integrates update metadata and compliance workflows
- SQL platform
  - stores site data, state messages, inventory, and reporting data

### Endpoint Management Flow

The normal endpoint flow looks like this:

1. A device is discovered or onboarded.
2. The SCCM client becomes installed and assigned.
3. The device appears in inventory and one or more collections.
4. Collections determine targeting for software, updates, baselines, and governance.
5. Content is distributed to the relevant distribution points.
6. The client retrieves policy, evaluates applicability, downloads content, and executes work.
7. State messages, inventory, and compliance data return to SCCM.
8. Operators review health, failures, compliance, and drift.

### Control Layers

Think about the service in these layers:

- discovery and assignment
- boundaries and content location
- collections and targeting
- content preparation and distribution
- deployment execution
- compliance, failure analysis, and remediation

---

## 3. Console Areas and What They Mean

### Administration

Use this area to understand platform structure.

- Sites: site topology, version, and high-level health
- Servers and Site System Roles: which servers host which roles
- Boundaries and Boundary Groups: network scoping and content location
- Security: RBAC and administrative scope

### Assets and Compliance

Use this area to understand the estate being managed.

- Devices: inventory and endpoint state
- Device Collections: targeting, governance, and operational segmentation
- User Collections: user-based delivery patterns where used

### Software Library

Use this area to understand what gets delivered.

- Applications: install, detection, supersedence, and deployment types
- Packages and Programs: legacy or specialized deployment content
- Software Updates: update catalog and deployment bundles
- Operating Systems: boot images, task sequences, and OSD dependencies

### Monitoring

Use this area to understand whether the service is healthy.

- deployment status
- software update compliance
- component status
- content distribution state
- client health trends

---

## 4. Script-to-Service Map

The repository already contains scripts that map cleanly to the service model.

| Service area | Useful scripts | Typical outcome |
|---|---|---|
| Boundary validation | scripts/SCCM/SCCM-BoundaryGroupAudit.ps1 | boundary-group coverage and linkage review |
| Collection design | scripts/SCCM/SCCM-CollectionAnalyse.ps1, scripts/SCCM/SCCM-CollectionMembershipDriftReport.ps1 | collection inventory and drift analysis |
| Client health | scripts/SCCM/SCCM-TestClientHealth.ps1, scripts/SCCM/SCCM-RepairClientHealth.ps1, scripts/SCCM/SCCM-RunClientActionsLocal.ps1 | health baseline and remediation path |
| Deployment failures | scripts/SCCM/SCCM-DeploymentFailureReport.ps1, scripts/SCCM/SCCM-RetryFailedDeployments.ps1 | failure reporting and retry workflow |
| Update servicing | scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1 | compliance summary and detail exports |
| Content validation | scripts/SCCM/SCCM-ValidateContentDistribution.ps1, scripts/SCCM/SCCM-RedistributeFailedContent.ps1 | distribution-state review and recovery |

---

## 5. Working Terminology Guide

### Site

An administrative unit that manages clients, content, and reporting.

### Site System Server

A server that hosts one or more SCCM roles.

### Management Point

The role clients use to obtain policy and location-related information.

### Distribution Point

The role that stores deployment content for client download.

### Boundary

A network location definition such as an IP subnet, AD site, or IP range.

### Boundary Group

A logical grouping of boundaries used for site assignment and content location.

### Collection

A logical group of devices or users used for targeting and reporting.

### Limiting Collection

The parent scope that constrains collection membership.

### Deployment Type

The install, detection, and uninstall logic for an application delivery method.

### Required Deployment

A deployment the client installs automatically according to schedule and policy.

### Available Deployment

A deployment users can install on demand from Software Center.

### Supersedence

A relationship where one application version replaces another.

### Software Update Group

A curated bundle of updates prepared for deployment.

### Deployment Package

The content container that stores update binaries for distribution.

### ADR

An Automatic Deployment Rule that selects updates using defined criteria and can create or update deployments.

---

## 6. Evidence Checklist

Use this checklist before marking your local version complete:

- export of site systems and roles
- export or screenshots of key device collections
- boundary-group review output
- one client health report
- one content-distribution validation report
- a short note documenting the real onboarding flow for new devices

---

## 7. Open Questions to Validate Locally

Do not treat these as answered unless the current environment proves them:

- how clients are assigned during imaging or manual onboarding
- which collections are production, pilot, exception, and governance collections
- whether update rings and application rings use the same collection strategy
- whether all site systems are still active and intentionally placed
- which reports are operationally important to management, audit, and support teams
