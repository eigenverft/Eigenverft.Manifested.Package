# TODO CATALOG VALIDATION

## Purpose

Design scratchpad for **engine-side package-definition validation**: check JSON without installing, validate a whole endpoint folder in one report, and make errors easy for humans and agents to fix.

This is **separate** from the planned agent authoring skill ([`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) → future `AgentSkills/PackageDefinitionAuthoring.md`). The skill will describe *how agents should work*; this document tracks *hard validation steps the module should implement*.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` on **2026-05-30**.

Open issues in this file are scheduled here. **No engine changes are implied by this file alone.**

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 2/6 — High**

---
---

## 📌 Catalog validation without install (schema + folder report)

- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🛡 Security / Trust
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

Authors and CI need to validate package-definition JSON **before** `Invoke-Package` mutates the machine. Today **`Assert-PackageDefinitionSchema`** (wire 1.8 + policy) runs only when a definition is loaded on the invoke path; **`Verify-PackageDefinitionCatalog`** scans folders for **signature/trust per file** but does not produce a combined schema + cross-file report (duplicate ids, mixed schema versions, dependency references).

### 🧭 Related Context

Related Issues:
- [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) — skill checklist should call validate command when shipped.
- [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) — runtime resolver and peer enforcement; validation catches **authored** policy mistakes only.
- [`TODO-OWNERSHIP.md`](TODO-OWNERSHIP.md) — optional ownership-policy warnings (separate from this issue).

Affected Areas:
- New validate command (name TBD); `Package.DefinitionSchema.ps1`, `Package.DefinitionSchema.Wire1_8.ps1`, `Package.DefinitionReference.ps1`; trust verify reuse; **18** shipped definitions under `Endpoint/Defaults/Eigenverft/`.

Dependencies:
- Cmdlet naming and report shape before implementation; peer-policy static checks align with TODO-DEPENDENCY wire.

### 🎯 Required Outcome

1. Validate **single file or endpoint folder** without install: schema version, wire 1.8, signature shape, trust (policy-aware), artifacts/dependencies shape.
2. **Folder report:** aggregate issues, duplicate `publisherId` + `definitionId`, optional strict schema-version consistency.
3. **Concept-first errors** for top failure kinds (extend retired-property pattern).
4. Optional later: machine-target warnings, peer-policy static checks ([`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md)), batch simulation.

### 🔎 Facts

Known:
- **`Assert-PackageDefinitionSchema`** (`Package.DefinitionSchema.ps1`): PowerShell asserts, not JSON Schema alone at runtime; invoked from **`Package.Config.Aggregation.ps1`** when resolving a definition for assign — **not** exposed as validate-only.
- **`Assert-PackageDefinitionSchema_1_8`** / **`Assert-PackageDefinitionSchemaVersionSupported`** in `Package.DefinitionSchema.Wire1_8.ps1` — retired nested properties throw with replacement paths (e.g. `artifactsByTarget` → `targetArtifacts`).
- **`Verify-PackageDefinitionSignature`** — per file via `Read-PackageJsonDocument` + `Test-PackageDefinitionSignatureDocument`; `-RequireTrusted`, `-ErrorOnFailure` (`Cmd.PackageTrust.ps1`).
- **`Verify-PackageDefinitionCatalog`** — `-Path` file or directory; recursive `*.json`; calls **`Verify-PackageDefinitionSignature`** per file; returns `CheckedCount`, `ValidCount`, `TrustedCount`, `FailedCount`, `Results` — **no** `Assert-PackageDefinitionSchema`, **no** duplicate-id scan across files.
- **`Get-PackageDefinitionJsonPathsUnderDirectory`** — lists `*.json` under a root (`Package.DefinitionReference.ps1`); used by endpoint scan, not validation report.
- **Shipped catalog:** **18** definitions, `schemaVersion` **1.8**, under `Endpoint/Defaults/Eigenverft/`; tests use `Verify-PackageDefinitionCatalog -RequireTrusted` on definition roots (`ConfigAndDefinitions.Tests.ps1` ~585).
- **No** `Invoke-Package -WhatIf` / `Validate-PackageDefinitions` surface.
- Within-file duplicate ids are asserted (e.g. duplicate artifact target id); **cross-file** duplicate `definitionId` on an endpoint is **not** scanned today.

Unknown:
- Final cmdlet name (`Test-*` vs `Validate-*` vs extend `Verify-*`).
- JSON report schema for CI; strict vs warn for unsigned team JSON.

---

### 🧩 Options

#### Option A — New `Test-PackageDefinitionCatalog` validate command (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
New exported command with `-Path` (file or folder), optional `-ReportFormat`, `-RequireTrusted`, machine-target mode. Pipeline: parse → schema version → wire asserts → signature/trust → folder cross-rules. Reuse `Read-PackageJsonDocument`, `Assert-PackageDefinitionSchema`, existing verify helpers. Clear **validate** vs **verify** naming.

Current State:
Validate only on invoke; verify catalog is trust-only.

Resulting State:
CI and agents get one report before sign/publish/install.

Solves:
- Product goals for validate-without-install and folder report.

Leaves Open:
- Peer-policy and batch simulation phases later.

Risks:
- Must not duplicate full dependency resolver logic.

Later Cost:
- Shared error-formatter maintenance with wire asserts.

---

#### Option B — Extend `Verify-PackageDefinitionCatalog` with schema pipeline (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Grow existing **`Verify-PackageDefinitionCatalog`** to run wire/schema asserts before trust, and emit unified `issues[]` report. Keeps one familiar command name for teams already calling verify on folders.

Current State:
`Verify-PackageDefinitionCatalog` is trust/signature aggregation only.

Resulting State:
Same cmdlet name does more; verify semantics broaden.

Solves:
- Reuses existing folder scan loop in `Cmd.PackageTrust.ps1`.

Leaves Open:
- Name overload (“verify” vs full schema validate); breaking change risk for trust-only callers.

Risks:
- Operators may think verify already means full validation today — it does not.

Later Cost:
- Possible rename/split in a follow-up release.

---

#### Option C — Repo-only Pester validation script (Defer Option)

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Defer
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Add CI Pester that calls internal asserts only; **no** new public module command. Fastest for repo CI; agents outside the repo get no first-class surface.

Current State:
Tests call internal paths ad hoc.

Resulting State:
CI gate on `Endpoint/Defaults`; module consumers unchanged.

Solves:
- Eigenverft repo quality gate without public API design.

Leaves Open:
- No validate command for PSGallery installs or team share paths.

Risks:
- Duplicates logic agents cannot invoke from installed module.

Later Cost:
- Public command still needed for product story.

---

### 💶 Value Assessment

- 💎 Value Type: 🛡 Risk / Loss Avoided · 🛟 Support Effort Reduced · 🚚 Delivery Unblocked
- 🧭 Value Direction: 🛡 Risk / Protection
- 🧾 Value Mechanism: Catches schema, trust, and folder consistency errors before assign/install; gives agents concept-first fixes aligned with wire asserts and PRODUCT-BOUNDARY.
- ⚖️ Option Value Summary:
  - Option A — New `Test-PackageDefinitionCatalog` validate command (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Clearest product surface for CI, agents, and team endpoints; separates validate from trust-only verify.
  - Option B — Extend `Verify-PackageDefinitionCatalog` with schema pipeline (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Reuses folder loop; risks confusing verify vs full validation semantics.
  - Option C — Repo-only Pester validation script (Defer Option)
    - 🧭 Resolution: ⚪ Defer
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: CI-only; does not satisfy installed-module or agent skill checklist needs.
- ✅ Good Result: One command validates file or endpoint folder without install; report lists schema, trust, and cross-file issues with actionable messages; CI can fail on error count before merge.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Prefer Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
`Verify-PackageDefinitionCatalog` today is explicitly signature/trust aggregation (`Verify-PackageDefinitionSignature` per file). Full validate-without-install needs **`Assert-PackageDefinitionSchema`** and folder rules with a name that does not imply verify already does schema work (Option B). Option C does not meet agent or installed-module consumers.

Required Checks:
- Confirm cmdlet name with maintainers (`Test-PackageDefinitionCatalog` vs `Validate-PackageDefinitions`).
- Define minimal `issues[]` report shape for phase 1 CI.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 🛟 Support / Customer Success · 🚚 Release Owner
- 🗣 Communication Lens: 🛡 Trust / Risk Summary
- 📬 Success Note: Package definitions can be checked before any install runs. Teams get one report for an entire endpoint folder, including trust and schema problems. Agents and CI see clearer messages that point to the right JSON fix.

### ❓ Open Decisions

- Machine-target matching default on vs opt-in.
- Strict vs warn for unsigned JSON on internal endpoints.
- Shared policy evaluator with TODO-DEPENDENCY resolver vs duplicated rules.

### 🚫 Out of Scope

- `Invoke-Package` assignment/install/PATH.
- Full dependency tree preview or runtime peer enforcement.
- LLM skill prose ([`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md)).

---

## Product goals (reference)

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
| Per-definition schema | `Assert-PackageDefinitionSchema` in `Package.DefinitionSchema.ps1`; called from `Package.Config.Aggregation.ps1` on invoke | No validate-only public command |
| Wire / policy | `Assert-PackageDefinitionSchema_1_8` in `Package.DefinitionSchema.Wire1_8.ps1` | Same — tied to load path unless new command wraps asserts |
| Signature verify | `Verify-PackageDefinitionSignature`; `Verify-PackageDefinitionCatalog` (`-Path`, `-RequireTrusted`, `-ErrorOnFailure`) | Catalog verify = per-file trust; **no** wire assert in that loop |
| Folder scan | `Get-PackageDefinitionJsonPathsUnderDirectory` (`Package.DefinitionReference.ps1`) | Lists paths only |
| Cross-file rules | Within-file duplicate target/location ids asserted | **No** endpoint-wide duplicate `definitionId` scan |
| Shipped catalog | **18** × `schemaVersion` **1.8** under `Endpoint/Defaults/Eigenverft/` | — |
| Error text | Retired-property throws with replacement hints (good pattern) | Not uniform for all failure kinds |
| Install side effects | `Invoke-Package` mutates on assign | No `-WhatIf` / validate-only surface |

**Remember:** [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) owns the **runtime resolver** (plan tree, batch pre-check, peer policy enforcement). Catalog validation here is **authored JSON correctness** and **static policy consistency** on an endpoint folder — it must not re-implement the full resolver, but it should catch mistakes **before** invoke.

When [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) adds `conflictsWith` / `requiresAbsent` (and optional mutex groups), this doc adds matching **validate-only** steps. A **clean resolver split** (graph / versions / peer policy / plan emit) is required on the dependency side; validation calls the same rules in read-only form where possible.

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
| **Peer policy (future)** | `conflictsWith` / `requiresAbsent` targets exist; no self-reference; symmetric warnings; mutex group well-formed | Not on wire — see [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) |
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

## Integration options (reference sketches)

*Primary selectable paths are in **Open Issues** above.*

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

- Schema validation is **PowerShell asserts** (`Package.DefinitionSchema.ps1` + `Wire1_8.ps1`), not JSON Schema alone at runtime.
- **`Verify-PackageDefinitionCatalog`** exists but only aggregates **signature/trust** per JSON file (2026-05-30).
- **`Assert-PackageDefinitionSchema`** runs on invoke load path, not as a standalone exported command.
- Trust verification per file: **`Verify-PackageDefinitionSignature`**.
- Validation on invoke is **not** the same product as validate-before-publish.
- **18** shipped signed definitions on wire **1.8**.

---

## Still open

- Cmdlet name and parameters (`Test-*` vs `Validate-*` vs extend `Verify-*`).
- Whether machine-target matching is default on or opt-in.
- Strict vs warn for unsigned JSON on team endpoints.
- JSON report schema for CI consumers.
- Relationship to dependency tree preview and **peer policy** ([`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md)).
- Shared rule module vs duplicated logic between validator and resolver (prefer one policy evaluator, two hosts).

---

## Out of scope

- `Invoke-Package` assignment, download, install, PATH registration.
- LLM prompt content (see agent skill).
- Fleet or manager validation policies.
