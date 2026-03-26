# SCCM Primary Site Server Migration Guide (Version-Different Move)

## 1. Purpose and Scope
This guide is a practical runbook to migrate a Microsoft Configuration Manager (SCCM/ConfigMgr Current Branch) **primary site server** from one server to another when there is a **version difference** (OS and/or ConfigMgr build gap).

Use this guide for:
- Standalone primary site migration
- Primary site migration in hierarchies (with minor adjustments for CAS)
- Side-by-side moves to new hardware/VM

This guide assumes:
- SCCM Current Branch (not legacy SCCM 2012)
- Existing SQL backup strategy is available
- Change window is approved

## 2. Migration Strategy (Recommended)
Use a **side-by-side migration with site backup and site recovery**. This is the safest path for version-different moves.

High-level flow:
1. Bring source site to a supported, stable version.
2. Take validated site + SQL backups.
3. Build target server and prerequisites.
4. Recover site on target server.
5. Re-point dependencies and validate.
6. Decommission source after a stabilization period.

## 3. Version-Difference Rules
When source and target differ, follow these rules:

1. Do not attempt to migrate from an unsupported build.
2. Patch source site to a supported build before final backup.
3. Recover site first, then upgrade to your desired target build if needed.
4. Keep ADK/WinPE, SQL version, and WSUS/SUP dependencies aligned with the recovered SCCM version.
5. Keep rollback possible until production validation is complete.

## 3.1 Version-Specific Path: Source 2403 -> Destination 2503
For your specific scenario (source 2403, destination 2503), use this order:

1. Keep production source stable on 2403 and install applicable hotfix rollup for that build.
2. Build the destination server with supported OS/SQL/prerequisites for both 2403 recovery and planned 2503 operation.
3. Perform final site backup and SQL backup from 2403 source.
4. Recover the site on destination server first.
5. Validate core operations while still effectively on recovered state.
6. Upgrade recovered destination site to 2503 in a controlled maintenance window.
7. Run full post-upgrade validation, then cut over integrations and operational ownership.

Why this order:
- It reduces variables during recovery.
- It keeps rollback straightforward (source 2403 remains viable until 2503 validation sign-off).
- It isolates recovery risk from upgrade risk.

Operational recommendation:
- Plan two windows when possible:
	- Window 1: Recovery and basic service restoration.
	- Window 2: Upgrade to 2503 and expanded validation.

Go/No-Go criteria between windows:
- MP, SUP, and DB health are stable.
- Pilot clients can receive policy and complete update scan cycle.
- No critical component status errors persist.

## 4. Pre-Migration Checklist

## 4.1 Governance and Access
- Confirm CAB/change ticket approval.
- Confirm maintenance window and outage communications.
- Confirm local admin, SQL admin, SCCM Full Administrator permissions.

## 4.2 Capture Current State (Export/Baseline)
- Site code, site server FQDN, SCCM build version.
- Site roles on current server (MP, SUP, DP, etc.).
- SQL Server instance details and collation.
- Boundary groups and assigned site settings.
- Client health baseline (active clients, unhealthy clients).
- Replication/component status baseline.

Suggested baseline commands (run from SCCM PowerShell session):
```powershell
# Site and version
Get-CMSite

# Distribution points and MPs
Get-CMDistributionPoint
Get-CMManagementPoint

# Software update points
Get-CMSoftwareUpdatePoint
```

## 4.3 Backup Validation
- Verify latest **Site Server Backup** completed successfully.
- Verify SQL DB backup + transaction log backup (if used).
- Verify backup restore test (at least one non-production validation).
- Copy backup payload to target-side secure path.

## 4.4 Dependency Readiness
- ADK + WinPE versions compatible with planned SCCM build.
- SQL version/collation supported.
- Service accounts and SPNs documented.
- PKI certs (if used) exported and available.
- Firewall/network rules ready for target server.

## 5. Build Target Server

1. Provision target server (CPU/RAM/disk per sizing).
2. Join domain; apply hardening baseline.
3. Install required Windows features.
4. Install prerequisites (.NET, BITS, WSUS prereqs if SUP will be local).
5. Install SQL (if local SQL is part of the move) with supported collation.
6. Install SCCM prerequisites tool output and verify no blockers.

## 6. Migration Runbook (Execution)

## Phase A - Finalize Source
1. Freeze high-risk changes (new role installs, major package restructures).
2. Ensure replication/component status is healthy.
3. Trigger final site backup and SQL backup.
4. Stop optional non-critical jobs during cutover window.

Go/No-Go check:
- Last backup valid
- No critical component errors
- Rollback checkpoint captured

## Phase B - Recover on Target
1. Launch SCCM Setup on target.
2. Select **Recover a site**.
3. Provide backup path and site DB details.
4. Complete setup and monitor `ConfigMgrSetup.log` and component logs.
5. Reinstall/rebind roles that must move with the site server.

Notes:
- If server name changes, validate all references and certificates.
- If SQL host changes, validate SQL permissions, SPNs, and connectivity.

## Phase C - Dependency Rebind
1. Validate MP/SUP/DP role state.
2. Validate WSUS/SUP sync and classifications/products.
3. Revalidate boundaries and boundary group mappings.
4. Revalidate discovery methods and maintenance tasks.
5. Reconfigure monitoring integrations (Zabbix checks, backup jobs, alert routing).

## Phase D - Controlled Client Reassignment (if needed)
1. Validate a pilot device collection first.
2. Confirm policy retrieval and software deployment execution.
3. Expand in waves after pilot success.

## 7. Post-Migration Validation (Mandatory)

## 7.1 Platform Health
- Site status green/no critical alerts.
- Component status healthy.
- Database replication healthy (if hierarchy).

## 7.2 Client Operations
- Clients receive policy.
- Hardware/software inventory cycles succeed.
- Software update scans and deployments succeed.
- OSD/PXE (if used) tested.

## 7.3 Content and Update Workflows
- Content distribution to DPs succeeds.
- Application deployment to test collection succeeds.
- ADR/SUP synchronization succeeds.

## 7.4 Reporting and Integrations
- SCCM reports load successfully.
- Ivanti CMDB ingest jobs (if consuming SCCM data) still succeed.
- Zabbix monitoring points to new server/roles and alerts normally.

## 8. Rollback Plan
Prepare rollback before cutover begins.

Rollback triggers (examples):
- Critical site components remain failed beyond agreed threshold.
- Client policy failures exceed agreed threshold.
- SUP/patch management unavailable beyond SLA.

Rollback actions:
1. Stop migration execution and freeze changes.
2. Redirect DNS/monitoring/integrations to source server.
3. Bring source services back to active state.
4. Validate client communication and patch workflows.
5. Document root cause and reschedule migration.

## 9. Recommended Timeline

1. Week 1: Assessment, compatibility checks, dependency inventory.
2. Week 2: Target build, prerequisite validation, dry run in lab/pre-prod.
3. Week 3: Production migration in maintenance window.
4. Week 4: Hypercare and source server decommission decision.

## 10. Common Pitfalls to Avoid

1. Migrating from outdated/unsupported source version.
2. Skipping tested restore validation.
3. Forgetting ADK/WinPE compatibility.
4. Missing SQL collation or permission requirements.
5. Cutting over without a hard rollback checkpoint.
6. Reassigning all clients at once instead of pilot waves.

## 11. Suggested Deliverables for Your EPM Team

1. Migration decision record (architecture + risks).
2. Pre-cutover checklist signed by SCCM/DBA/Network/Security.
3. Execution log with timestamps and owners.
4. Validation report (technical + service impact).
5. Post-implementation review with lessons learned.

## 12. Minimal Run Checklist (One-Page)

1. Confirm source version support and patch level.
2. Confirm healthy SCCM component state.
3. Take and verify final SCCM + SQL backups.
4. Build and validate target prerequisites.
5. Recover site on target.
6. Validate MP/SUP/DP and pilot clients.
7. Confirm patching, deployment, reporting.
8. Keep rollback viable until sign-off.
9. Complete hypercare, then decommission source.

---

## Appendix A - Practical Validation Questions
- Can a newly imaged or existing pilot client get policy within expected SLA?
- Can pilot client install one test application successfully?
- Can pilot client scan and receive software updates?
- Are SCCM alerts and Zabbix alerts both healthy and not duplicated?
- Are CMDB synchronization jobs reflecting the new SCCM authority correctly?

## Appendix B - Security and Compliance Notes
- Do not embed credentials in scripts or setup INI files in plain text.
- Store migration artifacts and logs in restricted paths.
- Maintain audit trail for all cutover actions and approvals.
- Sanitize exported logs before sharing outside admin teams.
