# TODO DEPENDENCY A

## Purpose

Execution-track issue for the selected **Option A** dependency architecture: implement a planning pipeline on top of the current recursive dependency install path (without switching to a lockfile-first solver in v1).

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** (or **Choose Direct Fix**) per issue with required author and `YYYY-MM-DD HH:mm`.

Open issues in this file are scheduled here. **No engine, schema, or catalog changes are implied by this file alone** unless explicitly implemented.

Related:
- This file is now the authoritative dependency-planning TODO; the prior split parent `TODO-DEPENDENCY.md` is no longer present in the workspace.
- [`TODO-SUPPLY-CHAIN.md`](TODO-SUPPLY-CHAIN.md) — release-age policy that must compose per dependency node.
- [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) — static policy/range lint alignment.

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 2/6 — High**

---
---

## 📌 Implement Option A dependency planning on current recursive install path

- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 4/4 Major ▰▰▰▰
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 4/4 Organization ▰▰▰▰
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: ✨ Functionality
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

The project now treats **Option A** as the selected architecture for v1 dependency work: keep direct `dependencies[]` semantics and recursive assign/materialize behavior, but add a **planning pass** that resolves graph, versions, peer-policy checks, shared-node dedupe, and batch fail-closed verdicts before install execution.

Current runtime still behaves as a minimal direct-edge resolver (`Resolve-PackageDependencies`) with no unified plan object, no edge version constraints, and no batch-level consistency check.

### 🧭 Related Context

Related Issues:
- [`TODO-SUPPLY-CHAIN.md`](TODO-SUPPLY-CHAIN.md) — age filters apply per resolved dependency node; do not duplicate age logic in the dependency planner.
- [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) — static checks for authored ranges/peer policy should reuse the same rule vocabulary.
- [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) — future authoring skill must describe Option-A policy vocabulary.

Affected Areas:
- `Package.Dependencies.ps1`
- `Cmd.InvokePackage.ps1`
- `PackageResult` projection and operation history
- Wire/schema for dependency edge constraints and peer policy (`conflictsWith`, `requiresAbsent`)

Dependencies:
- This issue assumes Option A is accepted; Option B lockfile-first migration is out of v1 scope.

### 🎯 Required Outcome

1. Add a **plan-first dependency pipeline** with separate sub-resolvers (graph, version satisfaction, peer policy, dedupe, plan emit).
2. Keep current recursive install model for execution, but only run it from an approved plan.
3. Add edge-level compatibility constraints (`versionRange` or agreed equivalent) and enforce fail-closed when no candidate satisfies policy.
4. Add peer-policy support (`conflictsWith`, `requiresAbsent`) in planning and batch pre-check.
5. Provide explainable output for operators/CI: resolved tree, picked versions, and policy violations before machine mutation.
6. Add multi-root batch pre-check for `Invoke-Package` so incompatible requested sets fail before install begins.

### 🔎 Facts

Known:
- Runtime today is direct-edge recursion, not a unified solver.
- Wire `dependency` in schema 1.8 has `definitionId` + optional `publisherId` only.
- Catalog currently has 18 definitions; 5 define non-empty `dependencies[]`.
- Cycle and self-dependency detection exists; cross-root version negotiation does not.
- `Invoke-Package` processes multiple `DefinitionId` values independently with optional fail-fast after failures.

Unknown:
- Final shape for edge constraint field (`versionRange` vs constrained policy enum).
- Minimum persisted plan schema (log-only vs export artifact vs history integration).
- Exact user-facing dry-run surface (`Invoke-Package` mode vs companion command).

---

### 🧩 Options

#### Option A1 — Planner-first in `Invoke-Package` (log-backed plan, no persisted artifact yet) (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Implement Option A by adding a planning pass directly in `Invoke-Package` flow: build/validate plan, fail closed on conflict, then execute existing recursive semantics. Keep plan output in command/result/log projection only for v1.

Current State:
Direct recursive invoke path with no unified planning object.

Resulting State:
Planner produces one dependency verdict in runtime; execution consumes approved in-memory plan; batch conflicts and peer-policy violations are caught pre-install.

Solves:
- Fastest route to fail-closed batch behavior.
- Lowest migration risk from current engine flow.

Leaves Open:
- Persisted/replayable plan artifact for CI auditing.

Risks:
- Harder to reuse planning output outside invoke path if no artifact schema exists.

Later Cost:
- Add artifact export and validation-surface reuse in later phase.

---

#### Option A2 — Planner + persisted plan artifact in v1 (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Deliver Option A with both planner integration and a first-class persisted plan format (export file and/or operation history object) in the same track.

Current State:
No planning artifact exists; no common schema to share between runtime and CI.

Resulting State:
Each approved dependency plan can be archived, diffed, and replay-validated by CI tooling.

Solves:
- Stronger auditability and deterministic review workflow in v1.
- Easier future dry-run and validation command reuse.

Leaves Open:
- Final storage target (file, history, or both) still needs narrowing.

Risks:
- Larger first delivery scope; format churn risk if learned too early.

Later Cost:
- Lower, if schema stabilizes early and is reused across tools.

---

#### Option A3 — Validation-surface first, invoke integration second (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Implement Option A planner logic first behind a validate/dry-run surface, then wire it into `Invoke-Package` execution after rule quality and report shape are stable.

Current State:
Planning and execution are tightly coupled in recursive invoke.

Resulting State:
Planner can be iterated safely before changing runtime behavior; invoke adopts it in a second phase.

Solves:
- De-risks policy/range correctness with earlier feedback loops.
- Strong alignment with catalog-validation workflows.

Leaves Open:
- Runtime still lacks fail-closed pre-check until second phase lands.

Risks:
- Two-step rollout may delay operator-facing invoke improvements.

Later Cost:
- Medium: integration debt if validate path diverges from invoke expectations.

---

### 💶 Value Assessment

- 💎 Value Type: ✨ Product Capability Improved · 🛡 Risk / Loss Avoided · 🚚 Delivery Unblocked
- 🧭 Value Direction: 🚀 Opportunity / Improvement · 🛡 Risk / Protection
- 🧾 Value Mechanism: Adds explicit pre-install dependency planning and fail-closed batch checks while retaining current execution behavior, reducing mid-run conflicts and unclear dependency outcomes.
- ⚖️ Option Value Summary:
  - Option A1 — Planner-first in `Invoke-Package` (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Fastest runtime win; leaves persisted artifact as follow-up.
  - Option A2 — Planner + persisted artifact in v1 (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Strongest v1 auditability; highest initial delivery cost.
  - Option A3 — Validation-surface first (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Safest logic incubation path; delays invoke-path benefit.
- ✅ Good Result: Operators and CI get a single explainable dependency plan before install; incompatible batch requests and peer conflicts fail early; dependency selection composes correctly with supply-chain age policy.

---

### 🏁 Recommendation

- [2026-05-30 13:48 | Author: Composer | Recommendation: Prefer Option A1 | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Option A is already selected as architecture baseline. Within that track, A1 gives the quickest fail-closed behavior in `Invoke-Package` and preserves implementation momentum; A2 can follow once plan schema stabilizes, and A3 can be used selectively if policy-rule churn blocks runtime integration.

Required Checks:
- Confirm edge constraint wire shape (`versionRange` vs policy enum) before schema patch.
- Define minimum plan object fields for Phase 1 tests.
- Keep planner/executor parity tests mandatory for each phase.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 🚚 Release Owner · 🛟 Support / Customer Success
- 🗣 Communication Lens: 🚚 Release Summary
- 📬 Success Note: Dependency installs become predictably plan-first: teams can see prerequisite trees and conflicts before machine changes, and multi-package invokes stop early when shared dependency policy cannot be satisfied.

### ✅ Resolved Decisions

- [2026-05-30 13:46 | Author: User | Decision: Option A selected as v1 dependency architecture baseline]
- Option B (lockfile-first migration) is deferred from this v1 track.

### ❓ Open Decisions

- Choose **A1 vs A2 vs A3** rollout inside the Option-A track.
- Final field model for edge constraints (`versionRange`, named policy, or both).
- Plan artifact persistence strategy (history, export file, or both).
- Whether dry-run ships as `Invoke-Package` planning mode, separate command, or both.
- Whether `mutexGroup` is in v1 or deferred after `conflictsWith` / `requiresAbsent`.

### 🚫 Out of Scope

- Full lockfile-first solver migration (former Option B).
- Fleet orchestration / rollout policy management across machines.
- npm-internal lockfile graph replacement for `npmMaterializedInstallGlobalPackage`.

### 🌱 Extracted Work

Required:
- [ ] **Phase 0 — Planner boundaries**: introduce sub-resolver contracts and plan object.
- [ ] **Phase 1 — Schema/wire**: edge constraints + peer policy (`conflictsWith`, `requiresAbsent`).
- [ ] **Phase 2 — Single-root planning pass**: graph resolution, versions, peer verdict, explainable output.
- [ ] **Phase 3 — Batch pre-check**: multi-`DefinitionId` compatibility before install.
- [ ] **Phase 4 — Execution integration**: run install from approved plan, keep behavior parity.
- [ ] **Phase 5 — Tests and projections**: parity tests, failure messaging, operation history/result projection.

Optional:
- [ ] **Phase 6+** — plan export artifact, `mutexGroup`, deeper validation/report alignment.

---
