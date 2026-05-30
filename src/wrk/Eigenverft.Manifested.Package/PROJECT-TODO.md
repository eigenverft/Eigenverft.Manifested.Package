# PROJECT TODO

Open work for **Eigenverft.Manifested.Package** (`src/prj/Eigenverft.Manifested.Package`). Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.1). Facts re-verified against the repo on **2026-05-30**.

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 3/6 — Normal**

---
---

## 📌 Record discovery model for search, manifest, and HTTPS catalog

- 🏷 Rating
  - 🚦 Priority: 3/6 Normal ▰▰▰▰▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🔁 Data / Compatibility
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

Future package search must work for both small and large catalogs. Today definitions are found only by known `DefinitionId` on `Invoke-Package` or by manually browsing endpoint folders. The design is unresolved: live endpoint scan at query time, a maintained index/manifest, or different rules by catalog size.

### 🧭 Related Context

Related Issues:
- Define catalog manifest contract (Priority 5/6 — Blocked on this decision).
- Implement `httpsCatalog` endpoint kind (Priority 5/6 — Blocked on this decision).

Affected Areas:
- Package endpoint discovery; future search command surface.

May Influence:
- [`TODO-COMMANDS.md`](TODO-COMMANDS.md) search design.

Dependencies:
- Catalog scale and HTTPS v1 scope must be documented in this issue before manifest or HTTPS implementation proceeds.

### 🎯 Required Outcome

A short decision record (in this issue or linked doc) states: default discovery for v1 search, whether a manifest is required before `httpsCatalog`, and sequencing for the Priority 5/6 manifest and HTTPS issues plus a future search cmdlet ([`TODO-COMMANDS.md`](TODO-COMMANDS.md)).

### 🔎 Facts

Known:
- **Endpoint kinds implemented today:** `moduleLocal` and `filesystem` resolve and scan; `httpsCatalog` throws from `Resolve-PackageEndpointRootPath` with *reserved for future support and is not implemented yet* (`Support/Package/Schema/...Package.EndpointInventory.Management.ps1`).
- **Default inventory** (`Configuration/Internal/PackageEndpointInventory.json`): enabled `moduleDefaults` (`moduleLocal`, `Endpoint/Defaults`); sample `corpPackageEndpoint` (`filesystem`, `\\\\corp-share\\PackageEndpoint`) is **disabled**.
- **Shipped catalog size (verified 2026-05-30):** **18** signed definition JSON files under `Endpoint/Defaults/Eigenverft/`, all **`schemaVersion` 1.8**.
- **Discovery today:** `Invoke-Package` loads definitions via `Get-PackageDefinitionJsonPathsUnderDirectory` → `Select-PackageDefinitionCandidatesFromEndpointScanRoot` per enabled endpoint (`Package.DefinitionReference.ps1`); trust/signature checks apply on load.
- **No search cmdlet:** confirmed in [`TODO-COMMANDS.md`](TODO-COMMANDS.md) — no `Search-Package` / `Find-PackageDefinition`.
- **HTTPS catalog and manifest** remain backlog (Priority 5/6); no manifest document type or parser exists in code yet.

Unknown:
- Expected definition counts for the first real team/corp `filesystem` or future `httpsCatalog` endpoint (only the disabled sample path exists in shipped inventory).
- Whether search must ship before `httpsCatalog` (product sequencing, not enforced in code).

---

### 🧩 Options

#### Option A — Decision: live scan for v1 search and HTTPS

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Record that v1 **search** and **httpsCatalog** may reuse today’s recursive `*.json` scan (same as `Invoke-Package` discovery). Defer manifest design until a defined scale threshold or HTTPS pain appears. Fastest path for the current **18**-definition module catalog; accept rework if team endpoints grow large.

Current State:
No search cmdlet. Enabled `moduleDefaults` scans 18 local definitions; `httpsCatalog` and manifest are unimplemented. No decision record ties search to manifest or HTTPS sequencing.

Resulting State:
A future search command walks endpoint paths at query time. Small catalogs work without a manifest. Large or remote catalogs may still need a later manifest-backed design.

Solves:
- Simple mental model for authors and operators on small catalogs.
- No manifest design prerequisite for a first search version.

Leaves Open:
- Large or remote catalogs may be slow or impractical.
- Manifest and HTTPS work may need a second search design pass.

Risks:
- Search behavior may need rework when catalog scale grows.

Later Cost:
- A manifest-backed model may replace or complement live scan later.

---

#### Option B — Decision: manifest before HTTPS catalog and search

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Record that manifest contract must be designed **before** `httpsCatalog` implementation and before a search cmdlet that must scale. Live scan remains only for `moduleLocal` / small filesystem roots. Aligns the two Priority 5/6 backlog issues but delays any search cmdlet until manifest work is scheduled.

Current State:
Manifest shape is undefined; HTTPS catalog and search backlog depend on an unresolved default discovery model.

Resulting State:
Manifest shape is defined first; HTTPS catalog and search read from the index. Live scan may remain only for tiny endpoints. Search, manifest, and large-catalog discovery share one contract.

Solves:
- Aligns search, manifest backlog, and large-catalog discovery in one design thread.
- Reduces risk of shipping search that HTTPS catalogs cannot use.

Leaves Open:
- Slower time to any search command.
- Rules for endpoints without a manifest still need writing.

Risks:
- Manifest design delays all dependent backlog items.

Later Cost:
- Lower rework if large catalogs are the main target.

---

#### Option C — Spike scale assumptions, then record A or B

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
Gather facts first (target definition counts for first team/corp/`httpsCatalog` endpoint, acceptable scan latency), then write the decision record choosing Option A or B. No search cmdlet, manifest parser, or HTTPS transport in this issue.

Current State:
Search/discovery model is unresolved; manifest and HTTPS backlog items depend on unstated assumptions about default discovery.

Resulting State:
A decision note records expected catalog sizes, manifest requirement for HTTPS v1, and v1 search model. Follow-up implementation issues for Option A or B proceed with an explicit chosen path.

Solves:
- Replaces assumptions with explicit facts and a single decision record.
- Unblocks manifest and HTTPS issues that currently depend on this choice.

Leaves Open:
- No user-visible search until a separate implementation issue ships.

Risks:
- One refinement step before any search code.

Later Cost:
- Low if the note is concrete enough to open focused implementation issues.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Prefer Option C | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Only **18** definitions ship today on a single enabled `moduleLocal` endpoint; `httpsCatalog` still throws at resolve time. Option C records scale targets before committing. Option A fits if the first team endpoint stays under a few hundred definitions; Option B if a large HTTPS catalog is imminent.

Required Checks:
- Confirm expected definition counts for the first HTTPS catalog target.
- Record the decision under **✅ Resolved Decisions** before manifest or HTTPS implementation starts.

### ❓ Open Decisions

- Default model for v1 search?
- Is manifest a prerequisite for HTTPS catalog, search, or both?

### 🚫 Out of Scope

- Implementing `Search-Package` in this issue.

### 🌱 Extracted Work

Required:
- [ ] Implement package search command
  Reason: Separate delivery issue after this decision issue closes; different effort, acceptance criteria, and rating.

Optional:
- [ ] Catalog discovery manifest for large endpoints
  Reason: Already tracked under Priority 5/6; sequence with this decision, do not duplicate unless split is required.

**Priority 4/6 — Low**

---
---

## 📌 Publish ownership and installer adoption guide (runtime already exists)

- 🏷 Rating
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 1/4 Producer ▰▱▱▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

`ownershipPolicy`, existing-install discovery, and `[DECISION]` logging already implement reuse, adoption, replace, and ignore paths. The gap is learnability: policies differ across **18** shipped definitions, only **SevenZip** uses `msiInstaller`, and there is no single author/operator guide tying schema fields to log lines and `Assigned.Status`.

Original report:

> Make installer adoption and removal rules obvious so already-installed tools can be reused without surprising first-call removals.

### 🧭 Related Context

Related Issues:
- [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) (optional warnings for ambiguous `ownershipPolicy` combinations).
- [`TODO-DOCUMENTATION.md`](TODO-DOCUMENTATION.md) (natural home for a maintainer-facing guide).

Affected Areas:
- `eigenverft-module-package-definition-1.8.schema.json` descriptions; shipped definitions under `Endpoint/Defaults/Eigenverft/`; assign/remove help text.

May Influence:
- Future MSI/desktop definitions beyond SevenZip and NotepadPlusPlus (`nsisInstaller`).

Dependencies:
- None known.

### 🎯 Required Outcome

A published guide (plus schema descriptions or examples) explains when `allowAdoptExternal`, `upgradeAdoptedInstall`, and `requirePackageOwnership` apply; maps them to `[DECISION]` / `[OUTCOME]` / `Assigned.Status`; and documents removal boundaries (package-owned vs external). No requirement to rewrite assign/remove engines unless the guide exposes a real bug.

### 🔎 Facts

Known:
- **Wire 1.8** defines `packageOperations.policy.ownershipPolicy` (`allowAdoptExternal`, `upgradeAdoptedInstall`, `requirePackageOwnership`) in `Support/Package/Schema/eigenverft-module-package-definition-1.8.schema.json`.
- **Shipped installer kinds (verified 2026-05-30):** **SevenZip** — `msiInstaller` / `msiUninstaller`; **NotepadPlusPlus** — `nsisInstaller` only. No other shipped definition uses `msiInstaller`.
- **Adoption policy split (verified):** `allowAdoptExternal: true` on **7** definitions (SevenZip, VSCodeUser, VSCodeRuntime, NotepadPlusPlus, PackageManagement, PowerShellGet, EigenverftManifestedAgent); **false** on the other **11**.
- **Runtime:** `Resolve-PackageExistingPackageDecision` emits `[DECISION]` reuse/adopt/replace/ignore messages (`Package.Install.Existing.ps1`); MSI/NSIS install engines exist (`Package.Install.InstallerEngine.ps1`).
- **Tests:** `Package.ConfigAndDefinitions.Tests.ps1` (SevenZip MSI shape); `Package.AcquisitionAndOwnership.Tests.ps1` (adopt/reuse/replace decisions).

Unknown:
- Author-facing schema descriptions vs JSON property names — whether agents/operators get enough guidance without reading tests and shipped JSON.
- Per-kind policy matrix for future MSI/desktop packages beyond SevenZip.

---

### 🧩 Options

#### Option A — Guide + schema descriptions (no engine change)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Add a maintainer guide (likely in `TODO-DOCUMENTATION.md` or wrk docs) with a scenario table: preinstalled 7-Zip, VS Code adopt, MSI install/remove, `requirePackageOwnership`, version replace. Extend JSON schema descriptions for `ownershipPolicy` and point SevenZip/VSCodeUser as canonical examples. Matches current code; no assign/remove rewrite.

Current State:
Behavior and wire schema exist; documentation does not connect policy fields to runtime messages.

Resulting State:
Authors and operators have one guide aligned with wire 1.8 and shipped examples; runtime unchanged unless guide finds bugs filed separately.

Solves:
- Closes the original “obvious rules” ask without risky behavior changes.

Leaves Open:
- Ambiguous definitions still install until validation issue adds warnings.

Risks:
- Guide drifts if engine messages change without doc updates.

Later Cost:
- Low if guide references stable `ExistingPackage.Decision` / `Assigned.Status` values.

---

#### Option B — Guide plus catalog validation warnings

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Deliver Option A, then add pre-install validation rules (for example `allowAdoptExternal: false` with `existingInstall.enabled: true` and no `requirePackageOwnership`) per [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md). Catches author mistakes earlier; more implementation than docs alone.

Current State:
Validation covers schema and retired names; ownership combinations are not linted.

Resulting State:
Guide plus actionable validation messages before `Invoke-Package` mutates the machine.

Solves:
- Reduces surprising first-run behavior caused by definition mistakes.

Leaves Open:
- Legitimate edge cases may need allow-list rules in validation.

Risks:
- False positives until rules are tuned against all **18** shipped definitions.

Later Cost:
- Ongoing validation maintenance as new installer kinds ship.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Enforcement already exists in install/ownership engines; the gap is author/operator learnability. Option B belongs in [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) as follow-up, not as a prerequisite for the guide.

Required Checks:
- Walk through SevenZip assign with a preinstalled 7-Zip and confirm guide text matches `[DECISION]` and `Assigned.Status` output.

### ❓ Open Decisions

- Guide location (`TODO-DOCUMENTATION.md` vs wrk-only doc)?
- Track Option B validation separately or as extracted work from this issue?

### 🚫 Out of Scope

- Rewriting `Resolve-PackageExistingPackageDecision` or MSI/NSIS engines (already implemented).
- Non-Windows installer ecosystems unless a shipped definition requires them.
- Dependency resolver work ([`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md)).

### 🌱 Extracted Work

Optional:
- [ ] Catalog validation for ambiguous `ownershipPolicy` combinations
  Reason: Option B scope; track in [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md).

---
---

## 📌 Decide whether to keep `artifacts` / `targetArtifacts` vocabulary (wire 1.8)

- 🏷 Rating
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 1/4 Producer ▰▱▱▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🔁 Data / Compatibility
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

Wire **1.8** requires top-level `artifacts` and per-release `targetArtifacts` for all **18** shipped definitions. The naming works today; the open question is whether to keep this vocabulary through the next schema break or plan a rename before the catalog grows further.

### 🧭 Related Context

Related Issues:
- Schema migration delivery (only if rename is chosen later — separate rated issue).

Affected Areas:
- Package definition schema property `artifacts`.

May Influence:
- Future package kinds and agent-authored definitions.

Dependencies:
- None known.

### 🎯 Required Outcome

Recorded decision under **✅ Resolved Decisions**: keep `artifacts` + `targetArtifacts` until a future break, or choose replacement terms and target schema version — without implementing migration in this issue.

### 🔎 Facts

Known:
- **Authoring schema today:** wire **1.8** (`Support/Package/Schema/eigenverft-module-package-definition-1.8.schema.json`); all **18** shipped definitions use top-level **`artifacts`** plus per-release **`targetArtifacts`** (verified 2026-05-30).
- **Validation:** `artifactsByTarget` is rejected; authors must use `targetArtifacts` (`Package.DefinitionSchema.Wire1_8.ps1`).
- **Rename would touch** every shipped definition, schema, validation, acquisition helpers, and tests — not a single-property rename.
- Closed note *schema 1.6* is historical; shipped catalog is on **1.8** now.

Unknown:
- Which kinds (npm tarballs, MSI files, models, etc.) are hardest for new authors to map into `artifacts` / `targetArtifacts` without examples.
- Whether rename cost exceeds pain if deferred (depends on catalog growth rate).

---

### 🧩 Options

#### Option A — Keep `artifacts` for now

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟠 Hard
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Record that `artifacts` stays until a future breaking schema. Document why and what signals would trigger a rename review. This closes the naming question without a break and keeps one stable term for authors. Rename may be harder if the catalog grows large, and awkward naming may discourage clearer definitions for new kinds.

Current State:
Shipped definitions use `artifacts`; no recorded decision on keep vs rename as more package kinds appear.

Resulting State:
A decision record states `artifacts` stays until a future breaking schema, with signals to reopen the review. Vocabulary stays stable; no schema break now.

Solves:
- Closes the naming question without a break.
- Authors keep one stable term.

Leaves Open:
- Rename may be harder if the catalog grows large.

Risks:
- Awkward naming may discourage clearer definitions for new kinds.

Later Cost:
- A breaking rename may require migration tooling and author updates later.

---

#### Option B — Plan rename in the next breaking schema

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟠 Hard
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Choose the replacement term and migration story now; implement the rename only in the next planned schema break. This gives clear long-term vocabulary while keeping decision and implementation separable. Actual schema and definition migration remain separate delivery work. Coordinating the break with authors, agents, and shipped definitions is the main risk.

Current State:
Naming friction is known but replacement term and migration story are not chosen.

Resulting State:
Replacement term and migration story are documented; rename executes at the next planned schema break. Authors know target vocabulary before the break lands.

Solves:
- Clear long-term vocabulary for authors and agents.
- Decision and implementation stay separable.

Leaves Open:
- Actual schema and definition migration is separate delivery work.

Risks:
- Coordinating break with authors, agents, and shipped definitions.

Later Cost:
- Lower author confusion after migration completes.

---

#### Option C — Defer decision until a new kind blocks authoring

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Defer
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
Ship more kinds first, then rerun this review with concrete examples of where `artifacts` hurts. The decision is grounded in evidence rather than speculation. Naming may stay confusing meanwhile, and migration cost may rise if the catalog grows quickly. Authors and agents may learn a term that is later renamed.

Current State:
Naming works for current 18 definitions; friction is forward-looking as more acquisition shapes grow under the same `artifacts` + `targetArtifacts` vocabulary.

Resulting State:
More kinds ship first; this issue reopens with examples before keep, rename, or defer is decided again.

Solves:
- Decision grounded in evidence.

Leaves Open:
- Naming may stay confusing meanwhile.
- Migration cost may rise if the catalog grows quickly.

Risks:
- Authors and agents learn a term that is later renamed.

Later Cost:
- Same as Option A or B after review, possibly with higher migration cost.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
All **18** definitions already use the terms successfully; rename cost is high (schema, validation, acquisition, tests). Option B only if a schema break is already scheduled. Option C leaves agents without a recorded vocabulary decision.

Required Checks:
- Revisit if a new package kind cannot model its files clearly using `artifacts`.
- If Option B is chosen later, open a separate schema migration issue with its own rating.

### ❓ Open Decisions

- Record **Choose Option A** under **✅ Resolved Decisions**?
- If pain appears on a new kind, reopen for Option B rename planning.

### 🚫 Out of Scope

- Renaming unrelated schema fields in this issue.
- Implementing migration code in this issue.

**Priority 5/6 — Backlog**

*Context: **endpoints** discover signed package-definition JSON; **depots** supply artifact bytes. File-share channels exist; HTTP/HTTPS variants are backlog.*

---
---

## 📌 Define catalog manifest contract (blocked on discovery decision)

- 🏷 Rating
  - 🚦 Priority: 5/6 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🔁 Data / Compatibility
  - 🚧 Readiness: 🔴 Blocked

### 📝 Statement

When catalogs grow beyond small recursive scans, hosts need a manifest/index contract so clients do not fetch and verify every definition JSON individually. No manifest type or parser exists in the repo; this issue is **blocked** until Priority 3/6 records whether v1 requires a manifest.

### 🧭 Related Context

Related Issues:
- Record discovery model for search, manifest, and HTTPS catalog (Priority 3/6 — blocks this issue).
- Implement `httpsCatalog` endpoint kind (below).

Affected Areas:
- Future manifest document; endpoint discovery sequencing; trust order with signed definitions.

Dependencies:
- Priority 3/6 **✅ Resolved Decisions** entry on manifest requirement.

### 🎯 Required Outcome

Written manifest contract: file shape (or API), how entries reference definition paths or hashes, fetch order, and how existing trust/signing rules apply. Implementation remains separate issues.

### 🔎 Facts

Known:
- `httpsCatalog` is validated in inventory schema (`baseUri`, `catalogPath` required) but **`Resolve-PackageEndpointRootPath` throws** — not executable (verified 2026-05-30).
- `Get-PackageEndpointSummaries` marks `httpsCatalog` not effective (*reserved for future support*).
- **No manifest document type** or parser exists in the repository today.
- **Filesystem/moduleLocal discovery** scans all `*.json` under the endpoint root (acceptable for **18** local definitions; scaling concern is forward-looking).

Unknown:
- Manifest format (static index file vs generated API).
- Whether team `filesystem` endpoints at scale require a manifest even before HTTPS.

---

### 🧩 Options

#### Option A — Full manifest contract before HTTPS v1

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
After Priority 3/6 chooses manifest-first discovery, specify manifest file shape, entry references (path and/or hash), fetch order, and how signing/trust reuses today’s definition rules. Implementation stays in follow-up issues.

Current State:
No manifest type; HTTPS catalog blocked.

Resulting State:
Authors and implementers share one contract for large catalogs and `httpsCatalog`.

Solves:
- Aligns manifest issue, HTTPS endpoint, and future search on one index model.

Leaves Open:
- Parser, transport, and endpoint runtime work.

Risks:
- Design blocked until Priority 3/6 closes.

Later Cost:
- Lower rework for large remote catalogs.

---

#### Option B — Minimal index stub for HTTPS v1 only

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Document a thin manifest (definition id → relative path or URL) sufficient to bootstrap `httpsCatalog` without full search metadata. Expand when search ships.

Current State:
Same as Option A blocker.

Resulting State:
HTTPS v1 can list definitions without per-URL directory scan; search fields deferred.

Solves:
- Faster path to HTTPS if scan-only is rejected for remote roots.

Leaves Open:
- Search ranking, tags, and rich metadata.

Risks:
- Second manifest revision when search requirements land.

Later Cost:
- Possible manifest v2 when search is designed.

---

#### Option C — No manifest; defer contract until scale pain

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Defer
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Record “no manifest for v1” in Priority 3/6 and close this issue without a contract until catalog size or HTTPS latency forces one.

Current State:
Unresolved discovery model.

Resulting State:
Manifest issue dormant; live scan remains the only discovery path.

Solves:
- Avoids premature format design.

Leaves Open:
- Large-catalog and HTTPS performance risk.

Risks:
- HTTPS implementation may need redesign later.

Later Cost:
- Manifest design under pressure after HTTPS ships.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Needs More Facts | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
No manifest code exists; Priority 3/6 must record whether manifest is required before contract work starts. If manifest-first, prefer Option A; if HTTPS-only minimal index, Option B; if scan-only v1, Option C.

Required Checks:
- Priority 3/6 **✅ Resolved Decisions** records default discovery model and manifest requirement.

### ❓ Open Decisions

- Manifest required vs optional per endpoint kind?
- Single manifest vs per-catalog versioned manifests?

### 🚫 Out of Scope

- Implementing HTTPS transport in this issue.
- Full-text search ranking algorithms.

---
---

## 📌 Implement `httpsCatalog` endpoint kind (blocked)

- 🏷 Rating
  - 🚦 Priority: 5/6 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: ✨ Functionality
  - 🚧 Readiness: 🔴 Blocked

### 📝 Statement

Inventory already accepts `httpsCatalog` entries (`baseUri`, `catalogPath`), but `Resolve-PackageEndpointRootPath` **throws** and summaries mark them not effective. Team/Eigenverft catalogs over HTTPS are not reachable until this kind is implemented and discovery/manifest sequencing is decided.

### 🧭 Related Context

Related Issues:
- Record discovery model (Priority 3/6).
- Catalog manifest contract (above).

Affected Areas:
- `Package.EndpointInventory.Management.ps1`; `Package.DefinitionReference.ps1`; TLS/proxy configuration.

Dependencies:
- Priority 3/6 discovery decision; manifest contract if Option B path is chosen.

### 🎯 Required Outcome

Enabled `httpsCatalog` endpoints resolve definitions end-to-end with unchanged trust/signing behavior (`PackageTrustInventory.json`, `catalogTrust`). Discovery mechanism (scan vs manifest) matches the recorded Priority 3/6 decision.

### 🔎 Facts

Known:
- Same **`httpsCatalog` not implemented** behavior as manifest issue (`Resolve-PackageEndpointRootPath` throw; endpoint summary `Effective = false`).
- Inventory schema expects `baseUri` + `catalogPath` on `httpsCatalog` entries (`Package.EndpointInventory.Management.ps1`).
- **Trust/signing** for definitions is implemented (Closed 2026-05-27): signed JSON, `PackageTrustInventory.json`, `catalogTrust` policy.
- **Today’s catalog path** is `moduleLocal` + recursive JSON scan, not HTTPS.

Unknown:
- TLS and corporate proxy constraints for target environments.
- Whether v1 HTTPS requires a manifest or may use per-URL scan like filesystem endpoints.

---

### 🧩 Options

#### Option A — `httpsCatalog` v1 with live JSON scan (no manifest)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🔌 Integration

Description:
Implement resolve/fetch for `baseUri` + `catalogPath` and reuse recursive `*.json` discovery over the remote tree, mirroring filesystem behavior. Unblocks small HTTPS catalogs quickly.

Current State:
Inventory validates `httpsCatalog`; resolve throws.

Resulting State:
Enabled HTTPS endpoints work like remote filesystem scans with existing trust rules.

Solves:
- Earliest team HTTPS catalog without manifest design.

Leaves Open:
- Large-catalog performance; manifest later.

Risks:
- May not scale; rework if manifest is adopted.

Later Cost:
- Manifest-backed discovery may replace scan path.

---

#### Option B — `httpsCatalog` only after manifest contract

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟠 Hard
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🔌 Integration

Description:
Ship HTTPS endpoint resolution together with manifest fetch/parse so clients never enumerate every definition URL.

Current State:
Blocked on manifest contract and Priority 3/6 decision.

Resulting State:
HTTPS catalogs use index-first discovery aligned with search backlog.

Solves:
- One discovery model for large remote catalogs.

Leaves Open:
- Longer lead time; manifest contract must land first.

Risks:
- Schedule coupling between two backlog items.

Later Cost:
- Lower discovery rework at scale.

---

#### Option C — Keep stub; document inventory-only until decisions land

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Defer
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Leave runtime throw in place; update wrk docs so authors know `httpsCatalog` is schema-reserved only.

Current State:
Throws on resolve.

Resulting State:
No behavior change; expectations documented.

Solves:
- Zero implementation risk while decisions mature.

Leaves Open:
- No HTTPS catalog access.

Risks:
- Teams may assume inventory entry implies working endpoint.

Later Cost:
- None until A or B is chosen.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Needs More Facts | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Implementation is blocked until Priority 3/6 chooses scan-only (Option A) vs manifest-first (Option B). Inventory schema is prepared; runtime still throws today. Option C is status quo only.

Required Checks:
- Manifest contract issue and Priority 3/6 decisions recorded or explicitly deferred for scan-only v1.

### ❓ Open Decisions

- Ship HTTPS before manifest, after manifest, or minimal scan-only v1?

### 🚫 Out of Scope

- Writable or authenticated catalog publishing.
- Changing trust policy.

---
---

## 📌 Read-only HTTP/HTTPS package depots (not started)

- 🏷 Rating
  - 🚦 Priority: 5/6 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: ✨ Functionality
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

Central teams should host artifact bytes on HTTP(S) and have machines acquire them through depot inventory — distinct from per-definition `vendorDownload`. Today **only `kind: filesystem`** depots exist; `New-PackageFilesystemDepotSource` cannot create HTTP depots and there is no reserved stub like `httpsCatalog`.

### 🧭 Related Context

Related Issues:
- Depot folder hygiene checks (local filesystem depots only today).

Affected Areas:
- `PackageDepotInventory.json`; `Package.Source.ps1` acquisition; `Invoke-PackageDepotDistribution`.

May Influence:
- Offline policy vs `vendorDownload` in definitions.

Dependencies:
- Record minimum v1 fetch semantics in this issue before implementation.

### 🎯 Required Outcome

New read-only HTTP/HTTPS depot kind(s) in inventory schema and acquisition path: resolve URL, verify hash/signature per existing artifact rules, materialize like filesystem depot mirrors. Writable/auth depots remain out of scope.

### 🔎 Facts

Known:
- **Depot inventory today:** shipped `PackageDepotInventory.json` defines only **`kind: filesystem`** sources (`defaultPackageDepot`, optional site/corp paths).
- **Depot commands:** `Get-PackageDepot`, `Add-PackageDepot`, `Set-PackageDepot`, `Remove-PackageDepot`; `New-PackageFilesystemDepotSource` always writes `kind: filesystem`.
- **No HTTP/HTTPS depot kind** in code (unlike endpoints, there is no reserved `httpDepot` stub — non-filesystem depot kinds are not implemented).
- Assign/materialize flow can **mirror** verified files via `Invoke-PackageDepotDistribution` (filesystem paths only).
- Writable or authenticated mirroring remains out of scope for this issue.

Unknown:
- Caching, etag, range/partial-fetch, and auth requirements for the first internal HTTP(S) depot consumer.

---

### 🧩 Options

#### Option A — v1: full-file GET only (HTTPS, no auth)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🔌 Integration

Description:
Add `httpsDepot` (or similar) with anonymous GET of whole artifact files into staging/depot layout. Matches simplest internal mirror hosting; defer etag/range/auth.

Current State:
Only filesystem depots; acquisition copies local paths.

Resulting State:
Read-only HTTPS depot entries work for full-file artifacts; cache headers optional later.

Solves:
- Unblocks internal hosting without SMB.

Leaves Open:
- Large files, resume, authenticated edges.

Risks:
- May need breaking inventory shape change later for cache/auth.

Later Cost:
- Follow-up issue for etag/range if files are large.

---

#### Option B — Spike fetch requirements first

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
Interview first consumer (largest artifacts, proxy rules, auth) and document v1 minimum before choosing Option A scope or a richer v1.

Current State:
No recorded fetch contract.

Resulting State:
Written v1 requirements; implementation issue re-rated.

Solves:
- Avoids wrong v1 transport design.

Leaves Open:
- No HTTP depot until follow-up.

Risks:
- Delay if consumer already known.

Later Cost:
- Low.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Less coupled to catalog discovery than HTTPS endpoints, but depot acquisition is still greenfield. A short requirements note prevents locking the wrong v1 transport.

Required Checks:
- Identify first hosted artifact types (MSI, zip, npm tarball) and size range.

### ❓ Open Decisions

- Option A minimal GET vs etag/cache in v1?
- Separate `http` and `https` kinds or one kind with scheme in URL?

### 🚫 Out of Scope

- Writable or authenticated depot mirroring.
- Changing `vendorDownload` semantics in definitions.

---
---

## 📌 Add depot layout hygiene validation (filesystem depots)

- 🏷 Rating
  - 🚦 Priority: 5/6 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 1/4 Producer ▰▱▱▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 📡 Operability
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

`Invoke-PackageDepotDistribution` mirrors artifacts into writable depots, but nothing validates depot folders for incomplete downloads, stray sidecars, or stale layouts before acquisition fails with ambiguous errors.

### 🧭 Related Context

Related Issues:
- Read-only HTTP/HTTPS package depots (separate transport backlog).

Affected Areas:
- Depot folders; mirror reconcile; acquisition paths.

Dependencies:
- None known.

### 🎯 Required Outcome

Validation or maintenance tooling flags depot layout problems before ambiguous acquisition or mirror behavior.

### 🔎 Facts

Known:
- **Depot management commands** exist (`Cmd.PackageDepot.ps1`).
- **Mirror step in assign flow:** `[STEP] Reconciling package file depot mirrors` → `Invoke-PackageDepotDistribution` (copies verified artifacts to writable mirror targets).
- **`Test-PackageDepotDistributionFileMatches`** exists for mirror byte/compare during distribution (`Package.Source.ps1`) — not a layout or orphan-file validator.
- **No depot layout hygiene command** (no `Test-PackageDepotLayout`, incomplete-download detection, or stray sidecar rules).
- Default depot path pattern: `{applicationRootDirectory}/PkgDepot` (`PackageDepotInventory.json`).

Unknown:
- Which depot IDs/paths and artifact layouts the first validation pass should cover (default only vs site/corp paths).

---

### 🧩 Options

#### Option A — `Test-PackageDepot` maintainer cmdlet

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Add an on-demand validator (orphan files, incomplete temp names, expected mirror layout) operators run before troubleshooting acquisition.

Current State:
Failures surface late during assign/mirror.

Resulting State:
Explicit pass/fail with remediation hints; assign flow unchanged.

Solves:
- Clear depot hygiene without slowing every assign.

Leaves Open:
- Does not auto-repair depots.

Risks:
- Rule tuning against real depot layouts.

Later Cost:
- Ongoing rule maintenance as artifact kinds grow.

---

#### Option B — Warnings during `Invoke-PackageDepotDistribution`

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Emit warnings when mirror reconcile detects suspicious files; no separate command.

Current State:
Distribution only compares source/target pairs it knows about.

Resulting State:
Operators see hints during normal assign without a new cmdlet.

Solves:
- Surfaces problems in the common workflow.

Leaves Open:
- No standalone audit path.

Risks:
- Warning noise on legitimate partial mirrors.

Later Cost:
- May still need Option A for support scenarios.

---

#### Option C — Maintainer doc only (defer code)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Document expected depot folder layout and manual cleanup; no automated checks.

Current State:
Tribal knowledge only.

Resulting State:
Written expectations; ambiguous failures remain until code lands.

Solves:
- Fast, zero-risk guidance.

Leaves Open:
- No automated detection.

Risks:
- Doc drift from actual mirror behavior.

Later Cost:
- Option A or B still needed for enforcement.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Prefer Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Hygiene is operability for maintainers; a dedicated test command matches depot management commands and avoids warning spam on every assign. Option B is a reasonable add-on after Option A rules exist.

Required Checks:
- Sample default and corp depot layouts from a real assign run before locking rules.

### ❓ Open Decisions

- Option A only vs A plus B warnings?

### 🚫 Out of Scope

- Auto-deleting depot content without explicit maintainer action.
- HTTPS depot transport (separate backlog issue).

**Priority 6/6 — Polish**

---
---

## 📌 Fix ExecutionCore header comments (`ExecutionEngine` → `ExecutionCore`)

- 🏷 Rating
  - 🚦 Priority: 6/6 Polish ▰▱▱▱▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 1/5 Simple ▰▱▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 0/4 Atomic ▱▱▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

**Nine** of **15** `Support/ExecutionCore/*.ps1` modules still use the pre-rename layer label `ExecutionEngine` in their header comment while filenames and types use `ExecutionCore`. The other six headers already say `ExecutionCore`. No other retired **product** names were found in source grep; validation throws that mention “retired property” are intentional.

### 🧭 Related Context

None known.

### 🎯 Required Outcome

All ExecutionCore module headers say `ExecutionCore` consistently with filenames (nine remaining mismatches fixed).

### 🔎 Facts

Known:
- Public rename to **Eigenverft.Manifested.Package** completed (Closed 2026-05-24).
- **Verified 2026-05-30:** nine files under `Support/ExecutionCore/` still have header comments `Eigenverft.Manifested.Package.ExecutionEngine.*` (FileSystem, PathTemplate, Registry, SystemResources, Elevation, CommandResolution, Npm, PathRegistration, StandardMessage); six others already use `ExecutionCore` in the header (for example `ExecutionCore.Json.ps1`).
- **Not found in repo grep:** `Manifested.Tool`, `PackageRepository`, `EvfManifest` in source.

### 🚫 Out of Scope

- Changing validation messages that say “retired property” for old config/definition field names (intentional).
- Public command renames (completed under Closed rename work).

---
---

## 📌 Improve scannability of help, state output, and catalog docs

- 🏷 Rating
  - 🚦 Priority: 6/6 Polish ▰▱▱▱▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 1/5 Simple ▰▱▱▱▱
  - 🌍 Benefit: 2/4 Individual ▰▰▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

Operators still drill into nested objects: `Get-PackageState` returns raw records, cmdlet help is dense, and **18** definition JSON files are the main catalog reference. Polish should not change schema or lifecycle behavior.

### 🧭 Related Context

Related Issues:
- [`TODO-COMMANDS.md`](TODO-COMMANDS.md) (readable state tables and future search — related presentation goals).
- [`TODO-DOCUMENTATION.md`](TODO-DOCUMENTATION.md) (broader doc structure).

### 🎯 Required Outcome

Agreed surfaces use consistent list/table formatting; `Get-PackageState` default output is skimmable without `-Raw`; no behavior or schema changes.

### 🔎 Facts

Known:
- **`Get-PackageState`** is exported; returns counts and `PackageRecords` / `OperationRecords` objects — not formatted tables (`Cmd.GetPackageState.ps1`).
- **Help text** lives on cmdlets (for example `Invoke-Package`, `Get-PackageState`); repo root [`README.md`](../../../README.md) exists; no `README.md` under `src/prj/Eigenverft.Manifested.Package/`.
- **18** shipped definitions under `Endpoint/Defaults/Eigenverft/` are the main catalog content to keep readable.
- Polish only; no schema or lifecycle change intended.

Unknown:
- Which surfaces hurt most in practice (root README vs cmdlet help vs `Get-PackageState` default output vs definition JSON examples).

---

### 🧩 Options

#### Option A — `Get-PackageState` default view + cmdlet help

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Format default `Get-PackageState` output (table or summarized columns) and tighten `Invoke-Package` / `Get-PackageState` help examples. Keeps `-Raw` for automation. Highest daily-use impact per [`TODO-COMMANDS.md`](TODO-COMMANDS.md).

Current State:
`Get-PackageState` returns nested objects; help exists but is not optimized for scanning.

Resulting State:
Default state command is human-scannable; help examples match common troubleshooting flows.

Solves:
- Day-to-day operator readability.

Leaves Open:
- Root README and definition JSON layout unchanged.

Risks:
- Formatting choices may need iteration.

Later Cost:
- Low.

---

#### Option B — Root README + definition catalog presentation

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Improve repo [`README.md`](../../../README.md) package list / quick-start and add a wrk index of the **18** shipped definitions (tables, grouping by kind). Complements Option A; can ship in either order.

Current State:
README exists at repo root; no module-level README; definitions are raw JSON under `Endpoint/Defaults/`.

Resulting State:
New readers find packages without opening every JSON file.

Solves:
- Onboarding and catalog browsing.

Leaves Open:
- Command output polish (Option A).

Risks:
- README drifts from shipped definitions unless generated or checked in CI later.

Later Cost:
- Optional generated catalog index later.

---

#### Option C — One combined polish pass (A + B)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Ship Option A and B together in one review when scope stays cosmetic.

Current State:
Multiple weak reader surfaces.

Resulting State:
Command output and top-level docs both improved.

Solves:
- Single review for all polish surfaces.

Leaves Open:
- None for this issue’s scope.

Risks:
- Review breadth if unrelated files included.

Later Cost:
- Low.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Prefer Option C | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Both command output and README/catalog index help different readers; combined effort is still small. Option A alone if timeboxed.

Required Checks:
- List files touched in Facts before merge.

### ❓ Open Decisions

- Option C combined vs Option A first, README later?

### 🚫 Out of Scope

- New commands or schema fields.
- Search/discovery features.

---
---

## 📌 Clarify version-change and rerun story in `[OUTCOME]` and `PackageResult`

- 🏷 Rating
  - 🚦 Priority: 6/6 Polish ▰▱▱▱▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 1/5 Simple ▰▱▱▱▱
  - 🌍 Benefit: 2/4 Individual ▰▰▱▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

Rerun logging is **partially there**: `[DECISION]`, `[OUTCOME]`, and `Assigned.Status` already exist, and `Get-PackageOutcomeSummary` branches on `InstallOrigin` (reuse, adopt, fresh install, prerequisite paths). The gap is plain-language **version-change** vocabulary (upgrade, downgrade, replace, refused) — especially when `versionUpdatePolicy` replaces a package-owned install or throws on `fail`.

### 🧭 Related Context

Related Issues:
- [`TODO-COMMANDS.md`](TODO-COMMANDS.md) (readable run summaries / state display).

Affected Areas:
- `Get-PackageOutcomeSummary` in `Package.CommandFlow.ps1`; `Package.Install.Existing.ps1`; optional `PackageResult` summary property.

Dependencies:
- None known.

### 🎯 Required Outcome

After `Invoke-Package`, one log line and/or `PackageResult` field states the rerun category in plain language (including version bump/replace). No new cmdlet; extend existing messages only.

### 🔎 Facts

Known:
- **Flow:** `[OUTCOME]` from `Get-PackageOutcomeSummary` (switch on `InstallOrigin` with `existingDecision` on reuse/adopt paths); `[OK]` prints `InstallOrigin` + `InstallStatus` (`Package.CommandFlow.ps1`).
- **Fields:** `ExistingPackage.Decision`, `InstallOrigin`, `Assigned.Status` (`RepairedPackageOwnedInstall`, `ReusedPackageOwned`, etc. — `Package.AcquisitionAndOwnership.Tests.ps1`).
- **Version replace:** `[DECISION] Replacing Package-owned install...` when selected version changes; `onNewSelectedVersion: fail` throws.
- **`[OUTCOME]`** does not name *upgraded*, *downgraded*, or *version refused*; default branch still dumps raw field names.
- **`Get-PackageState`** does not surface last run outcome (operation history has `installOrigin` only).
- **Tests** do not lock `[OUTCOME]` wording.

Unknown:
- External parsers of `[OUTCOME]` / `[OK]` tokens (none found in tests).

---

### 🧩 Options

#### Option A — Extend `Get-PackageOutcomeSummary` only

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Extend `Get-PackageOutcomeSummary` with version-change branches (prior vs selected version, replace vs refuse) and plainer wording on the default path — without new `PackageResult` properties.

Current State:
`[OUTCOME]` covers reuse/adopt/install paths but not explicit version vocabulary.

Resulting State:
Console shows a clear rerun story without API shape changes.

Solves:
- Operator clarity on re-invoke.

Leaves Open:
- Programmatic consumers must parse logs, not `PackageResult`.

Risks:
- Longer log lines.

Later Cost:
- Low.

---

#### Option B — Add `PackageResult.RunSummary` (logs + object)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Add a stable string (or small object) on `PackageResult` mirrored in `[OUTCOME]` so scripts and [`TODO-COMMANDS.md`](TODO-COMMANDS.md) state formatting can use the same text.

Current State:
Consumers combine multiple fields manually.

Resulting State:
One field documents rerun category; log matches field.

Solves:
- Humans and scripts share one summary.

Leaves Open:
- `Get-PackageState` still historical unless separate issue extends it.

Risks:
- Public surface addition needs test coverage.

Later Cost:
- Low.

---

### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Option A is quickest; Option B aligns logs with structured output for future `Get-PackageState` polish. Neither requires engine rewrites.

Required Checks:
- Confirm no external tool depends on exact current `[OUTCOME]` format.

### ❓ Open Decisions

- Option A only vs Option B `RunSummary`?

### 🚫 Out of Scope

- New cmdlets; schema changes; rewriting adoption engines.

---

## Closed

- [P3] Rename - 2026-05-24: Completed repository and module surface rename to **Eigenverft.Manifested.Package**, including public command names, module metadata, local root default `Evf.Package`, and removal of obsolete launch-profile artifacts.
- [P1] Trust - 2026-05-27: Completed trust-only catalog model with signed definition JSON, embedded public certificate verification, `PackageTrustInventory.json` authority, `PackageConfig.catalogTrust` policy, default trust prompt for valid unknown embedded keys, `.cer` preseed import, and local `.catalog-signing.json` signing password descriptor.
- [P3] Tooling - 2026-05-23: Bumped package-definition schema to 1.6 for shipped definitions including SevenZip and DotNetSdk10.
- [P3] Tooling - 2026-05-23: Added managed **SevenZip** and **DotNetSdk10** package definitions.
- [P2] Tooling - 2026-05-22: Added package version selection, refreshed shipped definition versions, and resolved npm installs from materialized local tarballs.
- [P2] Architecture - 2026-05-16: Retired legacy package-definition schemas and completed endpoint naming cleanup.
- [P1] Trust - 2026-05-16: Added package publisher trust commands and inventory management.
- [P2] Architecture - 2026-05-14: Replaced package repository inventory with endpoint inventory; definitions are discovered by endpoint scan order.
- [P2] Tooling - 2026-05-11: Added package depot management, mirror reconcile, package assignment inventory, and operation history.
- [P2] Tooling - 2026-05-02: Established generic package command surface, depot support, readiness checks, and removal groundwork.
- [P3] Tooling - 2026-03-19: Added managed CLI runtimes and explicit managed npm proxy ownership.
- [P3] Tooling - 2026-03-13: Added managed Git, PowerShell, Node, Python, editor, CLI, and prerequisite package paths.
