# SCCM Script Instructions

Use these instructions when creating or modifying scripts in this folder.

## Goals

- Build SCCM automation that is safe to rerun.
- Prefer deterministic, non-interactive operations.
- Keep scripts resilient to partial, null, or type-odd SCCM objects.
- Preserve dry-run and confirmation behavior for destructive paths.

## Environment Assumptions

- Scripts in this folder may run against Configuration Manager PowerShell cmdlets and WMI.
- SCCM provider objects can differ by environment and can expose partial properties.
- Some SCCM cmdlets throw `Argument types do not match` even when a direct fallback path can still succeed.

## Proven Rules

### 1. Keep SCCM scripts idempotent

- A successful first run must not break a second run.
- Always handle the steady-state case where only master collections remain.
- Empty delete sets must log cleanly and continue.
- No-op reruns should produce concise output rather than erroring on empty collections, app sets, or folder sets.

### 2. Never rely on raw SCCM object shapes

- Do not assume `.Name`, `.LocalizedDisplayName`, `.CI_ID`, `.CollectionID`, `.DeploymentID`, or similar properties are always present.
- Use a property-normalization helper pattern like `Get-ObjectPropertyValue` with candidate aliases.
- Treat SCCM objects as potentially null, partially loaded, or provider-version-dependent.

### 3. Prefer safe normalization before loops and joins

- Normalize scalars and pipeline results before `.Count`, indexing, `foreach`, or `-join`.
- Use array normalization helpers for pipeline output.
- Build log detail strings in variables before passing them to logging functions.
- When there are no names to log, use explicit text like `None`.

### 4. Preserve object types across PowerShell enumeration

- PowerShell can unwrap single-item results into scalars.
- If returning a `HashSet` or other collection object that must stay intact, return it with unary comma: `return ,$ids`.
- Do not assume a single returned object still supports collection methods like `.Contains()`.

### 5. Avoid interactive SCCM cmdlet prompts

- Destructive cmdlets must never fall back to interactive prompting.
- Always construct only valid non-interactive parameter sets.
- Use `-Confirm:$false` and `-ErrorAction Stop` on destructive SCCM cmdlets.
- Suppress warnings when they interfere with fallback handling using `-WarningAction SilentlyContinue` where appropriate.

### 6. Use a deployment deletion fallback chain

For deployment removal, use this order:

1. InputObject when the object is valid.
2. Fresh fetch by deployment ID, then delete by InputObject.
3. Delete by deployment ID.
4. Delete by application name plus collection name.

Notes:

- Fresh-fetch fallback is required because cached deployment objects can become type-incompatible.
- If neither deployment ID nor application name is available, skip with a clear warning and record the failure.
- Do not let `Remove-CMDeployment` prompt for missing parameters.

### 7. Treat `Argument types do not match` as an SCCM compatibility signal

- This error often means a provider object or cmdlet parameter set is incompatible, not that the target object is invalid.
- If dependency resolution throws this error and direct collection deletion still succeeds, log it as diagnostic noise rather than as a high-severity failure.
- Prefer direct-delete fallback over aborting the cleanup flow.

### 8. Delete in dependency-safe order

- Remove dependent deployments before deleting collections.
- When deleting versioned collections, sort by version descending so parent/include relationships are less likely to block deletion.
- After deployment removal, allow a short propagation pause before collection deletion.

### 9. Folder cleanup needs WMI fallback

- SCCM folder cmdlets do not always expose enough structure for reliable empty-folder cleanup.
- Use WMI `SMS_ObjectContainerNode` fallback to enumerate folder candidates when cmdlet-based discovery is incomplete.
- Protect canonical/master paths from deletion.
- When no child folders are discovered, emit one concise diagnostic sample instead of repeating the same object dump multiple times.

### 10. Logging must never crash the workflow

- Logging helpers must tolerate null, empty, or type-odd inputs.
- Wrap conversion to string defensively.
- Use a last-resort fallback path so logging errors do not mask the real failure.
- Keep operational logs readable with `Scope`, `Action`, and stable `Detail` strings.

## Security And Safety

- Do not hardcode site codes, server names, domains, collection IDs, credentials, tokens, or organization-specific values.
- Parameterize environment-specific values.
- Keep destructive operations gated by script switches and confirmation logic.
- Preserve `DryRun` behavior and ensure dry-run paths do not indirectly mutate state.

## SCCM Implementation Patterns

### Safe object access

- Resolve fields through alias lists.
- Cast IDs and names to string before passing them into SCCM cmdlets.
- Validate non-empty strings before creating parameterized scriptblocks.

### Safe cleanup planning

- Keep the newest two application versions by default.
- Also keep versions referenced by task sequences.
- Build keep and delete plans using normalized arrays and stable IDs.
- Log the plan using prebuilt strings, not inline dereferencing expressions.

### Safe supersedence handling

- Normalize supersedence entries before building the chain.
- Filter out entries without a valid app object.
- Resolve names and versions defensively.
- If fewer than two valid apps remain after normalization, skip supersedence cleanly.

## Validation Checklist

After changes in this folder, verify all of the following:

- No editor or parse errors remain.
- First-run consolidation completes.
- Second-run no-op path also completes.
- Cleanup handles zero legacy apps and zero legacy collections.
- Deployment removal never prompts interactively.
- Logging never throws while reporting another failure.
- Folder cleanup behaves correctly both when candidates exist and when no folders need deletion.

## Preferred Style For Future SCCM Scripts

- Use small helpers for normalization, logging, cache access, and fallback execution.
- Prefer explicit stage markers around long workflows for easier diagnostics.
- Keep retry logic separate from primary execution paths.
- Favor targeted fixes at the root cause over broad exception swallowing.
- Preserve existing public parameters and repo safety conventions unless the task requires a change.

## Known Good Outcome For This Folder

The Microsoft Edge consolidation work in this folder established these proven behaviors:

- Full consolidation with deployment migration and cleanup can complete successfully.
- Reruns after convergence must succeed with only the three master collections left.
- Expected SCCM provider quirks can be handled with normalization, fresh-fetch fallbacks, and non-interactive delete chains.
