# ONBOARDING PROFILES - Design Issues

Design scratchpad for **role-based onboarding profiles** - named, reviewable bundles of `DefinitionId` values for team and agent onboarding. Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.8): rating and option-profile tables with short rationales; **Option Kind** in each option heading; **Value Assessment** after Options with **Good Result**; **Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` and [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) on **2026-06-07**.

Open issues in this file are scheduled here. **No engine, schema, or catalog changes are implied by this file alone** unless an issue and chosen option state otherwise.

**Compose with:** [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) (local engine vs future Manager product). [`IDEA-AGENT-SCALES-PRODUCT.md`](IDEA-AGENT-SCALES-PRODUCT.md) (onboarding profiles as reviewable artifacts, not a runtime manager). [`TODO-DOCUMENTATION.md`](TODO-DOCUMENTATION.md) (natural home for profile chapter in hybrid docs). [`Get-PackageDefinitionAuthoringGuide`](../../prj/Eigenverft.Manifested.Package/Commands/Module/Eigenverft.Manifested.Package.Cmd.Module.ps1) / agent authoring path (profiles are sibling artifacts to definitions, not replacements).

**Product boundary (read narrowly):** Profiles are **content** (which packages belong to a role). Org-wide **mandate, rollout, and drift across many hosts** belong to a future **Eigenverft Manifested Manager** product - not this engine. The engine continues to execute explicit `Invoke-Package` assignment; profiles do not become fleet orchestration.

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 3/7 - Low**

---
---

## 📌 Teams lack named onboarding profiles for DefinitionId bundles

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | gap is strategic; core assign path works |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | format, examples, docs; optional read cmd |
| 🧠 Complexity | 3/5 Complex | ▰▰▰▱▱ | engine vs manager vs trust boundary |
| 🌍 Benefit | 3/4 Team | ▰▰▰▱ | shared role-based setup helps teams |
| 📦 Shape | 2/4 Composite | ▰▰▱▱ | artifact format plus docs plus optional cmd |
| 🎯 Quality | 🧭 Usability | - | roles easier than raw DefinitionId lists |
| 🚧 Readiness | 🟠 Needs Refinement | - | profile file shape not chosen yet |

### 📝 Statement

Teams and agents think in **roles** (backend dev, AI runtime, PowerShell maintainer), but the product only exposes individual **package definitions** (`DefinitionId`). Today every onboarding path is a hand-built comma list, wiki note, or README demo - there is no first-class, reviewable **profile** artifact that says "this role = these definitions, for this reason."

`Invoke-Package` already accepts multiple `-DefinitionId` values and the dependency planner orders prerequisites. The gap is **naming, curation, and review** - not a new install engine.

Original design intent (from product discussion and [IDEA-AGENT-SCALES-PRODUCT.md](IDEA-AGENT-SCALES-PRODUCT.md)):

> Profile = reviewable bundle of DefinitionIds. Agent or maintainer proposes; human reviews; execution stays `Invoke-Package`. Manager later may **require** a profile org-wide - but profile **content** should exist before that.

### 🧭 Related Context

Related Issues:
- [IDEA-AGENT-SCALES-PRODUCT.md](IDEA-AGENT-SCALES-PRODUCT.md) - onboarding profiles as idea; `New-PackageOnboardingProfile` name only, not committed.
- [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) - hybrid guide can host profile examples and team onboarding chapter.
- [TODO-OWNERSHIP.md](TODO-OWNERSHIP.md) - orthogonal; profiles do not change ownership rules.
- [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) - orthogonal; version cooling applies per definition at invoke time.

Affected Areas:
- Future profile artifact location (repo markdown/JSON, team endpoint, or module `Docs/`).
- README quick-start and demo command lists.
- Agent authoring workflow (`Get-PackageDefinitionAuthoringGuide`, `PackageDefinitionAuthoring.md`).
- Optional future read-only command surface (no commitment in v1).

May Influence:
- Future **Manifested Manager** product (profile-id policy binding across hosts).
- Onboarding profile recommendations in agent skills.
- `Search-Package` result enrichment (assigned vs recommended) - optional, not required for v1.

Dependencies:
- Choose profile artifact format and storage (see **Open Decisions**) before bulk authoring.
- [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) is the natural packaging home for user-facing profile docs if hybrid docs ship.

### 🎯 Required Outcome

1. A documented **profile artifact model**: stable `profileId`, human title, intended audience/role, ordered or unordered `definitionIds[]`, short rationale, version or revision metadata, and review/sign-off fields as appropriate for the storage medium.
2. At least **two shipped example profiles** (e.g. backend-dev, ai-local-runtime) validated against the **18** Eigenverft definitions and real dependency behavior.
3. Clear product rule: **execution remains `Invoke-Package`** in v1; profiles do not add background assignment, fleet policy, or a separate trust inventory.
4. Clear boundary note: **manager product** may later bind groups to `profileId`; this issue delivers **content**, not org-wide enforcement.
5. Agent/maintainer guidance: how to propose, review, and publish a profile without bypassing definition validation (`Test-PackageDefinitionCatalog`) or catalog trust.

### 🔎 Facts

Known:
- **`Invoke-Package` multi-root surface (verified):** `-DefinitionId` is `[string[]]` (mandatory). For `Assigned` / `-MaterializeOnly`, the command calls `New-PackageDependencyPlan` once for all roots, logs `[STEP] Planning package dependencies for N root definition(s).`, then iterates each root through `Invoke-PackageDefinitionCommandCore` with shared `DependencyPlan` + per-root `DependencyPlanNodeKey` (`Commands/Package/Eigenverft.Manifested.Package.Cmd.InvokePackage.ps1`).
- **`-PackageVersion` is global per call:** when specified, the same override applies to every root in that invocation (no per-definition version map on the command).
- **`-FailFast`:** stops after first non-Ready / non-Materialized result; default attempts every listed root.
- **Dependency planner (shipped schema 1.9):** `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1` expands `dependency.requires[]` from wire definitions, records violations (`DependencyConflict`, version-range issues, etc.), and is wired from `Invoke-Package` before any assign work runs.
- **Shipped catalog size:** **18** signed definitions under `Endpoint/Defaults/Eigenverft/` (all `schemaVersion: "1.9"`).
- **Shipped `dependency.requires` (non-empty) - 6 definitions:**

| DefinitionId | Requires (authored) |
| --- | --- |
| `CodexCli` | `VisualCppRedistributable` (>=14.0 <15.0), `NodeRuntime` (>=16.0.0) |
| `OpenCodeCli` | `NodeRuntime` (>=24.0.0) |
| `LlamaCppRuntime` | `VisualCppRedistributable` (>=14.0 <15.0) |
| `Qwen35_9B_Q6_K_Model` | `LlamaCppRuntime` (>=9094) |
| `PowerShellGet` | `PackageManagement` (>=1.4.4) |
| `EigenverftManifestedAgent` | `PowerShellGet` (>=2.2.5 <3.0.0) |

- **12 definitions** have `dependency.requires: []` (roots with no declared requires), including `PythonRuntime`, `GitRuntime`, `NodeRuntime`, `DotNetSdk10`, `SevenZip`, `PowerShell7`, `CursorCli`, etc.
- **Conflict policy (not requires):** `VSCodeRuntime` and `VSCodeUser` use `dependency.policy.conflictsWith` (mutual). `New-PackageDependencyPlan -DefinitionId VSCodeRuntime, VSCodeUser` is **rejected** with `DependencyConflict` (test: `Package.DiscoveryAndRemoval.Tests.ps1` - "ships Eigenverft dependency planner examples...").
- **Transitive expansion works without listing deps in a profile:** e.g. `New-PackageDependencyPlan -DefinitionId 'CodexCli'` yields child edges for `VisualCppRedistributable` and `NodeRuntime` with authored version ranges (same test file). Profile lists can therefore be **top-level roots only** if authors accept planner expansion.
- **README already models "profiles" informally:** Quick Start uses **4** ids (`SevenZip,DotNetSdk10,NodeRuntime,CodexCli`); Demo Commands use **13** ids in one `Invoke-Package` line (`README.md`). No named `profileId` or review metadata.
- **`Search-Package` is per-definition only:** each row's `InvokeCommand` is a **single** `-DefinitionId` string (optional `-PublisherId`); no multi-id or profile command (`Commands/Package/Eigenverft.Manifested.Package.Cmd.SearchPackage.ps1`).
- **Exported command surface:** **38** functions in `Eigenverft.Manifested.Package.psd1`; **none** named `*Onboarding*`, `*PackageProfile*`, or similar. Closest existing "profile" term: **`Get-PackageSigningProfile`** (catalog **signing** PFX/CER workflow in `Commands/Trust/Eigenverft.Manifested.Package.Cmd.PackageTrust.ps1`) - unrelated to onboarding DefinitionId bundles; Option B naming must avoid collision.
- **Agent authoring path today:** `Get-PackageDefinitionAuthoringGuide` + `AgentSkills/PackageDefinitionAuthoring.md` cover **package-definition** draft/validate/sign; **no** onboarding-profile section. "Profile" in authoring docs means **signing profile** (`Get-PackageSigningProfile`), not role bundles.
- **Validation surface:** `Test-PackageDefinitionCatalog` / `Package.DefinitionCatalogValidation.ps1` validate **package-definition JSON** under an endpoint scan root - not profile artifacts. Profile id validation in Option B would be a **new** read-only check (pattern exists; command does not).
- **State / inventory:** `PackageAssignmentInventory.json` tracks **per-definition** assignment facts via `Support/Package/State/` - no `profileId`, profile revision, or "assigned via profile" field.
- **Package-definition schema:** `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json` has `dependency` for definitions only - **no** onboarding-profile type on the wire (profiles should remain **sibling artifacts**, not entries inside definition JSON, for Option A).
- **Repo search:** no matches for `onboarding`, `OnboardingProfile`, or `PackageProfile` under `src/prj` (2026-06-07).
- **Catalog trust:** unchanged - per definition at `Invoke-Package` time via existing trust inventory / `catalogTrust` policy; profile name adds no trust dimension today.
- **`PRODUCT-BOUNDARY.md`:** fleet pin/rollout/reporting and cross-machine enforcement are Manager scope; local explicit `Invoke-Package` remains the engine action model.

Unknown:
- Whether teams prefer profiles on **git**, **team file share**, or **online endpoint** first.
- Whether example profiles should **omit** transitive deps (planner expands) or **document** expected expanded node set for reviewer clarity.
- Whether Option B command should be `Get-PackageOnboardingProfile` vs another name given `Get-PackageSigningProfile` exists.
- Exact JSON schema vs markdown-plus-front-matter for machine/agent consumption.

### Codebase reference (evaluation)

Use this table when scoring options - what exists vs what Option A/B/C would add.

| Area | Path / symbol | Today | Option A | Option B | Option C |
| --- | --- | --- | --- | --- | --- |
| Multi-assign entry | `Invoke-Package` | `[string[]] DefinitionId` + dependency plan | Unchanged; profile expands to same call | Unchanged; cmd emits invoke line | New `Invoke-PackageProfile` wrapper |
| Dependency expansion | `New-PackageDependencyPlan` | Shipped; tests for Codex/Qwen/VSCode conflict | Reuse as-is | Reuse for validation | Reuse internally |
| Discovery | `Search-Package` | Single-id `InvokeCommand` rows | No change | Optional list profiles separately | Could add profile search later |
| Definition validation | `Test-PackageDefinitionCatalog` | Endpoint `*.json` only | Manual review of profile lists | New profile reference check | Profile sign + validate |
| State | `PackageAssignmentInventory.json` | Per `DefinitionId` | No profile field | No profile field | Risk of profile fields creeping in |
| Schema wire | `eigenverft-module-package-definition-1.9.schema.json` | No profile object | No schema change | No schema change | Possible new profile schema |
| Docs / demos | `README.md` | Comma lists only | Named examples + invoke lines | Bundled profile files + cmd | Signed profile invoke |
| Agent skill | `PackageDefinitionAuthoring.md` | Definition authoring only | Add profile authoring section | Same + cmd docs | Sign/profile workflow |
| Tests to extend | `Package.DependencyPlanning.Tests.ps1` | Dependency plan fixtures | New profile list vs planner tests | Cmd + validation tests | Invoke wrapper + trust tests |

**Profile authoring constraints from shipped catalog (must respect in examples):**
- Do not combine `VSCodeRuntime` + `VSCodeUser` in one profile root list (planner conflict).
- Listing `CodexCli` alone is enough for planner to pull `NodeRuntime` + `VisualCppRedistributable`; duplicating those roots is optional redundancy, not required.
- `EigenverftManifestedAgent` pulls `PowerShellGet` -> `PackageManagement` chain when listed alone.

---

### 🧩 Options

#### Option A - Reviewable profile artifacts only (Reframed Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | closes naming and review gap for v1 |
| 🛠 Option Effort | 1/4 Trivial | ▰▱▱▱ | markdown/json examples plus boundary text |
| 🧠 Option Complexity | 2/5 Normal | ▰▰▱▱▱ | no runtime or trust model change |
| 🔮 Future Impact | 🟢 -1 Improves | ▰▰▱▱▱ | clean base for read cmd or manager |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | docs and files easy to revise |
| 🧬 Integration | 🟢 Compatible | - | matches agent-artifact engine boundary |
| 🤖 Agent Difficulty | 1/4 Routine | ▰▱▱▱ | mostly writing and example validation |
| 🧾 Agent Work | 📝 Writing / Docs | - | profiles as reviewable repo artifacts |

Description:
Reframe the issue from "add profile runtime" to "add **curated profile artifacts**." Ship a small profile file format (JSON or markdown with structured block), **two example profiles**, and a short authoring guide section (wrk or future hybrid docs). Operators and agents copy or script `Invoke-Package -DefinitionId ...` from the profile after review. **No new exported command**, no profile signing inventory, no `Invoke-PackageProfile` in v1. Trust remains on each definition at invoke time.

Current State:
Teams reuse README demo lines, private wikis, or ad-hoc scripts. Agents invent package sets per conversation without a stable team-owned artifact.

Resulting State:
Teams have versioned, reviewable profile files tied to roles. Onboarding is "pick profile X, run the documented invoke line." Engine behavior unchanged.

Solves:
- Role-based onboarding without fleet creep.
- Agent-scale catalog operations (propose profile PR, human review, publish).
- Manager-ready `profileId` references without building the manager now.

Leaves Open:
- No single command to load/display profiles from the module.
- No signed profile trust layer (inherits definition trust only).
- Org-wide mandatory profiles (Manager product).

Risks:
- Profiles drift from shipped definitions if not updated when catalog changes.
- Writable team shares could tamper with profile lists (mitigate with git review or read-only publish path).

Later Cost:
- Low if a future read command or manager references the same `profileId` and file shape.

---

#### Option B - Profile artifacts plus read-only discovery command (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | adds discoverability without new install path |
| 🛠 Option Effort | 2/4 Moderate | ▰▰▱▱ | schema, cmd, tests, bundled examples |
| 🧠 Option Complexity | 2/5 Normal | ▰▰▱▱▱ | read-only; invoke path unchanged |
| 🔮 Future Impact | 🟢 -1 Improves | ▰▰▱▱▱ | natural delegate target for manager later |
| ↩️ Reversibility | 🟡 Moderate | ▰▰▱▱ | public cmd and file shape harder to rename |
| 🧬 Integration | 🟢 Compatible | - | sits beside Search-Package read surfaces |
| 🤖 Agent Difficulty | 2/4 Guided | ▰▰▱▱ | bounded cmd with clear tests |
| 🧾 Agent Work | 💻 Local Code | - | read cmd plus validation of definition refs |

Description:
Deliver Option A artifact format and examples, plus an exported **read-only** command (e.g. `Get-PackageOnboardingProfile`) that loads profiles from a known module or endpoint path, validates that referenced `definitionIds` exist on enabled endpoints, and returns a ready `InvokeCommand` string. Still **no** `Invoke-PackageProfile` and **no** profile trust inventory - assignment stays explicit `Invoke-Package`.

Current State:
Same as Option A; no machine-discoverable profile list inside the module.

Resulting State:
Operators run one command to list or show a profile and copy the invoke line. Validation catches stale definition ids before assign.

Solves:
- Everything Option A solves, plus lower friction for Gallery-only users once bundled under `Docs/` or module data files.

Leaves Open:
- Signed profiles and org policy (Manager).
- Whether profiles live in module package vs team endpoint only.

Risks:
- Premature API surface if file format is still unstable.
- Duplication with future hybrid docs opener command unless paths are coordinated.

Later Cost:
- Moderate if profile format changes after public export.

---

#### Option C - Signed profiles with Invoke-PackageProfile (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | first-class profile install surface |
| 🛠 Option Effort | 3/4 Substantial | ▰▰▰▱ | schema, signing, cmd, trust rules, tests |
| 🧠 Option Complexity | 4/5 Hard | ▰▰▰▰▱ | parallel trust story to catalog |
| 🔮 Future Impact | 🟠 +1 Adds Debt | ▰▰▰▰▱ | profile trust may overlap manager scope |
| ↩️ Reversibility | 🟠 Hard | ▰▰▰▱ | new trust and invoke contract |
| 🧬 Integration | 🟡 Temporary | - | risks engine becoming policy layer |
| 🤖 Agent Difficulty | 3/4 Strong | ▰▰▰▱ | trust and signing need human review |
| 🧾 Agent Work | 🔌 Integration | - | new invoke and validation path |

Description:
Profiles become signed JSON (or signed documents) with their own validation and an `Invoke-PackageProfile -ProfileId` command that expands to `Invoke-Package` internally. Introduces profile-level trust questions (who may publish profiles, tamper detection on writable shares). Targets enterprises that want one named install surface.

Current State:
Trust and signing are definition-scoped only.

Resulting State:
Named profile invoke with profile signature checks before assignment.

Solves:
- Strong tamper resistance for profile lists on writable shares.
- Single named entry point for role setup.

Leaves Open:
- Org-wide mandate and drift still need Manager.
- Overlap with catalog trust and publisher inventory rules.

Risks:
- Second trust system beside package-definition trust.
- Slips toward fleet/policy product inside the engine.
- High authoring and migration cost for little gain at 18-definition scale.

Later Cost:
- Likely rework when Manager defines profile policy binding.

---

#### Option D - Defer profiles to Manifested Manager only (Reject Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🔴 Reject | ▱▱▱▱▱ | closes engine-side profile work entirely |
| 🛠 Option Effort | 0/4 N/A | ▱▱▱▱ | no delivery in this product |
| 🧠 Option Complexity | 1/5 Simple | ▰▱▱▱▱ | avoids boundary debate by waiting |
| 🔮 Future Impact | 🟠 +1 Adds Debt | ▰▰▰▰▱ | solo and isolated teams wait years |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | can reopen when manager exists |
| 🧬 Integration | 🔴 Conflicting | - | manager not shipped; content gap remains |
| 🤖 Agent Difficulty | 1/4 Routine | ▰▱▱▱ | no work now |
| 🧾 Agent Work | 🧩 Planning / Structuring | - | defer only |

Description:
Do not add profiles in the package engine or catalog layer. Wait until the **Manifested Manager** product owns role templates, org policy, and rollout. Teams continue using wiki lists and raw `Invoke-Package` until then.

Current State:
No profile artifacts.

Resulting State:
Unchanged until a separate manager product ships.

Solves:
- Avoids any engine scope creep toward fleet features.

Leaves Open:
- Team and agent onboarding curation for years.
- Isolated networks and small teams without manager deployment.
- Stable `profileId` for future manager to reference.

Risks:
- Manager inherits undefined profile content model.
- Agent onboarding stays conversational and non-repeatable.

Later Cost:
- Manager must invent profile format under time pressure.

---

### 💶 Value Assessment

- 💎 Value Type: 🧲 Adoption / Retention Improved · 🧭 User Experience Improved · 🔁 Rework Avoided
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Gives teams and agents a stable, reviewable layer between "role intent" and `Invoke-Package`, without adding fleet orchestration or a second trust system. Reduces repeated guessing of DefinitionId sets and prepares a `profileId` reference for a future Manager product.
- ⚖️ Option Value Summary:
  - Option A - Reviewable profile artifacts only (Reframed Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Best v1 value/effort; manager can reference same artifacts later.
  - Option B - Profile artifacts plus read-only discovery command (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Worth it after Option A format proves stable; coordinate with hybrid docs.
  - Option C - Signed profiles with Invoke-PackageProfile (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▰▱
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Over-built for current scale; profile trust duplicates definition trust.
  - Option D - Defer profiles to Manifested Manager only (Reject Option)
    - 🧭 Resolution: 🔴 Reject ▱▱▱▱▱
    - 🛠 Option Effort: 0/4 N/A ▱▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▰▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Protects engine scope but leaves teams and agents without a content model.
- ✅ Good Result: A new team member or agent can pick a named role profile, see which packages it includes and why, run documented `Invoke-Package` after review, and a future Manager can reference the same `profileId` without redefining content.

---

### 🏁 Recommendation

- [2026-06-07 18:00 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Option A delivers the real gap (named, reviewable DefinitionId bundles) without a second trust system or fleet-like invoke surface. Option B is a sensible follow-up once the artifact shape is stable and hybrid docs packaging is clearer. Option C front-loads profile signing and `Invoke-PackageProfile` before teams prove they need more than definition-level trust. Option D correctly protects engine scope but wrongly delays **content** that the Manager will need anyway - profile **policy** is manager work; profile **recipes** belong in catalog/docs now.

Required Checks:
- Run `New-PackageDependencyPlan -DefinitionId <profile-roots>` for each example profile and confirm `Accepted -eq $true` (mirror `Package.DependencyPlanning.Tests.ps1` Codex/Qwen patterns).
- Confirm no example profile lists both `VSCodeRuntime` and `VSCodeUser` (conflict test exists in same file).
- Walk generated `Invoke-Package -DefinitionId ...` on a test machine or fixture; compare `[STATE] Dependency plan approved...` node/edge counts when roots include `CodexCli` or `Qwen35_9B_Q6_K_Model`.
- Confirm listed ids exist under `Endpoint/Defaults/Eigenverft/` and pass `Test-PackageDefinitionCatalog` for the module endpoint root.
- Record profile file format in **Resolved Decisions** before authoring more than two examples.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🧑‍💼 Product Management · 🔧 Engineering · 👥 Customer / User Representative
- 🗣 Communication Lens: 🧑‍💼 Product Summary
- 📬 Success Note: Teams can onboard developers with named role profiles instead of memorizing raw package ids. Each profile is a reviewable list that still installs through the same trusted `Invoke-Package` command. Org-wide enforcement remains a future manager concern; this release improves clarity and repeatability for team-owned setups.

### ✅ Resolved Decisions

- **Profile content vs profile policy** - profile **content** (DefinitionId bundles) is in scope for this product layer; org-wide **mandate, rollout, and drift reporting** belong to the future Manager product ([PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md)).
- **Execution** - v1 assigns through explicit `Invoke-Package`; no `Invoke-PackageProfile` or background profile application in Option A.
- **Trust** - v1 inherits **per-definition** catalog trust at invoke time; no separate `PackageProfileTrustInventory` in Option A.
- **Agent model** - agents propose profile artifacts; humans review; engine executes trusted definitions only ([IDEA-AGENT-SCALES-PRODUCT.md](IDEA-AGENT-SCALES-PRODUCT.md)).

### ❓ Open Decisions

- JSON vs markdown-with-structure for the profile artifact format?
- Should profiles list transitive dependencies explicitly or only top-level `definitionIds`?
- Store v1 examples in repo `wrk/`, future `Docs/Guide/`, or team endpoint path convention?
- Trigger for Option B: after hybrid docs ship, or earlier as standalone command?

### 🚫 Out of Scope

- Fleet-wide profile assignment, hold, skip, rollout, or compliance dashboards (Manager product).
- Background auto-apply of profiles without explicit `Invoke-Package`.
- Separate profile signing/trust inventory (Option C - deferred unless explicitly reopened).
- Changing package definition schema or dependency planner semantics.
- `Search-Package` assigned-state enrichment (optional future extracted work).

### 🌱 Extracted Work

Optional:
- [ ] **Read-only `Get-PackageOnboardingProfile` command** (Option B)
  Reason: After artifact format stabilizes; improves Gallery-only discoverability alongside hybrid docs.
- [ ] **Signed `Invoke-PackageProfile` and profile trust** (Option C)
  Reason: Only if writable-share tampering or compliance requires profile-level signatures beyond definition trust.
- [ ] **Manager profile policy binding**
  Reason: Separate Manifested Manager product; references `profileId` from artifacts defined here.

---
