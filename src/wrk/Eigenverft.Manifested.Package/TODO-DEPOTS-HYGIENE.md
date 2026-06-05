# TODO DEPOTS HYGIENE

Design scratchpad for **filesystem depot layout hygiene validation**.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against the repo on **2026-05-30**.

Open issues in this file are scheduled here.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| HTTP(S) depot transport | [TODO-DEPOTS-HTTP.md](TODO-DEPOTS-HTTP.md) |
| Supply chain / acquisition | [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) |

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 2/7 — Backlog**

*Context: **endpoints** discover signed package-definition JSON; **depots** supply artifact bytes. File-share channels exist; HTTP/HTTPS variants are backlog.*

---
---

## 📌 Add depot layout hygiene validation (filesystem depots)

- 🏷 Rating
  - 🚦 Priority: 2/7 Backlog ▰▰▱▱▱▱▱
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
- [`TODO-DEPOTS-HTTP.md`](TODO-DEPOTS-HTTP.md).

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

#### Option A — `Test-PackageDepot` maintainer cmdlet (Implementation Option)

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

#### Option B — Warnings during `Invoke-PackageDepotDistribution` (Implementation Option)

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

#### Option C — Maintainer doc only (defer code) (Defer Option)

- 🧾 Option Profile
  - 🧭 Resolution: ⚪ Defer
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

### 💶 Value Assessment

- 💎 Value Type: 🧱 Maintenance Effort Reduced · 🛟 Support Effort Reduced
- 🧭 Value Direction: 💰 Cost / Efficiency · 🛡 Risk / Protection
- 🧾 Value Mechanism: Surfaces orphan and incomplete depot files before assign or mirror fails opaquely; reduces diagnosis time for maintainers and support.
- ⚖️ Option Value Summary:
  - Option A — `Test-PackageDepot` maintainer cmdlet (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Best support and maintenance value without warning noise on every assign; no auto-repair.
  - Option B — Warnings during `Invoke-PackageDepotDistribution` (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Surfaces problems in common assign flow; warning-noise risk; no standalone audit path.
  - Option C — Maintainer doc only (defer code) (Defer Option)
    - 🧭 Resolution: ⚪ Defer
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Fast zero-risk guidance; ambiguous failures remain until code lands.
- ✅ Good Result: Maintainers detect layout problems with explicit pass/fail or warnings before acquisition errors.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Prefer Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Hygiene is operability for maintainers; a dedicated test command matches depot management commands and avoids warning spam on every assign. Option B is a reasonable add-on after Option A rules exist.

Required Checks:
- Sample default and corp depot layouts from a real assign run before locking rules.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 🛟 Support / Customer Success
- 🗣 Communication Lens: 🛟 Support Summary
- 📬 Success Note: Depot layout problems can be detected before assign fails with unclear errors. Maintainers get explicit hygiene checks or guidance for mirror folders. Assign behavior stays unchanged unless a chosen option adds warnings during mirror.

### ❓ Open Decisions

- Option A only vs A plus B warnings?

### 🚫 Out of Scope

- Auto-deleting depot content without explicit maintainer action.
- HTTPS depot transport (separate backlog issue).
