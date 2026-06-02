---
---

# 📌 Implementation Decision — Implement Option A dependency planning on current recursive install path

Source Issue:
- Title: Implement Option A dependency planning on current recursive install path
- Issue File: `TODO-DEPENDENCY-A.md`
- Issue Recommendation: Prefer Option A1 — Planner-first in `Invoke-Package`

Output Artifact:
- Document Type: Implementation Decision
- File Name: `implementation-dependency-a.md`
- Rule: This document is separate from the issue document and must not be appended to it.

- 🏷 Implementation Rating
  - 🚧 Workflow State: 🟢 Ready To Implement
  - 🌊 Churn: 3/4 Structural ▰▰▰▱
  - 🧭 Assessment Depth: 3/4 Broad Mapping ▰▰▰▱
  - ♻️ Reuse Need: 3/4 Broad Reuse Map ▰▰▰▱
  - 🧰 Helper / Generalization Need: 3/4 Likely ▰▰▰▱
  - 🔁 Repetition Risk: 3/4 High ▰▰▰▱
  - 📍 Placement Risk: 3/4 High ▰▰▰▱
  - 📏 Growth Pressure: 3/4 High ▰▰▰▱
  - 👥 Stakeholder Technical Lens: 🔧 Maintainer / 🧪 Test / 🔁 Compatibility
  - 🤖 Agent Suitability: 3/4 Strong ▰▰▰▱
  - 🚧 Implementation Readiness: 🟢 Ready

### 📝 Implementation Statement

Implement the selected Option A dependency architecture by adding a plan-first dependency pipeline that runs before package mutation, while keeping the existing recursive dependency execution model as the execution mechanism.

Required Outcome:
The first implementation slice must produce an in-memory dependency plan for `Invoke-Package` assigned/materialize flows, detect batch-level conflicts before install/materialization begins, keep recursive dependency execution as the executor, and expose enough plan/verdict information for operators and tests. It must not introduce a persisted plan artifact in this slice.

Non-Goals:
- Do not implement a lockfile-first solver.
- Do not add a persisted dependency plan artifact, replay format, or export command.
- Do not implement fleet orchestration or rollout policy.
- Do not implement `mutexGroup` in the first slice.
- Do not duplicate supply-chain release-age policy; compose with that future policy at dependency-node selection boundaries.

### 👥 Stakeholder Technical Requirements

Maintainer / Structure:
- Dependency planning must have a focused owner and must not turn `Resolve-PackageDependencies` into a large mixed planner/executor.
- The recursive install path should remain readable and should consume an approved plan rather than own graph analysis.

Developer Experience:
- `Invoke-Package -DefinitionId A,B` should fail before machine mutation when the requested roots or shared dependencies are incompatible.
- Failure output should name the root, dependency edge, selected candidate, and policy violation where possible.

Test / QA:
- Planner logic must be directly testable without installing packages.
- Tests must cover graph walk, dedupe, cycles, peer-policy violation, version satisfaction failure, and multi-root pre-check.

Support / Diagnostics:
- Plan failures must be explainable in logs and result objects using stable reason labels.
- Operators should be able to distinguish "definition not found", "version unsatisfied", "peer policy violated", and "cycle" without reading raw JSON.

Release / Rollout:
- The implementation must be compatible with existing assigned/materialize flows and should avoid changing removal behavior.
- Rollback should be simple: planner integration should be removable without migrating persisted data.

Compatibility / Migration:
- Existing dependency objects with only `definitionId` and optional `publisherId` must keep working.
- Any schema additions for edge version constraints or peer policy must be additive and compatible with schema 1.8 documents that omit them.

Security / Trust:
- Planning must resolve definitions through the existing catalog-trust path.
- It must not bypass signing, `catalogTrust`, publisher conflict policy, or `AcceptUnknownSigningKey` behavior.

Performance / Cost:
- Current catalog size is small enough for direct plan scans, but the planner should avoid repeated selection work where a shared node is already resolved.
- No large index/cache should be introduced in this slice.

User-Facing Behavior:
- The visible behavior should be "plan first, mutate only after approval"; successful installs should still look like normal `Invoke-Package` outcomes.

### 🧭 Codebase Assessment

Assessment Depth:
- Broad Mapping.

Areas Inspected:
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.Dependencies.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.CommandFlow.ps1`
- `Schema/PackageDefinition/eigenverft-module-package-definition-1.8.schema.json`
- Existing package tests under `src/prj/Eigenverft.Manifested.Package.Test`
- `TODO-DEPENDENCY-A.md`
- `PROJECT-IMPLEMENTATION-FRAMEWORK.md`

Ownership Signals:
- `Package.Dependencies.ps1` owns current direct dependency recursion and dependency result projection.
- `Package.CommandFlow.ps1` owns assigned/materialize flow ordering and is where dependency planning must be invoked before mutation.
- Schema 1.8 owns authored dependency wire shape.
- Config/definition and lifecycle tests are the natural regression home.

Existing Patterns:
- Lifecycle support is split by concept into focused `Eigenverft.Manifested.Package.Package.*.ps1` files.
- Flows use ordered step arrays with `CurrentStep`, `[STEP]`, `[STATE]`, `[FAIL]`, and `PackageResult` mutation.
- Definition resolution goes through `Get-PackageConfig` / catalog trust rather than raw file loading.
- Tests use helper-generated package definitions and mocked config/inventory paths.

Reusable Assets:
- `Resolve-PackageDependencyStack`
- `Get-PackageDependencyReferenceKey`
- `Resolve-PackageDependencyPublisherId`
- `Resolve-PackageDependencyDefinition`
- `Resolve-PackageDependencies`
- `Invoke-PackageDefinitionCommandCore`
- `Resolve-PackagePackage`
- `Get-PackageConfig`
- `Resolve-PackageDefinitionReference`
- test helpers in `Eigenverft.Manifested.Package.Module.TestHelpers.ps1`

Existing Functions / Helpers Checked:
- `Resolve-PackageDependencies`: reuse as executor seam, not as graph planner.
- `Resolve-PackageDependencyDefinition`: reuse to execute approved dependency nodes.
- `Resolve-PackagePackage`: reuse selection logic when resolving candidate versions.
- `Get-PackageDependencyReferenceKey`: reuse or extend for stable node keys.
- `Invoke-PackageAssignedFlow` / `Invoke-PackageMaterializeOnlyFlow`: extend to call planning before dependency execution.

General-Purpose Candidate:
- Yes. Dependency graph planning should be a focused lifecycle helper layer.

Repetition Signals:
- Recursive dependency stack handling, dependency key normalization, dependency result projection, and accepted-status checks can be duplicated if planning is added inline.
- Multi-root `Invoke-Package` currently repeats per-root command core flow rather than planning roots together.

Constraints Found:
- Dependency wire shape currently allows only `definitionId` and optional `publisherId`.
- Current recursive execution detects self/cycle cases but has no unified graph object.
- `Invoke-Package` arrays currently run roots independently, with optional fail-fast after a failed result.
- Catalog trust and publisher conflict policy must remain authoritative during planning.
- Persisted plan artifacts are explicitly out of the first slice.

Debt / Risk Signals:
- `Resolve-PackageDependencies` is already a mixed direct-edge resolver/executor; adding graph planning inline would create a hard-to-test function.
- Batch pre-check requires a different scope than single-result execution.
- Edge constraint grammar and peer-policy wire shape are not final.

Unknowns:
- Final edge version-range grammar.
- Final peer-policy wire shape for `conflictsWith` and `requiresAbsent`.
- Exact result/log field names for the in-memory plan summary.
- Whether `Invoke-Package` should expose a future explicit dry-run/planning mode.

Assessment Judgement:
Option A1 fits the current codebase if the planner is introduced as a focused lifecycle helper layer and the existing recursive execution path is treated as the executor. The codebase does not support an A2 persisted artifact safely yet because the plan schema is not proven, and A3 delays the main runtime benefit without removing the need to integrate the planner into `Invoke-Package`.

### ♻️ Reuse Map

Reuse Directly:
- Existing definition resolution and catalog-trust functions.
- Existing version selection path through `Resolve-PackagePackage`.
- Existing dependency execution through `Resolve-PackageDependencyDefinition`.
- Existing lifecycle logging conventions.
- Existing Pester test helpers for authored package definitions.

Extend:
- `PackageResult` can carry an in-memory dependency plan/verdict.
- `Invoke-PackageAssignedFlow` and `Invoke-PackageMaterializeOnlyFlow` can call planning before recursive dependency execution.
- `Resolve-PackageDependencies` can accept/consume an approved plan or plan node context instead of discovering policy on its own.

Compose:
- Compose graph planning from definition resolution, package selection, edge parsing, peer-policy checks, and dedupe helpers.
- Compose batch planning from per-root graph plans plus shared-node reconciliation.

Avoid Duplicating:
- Do not reimplement catalog trust.
- Do not reimplement package version ordering.
- Do not reimplement existing package selection logic.
- Do not add a parallel dependency executor.
- Do not duplicate future supply-chain age policy.

Not Suitable:
- `Resolve-PackageDependencies` as the sole planner owner.
  Reason: It currently executes dependencies and would become too large and responsibility-dense.
- Operation history as the first plan artifact.
  Reason: Persisted plan schema is intentionally deferred from A1.

Reuse Judgement:
Reuse is strong enough for A1 if planning orchestrates existing resolution and selection helpers. New code is justified only for graph state, policy validation, dedupe, and batch verdicts.

### 🧰 Shared Helper / Generalization Check

Existing Functions Checked:
- `Get-PackageDependencyReferenceKey`
  Result: Extend for plan node keys if needed.
- `Resolve-PackageDependencyPublisherId`
  Result: Reuse for edge publisher selection.
- `Resolve-PackageDependencies`
  Result: Reuse as executor seam, not as planner owner.
- `Resolve-PackagePackage`
  Result: Reuse for version selection.
- `Resolve-PackageDefinitionReference`
  Result: Reuse indirectly through `Get-PackageConfig`.

Support Helpers Checked:
- lifecycle command-flow step pattern.
  Result: Extend with planning step before mutation.
- test package document helpers.
  Result: Reuse for planner fixtures.
- schema validation helpers.
  Result: Extend only after wire shape is selected.

General-Purpose Function Candidate:
- Yes.

Candidate Responsibility:
- Build and validate dependency plans from requested roots, definitions, target platform/architecture/release track, version edges, and peer-policy edges.

Candidate Location:
- New lifecycle support file: `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1`.

Why Generalize:
- Planning is a reusable concept needed by assigned flow, materialize flow, multi-root pre-check, tests, and future validation/dry-run surfaces.
- A focused file keeps graph logic out of the recursive executor and command-flow step arrays.

Why Keep Local:
- Only small adapters should stay local to `CommandFlow.ps1`, such as attaching plan/verdict to `PackageResult` and selecting assigned/materialize planning behavior.

Decision:
- Create focused helper.

### 🔁 Repetition Check

Repeated Logic Found:
- Dependency key construction and stack checks.
- Per-root dependency traversal.
- Dependency result/status acceptance.
- Definition/package resolution in recursive calls.

Potential Duplicate Implementation:
- Planner could accidentally duplicate package version selection, catalog trust checks, or recursive dependency execution.

Second-Time / Third-Time Rule:
- Dependency traversal already exists once as executor recursion; planning would become the second occurrence and should be separated into a reusable owner instead of being copied inline.

Recommended Handling:
- Extract planner responsibility into a focused helper file and keep execution logic in existing functions.

Reason:
Structural churn and high repetition risk make inline implementation unsafe. A focused planner avoids turning existing executor code into a mixed solver.

---

### 🧩 Implementation Options

#### Option A — A1 planner-first in `Invoke-Package` (Reuse / Extension Option)

- 🧾 Implementation Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
  - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
  - 🔁 Repetition Control: 3/4 Good ▰▰▰▱
  - 📍 Placement Fit: 3/4 Good ▰▰▰▱
  - 📏 Growth Impact: 3/4 Heavy ▰▰▰▱
  - 👥 Stakeholder Fit: 🟢 Satisfied
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱

Description:
Add a focused dependency-planning layer and integrate it into `Invoke-Package` assigned/materialize flows before machine mutation. Keep recursive dependency execution, but run it only after the in-memory plan is approved.

Codebase Basis:
Current command flows already have an early `ResolveDependencies` step before path/acquisition/install work. The dependency executor exists and can consume approved plan context after planning moves graph/policy concerns elsewhere.

Placement:
Create `Package.DependencyPlan.ps1` under lifecycle support and wire it in the module near `Package.Dependencies.ps1`. Add thin calls in assigned/materialize flows before dependency execution.

Reuse:
Reuse definition resolution, package selection, dependency key helpers, existing recursive dependency execution, lifecycle messages, and test fixtures.

Helper / Generalization:
A new focused planner helper makes sense because graph planning will serve assigned flow, materialize flow, multi-root pre-check, and future validation/dry-run work.

Repetition Control:
The planner owns traversal, dedupe, edge validation, and verdicts. Existing executor remains responsible for applying approved dependencies.

Stakeholder Technical Fit:
This option gives maintainers a focused owner, testers direct planner seams, and users fail-closed pre-mutation behavior without persisted migration risk.

Solves:
- Runtime pre-check for dependency graphs.
- Shared-node dedupe and multi-root conflict verdicts.
- Explainable plan/verdict before install execution.

Leaves Open:
- Persisted plan artifact.
- Final dry-run/public validation surface.
- Future supply-chain age policy composition.

Risks:
- Requires careful integration so recursive execution does not re-plan inconsistently.
- Edge version-range and peer-policy wire details still need coding-time decisions before schema changes.

Later Cost:
- Add persisted artifact/export once plan object shape is proven by runtime use.

---

#### Option B — A2 planner plus persisted plan artifact in v1 (Implementation Option)

- 🧾 Implementation Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
  - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
  - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
  - 🔁 Repetition Control: 4/4 Strong ▰▰▰▰
  - 📍 Placement Fit: 3/4 Good ▰▰▰▱
  - 📏 Growth Impact: 4/4 Harmful Risk ▰▰▰▰
  - 👥 Stakeholder Fit: 🟡 Partial
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🤖 Agent Difficulty: 4/4 Human-Led ▰▰▰▰

Description:
Build the planner and define a persisted plan schema, export/history representation, and replay/validation story in the same v1 slice.

Codebase Basis:
The repo has operation history and state persistence, but no dependency-plan schema or stable plan object yet.

Placement:
Planner helpers would still belong under lifecycle support, while persistence would touch state/history modules and possibly command/API surface.

Reuse:
Reuse the same planner and execution helpers as Option A, plus operation-history patterns.

Helper / Generalization:
Strong helper need, but artifact persistence adds another ownership boundary.

Repetition Control:
A persisted schema could reduce future duplicate reporting logic, but only after plan fields stabilize.

Stakeholder Technical Fit:
Good for auditability, weaker for delivery safety because it broadens compatibility and migration concerns.

Solves:
- Runtime planning.
- CI/audit artifact story.
- More complete v1 review surface.

Leaves Open:
- Exact artifact lifecycle and compatibility policy if plan shape changes.

Risks:
- Freezes plan schema too early.
- Touches more modules and public behavior before runtime semantics are proven.

Later Cost:
- Lower future artifact cost if correct, but high rework if early schema is wrong.

---

#### Option C — A3 validation-surface first (Split Option)

- 🧾 Implementation Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
  - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
  - 🔁 Repetition Control: 3/4 Good ▰▰▰▱
  - 📍 Placement Fit: 3/4 Good ▰▰▰▱
  - 📏 Growth Impact: 3/4 Heavy ▰▰▰▱
  - 👥 Stakeholder Fit: 🟡 Partial
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱

Description:
Implement dependency planner logic behind a validation or dry-run surface first, then integrate it into `Invoke-Package` after report shape and policy quality are proven.

Codebase Basis:
Catalog validation is already a related TODO track, and planner tests could mature before runtime behavior changes.

Placement:
Planner helper remains under lifecycle/support, but public exposure may wait for catalog validation or a future dry-run command.

Reuse:
Reuse planner helpers, schema validation, and test fixtures; do not change recursive execution initially.

Helper / Generalization:
Strong helper need; the planner should still be built as reusable core logic.

Repetition Control:
Good if validation and invoke later share the same planner; poor if validation creates a separate path.

Stakeholder Technical Fit:
Good for cautious rule development; weaker for operators because runtime still lacks fail-closed pre-check until phase two.

Solves:
- Lower-risk policy iteration.
- Early planner unit coverage.

Leaves Open:
- Main `Invoke-Package` fail-closed runtime outcome.
- Batch pre-check during real installs.

Risks:
- Validation path may drift from execution.
- Delays the selected Option A runtime benefit.

Later Cost:
- Must still integrate into assigned/materialize flows.

---

### 💶 Implementation Fit Assessment

- 💎 Fit Type: Maintainability / Compatibility / Testability
- 🧭 Fit Direction: Improves fit while controlling structural churn
- 🧾 Fit Mechanism: Prefer a focused planner helper that reuses existing resolution/execution code and adds fail-closed planning without forcing a persisted artifact too early.
- ⚖️ Option Fit Summary:
  - Option A — A1 planner-first in `Invoke-Package` (Reuse / Extension Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
    - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
    - 🔁 Repetition Control: 3/4 Good ▰▰▰▱
    - 📍 Placement Fit: 3/4 Good ▰▰▰▱
    - 📏 Growth Impact: 3/4 Heavy ▰▰▰▱
    - 👥 Stakeholder Fit: 🟢 Satisfied
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Best first runtime slice; delivers pre-mutation planning while deferring artifact schema risk.
  - Option B — A2 planner plus persisted plan artifact in v1 (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
    - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
    - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
    - 🔁 Repetition Control: 4/4 Strong ▰▰▰▰
    - 📍 Placement Fit: 3/4 Good ▰▰▰▱
    - 📏 Growth Impact: 4/4 Harmful Risk ▰▰▰▰
    - 👥 Stakeholder Fit: 🟡 Partial
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 4/4 Human-Led ▰▰▰▰
    - 🧾 Decision Note: Valuable later, but too much schema and persistence commitment for the first implementation slice.
  - Option C — A3 validation-surface first (Split Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
    - 🧰 Helper Fit: 4/4 Strong ▰▰▰▰
    - 🔁 Repetition Control: 3/4 Good ▰▰▰▱
    - 📍 Placement Fit: 3/4 Good ▰▰▰▱
    - 📏 Growth Impact: 3/4 Heavy ▰▰▰▱
    - 👥 Stakeholder Fit: 🟡 Partial
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Useful fallback if runtime integration blocks, but delays the required fail-closed invoke behavior.
- ✅ Good Implementation Result: `Invoke-Package` can build one dependency plan for requested roots, reject incompatible plans before mutation, and then execute existing recursive dependencies from the approved plan with clear logs and tests.

---

### 🏁 Implementation Recommendation

- [2026-06-01 15:45 | Author: Codex | Recommendation: Prefer Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Option A1 is the best fit for the current codebase and the user-selected issue recommendation. It gives the runtime fail-closed behavior that motivated the TODO, reuses existing selection/trust/execution code, and avoids freezing a persisted plan artifact before the in-memory plan shape is proven.

Required Checks:
- Settle edge version-range grammar before schema patch.
- Settle peer-policy wire shape for `conflictsWith` and `requiresAbsent` before schema patch.
- Define minimal in-memory plan fields before coding planner tests.
- Verify the planning step runs before path/acquisition/install/materialization mutation for multi-root `Invoke-Package`.

### 📍 Final Placement Decision

Chosen Placement:
- New focused planner owner: `src/prj/Eigenverft.Manifested.Package/Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1`.
- Integration seams: `Package.CommandFlow.ps1` and `Package.Dependencies.ps1`.
- Schema additions, if chosen during coding: `Schema/PackageDefinition/eigenverft-module-package-definition-1.8.schema.json`.

Reason:
Dependency planning is a lifecycle concern adjacent to dependency execution, but it has enough graph/policy responsibility to need a focused owner. Command flow owns when planning happens; dependency execution owns how approved dependencies are applied.

Rejected Placement:
- Put all planner logic in `Resolve-PackageDependencies`.
  Reason: That would mix graph planning, policy validation, recursive execution, and result projection in one function.
- Put planner logic in `Cmd.InvokePackage.ps1`.
  Reason: The command layer should not own dependency graph semantics.
- Put persisted plan output in operation history in the first slice.
  Reason: A1 intentionally avoids persisted artifact schema.

New Files:
- Yes.

New File Reason:
A focused planner support file is justified by structural churn, helper/generalization need, and high growth risk in existing dependency/execution files.

### 🌊 Churn and 📏 Growth Control

Churn Classification:
- Structural.

Growth Watch:
- `Package.Dependencies.ps1`: must not become a planner/solver file.
- `Package.CommandFlow.ps1`: should receive thin planning integration only.
- Schema 1.8: only additive dependency properties after wire shape is chosen.
- Tests: keep planner tests grouped rather than scattering large setup across suites.

Extraction Trigger:
- If planner code exceeds a small set of graph/policy helpers or starts mixing schema parsing, execution, logging, and result projection, extract by responsibility inside the planner file before continuing.

Allowed Local Churn:
- Thin flow-step additions.
- Small executor adapters to consume an approved plan.
- Focused schema/test updates required by chosen edge and peer-policy wire shape.

### 🛠 Implementation Plan

Steps:
1. Create `Package.DependencyPlan.ps1` and dot-source it near dependency lifecycle support.
2. Define an in-memory plan object with roots, nodes, edges, selected package/version metadata, dedupe keys, violations, and approved/failed verdict.
3. Add graph traversal that resolves definitions through existing config/trust paths and selects package versions through existing selection helpers.
4. Add edge validation hooks for version satisfaction, leaving final grammar choice explicit in code/tests before schema patch.
5. Add peer-policy validation hooks for `conflictsWith` and `requiresAbsent`, leaving final wire shape explicit in code/tests before schema patch.
6. Add multi-root planning before per-root execution in public `Invoke-Package` array handling or the earliest shared command-core seam that sees all requested roots.
7. Attach the approved plan or relevant plan node context to `PackageResult`.
8. Update `Resolve-PackageDependencies` to execute dependencies from the approved plan while preserving current recursive assigned/materialize behavior.
9. Emit concise `[STATE]`/failure messages that summarize plan approval or violations.
10. Keep persisted artifacts, dry-run command surface, lockfile migration, and `mutexGroup` out of this slice.

### 🧪 Verification Plan

Tests:
- Planner builds a single-root dependency tree with selected versions.
- Planner dedupes a shared dependency across multiple roots.
- Multi-root incompatible dependency policy fails before dependency execution or package mutation.
- Self-dependency and cycle detection remain fail-closed.
- Edge version satisfaction failure reports the edge and selected/available version context.
- `conflictsWith` and `requiresAbsent` peer-policy failures report clear violations after wire shape is chosen.
- Existing dependency-only definitions still work when they omit all new fields.
- Assigned and MaterializeOnly flows both consume approved plans.

Checks:
- Run dependency/config/command-flow Pester suites touched by the implementation.
- Run full Pester suite before acceptance.
- Run ScriptAnalyzer suite.
- Run `git diff --check`.

Reuse / Helper Verification:
- Review implementation to confirm catalog trust, definition reference, package selection, and recursive dependency execution are reused rather than duplicated.
- Confirm planner helper owns graph/policy state and command flow only orchestrates.

Repetition Verification:
- Search for duplicate graph traversal, duplicate version comparison, and duplicate peer-policy parsing before acceptance.
- If a second copy appears, move it into the planner helper or a schema parsing helper.

Stakeholder Verification:
- Maintainer: planner file is readable, focused, and not a dumping ground.
- Test / QA: graph/policy behavior is unit-testable without installing packages.
- Compatibility: old dependency documents still pass.
- Security / Trust: planner uses existing trust/definition resolution.
- User-facing: plan failures are visible before mutation.

### 🤖 Agent Instructions

Agent Role:
- Strong guided implementer.

Instructions:
- Create or return this as a separate file named `implementation-dependency-a.md`.
- Do not append this document to the original issue Markdown.
- Do not implement dependency engine, schema, catalog, or tests as part of the documentation-only framework pass.
- When implementing later, read this file before coding.
- Check existing functions, helpers, support utilities, tests, and repeated logic before editing code.
- Prefer Option A1 unless a concrete blocker is found.
- Keep planner logic in a focused lifecycle helper; do not expand `Resolve-PackageDependencies` into a solver.
- Preserve existing recursive dependency execution as the executor for approved plans.
- Do not add persisted plan artifacts in the first implementation slice.
- Do not implement full lockfile migration, fleet orchestration, or `mutexGroup`.
- Stop and report if edge version-range grammar or peer-policy wire shape cannot be settled safely during coding.
- After implementation, create `post-implementation-dependency-a.md` using `PROJECT-IMPLEMENTATION-FRAMEWORK.md` V0.4.
