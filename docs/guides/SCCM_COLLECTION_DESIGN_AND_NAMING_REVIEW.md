# SCCM Collection Design and Naming Review

Purpose: Review the current device collection structure, identify strengths and design concerns, and define the next actions needed to make the collection model easier to operate and safer to use.

Audience: Endpoint Managers, SCCM administrators, and service owners.

Status: First-pass review based on console screenshots. This is enough to close the first version of Task 7 and create a follow-up cleanup backlog.

---

## 1. What Was Reviewed

The current review is based on the visible Device Collections view and includes these example collections:

- `All Systems`
- `Basic DESKTOPS ALL`
- `Basic DESKTOPS ALL (0,2,4,6,8) Group 1`
- `Basic DESKTOPS ALL (1,3,5,7,9) Group 2`
- `Basic DESKTOPS NOT STD NAME`
- `Basic DESKTOPS PILOTS Group 1`
- `Basic DESKTOPS PILOTS Group 2`
- `Basic SERVERS ALL`
- `Basic SERVERS Exclude`
- `Basic SERVERS PILOTS`
- `Co-management Eligible Devices`
- `No contact 45 days`
- `Temp-ZIP`

The screenshots also show member counts, limiting collections, and reference counts, which is enough to identify broad structure and obvious naming issues.

---

## 2. High-Level Assessment

The current collection model shows useful operational intent. The environment already separates desktops from servers, uses pilot collections, includes a stale-device governance view, and has a co-management targeting collection.

That said, the naming model is only partly standardized. Some collection names are clear and purposeful, while others are ambiguous, temporary, or difficult for a new administrator to interpret.

Overall assessment:

- Structure maturity: Moderate
- Operational usefulness: Good
- Naming consistency: Mixed
- Governance readiness: Moderate
- New-admin readability: Needs improvement

---

## 3. Strengths in the Current Design

### Clear separation of device classes

The estate is visibly separated into desktop and server-focused collection groups. That is a good operational pattern because workstation and server targeting usually require different change control, deployment timing, and restart expectations.

### Pilot targeting already exists

Pilot collections exist for both desktops and servers. That is a strong indicator that controlled rollout is already part of the design, even if the exact pilot-to-ring mapping still needs validation.

Additional confirmed detail:

- `Basic DESKTOPS PILOTS Group 1` uses direct membership
- `Basic DESKTOPS PILOTS Group 2` uses direct membership
- `Basic DESKTOPS PILOTS Group 1` excludes `Basic DESKTOPS PILOTS Group 2`

That suggests the pilot design is being controlled deliberately rather than driven only by dynamic query logic. It also means the pilot collections should be treated as curated targeting groups and reviewed carefully before any broad deployment changes.

### Governance-oriented collections are present

Collections such as `No contact 45 days` and `Co-management Eligible Devices` show that the environment is not only deploying software but also using collections for lifecycle governance and modernization planning.

### Widespread use of limiting collections

Most visible collections appear to be limited by `All Systems`, which suggests the environment is using predictable parent scope boundaries rather than unrestricted direct targeting.

---

## 4. Observed Naming and Design Issues

### Issue 1: Naming patterns are inconsistent

There is a visible `Basic` prefix for several collections, which is helpful, but the overall naming pattern is not fully consistent. Compare:

- `Basic DESKTOPS ALL`
- `Basic SERVERS ALL`
- `Co-management Eligible Devices`
- `No contact 45 days`
- `Temp-ZIP`

These names do not all follow the same category, scope, or purpose model, which makes sorting and filtering less predictable.

### Issue 2: Some names describe implementation rather than purpose

Examples such as `Basic DESKTOPS ALL (0,2,4,6,8) Group 1` and `Basic DESKTOPS ALL (1,3,5,7,9) Group 2` suggest a segmentation rule, but the business meaning is not obvious. A new administrator may not understand whether these are load-balancing groups, phased update groups, query logic groups, or legacy partitions.

### Issue 3: Some names are ambiguous or non-standard

The following collection names should be reviewed first:

- `Basic DESKTOPS NOT STD NAME`
- `Temp-ZIP`

These names do not clearly tell an operator what the collection is for, how long it should exist, or whether it is safe to target.

### Issue 4: Temporary and exception collections need governance rules

Names that include temporary or exception behavior are operationally useful, but they need review ownership and expiry rules. Without that, temp collections often become permanent and create targeting risk.

### Issue 5: Production-critical status is not obvious from names alone

The visible naming scheme does not clearly distinguish:

- broad production collections
- pilot collections
- exclusion collections
- review-only governance collections
- temporary collections

That makes change review harder than it needs to be.

---

## 5. Production-Critical Collections Identified So Far

Based on the screenshots, the following collections should be treated as operationally important until proven otherwise:

- `All Systems`
  - Core limiting collection and broad device scope
- `Basic DESKTOPS ALL`
  - Appears to be a major workstation targeting collection
- `Basic SERVERS ALL`
  - Appears to be a major server targeting collection
- `Basic DESKTOPS PILOTS Group 1`
- `Basic DESKTOPS PILOTS Group 2`
- `Basic SERVERS PILOTS`
- `Co-management Eligible Devices`
- `No contact 45 days`

These collections either represent major population scopes, rollout control points, or governance views. They should be documented before any cleanup work is attempted.

---

## 6. Candidate Classification Model

To improve control, each collection should be classified into one of these categories:

- Production Targeting
- Pilot Targeting
- Exclusion
- Governance Review
- Temporary
- Legacy or Cleanup Candidate

Using the current evidence, the visible collections can be tentatively classified like this:

| Collection | Tentative Category | Notes |
|---|---|---|
| All Systems | Production Targeting | Core limiting scope |
| Basic DESKTOPS ALL | Production Targeting | Broad workstation targeting |
| Basic DESKTOPS ALL (0,2,4,6,8) Group 1 | Pilot or Segmentation | Purpose needs confirmation |
| Basic DESKTOPS ALL (1,3,5,7,9) Group 2 | Pilot or Segmentation | Purpose needs confirmation |
| Basic DESKTOPS NOT STD NAME | Governance Review | Likely naming-standard cleanup candidate |
| Basic DESKTOPS PILOTS Group 1 | Pilot Targeting | Clear pilot intent |
| Basic DESKTOPS PILOTS Group 2 | Pilot Targeting | Clear pilot intent |
| Basic SERVERS ALL | Production Targeting | Broad server targeting |
| Basic SERVERS Exclude | Exclusion | Should have strict governance |
| Basic SERVERS PILOTS | Pilot Targeting | Clear pilot intent |
| Co-management Eligible Devices | Governance Review | Modern management readiness targeting |
| No contact 45 days | Governance Review | Stale-device management |
| Temp-ZIP | Temporary | Needs owner and expiry validation |

---

## 7. Recommended Naming Standard

The collection model would benefit from a consistent naming format. One workable pattern is:

`[Platform or Scope] - [Device Class] - [Purpose] - [Qualifier]`

Examples:

- `SCCM - Workstations - Production - All`
- `SCCM - Workstations - Pilot - Group 1`
- `SCCM - Servers - Production - All`
- `SCCM - Servers - Exclusion - Patch Window`
- `SCCM - Governance - Stale Devices - 45 Days`
- `SCCM - Governance - CoManagement - Eligible`
- `SCCM - Temporary - ZIP Validation - Expires 2026-05-31`

Benefits of this model:

- easier sorting
- faster operator understanding
- clearer separation of production, pilot, governance, and temporary use
- easier review during change approval

---

## 8. Priority Cleanup Backlog for Task 7

These are the highest-value next steps:

### Priority 1

- Confirm the purpose of the two numbered desktop group collections
- Confirm whether the pilot collections are the real deployment rings
- Identify the owner and expiry date for `Temp-ZIP`
- Review why `Basic DESKTOPS NOT STD NAME` exists and whether it can be renamed or retired

Already confirmed:

- `Basic DESKTOPS PILOTS Group 1` uses direct membership
- `Basic DESKTOPS PILOTS Group 2` uses direct membership
- `Basic DESKTOPS PILOTS Group 1` excludes `Basic DESKTOPS PILOTS Group 2`

Still to confirm:

- whether Group 1 and Group 2 are permanent rollout rings, temporary pilots, or manually curated exception groups

### Priority 2

- Document which collections are safe for production targeting
- Document which collections are review-only and should never receive deployments
- Identify any direct membership collections used as exceptions
- Confirm refresh schedules for pilot and governance collections

### Priority 3

- Standardize naming prefixes
- Apply an owner field or documentation reference to temporary and exclusion collections
- Add quarterly review of stale, temporary, and exception collections

---

## 9. Suggested Evidence and Reporting for Task 7

Use the following as closure evidence:

- Export of device collections with member count, limiting collection, and reference count
- Screenshot of the main Device Collections view
- A simple classification table mapping each key collection to business purpose
- A backlog list of ambiguous, temporary, or cleanup-candidate collections

Suggested report columns for an export:

- Collection Name
- Collection Type
- Purpose Category
- Limiting Collection
- Member Count
- Refresh Type
- Owner
- Safe for Production Targeting
- Review Required
- Notes

---

## 10. Completion Position for Task 7

Task 7 can be considered drafted and partially closed because:

- the current collection structure has been reviewed at a high level
- key strengths and naming issues are documented
- production-critical collections are identified
- a cleanup backlog exists

Task 7 becomes fully complete once the ambiguous collection purposes, the exact business meaning of the pilot group split, and temporary collection ownership are validated.