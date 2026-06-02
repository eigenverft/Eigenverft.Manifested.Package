# ISSUE SCHEMA DEPENDENCY TOPLEVEL

Issue definition follows [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; option kind in each option heading; Value Assessment after Options; Stakeholder Success Note after Recommendation; one Choose/Prefer recommendation with required author and `YYYY-MM-DD HH:mm`.

---
---

## 📌 Consolidate dependency wire shape into one top-level object

- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧭 Usability / 🛡 Schema Integrity
  - 🚧 Readiness: 🟡 Needs Wire-Shape Decision

### 📝 Statement

The dependency-planning implementation added two authored top-level dependency-related fields to `eigenverft-module-package-definition-1.8.schema.json`: required `dependencies[]` and optional `dependencyPolicy`. This splits one conceptual dependency namespace into multiple top-level JSON elements.

Package-definition JSON should expose one top-level dependency object only. Dependency edges, edge version ranges, and peer policy (`conflictsWith`, `requiresAbsent`) should live under that single object or an explicitly chosen equivalent shape.

Original report:

> Our `eigenverft-module-package-definition-1.8.schema.json` has multiple top-level dependency elements. There should be only one dependency top-level object in the JSON.

### 🧭 Related Context

Related Issues:
- [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) — implemented A1 dependency planning and introduced edge ranges / peer policy.
- [`implementation-dependency-a.md`](implementation-dependency-a.md) — implementation decision artifact for A1.
- [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) — future authoring guidance must describe the final dependency JSON shape.

Affected Areas:
- `src/prj/Eigenverft.Manifested.Package/Schema/PackageDefinition/eigenverft-module-package-definition-1.8.schema.json`
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_8.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1`
- Shipped signed package definitions under `Endpoint/Defaults/Eigenverft/`
- Catalog/signing tests in `Eigenverft.Manifested.Package.Package.ConfigAndDefinitions.Tests.ps1`

Dependencies:
- The implementation must preserve or deliberately migrate existing `dependencies[]` consumers.
- Any changed shipped package-definition JSON must be re-signed with `Resign-PackageDefinition -Cert Eigenverft -KeepSchemaVersion`.

### 🎯 Required Outcome

1. Author-facing package-definition JSON has exactly one top-level dependency namespace object.
2. Dependency edges and peer policy are represented inside that single object.
3. Schema and wire validation reject ambiguous documents that mix the new single object with the old split top-level shape, unless a deliberate compatibility window is documented.
4. Runtime dependency planning reads the final shape and continues to support edge `versionRange`, `conflictsWith`, and `requiresAbsent`.
5. Shipped Eigenverft definitions are migrated to the final shape and re-signed.
6. Tests prove the schema, runtime planner, and signed shipped catalog all agree on the final shape.

### 🔎 Facts

Known:
- Schema 1.8 currently requires top-level `dependencies`.
- Schema 1.8 currently also allows top-level `dependencyPolicy`.
- `$defs.dependency`, `$defs.dependencyPolicy`, and `$defs.dependencyPolicyReference` are internal schema definitions, not authored top-level instance fields.
- Current shipped definitions now exercise both top-level `dependencies[]` and top-level `dependencyPolicy` after the A1 catalog pass.
- The dependency planner reads `definition.dependencies` and `definition.dependencyPolicy`.
- Shipped package-definition JSON is signed; semantic content changes invalidate `signatureValue`.

Unknown:
- Final nested property names inside the single top-level object, for example `dependency.requires[]` plus `dependency.policy`, or another agreed vocabulary.
- Whether this should remain a schema 1.8 corrective patch or become a schema 1.9 migration.
- Whether runtime should temporarily accept old split-shape documents for compatibility.

---

### 🧩 Options

#### Option A — Single `dependency` object with nested edges and policy (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟢 Compatible with Planner After Migration
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code / Schema

Description:
Replace the split authoring shape with one top-level `dependency` object. Place prerequisite edges and peer policy under that object, with final nested names chosen in the implementation document. Update schema, wire validation, runtime planner reads, shipped definitions, and tests.

Current State:
Dependency edges and peer policy are separate top-level siblings.

Resulting State:
Authors see one dependency namespace and one place to edit all dependency-related fields.

Solves:
- Removes top-level schema clutter.
- Prevents agents from treating dependency edges and dependency policy as unrelated concepts.
- Gives catalog examples one coherent shape.

Leaves Open:
- Compatibility behavior for old `dependencies[]` documents must be chosen.

Risks:
- Migration touches signed JSON and runtime reads; missed signing or stale compatibility tests could break strict catalog trust.

Later Cost:
- Lower authoring and validation cost once the shape is unified.

---

#### Option B — Keep `dependencies[]`, nest only policy under it indirectly (Rejected Shape Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 1/4 Simple ▰▱▱▱
  - 🧾 Agent Work: 📝 Schema Tweak

Description:
Keep top-level `dependencies[]` and try to avoid top-level `dependencyPolicy` by moving only policy elsewhere or documenting the split.

Current State:
The split already exists.

Resulting State:
Top-level dependency shape remains array-first and cannot naturally contain peer policy without another namespace.

Solves:
- Smallest patch.

Leaves Open:
- Does not satisfy the one top-level dependency object requirement.

Risks:
- Keeps the conceptual split and invites more top-level dependency siblings later.

Later Cost:
- Higher if the catalog grows before the shape is unified.

---

#### Option C — Defer until schema 1.9 (Deferral Option)

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Deferred
  - 🛠 Option Effort: 1/4 Trivial Now ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Compatible Short Term
  - 🤖 Agent Difficulty: 1/4 Simple ▰▱▱▱
  - 🧾 Agent Work: 🧭 Decision / Deferral

Description:
Leave schema 1.8 as-is and defer the single-object dependency shape to a future schema 1.9 migration.

Current State:
The split shape has already reached schema and shipped JSON examples.

Resulting State:
No immediate churn, but the current awkward shape remains visible to authors and agents.

Solves:
- Avoids immediate migration and signing work.

Leaves Open:
- The reported schema issue remains unresolved.

Risks:
- More definitions may copy the split pattern before migration.

Later Cost:
- Higher because more signed catalog JSON may need migration.

---

### 💶 Value Assessment

- 💎 Value Type: 🛡 Risk / Loss Avoided · 🧭 Authoring Usability Improved
- 🧭 Value Direction: 🛡 Risk / Protection · 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Consolidating dependency fields into one authoring namespace reduces schema confusion, prevents divergent dependency vocabulary, and keeps signed shipped examples aligned with the planner model.
- ⚖️ Option Value Summary:
  - Option A — Single `dependency` object with nested edges and policy (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Best long-term authoring shape; requires careful compatibility and signing pass.
  - Option B — Keep `dependencies[]`, nest only policy under it indirectly (Rejected Shape Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 1/4 Simple ▰▱▱▱
    - 🧾 Decision Note: Too small to solve the actual one-object requirement.
  - Option C — Defer until schema 1.9 (Deferral Option)
    - 🧭 Resolution: ⚪ Deferred
    - 🛠 Option Effort: 1/4 Trivial Now ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 1/4 Simple ▰▱▱▱
    - 🧾 Decision Note: Avoids churn now but lets the split shape spread.
- ✅ Good Result: Package authors edit exactly one dependency object, and strict signed catalog definitions still verify after migration.

---

### 🏁 Recommendation

- [2026-06-02 05:22 | Author: Codex | Recommendation: Choose Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
The current split was introduced by the dependency planner pass, but the concept belongs together. Option A fixes the authoring model while the affected surface is still small and before more package definitions copy the split shape.

Required Checks:
- Confirm the final nested names before implementation.
- Run schema/wire tests, planner tests, full Pester, and `git diff --check`.
- Re-sign every changed shipped package-definition JSON with `Resign-PackageDefinition -Cert Eigenverft -KeepSchemaVersion`.
- Verify the shipped catalog in a fresh local profile with `Verify-PackageDefinitionCatalog -RequireTrusted`.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Maintainer / 🧪 Test / 🧭 Catalog Author
- 🗣 Communication Lens: Technical Summary
- 📬 Success Note: Dependency authoring is being tightened so package JSON has one dependency namespace instead of separate top-level fields for edges and policy. The planner capability remains, but the schema and examples will become easier for maintainers and agents to use correctly.

### ❓ Open Decisions

- Exact top-level property name: likely `dependency`, but implementation should confirm before patching schema and shipped JSON.
- Exact nested edge list name: `requires`, `edges`, or another project vocabulary.
- Schema version strategy: corrective schema 1.8 patch vs schema 1.9 migration.
- Compatibility window for old `dependencies[]` plus `dependencyPolicy` documents.

### 🚫 Out of Scope

- Reworking the dependency planner algorithm.
- Adding persisted dependency plan artifacts, lockfiles, dry-run command surface, fleet orchestration, or `mutexGroup`.
- Changing dependency version-range grammar.
- Fixing unrelated ScriptAnalyzer warnings or unrelated TODO/index files.

### 🌱 Extracted Work

Optional:
- [ ] Update catalog authoring guidance after the final dependency object shape lands.
  Reason: Agent and maintainer docs should point to the unified shape once implemented.

