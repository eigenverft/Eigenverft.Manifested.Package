# SUPPLY CHAIN — Design Issues

Design scratchpad for **delayed auto-update** and **vendor release-age** policy on package version selection. Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` on **2026-05-30**.

Open issues in this file are scheduled here. **No engine, schema, or catalog changes are implied by this file alone.**

**Compose with:** version selection is its own resolver step — do not mix with prerequisite graph logic ([`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md)). Authors and agents — [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md). Static policy lint — [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md).

**Product boundary (read narrowly):** [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) targets *governed, reviewable catalog content* and *explainable release selection* — not “never touch the network.” Depot/offline paths are a **core strength**, and isolated networks must **fail closed** instead of reaching public upstream unexpectedly. The engine **already** calls GitHub during **acquisition** for `githubRelease` sources (`Package.Source.ps1`). Release-age policy should not re-use PRODUCT-BOUNDARY as a blanket ban on GitHub; it should separate **which step** may use the network (authoring vs selection vs acquire).

---

## Open Issues

Sorted by **Priority** (lower number first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 2/6 — High**

---
---

## 📌 Add vendor release-age policy to automatic version selection

- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 4/4 Organization ▰▰▰▰
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🛡 Security / Trust
  - 🚧 Readiness: 🟢 Ready

### 📝 Statement

Automatic version pick today chooses the **highest authored** `artifacts.releases[]` row with **no cooling window** after the upstream vendor shipped that version. A maintainer can add a new release row and every machine on `latestByVersion` will select it on the next assign. Supply-chain hardening needs a **small default delay** (example: **7 days**) keyed off **vendor/upstream release time**, not catalog publication time — plus explainability when rows are skipped as “too new.”

Original design intent:

> Delayed auto-update is not a long embargo; it is a cooling window before a newly authored version becomes eligible for automatic selection. Explicit version pins remain operator overrides.

### 🧭 Related Context

Related Issues:
- [`TODO-DEPENDENCY-A.md`](TODO-DEPENDENCY-A.md) — prerequisite resolution must **compose** with per-package release-age policy on dependency nodes; do not duplicate age logic inside the dependency graph solver.
- Version-change `[OUTCOME]` vocabulary shipped 2026-05-30 ([DECISIONS.md](DECISIONS.md)); extend for skipped-for-age once selection audit exists.

Affected Areas:
- `Package.VersionSelection.ps1`; `Package.DefinitionSchema.Wire1_8.ps1`; `eigenverft-module-package-definition-1.8.schema.json` (or 1.9 sibling); `Package.Config.Aggregation.ps1` / `PackageConfig.json` `selectionDefaults`; all **18** shipped definitions under `Endpoint/Defaults/Eigenverft/`; `Package.Selection.ps1` projection and execution messages.

May Influence:
- Agent authoring workflow ([`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md)) — every new `releases[]` row needs `upstreamReleasedAtUtc` when age-aware strategies are used.
- Catalog validation ([`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md)) — lint missing vendor dates before sign/publish.

Dependencies:
- None blocking design; **selection** must use **authored** `upstreamReleasedAtUtc` only (see **Boundary note** below).

### 🎯 Required Outcome

1. Wire and runtime support **vendor release-age policy**: per-target and global `minReleaseAge` (name TBD), age-aware `latestByVersion` / `previousByVersion`, and optional offset strategies — with **fail-closed** behavior when every candidate is still inside the cooling window.
2. Each selectable `artifacts.releases[]` row carries **`upstreamReleasedAtUtc`** (on `upstreamRelease`) when age-aware selection applies; `definitionPublication.publishedAtUtc` stays catalog-publication time only.
3. **Explicit pin bypass:** `Invoke-Package -PackageVersion` / exact version selector skips age filtering (already the pin path in `Resolve-PackageVersionCandidateSelection`).
4. **Explainability v1:** selection result records versions skipped for age (logs / `SkippedCandidates` audit); no requirement for a full dry-run product command in phase 1.
5. Shipped catalog backfilled, revisions bumped, definitions re-signed.

### 🔎 Facts

Known:
- **Selection is local to authored candidates** — `Package.VersionSelection.ps1` header states no network “latest” lookup; `Resolve-PackageVersionCandidateSelection` sorts compatible release rows by version string only.
- **Strategies today (runtime):** `latestByVersion` (highest version), `previousByVersion` (second highest), and **exact** match when selector is a version string or `-PackageVersion` override (`Package.VersionSelection.ps1`).
- **Strategies today (wire 1.8):** `artifacts.targets[].versionSelection.strategy` enum allows only **`latestByVersion`**; `Wire1_8` throws on any other target strategy (`Package.DefinitionSchema.Wire1_8.ps1`).
- **`previousByVersion` today:** usable via **`Invoke-Package -PackageVersion previousByVersion`** (tests in `Package.ConfigAndDefinitions.Tests.ps1`); not authorable on the definition target row.
- **Global defaults:** `Configuration/Internal/PackageConfig.json` → `selectionDefaults.strategy: latestByVersion`, `releaseTrack: stable`; aggregation copies `strategy` and `releaseTrack` into `PackageConfig` (`Package.Config.Aggregation.ps1`). **No** `minReleaseAge` or cooling field exists.
- **`Resolve-PackagePackage` guard:** throws if `PackageConfig.SelectionStrategy` is not `latestByVersion` (`Package.Selection.ps1`) — global config cannot be `previousByVersion` even though the version selector function supports it.
- **Publication vs vendor time:** `definitionPublication.publishedAtUtc` is required on every definition; **`upstreamRelease`** on wire 1.8 has only `sourceId` + `releaseTag` — **no** vendor release timestamp (`eigenverft-module-package-definition-1.8.schema.json`).
- **GitHub helper:** `Get-GitHubRelease` returns `PublishedAtUtc` from the GitHub API (`ExecutionCore.Upstream.GitHubRelease.ps1`). Used only during **acquisition** URL resolution for `githubRelease` sources (`Package.Source.ps1`) — **not** during version selection.
- **`githubRelease` sources (shipped):** **3** definitions reference `kind: githubRelease` (GitRuntime, PowerShell7, LlamaCppRuntime). Most other downloads use `vendorDownload` / `packageDepot` with `upstreamRelease.releaseTag` only.
- **Multi-release catalog (verified):** **9** of **18** shipped definitions have **two** `artifacts.releases[]` version rows (e.g. NodeRuntime **26.2.0** and **24.15.0**); the rest have one. `latestByVersion` immediately picks the highest (e.g. Node **26.2.0**).
- **Post-selection install policy:** `versionUpdatePolicy.onNewSelectedVersion` (`replacePackageOwnedInstall` / `fail`) governs **install slot** behavior after the selected version **changes** — not which versions are eligible (`Package.AcquisitionAndOwnership.Tests.ps1`).
- **Explainability today:** projected `package.versionSelection` (`source`, `selector`, `orderingKind`, `requestedVersion`) on `PackageResult`; `[STATE] Selected package artifact target...` in `Package.Selection.ps1`. **No** audit of versions skipped for age.
- **Trust model (done elsewhere):** signed definitions + `catalogTrust` — age policy composes with trust; does not replace it (shipped 2026-05-27).
- **Network today is not absent:** `githubRelease` acquisition already requires GitHub at assign time for download URL resolution; `vendorDownload` / `packageDepot` paths can stay depot- or file-backed. PRODUCT-BOUNDARY “offline-capable” applies to **controlled** flows (internal endpoint + depot), not to forbidding GitHub wherever upstream hosts on GitHub.

Unknown:
- Exact `minReleaseAge` duration syntax and parser (e.g. `7d` vs ISO-8601 duration).
- Whether cooling defaults should differ by publisher, package sensitivity, or stay global-only for v1.
- Final names for offset strategies (`currentMinusOneWeek` vs alternatives).

---

### 🧩 Options

#### Option A — Authored vendor release date at selection time (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Add `upstreamReleasedAtUtc` to each `artifacts.releases[]` row. **Version selection** filters and ranks using those **signed, authored** timestamps only — same “local to authored candidates” rule as today’s version ordering. Maintainers, agents, or CI set the date when the catalog row is written (manual entry, copy from release notes, or a **separate** maintain-time helper — not part of selection). Acquisition may still use GitHub or other networks per existing `artifacts.sources` kinds.

Current State:
Version ordering uses authored version strings only; no upstream timestamp on the wire.

Resulting State:
Age-aware `latestByVersion` / `previousByVersion` use one policy clock for every source kind. Isolated operators who only use depot-backed acquire paths are unaffected at selection time; GitHub-backed packages behave like today at acquire, with cooling enforced before a new row becomes the automatic pick.

Solves:
- Matches existing `Package.VersionSelection.ps1` design (no network in selection).
- Vendor dates become reviewable catalog facts (signing, validation) — aligns with “not silently trust latest upstream.”
- Does not fight PRODUCT-BOUNDARY: offline/depot remains supported; GitHub is not “mixed into selection.”

Leaves Open:
- Authoring burden to populate accurate `upstreamReleasedAtUtc` on each new release row.

Risks:
- Wrong or stale authored dates weaken the policy (mitigate with validation at publish).

Later Cost:
- Low if validation enforces dates when age-aware strategies are enabled.

---

#### Option B — Runtime GitHub enrichment at selection time (Implementation Option)

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
Call `Get-GitHubRelease` while ranking candidates for rows tied to `githubRelease` sources, using API `published_at` as the policy clock on every `Invoke-Package`.

Current State:
GitHub is used at acquisition only; selection never calls the network.

Resulting State:
GitHub-backed packages get live vendor dates at select time; other source kinds need a parallel rule.

Solves:
- Less manual date entry for three shipped `githubRelease` definitions at authoring time.

Leaves Open:
- `vendorDownload` / `packageDepot` packages still need authored dates anyway — two policy clocks in one engine.
- Selection outcome can change when GitHub is unreachable even if the signed catalog did not change.

Risks:
- Breaks “selection is local to authored candidates” (`Package.VersionSelection.ps1`).
- Extra latency and rate limits on every assign; policy not fully determined by signed JSON.
- Awkward fit with catalog trust: cooling would depend on live API, not reviewed catalog content.

Later Cost:
- Likely rework toward Option A once multi-source catalogs grow.

---

#### Option C — Optional maintain-time GitHub assist (authoring only) (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
**Not a third selection mode.** Optional maintainer command or agent step: when authoring a row whose `upstreamRelease` points at `githubRelease`, call `Get-GitHubRelease` once and **write** `upstreamReleasedAtUtc` into the definition before sign/publish. Selection still uses Option A. Same pattern as using GitHub today to verify `releaseTag` / assets — network at **catalog maintenance**, not at **version pick**.

Current State:
`Get-GitHubRelease` exists; dates are not persisted on the release row.

Resulting State:
Authors of GitRuntime / PowerShell7 / LlamaCppRuntime can fill vendor dates faster; runtime selection unchanged.

Solves:
- Convenience for GitHub-hosted packages without Option B’s runtime coupling.

Leaves Open:
- `vendorDownload` / baseUri rows still need manual or other sourcing for dates.

Risks:
- Treated as required infrastructure instead of optional tooling.

Later Cost:
- None if it stays optional extracted work under Option A.

---

### 💶 Value Assessment

- 💎 Value Type: 🛡 Risk / Loss Avoided · 🔁 Rework Avoided · 🧭 User Experience Improved
- 🧭 Value Direction: 🛡 Risk / Protection
- 🧾 Value Mechanism: Adds a reviewable cooling window before automatic version selection picks a newly authored row; keeps policy in signed catalog content and explainable logs instead of silent “highest version wins” on the next assign.
- ⚖️ Option Value Summary:
  - Option A — Authored vendor release date at selection time (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧬 Integration: 🟢 Compatible
    - 🧾 Decision Note: Matches `Package.VersionSelection.ps1` (no network at selection); vendor dates are signed, validatable catalog facts for all source kinds.
  - Option B — Runtime GitHub enrichment at selection time (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧬 Integration: 🟡 Temporary
    - 🧾 Decision Note: Less authoring work for three `githubRelease` packages only; splits policy clocks and breaks selection-from-signed-catalog model.
  - Option C — Optional maintain-time GitHub assist (authoring only) (Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Optional convenience on top of A; does not change selection runtime; safe to defer to extracted work.
- ✅ Good Result: Automatic selection respects a default cooling window from vendor release time; operators see which versions were skipped as too new; explicit pins still override; fail-closed when no row is eligible.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Release-age policy belongs in **reviewed catalog content**, enforced at **selection** from authored fields — consistent with signed definitions and with `Package.VersionSelection.ps1`. Reject Option B: mixing GitHub into selection duplicates the acquisition network story and splits policy across source kinds. Option C is **optional authoring convenience** on top of A, not a separate integration path; do not justify it with a strict “offline-only product” reading of PRODUCT-BOUNDARY (GitHub at acquire is already in scope).

Required Checks:
- Confirm default cooling window (7 days) with stakeholders.
- Record `minReleaseAge` syntax decision before schema pass.
- Document in schema/agent guidance: `upstreamReleasedAtUtc` is set at publish time (any source), not fetched during `Invoke-Package` selection.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🛡 Security / Compliance · 🔧 Engineering · 🚚 Release Owner
- 🗣 Communication Lens: 🛡 Trust / Risk Summary
- 📬 Success Note: Automatic package version selection now waits a short cooling period after the vendor ships a release before that version becomes eligible. The policy is visible in signed catalog data and in logs when a version is skipped as too new. Explicit version pins still work for urgent overrides. Isolated and depot-backed deployments are not forced to call GitHub during version pick.

### ✅ Resolved Decisions

- **Policy clock** — vendor/upstream release time per `artifacts.releases[]` row (`upstreamReleasedAtUtc` on `upstreamRelease`), **not** `definitionPublication.publishedAtUtc`.
- **Delayed auto-update** — small default cooling window (example **7 days**) before a version is eligible for automatic selection; not a long embargo.
- **Strategy model** — keep `latestByVersion` and `previousByVersion`; **`latest` is age-aware** (newest row that passes policy). Add offset strategies later (e.g. relative to vendor date and “now”).
- **Pin bypass** — `Invoke-Package -PackageVersion` / exact selector skips age filtering.
- **Precedence** — per-target `versionSelection` overrides global `selectionDefaults`; engine default when unset (target → global → engine default for `minReleaseAge`).
- **Fail closed** — if every candidate is too new, error with skipped versions, vendor dates, and remaining cooling time; **no** silent fallback to the newest authored row.
- **Selection integration** — **Option A**: age filter uses **authored** `upstreamReleasedAtUtc` only; no live upstream lookup in `Resolve-PackageVersionCandidateSelection`.
- **GitHub** — optional **Option C** tooling at catalog maintain/publish time only; **not** a runtime selection dependency. GitHub at **acquire** for `githubRelease` stays as today.
- **Explainability v1** — `SkippedCandidates` (or equivalent) on selection result + log lines before any full planning/dry-run command.

### ❓ Open Decisions

- Should cooling apply globally only, or also per-publisher / per-sensitive-package overrides in v1?
- Does `previousByVersion` apply age policy to the “second” slot the same way as `latest`? (**Recommended: yes** — both operate on the age-filtered set.)
- Exact `minReleaseAge` string syntax and parsing rules.
- Final offset strategy names (`currentMinusOneWeek` vs `latestReleasedBefore` / similar).
- Schema **1.8 additive** vs **1.9** break for `upstreamReleasedAtUtc`, extended `versionSelection.strategy` enum, and `selectionDefaults.minReleaseAge`.
- Whether to wire `previousByVersion` on definition targets (schema) in the same pass as age policy.
- Agent/maintainer workflow: validation when `upstreamReleasedAtUtc` is missing on a row used with age-aware strategy; CI signing steps.
- Whether Option C maintain-time GitHub helper ships in v1 or only manual/agent date entry.

### Boundary note (PRODUCT-BOUNDARY vs network)

| Concern | What boundary says | How release-age should apply |
|--------|---------------------|------------------------------|
| Silent trust of “latest” | Not a catalog that silently trusts latest upstream releases | Cooling + explainable skip — policy is explicit in JSON and logs |
| Offline / isolated | Depot/endpoint strength; fail closed to public upstream when isolated | Selection uses signed catalog timestamps; acquire path chooses depot vs vendor vs GitHub per definition |
| Live upstream metadata | Risky when install was **expected** to be offline | Do not add **selection-time** GitHub; acquire-time GitHub for `githubRelease` is already a product choice |
| Explainability | Latest, previous, pinned, skipped, replaced clear in results/logs | `SkippedCandidates` for “too new” rows |

PRODUCT-BOUNDARY does **not** require banning GitHub from the product. It requires **clear, governed behavior** per step. Treat “offline-capable” as **supported deployment mode**, not as “Option C hybrid because GitHub is awkward.”

### 🚫 Out of Scope

- Fleet-wide hold, skip, or rollout orchestration (manager product).
- Network “fetch latest upstream” as a version **selection** strategy.
- Using `definitionPublication.publishedAtUtc` as a proxy for vendor release age.
- Background auto-update service (PRODUCT-BOUNDARY: not a background mutator).
- Changing trust/signing policy (already shipped).

### 🌱 Extracted Work

Required:
- [ ] **Phase 1 — Wire / validation** — `Package.DefinitionSchema.Wire1_8.ps1` (or `_1_9`): `upstreamReleasedAtUtc`, `minReleaseAge`, extended `versionSelection.strategy`; require vendor date when age-aware strategies are used.
  Reason: Schema and validation before runtime behavior changes.
- [ ] **Phase 2 — Version selection engine** — `Package.VersionSelection.ps1`: age filter, strategy extensions, `SkippedCandidates` on selection result; fail-closed messaging.
  Reason: Core policy enforcement.
- [ ] **Phase 3 — Config aggregation** — merge global `selectionDefaults` with per-target `versionSelection`; relax `Resolve-PackagePackage` global strategy guard if `previousByVersion` is wire-authorable.
  Reason: Precedence table and consistency with runtime strategies.
- [ ] **Phase 4 — Projection / messages** — `Package.Selection.ps1`, `Write-PackageExecutionMessage`: picked vs skipped versions in `[STATE]` / outcome-adjacent logs.
  Reason: Explainable release selection (product boundary + operator clarity).
- [ ] **Phase 5 — Catalog backfill** — all **18** definitions: populate `upstreamReleasedAtUtc`, bump `definitionRevision`, re-sign.
  Reason: Policy is inert without data on shipped rows (especially **9** multi-release packages).
- [ ] **Phase 6 — Tests** — cooling window, pin bypass, fail-closed when all rows too new, global vs target precedence.
  Reason: Prevent regressions on selection and messaging.

Optional (Option C — authoring only):
- [ ] **Maintain-time GitHub date command** — populate `upstreamReleasedAtUtc` from `Get-GitHubRelease` when writing/signing a definition (never during selection).
  Reason: Convenience for `githubRelease` maintainers; orthogonal to offline-capable depot deploys.
- [ ] **Phase 2 explainability on `PackageResult` / operation history** — surface same audit outside logs.
  Reason: Optional `PackageResult.RunSummary`; defer if `[OUTCOME]` logs are enough ([DECISIONS.md](DECISIONS.md)).

---

## Policy reference (normative sketch)

*Retained from prior scratchpad for implementers; finalize names in schema pass.*

### Precedence

| Setting | Global (`package.selectionDefaults`) | Per-target (`artifacts.targets[].versionSelection`) | Resolved |
|---------|--------------------------------------|-----------------------------------------------------|----------|
| `strategy` | default | target override | Target → global → `latestByVersion` |
| `minReleaseAge` (TBD) | default duration | target override | Target → global → engine default (e.g. 7 days) |
| `allowPrerelease` | — | target only (wire today) | Target unless global mirror added later |

### Age-aware selection algorithm

1. Build compatible release candidates (platform, architecture, release track) with version ordering metadata and `upstreamReleasedAtUtc`.
2. Unless the operator pinned an exact version, drop rows where `nowUtc - upstreamReleasedAtUtc < effectiveMinReleaseAge`.
3. Among survivors, apply resolved strategy (`latestByVersion`, `previousByVersion`, offset strategies TBD).
4. If no row survives: **fail closed** with skipped versions, vendor dates, and remaining cooling time.

### Schema sketch (draft)

| Location | Field | Notes |
|----------|--------|--------|
| `artifacts.releases[].upstreamRelease` | `upstreamReleasedAtUtc` | ISO-8601 UTC; required when target uses age-aware strategy |
| `artifacts.targets[].versionSelection` | `minReleaseAge` | Duration string (syntax TBD) |
| `artifacts.targets[].versionSelection.strategy` | enum extension | Add `previousByVersion`; offset strategies TBD |
| `package.selectionDefaults` | `minReleaseAge` | Global default cooling window |

---

## Closed / elsewhere

- **Trust-only catalog** (signed definitions, `catalogTrust`, publisher inventory) — shipped 2026-05-27. Composes with but does not replace release-age policy.
