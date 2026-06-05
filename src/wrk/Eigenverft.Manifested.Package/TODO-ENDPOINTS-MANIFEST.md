# TODO ENDPOINTS MANIFEST

Design scratchpad for the **catalog manifest/index contract** for large-catalog and HTTPS-at-scale discovery.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` on **2026-06-01**.

Open issues in this file are scheduled here.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| Discovery model | [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) |
| `httpsCatalog` implementation | [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md) |
| Search cmdlet | Shipped `Search-Package` local scan — [DECISIONS.md](DECISIONS.md) |
| Agent authoring target discovery | Shipped `Get-PackageDefinitionAuthoringGuide`; future HTTPS authoring authorization remains separate |

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 2/7 — Backlog**

*Context: **endpoints** discover signed package-definition JSON; **depots** supply artifact bytes.*

---
---
## 📌 Define catalog manifest contract (large-catalog path)

- 🏷 Rating
  - 🚦 Priority: 2/7 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🔁 Data / Compatibility
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

When catalogs grow beyond small recursive scans, hosts need a manifest/index contract so clients do not fetch and verify every definition JSON individually. The draft [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) now records live scan for small `moduleLocal` / `filesystem` / `httpsCatalog` v1 paths and a manifest trigger for large catalogs (~200+ definitions or multi-second scan latency). No manifest type or parser exists in the repo today.

This manifest issue is about read-side discovery metadata: what definitions exist, where to fetch them, and how trust verification proceeds. It should not quietly become a package-definition publishing API. If HTTP(S) endpoints later support creating or updating definitions, that needs a separate write-side surface with authorization. The manifest may later advertise endpoint capabilities, but create/update behavior must remain distinct from read-side index fetch.

### 🧭 Related Context

Related Issues:
- [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) (recorded; large-catalog manifest still required at scale).
- [`TODO-ENDPOINTS-HTTPS.md`](TODO-ENDPOINTS-HTTPS.md).
- Shipped `Get-PackageDefinitionAuthoringGuide`, which must not select HTTPS authoring targets until HTTPS create/update authorization checks exist.

Affected Areas:
- Future manifest document; endpoint discovery sequencing; trust order with signed definitions.
- Future endpoint capability advertisement if manifests expose read/write support.

Dependencies:
- Draft [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) is recorded; a concrete large-catalog requirement or at-scale HTTPS/search target should drive the first contract.
- HTTPS create/update authoring is a separate authorization decision, not a prerequisite for read-side manifests.

### 🎯 Required Outcome

Written manifest contract: file shape (or API), how entries reference definition paths or hashes, fetch order, and how existing trust/signing rules apply. Implementation remains separate issues. If endpoint capabilities are included, the contract must clearly separate read/list/fetch capability from create/update authoring capability.

### 🔎 Facts

Known:
- `httpsCatalog` is validated in inventory schema (`baseUri`, `catalogPath` required) but **`Resolve-PackageEndpointRootPath` throws** — not executable (verified 2026-06-01).
- `Get-PackageEndpointSummaries` marks `httpsCatalog` not effective (*reserved for future support*).
- **No manifest document type** or parser exists in the repository today.
- **Filesystem/moduleLocal discovery** scans all `*.json` under the endpoint root (acceptable for **18** local definitions; scaling concern is forward-looking).
- Draft [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) records live scan for small catalogs and a manifest requirement before large remote catalogs.

Unknown:
- Manifest format (static index file vs generated API).
- Exact first at-scale catalog target, entry metadata, and compatibility/versioning requirements.
- Whether manifests should advertise endpoint capabilities at all, or whether authoring capability should live only in `PackageEndpointInventory.json`.
- If manifests advertise HTTPS create/update capability, how authorization state is represented without exposing secrets.

---

### 🧩 Options

#### Option A — Full manifest contract before large HTTPS/search use (Implementation Option)

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
Specify manifest file shape, entry references (path and/or hash), fetch order, metadata needed by search, and how signing/trust reuses today’s definition rules before teams rely on large HTTPS/search catalogs. Implementation stays in follow-up issues. If capability advertisement is included, keep read-side discovery separate from any create/update authoring surface.

Current State:
No manifest type; small catalogs may still use live scan, but large HTTPS/search paths need a contract first.

Resulting State:
Authors and implementers share one contract for large catalogs and `httpsCatalog`.

Solves:
- Aligns manifest issue, HTTPS endpoint, and future search-at-scale on one index model.
- Prevents the read manifest from becoming an accidental publish API.

Leaves Open:
- Parser, transport, and endpoint runtime work.
- HTTPS authoring authorization and create/update semantics.

Risks:
- Requires a concrete first at-scale consumer so the contract is not overfit or underfit.

Later Cost:
- Lower rework for large remote catalogs.

---

#### Option B — Minimal index stub for HTTPS v1 only (Implementation Option)

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
Document a thin manifest (definition id → relative path or URL) sufficient to bootstrap read-side `httpsCatalog` without full search metadata. Expand when search ships.

Current State:
Same as Option A blocker.

Resulting State:
HTTPS v1 can list definitions without per-URL directory scan; search fields deferred.

Solves:
- Faster path to HTTPS if scan-only is rejected for remote roots.

Leaves Open:
- Search ranking, tags, and rich metadata.
- HTTPS create/update authoring remains undefined.

Risks:
- Second manifest revision when search requirements land.

Later Cost:
- Possible manifest v2 when search is designed.

---

#### Option C — No manifest; defer contract until scale pain (Defer Option)

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
Keep the small-catalog live-scan decision and close this issue without a contract until catalog size or HTTPS latency forces one.

Current State:
Draft discovery model recorded: small catalogs live-scan; large catalogs need a manifest before teams rely on HTTPS/search at scale.

Resulting State:
Manifest issue dormant; live scan remains the only discovery path.

Solves:
- Avoids premature format design.

Leaves Open:
- Large-catalog and HTTPS performance risk.
- No endpoint capability advertisement for future authoring-guide checks.

Risks:
- HTTPS implementation may need redesign later.

Later Cost:
- Manifest design under pressure after HTTPS ships.

---

#### Option D — Already resolved: wait for discovery record (Closed Discovery Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
This was the prior waiting path. The discovery record now exists, so this option is no longer the active recommendation.

Current State:
The repo now has a discovery stance: live scan for small catalogs, manifest before large catalogs.

Resulting State:
Manifest contract work is sequenced after a concrete at-scale need; avoids designing against an abstract future catalog.

Solves:
- Records that the wait-for-discovery path is complete and points future work at a concrete large-catalog trigger.

Leaves Open:
- No manifest contract until a large-catalog target is selected.

Risks:
- Stale if the discovery decision changes before a large-catalog target appears.

Later Cost:
- Low if the first at-scale target is concrete enough to choose A or B quickly.

---

### 💶 Value Assessment

- 💎 Value Type: 🔎 Better Decision · 🚚 Delivery Unblocked
- 🧭 Value Direction: 🔎 Decision / Learning
- 🧾 Value Mechanism: Defines an index contract aligned with trust and signing before manifest parser and HTTPS catalog implementation; enables large-catalog discovery without per-definition fetch storms.
- ⚖️ Option Value Summary:
  - Option A — Full manifest contract before large HTTPS/search use (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧬 Integration: 🟣 Strategic
    - 🧾 Decision Note: Best long-term HTTPS and search alignment once a large-catalog target exists.
  - Option B — Minimal index stub for HTTPS v1 only (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧬 Integration: 🟡 Temporary
    - 🧾 Decision Note: Faster HTTPS bootstrap; may need manifest revision when search ships.
  - Option C — No manifest; defer contract until scale pain (Defer Option)
    - 🧭 Resolution: ⚪ Defer
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Avoids premature design; leaves large-catalog and HTTPS performance risk.
  - Option D — Already resolved: wait for discovery record (Closed Discovery Option)
    - 🧭 Resolution: 🔵 Discovery
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Superseded by [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md).
- ✅ Good Result: Manifest shape, entry references, and trust order are written; implementers share one contract.
- ✅ Boundary Result: The manifest contract does not blur read-side discovery with write-side create/update authoring.

---

### 🏁 Recommendation

- [2026-06-01 00:00 | Author: Codex | Recommendation: Prefer Option A when the first large-catalog target is selected | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
No manifest code exists. The draft discovery record now says small catalogs can live-scan and large catalogs need a manifest before teams depend on HTTPS/search at scale. Option A is the right contract path once the first large-catalog target supplies concrete metadata and latency requirements; Option B remains a possible narrower bootstrap if HTTPS needs only a path index.

Required Checks:
- Identify the first large filesystem/HTTPS catalog target and required search metadata.
- Decide manifest versioning, entry hash/path fields, and trust verification order before parser work.
- Decide separately whether endpoint authoring capability belongs in manifest capability metadata, endpoint inventory metadata, or both.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 🚚 Release Owner
- 🗣 Communication Lens: 🔧 Technical Summary
- 📬 Success Note: Small catalogs keep the simple live-scan model. Large and HTTPS-at-scale catalogs get a manifest contract before teams rely on them, so search and trust behavior can be predictable without fetching every definition.

### ❓ Open Decisions

- Manifest required vs optional per endpoint kind?
- Single manifest vs per-catalog versioned manifests?
- Should the manifest advertise endpoint capabilities, or should create/update authoring capability remain entirely in endpoint inventory and endpoint-specific probes?
- If an HTTPS endpoint advertises create/update capability, how should authorization be verified before `Get-PackageDefinitionAuthoringGuide` selects it?

### 🚫 Out of Scope

- Implementing HTTPS transport in this issue.
- Full-text search ranking algorithms.
- Implementing package-definition create/update publishing.
- Defining HTTPS write authorization.

---
---
