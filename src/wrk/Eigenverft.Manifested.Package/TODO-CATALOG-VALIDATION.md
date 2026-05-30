# TODO CATALOG VALIDATION

## Purpose

Design scratchpad for **engine-side package-definition validation**: check JSON without installing, validate a whole endpoint folder in one report, and make errors easy for humans and agents to fix.

This is **separate** from the planned agent authoring skill ([`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) → future `AgentSkills/PackageDefinitionAuthoring.md`). The skill will describe *how agents should work*; this document tracks *hard validation steps the module should implement*.

Promotion to [`PROJECT-TODO.md`](PROJECT-TODO.md) happens when implementation is scheduled. **No engine changes are implied by this file alone.**

---

## Product goals (from PROJECT-TODO)

| Goal | User story (short) | Desired outcome |
|------|-------------------|-----------------|
| **Validate without install** | Check package JSON before download, PATH, or inventory writes | Report schema, retired names, trust, signature, platform selection, dependencies, acquisition/depot plan shape |
| **Validate whole folder** | One report for all definitions under an endpoint root | Find broken JSON, unsupported schema versions, duplicate ids, missing platform targets — CI-friendly |
| **Better validation errors** | Agent or human fixes the next edit quickly | Point at bad value, explain concept, name preferred replacement |

**Not in this doc:** LLM workflow and human review gates — see [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md). The future skill may **reference** these engine steps once they exist.

---

## Current engine facts

| Area | Today | Gap |
|------|--------|-----|
| Per-definition schema | `Assert-PackageDefinitionSchema` during config aggregation / invoke | Runs as part of install path, not a dedicated validate-only command |
| Wire / policy | `DefinitionSchema.Wire1_8.ps1`, acquisition vocabulary, signature assertions | Same — tied to load path |
| Signature verify | `Verify-PackageDefinitionSignature`, `Verify-PackageDefinitionCatalog` | Per-file trust checks; not a combined schema + folder report |
| Folder scan helper | `Get-PackageDefinitionJsonPathsUnderDirectory` | Lists paths; no aggregated validation report |
| Error text | Mix of wire throws with replacement hints and generic schema messages | Not consistently “package concept first” for all failure kinds |
| Install side effects | `Invoke-Package` always mutates when assignment runs | No `-WhatIf` / `Validate-PackageDefinitions` style surface |

**Remember:** [`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md) owns the **runtime resolver** (plan tree, batch pre-check, peer policy enforcement). Catalog validation here is **authored JSON correctness** and **static policy consistency** on an endpoint folder — it must not re-implement the full resolver, but it should catch mistakes **before** invoke.

When [`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md) adds `conflictsWith` / `requiresAbsent` (and optional mutex groups), this doc adds matching **validate-only** steps. A **clean resolver split** (graph / versions / peer policy / plan emit) is required on the dependency side; validation calls the same rules in read-only form where possible.

---

## Validation steps (intended hardcoded checks)

These are **engine responsibilities** — deterministic, repeatable, same in CI and locally. Order may become a pipeline; names are draft.

| Step | Checks (draft) | Touches today |
|------|----------------|---------------|
| **Parse** | Valid JSON, UTF-8, file readable | Ad hoc |
| **Schema version** | Supported `schemaVersion`; `$schema` alignment | `Assert-PackageDefinitionSchemaVersionSupported` |
| **Wire 1.8** | Required sections, retired properties, acquisition kinds | `Assert-PackageDefinitionSchema_1_8`, vocabulary asserts |
| **Publication identity** | `definitionId`, `publisherId`, duplicate ids in folder | Partial via discovery; folder duplicate scan **missing** |
| **Signature shape** | unsigned vs signed rules; no partial crypto fields | Signature schema asserts |
| **Trust** | Embedded cert valid; thumbprint vs trust inventory (policy-aware) | Verify commands |
| **Artifacts shape** | targets/releases/sources consistency, hashes present when required | Wire + policy |
| **Dependencies** | `definitionId` resolvable on endpoint; optional cycle pre-check | Load-time only today |
| **Peer policy (future)** | `conflictsWith` / `requiresAbsent` targets exist; no self-reference; symmetric warnings; mutex group well-formed | Not on wire — see [`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md) |
| **Platform / target** | At least one target matching current machine class (optional mode) | Selection code exists; validate-only wrapper **missing** |
| **Depot / download plan** | `packageDepot` paths plausible; `vendorDownload` template resolvable (optional offline mode) | Partial at acquire time |

Folder validation = run the pipeline for **every** `*.json` under an endpoint root, plus **cross-file** rules (duplicate `publisherId` + `definitionId`, mixed schema versions).

### Peer policy static checks (when schema ships — from TODO-DEPENDENCY)

Validate **authored intent**, not machine inventory:

| Check | Example failure |
|-------|-----------------|
| Target `definitionId` exists on same endpoint (or declared external catalog) | `conflictsWith` points at missing package |
| No self-reference | `DotNetSdk10` conflicts with itself |
| Symmetry warning (optional) | A conflicts with B but B silent about A |
| Mutex group string non-empty; members share group only when intended | Typo splits one family across two groups |
| Policy + dependencies sanity (warning) | `requiresAbsent NodeRuntime18` but `dependencies` pulls `NodeRuntime18` |
| Batch simulation mode (optional) | Given `-SimulateBatch DefinitionIds`, report peer violations without install |

Runtime peer enforcement remains the **dependency resolver**; validation reports should use the same **concept names** (`conflictsWith`, `requiresAbsent`, mutex group) so agents and humans align with plan failures.

---

## Integration options (surface)

### Option A — New cmdlet e.g. `Test-PackageDefinitionCatalog`

- **Meaning:** `-Path` to file or folder; `-ReportFormat` text/json; no install.
- **Fits today:** Wraps existing asserts + verify; adds folder aggregation and error formatter.
- **Skill hook:** skill checklist calls this before sign/publish.

### Option B — Extend `Verify-PackageDefinitionCatalog`

- **Meaning:** Grow existing verify command into full schema + folder report.
- **Risk:** Name overload if verify stays trust-focused only.

### Option C — CI script in repo only

- **Meaning:** Pester or script calls internal asserts; no new public command.
- **Risk:** Agents and teams outside repo do not get the same surface.

**No decision yet.** Soft lean: **Option A** with clear validate-vs-verify naming.

---

## Error message direction

| Today | Target |
|-------|--------|
| `Package definition 'X' uses retired property 'artifactsByTarget'. Use 'targetArtifacts'.` | Good pattern — keep |
| Generic JSON Schema pointer only | Add one-line **what this field means** for package authors |
| Internal path only | Include `definitionPublication.definitionId`, file path, and suggested fix |

Agent-facing output should be copy-pasteable into the next JSON edit (see PRODUCT-BOUNDARY: agent-friendly schema).

---

## Schema sketch (draft)

No wire change required for validation itself. Optional future:

| Output | Field | Notes |
|--------|--------|--------|
| Report object | `issues[]` | `severity`, `file`, `jsonPath`, `concept`, `message`, `suggestedFix` |
| Summary | `definitionCount`, `errorCount`, `warningCount` | For CI exit codes |

---

## Future implementation checklist

Reference only.

1. **Public command** — validate file + folder; document in README next to trust commands.
2. **Reuse** — `Read-PackageJsonDocument`, `Assert-PackageDefinitionSchema`, `Verify-PackageDefinitionSignature`, `Get-PackageDefinitionJsonPathsUnderDirectory`.
3. **Folder rules** — duplicate id scan; optional strict “all files same schemaVersion”.
4. **Error formatter** — shared helper for concept-first messages (wire asserts + schema).
5. **CI** — workflow step on `Endpoint/Defaults` and team endpoint fixtures.
6. **Skill update** — when [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) deliverable exists, add validate command to its self-check checklist.
7. **Tests** — golden files with intentional errors; folder report snapshot.

### Phased delivery

| Phase | Deliverable |
|-------|-------------|
| 1 | Single-file validate without install (schema + wire + signature shape) |
| 2 | Folder report + duplicate id detection |
| 3 | Concept-first error messages across top failure types |
| 4 | Optional machine-target and offline depot/download plan warnings |
| 5 | Peer policy static checks (align with TODO-DEPENDENCY wire) |
| 6 | Optional batch simulation for catalog maintainers |

---

## Resolved (facts about today)

- Schema validation is **PowerShell asserts**, not JSON Schema alone at runtime.
- Trust verification commands exist per definition.
- Validation on invoke is **not** the same product as validate-before-publish.

---

## Still open

- Cmdlet name and parameters (`Test-*` vs `Validate-*` vs extend `Verify-*`).
- Whether machine-target matching is default on or opt-in.
- Strict vs warn for unsigned JSON on team endpoints.
- JSON report schema for CI consumers.
- Relationship to dependency tree preview and **peer policy** ([`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md)).
- Shared rule module vs duplicated logic between validator and resolver (prefer one policy evaluator, two hosts).

---

## Out of scope

- `Invoke-Package` assignment, download, install, PATH registration.
- LLM prompt content (see agent skill).
- Fleet or manager validation policies.
