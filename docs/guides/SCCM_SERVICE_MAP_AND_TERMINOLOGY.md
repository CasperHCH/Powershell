# SCCM Service Map and Terminology Guide

Purpose: Provide a beginner-friendly service map and glossary for the current SCCM environment so an Endpoint Manager can understand how the platform is structured and how work flows through it.

Audience: Endpoint Managers, SCCM administrators, service owners, and new team members.

Status: Drafted from console screenshots and updated with confirmed environment details. One remaining item still needs validation before the task can be considered fully complete.

---

## 1. Current Environment Snapshot

The current screenshots and follow-up clarification indicate a single-site SCCM environment with these characteristics:

- One active primary site
- One primary site server hosting all SCCM roles
- Three additional site system servers acting as distribution points
- A structured device collection model for desktops, servers, pilot rings, stale-device review, and co-management eligibility
- A dedicated application folder used for packaged software
- Software Updates, Software Update Groups, Deployment Packages, Automatic Deployment Rules, and Third-Party Software Update Catalogs all present in the console
- Endpoint client installation performed through imaging
- Monthly patching cadence aligned to the fourth Wednesday of each month

This is enough to create a first-pass service map for onboarding and operational understanding.

---

## 2. Logical Service Map

### Topology Layer

The environment uses a single active primary site as the core of management.

- Primary site
  - Hosts the full SCCM role set
  - Acts as the operational center for administration, application management, software updates, and reporting
- Additional site system servers
  - Three additional servers are present
  - These are confirmed as site systems and distribution points
  - Their primary service-map purpose is to make deployment and update content available closer to endpoints

### Endpoint Management Flow

The service flow for endpoints can be described like this:

1. Devices are built through imaging and enter the managed estate through the client installation process tied to that imaging workflow.
2. Devices become visible in Assets and Compliance.
3. Devices are grouped into collections.
4. Collections are used to target software, policies, pilots, and reporting views.
5. Applications and updates are distributed through the Software Library.
6. Content is made available through the three site system distribution points and the primary site infrastructure.
7. Clients evaluate policy, download content, install software or updates, and report compliance state.
8. The Endpoint Manager uses Monitoring, collection views, deployment results, and report exports to assess health and drive action.

### Collection and Targeting Layer

The screenshots show a practical collection structure already in place:

- `All Systems`
  - Broadest device target and likely the top limiting collection for device-based operational work
- Desktop population collections
  - Desktop estate is split into broad groups and sub-groups
  - There are separate pilot collections for desktops
- Server population collections
  - There is a dedicated all-servers collection
  - There is also a pilot collection for servers
- Stale-contact review collection
  - A collection exists for devices with no contact for 45 days
  - This is useful for stale-device governance and cleanup tasks
- Co-management eligibility collection
  - A dedicated collection exists for co-management eligible devices
  - This indicates that endpoint targeting strategy may also support modern management transition decisions

### Application Management Layer

The screenshots show a packaged application area under the Applications node.

- A dedicated applications folder is being used for managed software
- Application objects show software version, deployment type count, deployment count, status, publisher, and supersedence state
- The visible application list suggests a mixed estate including Microsoft products, browser packages, utilities, and third-party line-of-business software
- Some packages are already marked as superseded, which is a sign that version lifecycle management is active at least for part of the estate

### Deployment Model Layer

The screenshots show at least one application deployment folder with separate intent-based collections:

- `Install (Available)`
- `Install (Required)`
- `Uninstall`

This suggests the environment is using a structured application deployment pattern where the same application can be:

- Made available for optional user-initiated install
- Required for mandatory deployment
- Targeted for uninstall when needed

That is a strong pattern for service mapping because it clearly separates deployment intent from the application object itself.

### Software Update Layer

The Software Updates node shows:

- All Software Updates
- Declined updates
- Software Update Groups
- Deployment Packages
- Automatic Deployment Rules
- Third-Party Software Update Catalogs

This indicates a mature enough update structure to support:

- Normal monthly update selection
- Group-based update deployments
- Package-based content management
- Some level of automated rule-based update processing
- Third-party catalog integration

Patch operations are also known to follow a regular service rhythm:

- The fourth Wednesday of each month is patch day
- Most servers receive automatic updates
- All client devices receive automatic updates
- Restarts occur as needed for completion

The screenshot also suggests a high compliance view is being surfaced in the console, though that should be validated with collection-specific reporting before using it as a KPI.

---

## 3. Beginner-Friendly Service Explanation

An Endpoint Manager can think of this SCCM environment in five parts:

### 1. Device Visibility

SCCM first needs to know that a device exists. That visibility becomes the basis for inventory, collections, compliance, and troubleshooting.

In this environment, imaging is a confirmed part of the client onboarding model, so the Endpoint Manager should treat imaging as an upstream dependency for consistent SCCM client presence.

### 2. Collections

Collections are the targeting engine. They decide which devices receive software, updates, baselines, or review attention. In this environment, desktop groups, server groups, pilot groups, stale-contact review, and co-management eligibility are all driven by collections.

### 3. Content and Deployment

Applications and updates are prepared in the Software Library, then targeted through collections. Content must be available on the right infrastructure before clients can install anything successfully.

### 4. Client Evaluation

The SCCM client receives policy, evaluates whether software or updates apply, downloads content, installs it, and returns state messages. This is where client logs, deployment status, and compliance metrics become important.

### 5. Monitoring and Reporting

The Endpoint Manager reviews the results through collection views, application deployment summaries, software update compliance, stale-device analysis, and recurring exports. That reporting loop is what turns SCCM from a deployment tool into a managed service.

---

## 4. Operational Map by Console Area

### Administration

Use this area to understand the platform itself.

- Sites
  - Confirms site topology and site status
- Servers and Site System Roles
  - Shows which servers host SCCM roles
- Boundaries and Boundary Groups
  - Define where clients belong and where they find content
- Security and Administrative Users
  - Shows RBAC scope and administrative permissions

### Assets and Compliance

Use this area to understand the managed endpoint estate.

- Devices
  - Main inventory and endpoint population view
- Device Collections
  - Primary targeting and segmentation model
- Built-in operational folders
  - Evidence of how the environment separates applications, maintenance windows, patching, OS deployment, and custom operational groupings

### Software Library

Use this area to manage what gets deployed.

- Applications
  - Application definitions, versions, deployment types, and supersedence
- Application Groups
  - Grouped software delivery when needed
- Software Updates
  - Update catalog and compliance foundation
- Software Update Groups
  - Curated deployment bundles for patching
- Deployment Packages
  - Update content packaging
- Automatic Deployment Rules
  - Automation for recurring update selection and deployment preparation

### Monitoring

Use this area to understand whether the service is succeeding.

- Deployment status
- Software update compliance
- Client health trends
- Content distribution state
- State-message-driven success and failure analysis

---

## 5. Working Terminology Guide

### Primary Site

The main SCCM site responsible for managing clients, content, policy, and reporting in the environment.

### Site System Server

A server that hosts one or more SCCM roles to support management functions such as content distribution, policy, or update services.

### Distribution Point

An SCCM role that stores content so clients can download applications, packages, operating system content, or update files locally or efficiently across the network. In this environment, the three additional site system servers act as distribution points.

### Collection

A logical group of devices or users used for targeting software, updates, configuration, or reporting.

### Limiting Collection

The parent scope that restricts what a collection can include.

### Pilot Collection

A smaller collection used to test deployments before wider release.

### Required Deployment

A deployment the client is expected to install automatically according to schedule and policy.

### Available Deployment

A deployment offered to users for optional installation through Software Center.

### Uninstall Deployment

A deployment intended to remove software from the targeted collection.

### Deployment Type

The technical definition of how an application is installed, detected, and optionally uninstalled.

### Detection Method

The logic SCCM uses to confirm whether an application is already present or was installed successfully.

### Supersedence

A relationship where a newer application version replaces an older one, optionally uninstalling the older version.

### Software Update Group

A curated bundle of updates that can be deployed together.

### Deployment Package

The content container used to distribute update files to the infrastructure.

### Automatic Deployment Rule (ADR)

An automation rule that selects updates based on criteria and prepares them for deployment.

### Patch Day

The regular operating day when the monthly patch process is expected to be executed. In this environment, patch day is the fourth Wednesday of each month.

### Co-management Eligible Devices

A collection indicating devices that may qualify for shared management patterns across management platforms.

### Stale Device Review

The operational practice of finding devices that have not communicated recently and deciding whether to remediate, exclude, or retire them.

---

## 6. What the Screenshots Already Tell the Endpoint Manager

From the current screenshots, a new Endpoint Manager can already conclude the following:

- The environment is not a blank or immature SCCM deployment; it has a visible structure for device segmentation, applications, and software updates
- The core SCCM platform is centralized on a single primary site server that hosts all roles
- Content delivery is supported by three dedicated site system distribution points
- Desktop and server targeting are being treated differently, which is good operational practice
- Pilot collections exist, which suggests controlled rollout capability is already part of the service model
- Co-management and stale-device review are already represented in collections, which supports governance and modernization work
- The application estate is large enough that packaging standards, supersedence review, and deployment reporting should be considered recurring tasks
- The update area includes ADRs and third-party update catalogs, meaning update governance likely extends beyond only Microsoft monthly patching
- Imaging is an important upstream dependency for getting managed devices into the SCCM lifecycle
- Monthly patching is already scheduled and operationalized around the fourth Wednesday, with automatic updates and restart behavior in place for most servers and all client devices

---

## 7. Remaining Items to Validate Before Marking the Task Fully Complete

Most of the original unknowns are now clarified. The remaining point that still needs confirmation is:

- Whether the visible desktop and server pilot collections map directly to the real deployment ring model or are only partial pilot targets

Useful follow-up clarifications that would improve the guide further, but are no longer blockers for a first completion:

- Which discovery methods are enabled
- How Automatic Deployment Rules are currently configured
- Whether there are formal maintenance windows by device group
- Which reports are already consumed by management or audit stakeholders

---

## 8. Suggested Evidence to Attach to Task 2

Use the following as closure evidence for the Jira task:

- Screenshot of the active site topology
- Screenshot of servers and site system roles
- Screenshot of key device collections
- Screenshot of the application management node
- Screenshot of the software updates node
- This service map and terminology guide

---

## 9. Recommended Next Action

Use this document to close the first version of Task 2. The only open validation point is whether the visible pilot collections are the true deployment rings. That detail can be confirmed during Task 7, Task 13, or Task 19 because those later tasks naturally force deeper review of collections, deployment strategy, and update servicing.