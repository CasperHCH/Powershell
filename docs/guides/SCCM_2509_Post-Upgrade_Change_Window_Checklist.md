# SCCM 2509 Post-Upgrade Change Window Checklist (Detailed Beginner Runbook)

Purpose: Step-by-step, beginner-friendly runbook for post-upgrade validation after moving Configuration Manager from 2403 to 2509.

Audience: Administrators who may not perform ConfigMgr upgrades often and need exact instructions.

How to use this document:
1. Follow sections in order.
2. Do not skip decision gates.
3. If a check fails, stop and run the listed corrective action before continuing.
4. Record evidence and timestamps as you go.

---

## 0) Change Setup (Do This Before Starting T+0 Clock)

### A. Confirm people and communication

- [ ] Change ticket approved and visible to all participants.
- [ ] Bridge/chat channel open and tested.
- [ ] Escalation contacts ready:
	- [ ] SCCM owner
	- [ ] SQL DBA
	- [ ] Server/VM team
	- [ ] Microsoft support contact path

### B. Confirm rollback readiness

- [ ] Latest known-good backup timestamp is documented.
- [ ] Restore owner and restore method are confirmed.
- [ ] Business owner agrees to rollback trigger conditions in this document.

### C. Fill environment details

- [ ] Hierarchy type (standalone primary or CAS + child primary): ____________________
- [ ] Top-level site code: ____________________
- [ ] Top-level site server name: ____________________
- [ ] SQL server / instance: ____________________
- [ ] AG enabled? (Yes/No): ____________________
- [ ] Primary sites: ____________________
- [ ] Secondary sites: ____________________
- [ ] Number of remote consoles in use: ____________________

### D. Start execution log

- Change start time: ____________________
- Operator name: ____________________
- Notes:
	- ______________________________________________________________
	- ______________________________________________________________

---

## 1) T+0 to T+30: Immediate Post-Upgrade Health

Goal: Confirm the site upgrade actually finished correctly before touching clients or OSD.

### 1.1 Verify update status in console

Steps:
1. Open Configuration Manager console.
2. Go to Monitoring > Overview > Updates and Servicing Status.
3. Select the 2509 update item.
4. Confirm top-level state is Complete.
5. Expand details and review all phases (Replication, Prerequisites, Installation, Post Installation).

What success looks like:
- [ ] No phase shows Failed.
- [ ] Post Installation is completed.

If not successful:
- [ ] Capture exact error text.
- [ ] Note phase where it failed.
- [ ] Open relevant logs on site server:
	- [ ] CMUpdate.log
	- [ ] ConfigMgrPrereq.log (if prereq-related)
- [ ] Decide whether to Retry from Updates and Servicing per Microsoft guidance.

Evidence:
- [ ] Screenshot of final status and phases saved.
- File name/location: ____________________

### 1.2 Verify critical post-install tasks

Steps:
1. In the same status view, click Post Installation task details.
2. Confirm critical items complete, including:
	 - SMS_EXECUTIVE service reinstall
	 - SMS_DATABASE_NOTIFICATION_MONITOR
	 - SMS_HIERARCHY_MANAGER
	 - SMS_REPLICATION_CONFIGURATION_MONITOR
	 - SMS_POLICY_PROVIDER (primary)

What success looks like:
- [ ] All critical post-install tasks completed or not applicable.

If not successful:
- [ ] Wait 10-15 minutes and refresh.
- [ ] If still stuck, collect log details and escalate.

### 1.3 Verify versions on sites and site systems

Steps:
1. Go to Administration > Site Configuration > Sites.
2. Right-click column header, choose column selector, add Version if not shown.
3. Confirm top-level and child site versions are at 2509.
4. Go to Administration > Site Configuration > Servers and Site System Roles.
5. Verify key role servers are online and normal.
6. Go to Administration > Site Configuration > Servers and Site System Roles > Distribution Points (or Distribution Points node if used in your console layout), check version/status.

What success looks like:
- [ ] Top-level site is 2509.
- [ ] Child primary sites are upgraded (if hierarchy includes CAS).
- [ ] No critical site role remains failed.

If not successful:
- [ ] Restart affected remote role server if pending reboot or stale state suspected.
- [ ] Recheck component status.

### 1.4 Upgrade secondary sites manually (if any)

Steps:
1. Go to Administration > Site Configuration > Sites.
2. Select secondary site.
3. Click Upgrade in ribbon.
4. Confirm prompt.
5. Use Show Install Status and monitor until complete.

What success looks like:
- [ ] All secondary sites show expected 2509 version.

### 1.5 Update admin consoles

Steps:
1. On each admin workstation, open ConfigMgr console.
2. Accept update prompt immediately.
3. After update, go to About Configuration Manager.
4. Record console version.

What success looks like:
- [ ] All active admin consoles updated.

### 1.6 Replication sanity check

Steps:
1. Go to Monitoring > Site Hierarchy.
2. Confirm links are healthy.
3. Go to Monitoring > Database Replication.
4. Confirm replication groups are active and no growing backlog.

What success looks like:
- [ ] Link state healthy.
- [ ] No sustained increase in backlog.

If not successful:
- [ ] Do not continue to client rollout.
- [ ] Run Replication Link Analyzer workflow and escalate.

### Decision Gate at T+30

Proceed only if all are true:
- [ ] Update phases complete with no blocking errors.
- [ ] Site and role versions are correct.
- [ ] Replication is healthy.

If GO:
- [ ] Continue to Section 2.

If NO-GO:
- [ ] Freeze all non-remediation changes.
- [ ] Start targeted remediation.
- [ ] Open high-severity incident and prepare rollback briefing.

---

## 2) T+30 to T+60: Stabilization and Baseline Services

Goal: Restore temporarily changed settings and prove core ConfigMgr functions work.

### 2.1 Restore pre-upgrade temporary settings

Perform only what applies in your environment:

- [ ] Re-enable MP database replicas if previously disabled.
	- Steps performed by: ____________________
	- Time completed: ____________________
- [ ] Set SQL AG failover back to Automatic if set to Manual for upgrade.
	- Verified by DBA: ____________________
	- Time completed: ____________________
- [ ] Re-enable maintenance tasks that were disabled.
	- Backup Site Server restored schedule: [ ]
	- Delete Aged Client Operations restored schedule: [ ]
	- Delete Aged Discovery Data restored schedule: [ ]
- [ ] Restore antivirus real-time controls/policies to standard state.

What success looks like:
- [ ] No temporary upgrade-only settings left behind.

### 2.2 Validate inventory/customization/extension state

Steps:
1. Open Client Settings where hardware inventory classes were previously customized.
2. Confirm custom class states did not revert unexpectedly.
3. Check partner extension/add-on status and compatibility with 2509.
4. Run one smoke test for any custom automation script your team depends on.

What success looks like:
- [ ] Hardware inventory custom states match pre-upgrade baseline.
- [ ] Extensions are functional.
- [ ] Critical custom automations complete successfully.

### 2.3 Run platform smoke tests (minimum)

Test 1: Client policy retrieval
1. Pick one known healthy test client.
2. Trigger Machine Policy Retrieval and Evaluation Cycle.
3. Confirm policy arrival without errors.

Test 2: Application deployment
1. Deploy a small test app to pilot collection.
2. Confirm deployment policy received and install succeeds.

Test 3: Software update path
1. Run software updates synchronization.
2. Confirm sync completes.
3. Validate one test update deployment appears correctly.

Test 4: New client registration
1. Install ConfigMgr client on one test device.
2. Confirm it registers and appears Active in console.

What success looks like:
- [ ] All 4 tests pass.

If any test fails:
- [ ] Capture exact error text, target device, and time.
- [ ] Stop progression to next stage until failure is understood.

### Decision Gate at T+60

Proceed only if all are true:
- [ ] Core management workflows are working.
- [ ] No major replication/component deterioration.
- [ ] Restored dependencies remain stable.

If GO:
- [ ] Continue to Section 3.

If NO-GO:
- [ ] Pause broad rollout.
- [ ] Stay in remediation mode.
- [ ] Escalate to rollback decision board if service impact rises.

---

## 3) T+60 to T+120: Client and OSD Service Validation

Goal: Validate user-impacting paths before declaring stable.

### 3.1 Client upgrade pilot validation

Steps:
1. Confirm pre-production collection is configured (if used).
2. Deploy/allow 2509 client in pilot flow.
3. Validate pilot devices for:
	 - Policy retrieval
	 - App install
	 - Hardware/software inventory
	 - Software updates scan/install
4. Track failures by percentage and symptom.

What success looks like:
- [ ] Pilot success rate meets your change criteria.
- [ ] No systemic client regression found.

Decision:
- [ ] Record whether to promote to production now or defer to phased rollout.

### 3.2 OSD readiness validation

Steps:
1. Go to Software Library > Operating Systems > Boot Images.
2. For each boot image (default and custom), run Update Distribution Points.
3. Wait for content distribution completion to required DPs.
4. Validate PXE boot on one test machine.
5. If bootable media is used, regenerate media from current boot image.
6. Run one full test task sequence deployment.

What success looks like:
- [ ] PXE test passes.
- [ ] Task sequence test completes expected stages.
- [ ] No missing content errors.

If not successful:
- [ ] Check DP content status and boundary assignments.
- [ ] Re-run boot image update and redistribute.

### 3.3 PowerShell operations validation

Steps:
1. On each admin host with ConfigMgr console/module, open elevated PowerShell.
2. Run Update-Help for ConfigurationManager module.
3. Run one or two commonly used SCCM automation scripts.

What success looks like:
- [ ] Help updates successfully.
- [ ] No breaking changes in critical operations scripts.

### Decision Gate at T+120

Declare stable only if all are true:
- [ ] Client pilot is healthy.
- [ ] OSD path is validated end-to-end.
- [ ] No high-severity incidents caused by upgrade.

If GO:
- [ ] Declare change successful.
- [ ] Hand over to operations.
- [ ] Schedule phased broad client rollout if not already started.

If NO-GO:
- [ ] Compare remediation ETA versus rollback risk.
- [ ] Execute approved rollback plan if thresholds are met.
- [ ] If rollback is deferred, continue controlled operations with incident command.

---

## 4) Evidence Pack (CAB/Audit)

Collect and attach all of the following:

- [ ] Updates and Servicing Status final screenshot/export.
- [ ] Site Hierarchy and Database Replication screenshots/exports.
- [ ] Site version evidence (Sites node) and role status evidence.
- [ ] Console version evidence from About dialog.
- [ ] Smoke test records (policy/app/update/new client).
- [ ] OSD test records (boot image redistribution, PXE, TS result).
- [ ] List of restored temporary settings (AG, replicas, maintenance tasks, AV).
- [ ] Incident log with timeline and owner per action.

Evidence location (share/path/ticket): ____________________

---

## 5) Rollback Trigger Matrix

Start rollback review immediately if any condition is true:

- [ ] Upgrade remains failed/stuck and cannot be remediated in maintenance window.
- [ ] Replication health degrades and trend worsens.
- [ ] Core endpoint management is broken for pilot or broader scope.
- [ ] OSD business-critical process cannot be restored quickly.
- [ ] Security/compliance posture is negatively impacted by upgrade side effects.

Before executing rollback, confirm:

- [ ] Backup currency and integrity are validated.
- [ ] Data drift/business impact assessment is completed.
- [ ] Stakeholder approval captured in ticket/bridge notes.

Rollback decision time: ____________________
Rollback approved by: ____________________

---

## 6) Beginner Quick Commands and Where to Look

Use this section if you are not sure where to verify.

### A. Most important console paths

- Monitoring > Updates and Servicing Status
- Monitoring > Site Hierarchy
- Monitoring > Database Replication
- Administration > Site Configuration > Sites
- Administration > Site Configuration > Servers and Site System Roles
- Software Library > Operating Systems > Boot Images

### B. Most important upgrade logs on site server

- CMUpdate.log
- ConfigMgrPrereq.log

Default location pattern:
- <ConfigMgrInstallDir>\Logs

### C. Common beginner mistakes to avoid

- [ ] Do not start broad client rollout before replication health is confirmed.
- [ ] Do not forget manual upgrade of secondary sites.
- [ ] Do not assume default boot image update means DP content is already redistributed.
- [ ] Do not close the change without evidence artifacts.

---

## 7) Execution Notes (Freeform)

- [ ] Notes captured during execution:








---

## References

- https://go.microsoft.com/fwlink/p/?LinkId=626562
- https://learn.microsoft.com/en-us/intune/configmgr/core/servers/manage/checklist-for-installing-update-2509
- https://learn.microsoft.com/en-us/intune/configmgr/core/servers/manage/post-in-console-updates
- https://learn.microsoft.com/en-us/intune/configmgr/core/servers/manage/post-in-console-updates
