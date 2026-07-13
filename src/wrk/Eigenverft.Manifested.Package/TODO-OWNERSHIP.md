# TODO OWNERSHIP

Design scratchpad for the **ownership and installer adoption guide** - learnability for `ownershipPolicy`, existing-install discovery, and log-line mapping for **Eigenverft.Manifested.Package**.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.8): rating and option-profile tables with short rationales; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against the repo on **2026-05-30**.

Open issues in this file are scheduled here. **No engine changes are implied by this file alone** unless an issue states otherwise.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| Hybrid documentation (maintainer chapter home) | [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) |
| Catalog validation warnings | Future `Test-PackageDefinitionCatalog` ownership-policy rules |
| Agent authoring skill | Shipped `Get-PackageDefinitionAuthoringGuide` / `PackageDefinitionAuthoring.md` |

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 3/7 - Low**

---
---
## 📌 Publish ownership and installer adoption guide (runtime already exists)

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | learnability issue can wait safely |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | guide and schema text, no engine rewrite |
| 🧠 Complexity | 2/5 Normal | ▰▰▱▱▱ | policy matrix needs careful wording |
| 🌍 Benefit | 1/4 Producer | ▰▱▱▱ | mainly authors and maintainers benefit |
| 📦 Shape | 1/4 Focused | ▰▱▱▱ | one guide plus examples |
| 🎯 Quality | 🧭 Usability | - | makes ownership rules easier to use |
| 🚧 Readiness | 🟢 Ready | - | runtime facts are verified |

### 📝 Statement

`ownershipPolicy`, existing-install discovery, and `[DECISION]` logging already implement reuse, adoption, replace, and ignore paths. The gap is learnability: policies differ across **18** shipped definitions, only **SevenZip** uses `msiInstaller`, and there is no single author/operator guide tying schema fields to log lines and `Assigned.Status`.

Original report:

> Make installer adoption and removal rules obvious so already-installed tools can be reused without surprising first-call removals.

### 🧭 Related Context

Related Issues:
- `Test-PackageDefinitionCatalog` (optional future warnings for ambiguous `ownershipPolicy` combinations).
- [`TODO-DOCUMENTATION.md`](TODO-DOCUMENTATION.md) (natural home for a maintainer-facing guide).

Affected Areas:
- `eigenverft-module-package-definition-1.9.schema.json` descriptions; shipped definitions under `Endpoint/Defaults/Eigenverft/`; assign/remove help text.

May Influence:
- Future MSI/desktop definitions beyond SevenZip and NotepadPlusPlus (`nsisInstaller`).

Dependencies:
- None known.

### 🎯 Required Outcome

A published guide (plus schema descriptions or examples) explains when `allowAdoptExternal`, `upgradeAdoptedInstall`, and `requirePackageOwnership` apply; maps them to `[DECISION]` / `[OUTCOME]` / `Assigned.Status`; and documents removal boundaries (package-owned vs external). No requirement to rewrite assign/remove engines unless the guide exposes a real bug.

### 🔎 Facts

Known:
- **Wire 1.9** defines `packageOperations.policy.ownershipPolicy` (`allowAdoptExternal`, `upgradeAdoptedInstall`, `requirePackageOwnership`) in `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json`.
- **Shipped installer kinds (verified 2026-05-30):** **SevenZip** - `msiInstaller` / `msiUninstaller`; **NotepadPlusPlus** - `nsisInstaller` only. No other shipped definition uses `msiInstaller`.
- **Adoption policy split (verified):** `allowAdoptExternal: true` on **7** definitions (SevenZip, VSCodeUser, VSCodeRuntime, NotepadPlusPlus, PackageManagement, PowerShellGet, EigenverftManifestedAgent); **false** on the other **11**.
- **Runtime:** `Resolve-PackageExistingPackageDecision` emits `[DECISION]` reuse/adopt/replace/ignore messages (`Package.Install.Existing.ps1`); MSI/NSIS install engines exist (`Package.Install.InstallerEngine.ps1`).
- **Tests:** `Package.Definitions.Tests.ps1` (SevenZip MSI shape); `Package.OwnershipLifecycle.Tests.ps1` (adopt/reuse/replace decisions).

Unknown:
- Author-facing schema descriptions vs JSON property names - whether agents/operators get enough guidance without reading tests and shipped JSON.
- Per-kind policy matrix for future MSI/desktop packages beyond SevenZip.

---

### 🧩 Options

#### Option A - Guide + schema descriptions (no engine change) (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | closes the documentation gap |
| 🛠 Option Effort | 2/4 Moderate | ▰▰▱▱ | guide, schema descriptions, examples |
| 🧠 Option Complexity | 2/5 Normal | ▰▰▱▱▱ | known runtime behavior needs mapping |
| 🔮 Future Impact | 🟢 -1 Improves | ▰▰▱▱▱ | improves author policy choices later |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | docs can be revised |
| 🧬 Integration | 🟢 Compatible | - | matches existing runtime |
| 🤖 Agent Difficulty | 2/4 Guided | ▰▰▱▱ | docs need source-backed wording |
| 🧾 Agent Work | 📝 Writing / Docs | - | guide and schema descriptions |

Description:
Add a maintainer guide (likely in `TODO-DOCUMENTATION.md` or wrk docs) with a scenario table: preinstalled 7-Zip, VS Code adopt, MSI install/remove, `requirePackageOwnership`, version replace. Extend JSON schema descriptions for `ownershipPolicy` and point SevenZip/VSCodeUser as canonical examples. Matches current code; no assign/remove rewrite.

Current State:
Behavior and wire schema exist; documentation does not connect policy fields to runtime messages.

Resulting State:
Authors and operators have one guide aligned with wire 1.9 and shipped examples; runtime unchanged unless guide finds bugs filed separately.

Solves:
- Closes the original "obvious rules" ask without risky behavior changes.

Leaves Open:
- Ambiguous definitions still install until validation issue adds warnings.

Risks:
- Guide drifts if engine messages change without doc updates.

Later Cost:
- Low if guide references stable `ExistingPackage.Decision` / `Assigned.Status` values.

---

#### Option B - Guide plus catalog validation warnings (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | adds automated mistake checks |
| 🛠 Option Effort | 3/4 Substantial | ▰▰▰▱ | guide plus catalog linting rules |
| 🧠 Option Complexity | 2/5 Normal | ▰▰▱▱▱ | rules across definitions need tuning |
| 🔮 Future Impact | 🟢 -1 Improves | ▰▰▱▱▱ | catches mistakes before install |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | warnings can be tuned |
| 🧬 Integration | 🟢 Compatible | - | extends existing catalog test |
| 🤖 Agent Difficulty | 2/4 Guided | ▰▰▱▱ | validation rules need review |
| 🧾 Agent Work | 🧠 System Logic | - | lints ownership policy choices |

Description:
Deliver Option A, then add pre-install validation rules to `Test-PackageDefinitionCatalog` (for example `allowAdoptExternal: false` with `existingInstall.enabled: true` and no `requirePackageOwnership`). Catches author mistakes earlier; more implementation than docs alone.

Current State:
`Test-PackageDefinitionCatalog` covers schema, trust, and static dependency references; ownership combinations are not linted.

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

### 💶 Value Assessment

- 💎 Value Type: 🧭 User Experience Improved · 🛟 Support Effort Reduced
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Connects existing runtime behavior to learnable policy guidance for **18** heterogeneous definitions; reduces mistaken policies and support threads without changing assign/remove engines.
- ⚖️ Option Value Summary:
  - Option A - Guide + schema descriptions (no engine change) (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Closes learnability gap without engine risk; leaves ambiguous definitions without automated warnings.
  - Option B - Guide plus catalog validation warnings (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Agent Work: 🧠 System Logic
    - 🧾 Decision Note: Best mistake prevention with substantial effort; primary home is catalog-validation work.
- ✅ Good Result: Authors and operators predict reuse/adopt/replace/remove from schema fields without reading install engine source.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Enforcement already exists in install/ownership engines; the gap is author/operator learnability. Option B belongs as a later `Test-PackageDefinitionCatalog` rule extension, not as a prerequisite for the guide.

Required Checks:
- Walk through SevenZip assign with a preinstalled 7-Zip and confirm guide text matches `[DECISION]` and `Assigned.Status` output.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 🛟 Support / Customer Success
- 🗣 Communication Lens: 🧑‍💼 Product Summary
- 📬 Success Note: Ownership and installer adoption rules are documented with examples tied to real log lines and statuses. Runtime behavior is unchanged; authors can choose policies confidently. Optional validation remains a separate catalog-quality issue.

### ❓ Open Decisions

- Guide location (`TODO-DOCUMENTATION.md` vs wrk-only doc)?
- Track Option B validation separately or as extracted work from this issue?

### 🚫 Out of Scope

- Rewriting `Resolve-PackageExistingPackageDecision` or MSI/NSIS engines (already implemented).
- Non-Windows installer ecosystems unless a shipped definition requires them.
- Runtime dependency planning and schema 1.9 dependency policy.

### 🌱 Extracted Work

Optional:
- [ ] Catalog validation for ambiguous `ownershipPolicy` combinations
  Reason: Option B scope; implement as future `Test-PackageDefinitionCatalog` rules.

---
---
