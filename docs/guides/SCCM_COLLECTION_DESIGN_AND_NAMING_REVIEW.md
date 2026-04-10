# SCCM Collection Design and Naming Review

Purpose: Provide a repeatable review framework for SCCM device and user collections without assuming one specific environment or screenshot set.

Audience: Endpoint Managers, SCCM administrators, service owners, and change reviewers.

Status: Repository-aligned review template. Use this guide together with collection exports and script output before making structural cleanup decisions.

---

## 1. Review Goals

The collection review should answer five questions:

1. Which collections are safe for production targeting?
2. Which collections exist only for pilot, staging, governance, or exception handling?
3. Which collections are temporary, stale, or ambiguous?
4. Which collections overlap enough to create deployment risk or reporting confusion?
5. Which collections need naming cleanup, ownership, or retirement?

---

## 2. Evidence to Gather First

Before rating any collection, gather these inputs:

- export of device and user collections with limiting collection, refresh type, and member count
- query-rule and direct-membership details for high-impact collections
- deployment references for collections used by applications, packages, baselines, or updates
- last refresh or last membership-change evidence where available

Useful repository scripts:

- scripts/SCCM/SCCM-CollectionAnalyse.ps1
- scripts/SCCM/SCCM-CollectionMembershipDriftReport.ps1
- scripts/SCCM/SCCM-AnalyzeStaleCollectionsAndDeployments.ps1
- scripts/SCCM/SCCM-ReferenceImpactAnalysis.ps1

---

## 3. Classification Model

Every important collection should be classified into one of these categories:

- Production Targeting
- Pilot Targeting
- Staging or Testing
- Exclusion
- Governance Review
- Temporary
- Legacy or Retirement Candidate

If a collection cannot be classified quickly, treat that as a finding rather than an acceptable steady state.

Suggested review table:

| Collection | Type | Category | Owner | Safe for targeting | Review notes |
|---|---|---|---|---|---|
| Fill locally | Device or User | Fill locally | Fill locally | Yes or No | Fill locally |

---

## 4. Naming Standard

Choose one naming format and apply it consistently. One workable pattern is:

[Platform] - [Scope] - [Purpose] - [Qualifier]

Examples:

- SCCM - Workstations - Production - All
- SCCM - Workstations - Pilot - Ring 1
- SCCM - Servers - Exclusion - Patch Freeze
- SCCM - Governance - Stale Devices - 45 Days
- SCCM - Temporary - Packaging Validation - Expires 2026-05-31

The exact wording can differ, but every name should make purpose clear to a new administrator.

---

## 5. Common Risk Indicators

Prioritize review when you find collections with these traits:

- ambiguous names that do not describe purpose
- temporary or test names with no owner or expiry date
- broad member counts paired with unclear deployment references
- direct-membership collections used in production with no documented process
- overlapping collections that could receive conflicting deployments
- stale collections with no recent membership or deployment activity

---

## 6. Review Workflow

Use this order:

1. Identify high-impact collections tied to production deployments.
2. Confirm limiting collections and refresh logic.
3. Map current deployment references before renaming or retiring anything.
4. Flag temporary, stale, or ambiguous collections.
5. Decide whether each candidate should be renamed, documented, re-scoped, or retired.

Do not clean up collections based only on naming preference. Confirm deployment references and business use first.

---

## 7. Minimum Evidence for Closure

Treat the review as first-pass complete only when you have:

- a classification table for important collections
- a list of production-critical collections
- a cleanup backlog for ambiguous or temporary collections
- at least one reference-impact check for any collection proposed for removal or redesign

---

## 8. Open Questions to Validate Locally

These questions should be answered in the environment-specific version of this guide:

- which collections are the real deployment rings
- which collections are safe only for reporting and must never be targeted
- which exception or exclusion collections have approved owners
- which temporary collections have passed their intended expiry date
- whether user collections follow the same naming and governance model as device collections
