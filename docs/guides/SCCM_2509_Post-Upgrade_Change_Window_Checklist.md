# SCCM 2509 Post-Upgrade Change Window Checklist

Purpose: Step-by-step runbook for validating a Configuration Manager 2509 upgrade during the change window and immediate hypercare period.

Audience: Administrators running or validating an in-console upgrade who need an evidence-driven checklist.

How to use this document:
1. Fill the environment fields before the change starts.
2. Follow the decision gates in order.
3. Stop progression when a gate fails.
4. Record evidence paths and timestamps as you go.

Repository validation aids:

- scripts/SCCM/SCCM-TestClientHealth.ps1
- scripts/SCCM/SCCM-ValidateContentDistribution.ps1
- scripts/SCCM/SCCM-SoftwareUpdateComplianceReport.ps1

---

## 0) Change Setup

### A. Confirm people and communication

- [ ] Change ticket approved and visible.
- [ ] Bridge or chat channel open and tested.
- [ ] Escalation contacts identified for SCCM, SQL, server, and support owners.

### B. Confirm rollback readiness

- [ ] Latest known-good backup timestamp documented.
- [ ] Restore owner and restore method confirmed.
- [ ] Rollback trigger conditions agreed.

### C. Fill environment details

- [ ] Hierarchy type: ____________________
- [ ] Site code: ____________________
- [ ] Top-level site server: ____________________
- [ ] SQL server and instance: ____________________
- [ ] Secondary sites, if any: ____________________
- [ ] Number of active admin consoles: ____________________

### D. Start execution log

- Change start time: ____________________
- Operator name: ____________________
- Evidence path: ____________________

---

## 1) Immediate Post-Upgrade Health

Goal: Prove the upgrade completed correctly before broad client impact is accepted.

### 1.1 Update state

- [ ] Updates and Servicing Status shows the 2509 update as complete.
- [ ] Post-install tasks show no blocking failures.
- [ ] Relevant logs reviewed for persistent errors.

### 1.2 Site and role versions

- [ ] Sites node shows expected version.
- [ ] Key site roles are online and healthy.
- [ ] Distribution points and remote roles show expected status.

### 1.3 Replication sanity check

- [ ] Site hierarchy status is healthy.
- [ ] Database replication backlog is acceptable.

Decision gate:

- [ ] Go to stabilization only if update, role, and replication checks are healthy.

---

## 2) Stabilization and Core Service Validation

Goal: Restore temporary settings and prove the platform can still perform basic management tasks.

### 2.1 Restore temporary pre-upgrade changes

- [ ] Maintenance tasks restored.
- [ ] SQL or AG settings restored where applicable.
- [ ] Temporary security or antivirus exceptions removed.

### 2.2 Platform smoke tests

- [ ] One client retrieves policy successfully.
- [ ] One application deployment succeeds.
- [ ] One software update synchronization and visibility check succeeds.
- [ ] One new or reinstalled client registers successfully.

Useful evidence sources:

- client-health output from scripts/SCCM/SCCM-TestClientHealth.ps1
- content-validation output from scripts/SCCM/SCCM-ValidateContentDistribution.ps1

Decision gate:

- [ ] Go to pilot validation only if core management workflows work normally.

---

## 3) Pilot and OSD Validation

Goal: Validate user-impacting paths before declaring the upgrade stable.

### 3.1 Pilot client validation

- [ ] Pilot devices receive policy.
- [ ] Pilot devices install a test application.
- [ ] Pilot devices complete inventory and update scan.
- [ ] No systemic regression is visible in the pilot sample.

### 3.2 OSD readiness

- [ ] Boot images redistributed where required.
- [ ] PXE or media test succeeds.
- [ ] One test task sequence completes expected stages.

### 3.3 Automation validation

- [ ] Critical SCCM automation scripts still run.
- [ ] Reporting and monitoring integrations still function.

Decision gate:

- [ ] Declare stable only if pilot, OSD, and automation checks pass.

---

## 4) Evidence Pack

Collect and attach all of the following:

- [ ] final Updates and Servicing status evidence
- [ ] site and replication evidence
- [ ] console-version evidence
- [ ] smoke test records
- [ ] pilot validation records
- [ ] OSD test records, if OSD is used
- [ ] note of restored temporary settings
- [ ] incident timeline or remediation notes

---

## 5) Rollback Trigger Review

Start rollback review immediately if any of these are true:

- [ ] the upgrade is failed or stuck beyond the change window
- [ ] replication health worsens materially
- [ ] core endpoint-management workflows are broken
- [ ] OSD or patching cannot be restored quickly enough
- [ ] security or compliance posture is negatively affected

Before rollback execution:

- [ ] backup integrity is reconfirmed
- [ ] business-impact assessment is captured
- [ ] rollback approval is recorded
