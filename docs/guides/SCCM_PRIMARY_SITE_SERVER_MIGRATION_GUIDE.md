# SCCM Primary Site Server Migration Guide

Purpose: Provide a practical runbook for moving a Configuration Manager primary site to a new server when the operating system, SQL build, or Configuration Manager version differs between source and destination.

Audience: SCCM administrators, infrastructure engineers, DBAs, and change leads.

Status: Reusable migration runbook. Fill in environment-specific values and dependency owners before execution.

---

## 1. Recommended Strategy

Use a side-by-side migration with validated backup and recovery unless Microsoft guidance for your exact version path requires another approach.

High-level flow:

1. Bring the source site to a supported and stable build.
2. Capture validated site and SQL backups.
3. Build the destination server and prerequisites.
4. Recover the site on the destination.
5. Rebind dependencies and validate core services.
6. Keep rollback viable until production sign-off.

---

## 2. Version-Difference Rules

Follow these rules for version-different moves:

1. Do not migrate from an unsupported source build.
2. Recover first, then upgrade further only after core validation.
3. Keep SQL, ADK, WinPE, and WSUS dependencies aligned with the recovered build.
4. Separate recovery risk from upgrade risk where possible.
5. Preserve a tested rollback point until pilot validation is complete.

If you need to document a specific example path, add it as a local appendix rather than embedding one environment's upgrade sequence into the base guide.

---

## 3. Pre-Migration Checklist

### Governance and Access

- change approval and communications confirmed
- SCCM, SQL, server, and network owners identified
- required admin permissions confirmed

### Baseline Capture

- site code, version, and topology exported
- site roles and site-system servers documented
- boundary groups and assignment behavior documented
- client-health and component-health baseline captured

### Backup Validation

- latest site backup validated
- latest SQL backup validated
- restore test evidence available
- backup payload copied to a controlled destination

### Dependency Readiness

- ADK and WinPE compatibility confirmed
- SQL version and collation confirmed
- service accounts and certificates documented
- firewall and name-resolution dependencies prepared

---

## 4. Execution Phases

### Phase A: Freeze and Finalize Source

1. Freeze high-risk changes.
2. Confirm healthy component status.
3. Run final site and SQL backups.
4. Capture rollback checkpoint details.

### Phase B: Recover on Destination

1. Launch setup and choose site recovery.
2. Supply validated backup and database details.
3. Monitor setup and component logs.
4. Reinstall or validate roles that must move with the site server.

### Phase C: Rebind Dependencies

1. Validate management point, software update point, and distribution-point behavior.
2. Recheck boundaries, boundary groups, and content location.
3. Reconfigure monitoring, scheduled jobs, and reporting integrations.
4. Update any automation that points to the old host.

### Phase D: Pilot Validation

1. Validate one pilot collection first.
2. Confirm client policy retrieval, content download, software deployment, and update scan.
3. Expand only after pilot success.

---

## 5. Post-Migration Validation

### Platform Health

- site status and component status healthy
- replication healthy where applicable
- key logs reviewed for persistent errors

### Client Operations

- policy retrieval works
- hardware and software inventory works
- test application deployment works
- software update scan and deployment works

### Content and Update Workflows

- content distribution succeeds
- distribution-point state is healthy
- update synchronization succeeds

### Reporting and Automation

- required reports load successfully
- automation pointing to SCCM still succeeds
- monitoring no longer targets the retired host

Useful repository scripts during validation:

- scripts/SCCM/SCCM-TestClientHealth.ps1
- scripts/SCCM/SCCM-ValidateContentDistribution.ps1
- scripts/SCCM/SCCM-BoundaryGroupAudit.ps1
- scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1

---

## 6. Rollback Position

Prepare rollback before starting execution.

Rollback triggers can include:

- persistent critical component failure
- widespread client policy or content failures
- broken update servicing beyond agreed tolerance
- unresolved database or replication errors

Rollback actions should be documented locally and should include who approves rollback, how source services are reactivated, and how client impact is measured.

---

## 7. Evidence Pack

Capture these items for the change record:

- approved checklist with owners and timestamps
- backup validation evidence
- recovery log references
- pilot validation results
- final service-health summary
- rollback readiness note or rollback decision record
