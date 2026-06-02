# TODO DEPOTS HTTP

Design scratchpad for **read-only HTTP/HTTPS package depots** (artifact byte hosting).

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against the repo on **2026-05-30**.

Open issues in this file are scheduled here.

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| Depot layout hygiene | [TODO-DEPOTS-HYGIENE.md](TODO-DEPOTS-HYGIENE.md) |
| HTTPS catalog endpoints | [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md) |
| Supply chain / acquisition | [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) |

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 5/6 — Backlog**

*Context: **endpoints** discover signed package-definition JSON; **depots** supply artifact bytes. File-share channels exist; HTTP/HTTPS variants are backlog.*

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
- [`TODO-DEPOTS-HYGIENE.md`](TODO-DEPOTS-HYGIENE.md) (filesystem depots).

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

#### Option A — v1: full-file GET only (HTTPS, no auth) (Implementation Option)

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

#### Option B — Spike fetch requirements first (Discovery Option)

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

### 💶 Value Assessment

- 💎 Value Type: ✨ Product Capability Improved · 🚀 Opportunity / Improvement
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Extends depot acquisition beyond filesystem mirrors while reusing hash and signature verification so central teams can host artifact bytes on HTTP(S).
- ⚖️ Option Value Summary:
  - Option A — v1: full-file GET only (HTTPS, no auth) (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Unblocks internal HTTPS mirrors quickly; defers etag, range, and auth.
  - Option B — Spike fetch requirements first (Discovery Option)
    - 🧭 Resolution: 🔵 Discovery
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Best decision value before greenfield transport; defers product capability until requirements are explicit.
- ✅ Good Result: Read-only HTTP(S) depots materialize verified artifacts like today’s filesystem depots.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Less coupled to catalog discovery than HTTPS endpoints, but depot acquisition is still greenfield. Option B best satisfies the Value Assessment (avoid wrong v1 transport) before Option A implementation. A short requirements note prevents locking the wrong v1 transport.

Required Checks:
- Identify first hosted artifact types (MSI, zip, npm tarball) and size range.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🔧 Engineering · 📡 Operations
- 🗣 Communication Lens: 🚚 Release Summary
- 📬 Success Note: Package depots can be hosted on read-only HTTP(S) as well as file shares. Machines acquire artifacts through the same verification rules as filesystem depots. Writable and authenticated depots remain out of scope for this issue.

### ❓ Open Decisions

- Option A minimal GET vs etag/cache in v1?
- Separate `http` and `https` kinds or one kind with scheme in URL?

### 🚫 Out of Scope

- Writable or authenticated depot mirroring.
- Changing `vendorDownload` semantics in definitions.

---
---
