# SCCM Software Update Servicing Model

Purpose: Provide a reusable software update servicing model for SCCM/MECM that can be adapted to the live environment without carrying forward screenshot-specific assumptions.

Audience: Endpoint Managers, SCCM administrators, service owners, and change stakeholders.

Status: Repository-aligned template. Confirm cadence, targeting, ADR behavior, and restart policy against the current environment before treating this guide as operational truth.

---

## 1. Core Update Components

Most SCCM update services are built from the same core objects:

- Software Updates: the update catalog and metadata view
- Software Update Groups: logical bundles of selected updates
- Deployment Packages: content containers for update binaries
- Automatic Deployment Rules: scheduled logic for selecting and deploying updates
- Collections: the targeting layer for pilot, production, exceptions, and special handling
- Monitoring views and reports: the evidence layer for compliance and failures

If third-party catalogs are enabled, treat them as an extension of the same servicing model rather than a separate process.

---

## 2. End-to-End Service Flow

The normal servicing path looks like this:

1. Synchronize update metadata.
2. Review or decline irrelevant updates.
3. Build or refresh Software Update Groups.
4. Ensure deployment-package content is downloaded and distributed.
5. Target collections through ADRs or manual deployments.
6. Let clients scan, evaluate applicability, download content, and install updates.
7. Review restart state, failures, and unknown devices.
8. Remediate non-compliance and repeat failures.
9. Publish compliance evidence and exception notes.

---

## 3. Operational Decisions to Document

Every environment should explicitly document these items:

- monthly or weekly patch cadence
- pilot-to-production promotion rules
- client and server restart behavior
- emergency patch process
- excluded or manually handled server groups
- ADR ownership and approval expectations
- reporting audiences and due dates

If any item above is unclear, treat it as an open operational gap rather than inferring behavior from object names.

---

## 4. Suggested Monthly Rhythm

Use a rhythm like this unless the local environment defines another model:

- readiness review: check synchronization, package content, targeting, and maintenance windows
- deployment window: observe ADR runs or manual deployments and confirm content health
- early validation: review first-wave compliance and failures
- remediation window: retry, remediate, or manually intervene on known failure groups
- closeout: publish final compliance, exceptions, and carry-forward actions

Record the actual local cadence in a short table:

| Phase | Day or trigger | Owner | Evidence |
|---|---|---|---|
| Readiness review | Fill locally | Fill locally | ADR status, package state |
| Initial deployment | Fill locally | Fill locally | deployment creation and targeting |
| Early compliance review | Fill locally | Fill locally | first compliance report |
| Exception remediation | Fill locally | Fill locally | retry and repair actions |
| Final closeout | Fill locally | Fill locally | final report and exception log |

---

## 5. Script Support in This Repository

These scripts support the update servicing workflow directly:

| Need | Useful scripts | Typical use |
|---|---|---|
| Compliance reporting | scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1 | export summary and detail reports |
| Distribution health | scripts/SCCM/SCCM-ValidateContentDistribution.ps1, scripts/SCCM/SCCM-RedistributeFailedContent.ps1 | detect and repair failed package distribution |
| Failure analysis | scripts/SCCM/SCCM-DeploymentFailureReport.ps1, scripts/SCCM/SCCM-RetryFailedDeployments.ps1 | inspect deployment failures and trigger retries |
| Client-side execution checks | scripts/SCCM/SCCM-TestClientHealth.ps1, scripts/SCCM/SCCM-RunClientActionsLocal.ps1, scripts/SCCM/SCCM-RepairClientHealth.ps1 | verify and repair clients that do not scan or report correctly |

---

## 6. Targeting Model Checklist

Confirm these targeting patterns before documenting the local model:

- workstation production collections
- workstation pilot collections
- server production collections
- server pilot or manual-approval collections
- exclusion collections
- stale or inactive-device collections that should not distort compliance reporting

If collection purpose is unclear, use scripts/SCCM/SCCM-CollectionAnalyse.ps1 and scripts/SCCM/SCCM-CollectionMembershipDriftReport.ps1 before changing any deployment scope.

---

## 7. Evidence Pack

Use the following evidence before calling the servicing model documented:

- one export or screenshot of ADR configuration
- one Software Update Group example
- one deployment-package content validation report
- one compliance summary export
- one exception list for failed, unknown, or restart-pending devices
- a written note on who approves emergency or out-of-band deployments

---

## 8. Open Questions to Resolve Locally

Common gaps that should be resolved in the local copy of this guide:

- whether servers are fully automatic, partially manual, or phased by maintenance window
- whether ADR names still reflect current behavior
- whether third-party update catalogs are actively deployed or only configured
- whether restart deadlines differ by endpoint type
- which stakeholder groups receive monthly compliance reporting
