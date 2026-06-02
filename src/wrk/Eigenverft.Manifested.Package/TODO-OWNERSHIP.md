# TODO OWNERSHIP

Design scratchpad for the **ownership and installer adoption guide** — learnability for `ownershipPolicy`, existing-install discovery, and log-line mapping for **Eigenverft.Manifested.Package**.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **Value Assessment** after Options with **Good Result**; **Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against the repo on **2026-05-30**.

Open issues in this file are scheduled here. **No engine changes are implied by this file alone** unless an issue states otherwise.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| Hybrid documentation (maintainer chapter home) | [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) |
| Catalog validation warnings | [TODO-CATALOG-VALIDATION.md](TODO-CATALOG-VALIDATION.md) |
| Agent authoring skill | [TODO-CATALOG-AGENT.md](TODO-CATALOG-AGENT.md) |

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

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

#### Option A — Guide + schema descriptions (no engine change) (Implementation Option)

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

#### Option B — Guide plus catalog validation warnings (Implementation Option)

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

### 💶 Value Assessment

- 💎 Value Type: 🧭 User Experience Improved · 🛟 Support Effort Reduced
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Connects existing runtime behavior to learnable policy guidance for **18** heterogeneous definitions; reduces mistaken policies and support threads without changing assign/remove engines.
- ⚖️ Option Value Summary:
  - Option A — Guide + schema descriptions (no engine change) (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Closes learnability gap without engine risk; leaves ambiguous definitions without automated warnings.
  - Option B — Guide plus catalog validation warnings (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Agent Work: 🧠 System Logic
    - 🧾 Decision Note: Best mistake prevention with substantial effort; primary home is catalog-validation work.
- ✅ Good Result: Authors and operators predict reuse/adopt/replace/remove from schema fields without reading install engine source.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Enforcement already exists in install/ownership engines; the gap is author/operator learnability. Option B belongs in [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) as follow-up, not as a prerequisite for the guide.

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
  Reason: Option B scope; track in [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md).

---
---
