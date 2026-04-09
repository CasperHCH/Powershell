# SCCM Software Update Servicing Model

Purpose: Document the current software update servicing model for the SCCM environment, including patch cadence, update management components, operational flow, and the main validation gaps that remain.

Audience: Endpoint Managers, SCCM administrators, service owners, and change stakeholders.

Status: First-pass service model based on console screenshots and confirmed patching details. This is enough to close the first version of Task 19 and support later refinement in Task 20 and Task 21.

---

## 1. Confirmed Current-State Summary

The current environment includes these update-management elements:

- `All Software Updates`
- `Declined Updates`
- `Software Update Groups`
- `Deployment Packages`
- `Automatic Deployment Rules`
- `Third-Party Software Update Catalogs`

The visible ADR set currently includes:

- `SUG ALL_REQUIRED_MICROSOFT_SECURITY_UPDATES_DESKTOP - PILOT - PROD`
- `SUG ALL_REQUIRED_MICROSOFT_SECURITY_UPDATES_SERVERS - PILOT - PROD - MANUAL`
- `SUG MICROSOFT_EDGE-STABLE_CHANNEL - PILOT - PROD`

The current operating cadence is:

- Patch day is the fourth Wednesday of each month
- Most servers receive automatic updates
- All client devices receive automatic updates
- Restarts occur as needed to complete installation

This indicates the environment already has a functioning software update model with both Microsoft and third-party update capabilities.

The screenshot also confirms that the visible ADRs are enabled and currently reporting successful execution state.

The ADR deployment settings shown so far also confirm that both the desktop and server security-update ADRs are configured to automatically deploy all software updates found by the rule and automatically approve any license agreements.

---

## 2. End-to-End Update Service Flow

The current servicing model can be described as follows:

1. Updates are synchronized into SCCM and become visible in the Software Updates node.
2. Irrelevant or unwanted updates can be managed through decline practices.
3. Updates are grouped into Software Update Groups for deployment control.
4. Update content is stored and distributed using Deployment Packages.
5. Automatic Deployment Rules support recurring update selection and preparation.
6. Clients and servers receive targeted update deployments through SCCM collections.
7. Devices scan, evaluate applicability, download content, install updates, and restart when required.
8. Compliance is reviewed through SCCM monitoring views and collection-based reporting.
9. Exceptions and failures feed follow-up remediation work.

The currently visible model also suggests that pilot and production language is embedded directly in ADR naming, which is useful for change traceability.

---

## 3. Current Patch Cadence

### Standard Monthly Rhythm

- The fourth Wednesday of each month is the defined patch day
- Most servers are configured for automatic update installation
- All client devices are configured for automatic update installation
- Restart behavior is allowed when needed to complete patching

### Operational Meaning

For an Endpoint Manager, this means the service already has a predictable monthly execution point. That is useful because it allows reporting, exception review, and stakeholder communication to be organized around a known cycle.

### Practical Reporting Windows

These reporting checkpoints are recommended for the current model:

- T-3 to T-1 days: readiness review
- Patch day: deployment and monitoring watch
- T+1 day: initial compliance and failure summary
- T+3 to T+5 days: non-compliance and restart follow-up
- Month-end: final compliance summary and exception carry-forward

---

## 4. Update Components and Their Role

### All Software Updates

The master catalog view used to search, filter, and assess update scope.

### Declined Updates

A control point for removing unwanted or irrelevant updates from active servicing focus.

### Software Update Groups

The logical bundles used to organize and deploy selected updates to collections.

### Deployment Packages

The content containers used to distribute update binaries through the SCCM infrastructure.

### Automatic Deployment Rules

The automation mechanism used to regularly identify updates that meet defined criteria and prepare them for deployment.

From the current screenshot, ADRs are being used for at least:

- Microsoft security updates for desktops
- Microsoft security updates for servers
- Microsoft Edge Stable Channel updates

This confirms that ADRs are not only present in the console but actively part of the patching model.

The current deployment-settings screenshots also show that the visible desktop and server security ADRs are configured for broad automatic deployment behavior rather than a restricted license-preapproval-only mode.

### Third-Party Software Update Catalogs

Evidence that the update service likely includes supported non-Microsoft content as part of patch governance.

---

## 5. First-Pass Servicing Model by Endpoint Type

### Clients

- All clients auto-update
- Restarts are allowed as needed
- Collection-based targeting is assumed, but the exact ring mapping still needs validation
- Compliance reporting should be collection-based to make workstation results meaningful
- Desktop security updates appear to be managed through an enabled ADR with pilot and production intent in the naming
- Desktop security-update automation is configured to automatically deploy all matching updates found by the rule

### Servers

- Most servers auto-update
- Restarts are allowed as needed
- Because the statement is `most servers`, exception handling should be explicitly documented later
- Server collections should be treated separately from workstation collections in reporting and change review
- A server-focused ADR is visible and marked `MANUAL`, which suggests server patching may have additional approval or execution control compared with client patching
- The server security-update ADR is also configured to automatically deploy all matching updates found by the rule, so the `MANUAL` wording now looks more like process naming, legacy naming, or another-tab behavior that still needs confirmation

---

## 6. Role of Collections in Update Servicing

Even though the exact ring model is still being validated, the visible collection structure strongly suggests these likely update scopes:

- broad workstation population collections
- broad server population collections
- pilot collections for controlled rollout
- exclusion collections for devices that should not follow the main pattern
- governance collections for stale or transitional devices

This means the update servicing model should be understood as collection-driven, not just patch-catalog-driven. The patch process is only safe if collection purpose is clear.

The naming pattern in the visible ADRs reinforces this point because desktop, server, pilot, and production intent are all represented directly in the update automation layer.

---

## 6A. Confirmed ADR Behavior From Screenshot

The current screenshot provides these useful details:

- software update point synchronization occurs every 6 hours
- the desktop security-updates ADR is configured to run on a schedule
- that schedule is set to occur 1 day after the second Tuesday of every month
- the visible ADRs are enabled
- the visible ADRs show success as the last execution result
- both the desktop and server security-update ADRs are configured to automatically deploy all updates found by the rule
- both the desktop and server security-update ADRs are configured to automatically approve license agreements

Operationally, this means the environment likely uses a Microsoft Patch Tuesday aligned workflow where automated evaluation begins shortly after the second Tuesday, while the broader operational patch day is managed later in the month.

---

## 7. What the Endpoint Manager Should Monitor Each Month

### Readiness

- ADR execution status
- ADR last evaluation time and last error code
- ADR deployment-setting review for true auto-deploy versus process-only naming
- successful update group creation or refresh
- deployment package content availability
- distribution point content health
- collection targeting validity

### Deployment Execution

- deployment status by collection
- early failure counts
- download failures
- restart-pending counts
- content distribution problems

### Compliance and Exception Review

- compliant versus non-compliant counts
- unknown devices
- stale or inactive devices distorting compliance views
- repeat failure patterns
- server exceptions requiring manual handling

---

## 8. Recommended Reporting Pack for Task 19

The first version of Task 19 should produce or define these report outputs:

### 1. Patching Lifecycle Summary

A simple flow diagram showing:

- sync
- selection
- grouping
- packaging
- deployment
- client evaluation
- restart
- compliance review
- remediation

### 2. Patch Cadence Summary

A one-page note stating:

- patch day is the fourth Wednesday of each month
- clients auto-update
- most servers auto-update
- restarts occur as needed

### 3. Targeting Model Summary

A short mapping of:

- workstation patch targets
- server patch targets
- pilot targets
- exclusions

### 4. Compliance Review Template

A monthly report shell with these headings:

- total targeted devices
- compliant
- non-compliant
- unknown
- restart pending
- top failure reasons
- carry-forward exceptions

---

## 9. Open Questions That Do Not Block First Completion

These points are still worth validating later:

- the exact target collections for each ADR
- whether the `MANUAL` server ADR name reflects schedule, deployment timing, approval process, or simply older naming
- the product, classification, and supersedence filters used in each ADR
- whether there are maintenance windows by device group
- how emergency patching differs from normal monthly patching
- which server groups are excluded from the normal auto-update model
- which stakeholders currently receive monthly patch reporting
- whether third-party catalogs are actively deployed or only configured

None of these gaps prevent a first-pass servicing model from being documented.

---

## 10. Suggested Evidence and Reporting for Task 19

Use the following as closure evidence:

- Screenshot of the Software Updates node
- Screenshot or export of Automatic Deployment Rules
- Screenshot or export of Software Update Groups and Deployment Packages
- A short patch-cadence note confirming the fourth-Wednesday model
- This servicing model document

Useful export columns for monthly reporting:

- Collection Name
- Deployment Name
- Targeted Devices
- Compliant
- Non-Compliant
- Unknown
- Percent Compliance
- Restart Pending
- Top Error Code
- Notes

---

## 11. Completion Position for Task 19

Task 19 can be considered drafted and partially closed because:

- the update-management components are identified
- the monthly patch rhythm is documented
- the expected end-to-end servicing flow is documented
- the relationship between collections, ADRs, packages, and compliance is explained
- the desktop and server ADR deployment-setting behavior is partially confirmed

Task 19 becomes fully complete once ADR configuration, maintenance-window behavior, emergency patch flow, and stakeholder reporting expectations are validated.