# TODO ENDPOINTS HTTPS

Design scratchpad for implementing the **httpsCatalog** endpoint kind.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` on **2026-06-01**.

Open issues in this file are scheduled here.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| Discovery model | [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) |
| Manifest contract | [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md) |
| Search cmdlet | Shipped `Search-Package` local scan — [DECISIONS.md](DECISIONS.md) |

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 5/6 — Backlog**

*Context: **endpoints** discover signed package-definition JSON; **depots** supply artifact bytes.*

---
---
## 📌 Implement `httpsCatalog` endpoint kind (small-catalog v1)

- 🏷 Rating
  - 🚦 Priority: 5/6 Backlog ▰▰▱▱▱▱▱
  - 🛠 Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: ✨ Functionality
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

Inventory already accepts `httpsCatalog` entries (`baseUri`, `catalogPath`), but `Resolve-PackageEndpointRootPath` **throws** and summaries mark them not effective. The draft [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) now records that small HTTPS catalogs may use live recursive JSON scan first; manifest-backed discovery is required before relying on HTTPS at large-catalog scale.

### 🧭 Related Context

Related Issues:
- [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md).
- [`TODO-ENDPOINTS-MANIFEST.md`](TODO-ENDPOINTS-MANIFEST.md).

Affected Areas:
- `Package.EndpointInventory.Management.ps1`; `Package.DefinitionReference.ps1`; TLS/proxy configuration.

Dependencies:
- Draft [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) is recorded; manifest contract is only blocking for large-catalog / at-scale HTTPS.

### 🎯 Required Outcome

Enabled `httpsCatalog` endpoints resolve definitions end-to-end with unchanged trust/signing behavior (`PackageTrustInventory.json`, `catalogTrust`). Discovery mechanism follows [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md): live scan for small catalogs, manifest before large-catalog scale.

### 🔎 Facts

Known:
- Same **`httpsCatalog` not implemented** behavior as manifest issue (`Resolve-PackageEndpointRootPath` throw; endpoint summary `Effective = false`).
- Inventory schema expects `baseUri` + `catalogPath` on `httpsCatalog` entries (`Package.EndpointInventory.Management.ps1`).
- **Trust/signing** for definitions is implemented (shipped 2026-05-27): signed JSON, `PackageTrustInventory.json`, `catalogTrust` policy.
- **Today’s catalog path** is `moduleLocal` + recursive JSON scan, not HTTPS.

Unknown:
- TLS and corporate proxy constraints for target environments.
- Exact small-catalog URL listing/fetch shape for `baseUri` + `catalogPath`.

---

### 🧩 Options

#### Option A — `httpsCatalog` v1 with live JSON scan (no manifest) (Implementation Option)

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

#### Option B — `httpsCatalog` after manifest contract for large catalogs (Implementation Option)

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
Blocked on manifest contract for large-catalog / at-scale use; not required for a small-catalog v1 scan path.

Resulting State:
HTTPS catalogs use index-first discovery aligned with search backlog.

Solves:
- One discovery model for large remote catalogs.

Leaves Open:
- Longer lead time; manifest contract must land first for at-scale HTTPS.

Risks:
- Schedule coupling between two backlog items.

Later Cost:
- Lower discovery rework at scale.

---

#### Option C — Keep stub; document inventory-only until decisions land (Defer Option)

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

### 💶 Value Assessment

- 💎 Value Type: ✨ Product Capability Improved · 🚚 Delivery Unblocked
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Turns inventory-reserved `httpsCatalog` into an effective endpoint kind with the existing trust model so team catalogs can live on HTTPS instead of SMB shares.
- ⚖️ Option Value Summary:
  - Option A — `httpsCatalog` v1 with live JSON scan (no manifest) (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧬 Integration: 🟡 Temporary
    - 🧾 Decision Note: Earliest HTTPS access; may not scale without later manifest work.
  - Option B — `httpsCatalog` after manifest contract for large catalogs (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧬 Integration: 🟣 Strategic
    - ↩️ Reversibility: 🟠 Hard
    - 🧾 Decision Note: One discovery model at scale; coupled to manifest contract.
  - Option C — Keep stub; document inventory-only until decisions land (Defer Option)
    - 🧭 Resolution: ⚪ Defer
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Zero implementation risk; no HTTPS catalog access until A or B is chosen.
- ✅ Good Result: Enabled HTTPS catalog endpoints resolve signed definitions; discovery matches [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md).

---

### 🏁 Recommendation

- [2026-06-01 00:00 | Author: Codex | Recommendation: Prefer Option A for small-catalog v1; reserve Option B for large catalogs | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
The draft discovery decision now records live scan for small catalogs, while code still keeps `httpsCatalog` as an inventory-reserved runtime throw. Option A is the clearest small-catalog implementation path. Option B remains the right at-scale path once [`TODO-ENDPOINTS-MANIFEST.md`](TODO-ENDPOINTS-MANIFEST.md) defines the manifest contract.

Required Checks:
- Confirm TLS/proxy expectations and acceptable scan latency for the first small HTTPS catalog.
- Keep the ~200-definition / multi-second latency trigger from [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) as the point where manifest work becomes blocking.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 📡 Operations
- 🗣 Communication Lens: 🚚 Release Summary
- 📬 Success Note: HTTPS catalog implementation has a small-catalog v1 path: live scan with the same trust model as local endpoints. Large remote catalogs still require a manifest contract before teams depend on them at scale.

### ❓ Open Decisions

- Final small-catalog fetch/cache behavior and proxy defaults.
- Exact large-catalog cutoff beyond the current ~200-definition / multi-second trigger.

### 🚫 Out of Scope

- Writable or authenticated catalog publishing.
- Changing trust policy.
