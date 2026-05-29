# TODO SUPPLY CHAIN

## Purpose

Design scratchpad for **delayed auto-update** and **vendor release-age** policy on package version selection. Locks integration choices and open questions before engine or schema work.

Promotion to [`PROJECT-TODO.md`](PROJECT-TODO.md) happens when implementation is scheduled. **No engine, schema, or catalog changes are implied by this file alone.**

---

## Current engine facts

| Area | Today | Gap |
|------|--------|-----|
| Version pick | `Resolve-PackageVersionCandidateSelection` sorts authored `artifacts.releases[]` by version string; `latestByVersion` picks the highest version with **no age filter** | A newly authored row is selected as soon as it is the highest version |
| Strategies | Runtime supports `latestByVersion`, `previousByVersion`, and exact pin; schema `versionSelection.strategy` allows only `latestByVersion` | Age-gated and offset strategies are not modeled on the wire |
| Release timestamps | `definitionPublication.publishedAtUtc` records when the **definition document** was published | Not when the **upstream/vendor** published that package version |
| Upstream metadata | `artifacts.releases[].upstreamRelease` has `sourceId` and `releaseTag` only | No per-release vendor release timestamp in the catalog |
| GitHub | `Get-GitHubRelease` returns `PublishedAtUtc` but only for **download URL** resolution in acquisition | Not used when choosing which authored release row wins |
| Command pin | `Invoke-Package -Version` uses exact selection and bypasses strategy | Already satisfies “operator accepts risk” for a pinned version |
| Re-invoke policy | `versionUpdatePolicy.onNewSelectedVersion` (`replacePackageOwnedInstall` / `fail`) | Governs **install slot** behavior after selection changes, not **which versions are eligible** |
| Explainability | Projected `package.versionSelection` (`source`, `selector`, `orderingKind`) plus execution messages | No audit of versions **skipped because too new** |
| Global selection | `PackageConfig` `selectionDefaults.strategy` defaults to `latestByVersion` | No global `minReleaseAge` or delayed-update defaults |

**Selection today is local:** strategies rank **authored** release rows only. There is no network “fetch latest upstream” step in version selection (`Package.VersionSelection.ps1`).

---

## Locked decisions

1. **Vendor release date is the policy clock** — not `definitionPublication.publishedAtUtc`. Each selectable `artifacts.releases[]` row needs an upstream/vendor release time (working name: `upstreamReleasedAtUtc`, likely on `upstreamRelease`).
2. **Auto-update is delayed, not instant** — do not auto-select a version until it has passed a **small cooling window** (example engine default: **7 days**). This is supply-chain hardening, not a long embargo.
3. **Strategy model** — keep `latestByVersion` and `previousByVersion`, but **`latest` is age-aware**: newest authored release **that passes release-age policy**. Add offset strategies (e.g. `currentMinusOneWeek`) expressed relative to vendor release dates and “now”.
4. **Explicit version pin bypasses age policy** — `Invoke-Package -Version` / exact selector remains an operator override (already implemented).
5. **Policy scope: global + per-target** — see [Policy precedence](#policy-precedence). Target overrides global; engine supplies defaults when neither is set.
6. **Hybrid metadata (recommended)** — authored `upstreamReleasedAtUtc` is **required** for age-aware selection. GitHub `published_at` may **backfill or verify at catalog maintain time** only; it must not be the sole runtime gate (offline and non-GitHub sources must work).
7. **Schema versioning** — prefer **additive schema 1.8** fields if wire-compatible; otherwise introduce **1.9** with parallel `_1_9` validators (same pattern as Wire1_8 / policy `_1_8` modules).

---

## Integration options

### Option A — Authored vendor release date only (offline-first)

- Add `upstreamReleasedAtUtc` to catalog; selection filters on authored dates only.
- **Pros:** Works for all `artifacts.sources` kinds; offline; fits signed catalog trust.
- **Cons:** Maintainers or agents must populate dates when adding releases.

### Option B — Runtime GitHub enrichment at selection time

- Call `Get-GitHubRelease` while ranking candidates for `githubRelease` sources.
- **Pros:** Less manual date entry for GitHub-heavy packages.
- **Cons:** Breaks offline selection; rate limits; `download` / baseUri packages still uncovered; conflicts with “selection is local to authored candidates”.

### Option C — Hybrid maintain-time + authored selection (recommended)

- **Catalog:** require `upstreamReleasedAtUtc` for age-aware strategies; maintainer tooling may set it from GitHub when authoring.
- **Selection:** filter and rank using **authored dates only**; optional future warn if maintain-time GitHub disagrees.
- **Product fit:** delayed auto-update with a small offset; `latestByVersion` still mandatory as a strategy name but only among releases old enough to pass policy.

**Decision:** implement toward **Option C**. GitHub is a **catalog authoring aid**, not the runtime policy source of truth.

---

## Policy precedence

| Setting | Global (`package.selectionDefaults`) | Per-target (`artifacts.targets[].versionSelection`) | Resolved value |
|---------|--------------------------------------|-----------------------------------------------------|----------------|
| `strategy` | default strategy | target strategy | **Target** if set; else **global**; else `latestByVersion` |
| `minReleaseAge` (name TBD) | default duration | target override | **Target** if present; else **global**; else **engine default** (e.g. 7 days) |
| `allowPrerelease` | — | target only (schema today) | Keep on target unless a global mirror is added later |

### Age-aware selection algorithm (normative)

1. Build compatible release candidates (platform, architecture, release track) with version ordering metadata and `upstreamReleasedAtUtc`.
2. Unless the operator pinned an exact version, drop rows where `nowUtc - upstreamReleasedAtUtc < effectiveMinReleaseAge`.
3. Among survivors, apply the resolved strategy:
   - `latestByVersion` — highest version among eligible rows
   - `previousByVersion` — second highest among eligible rows
   - Offset strategies (e.g. `currentMinusOneWeek`) — newest row whose vendor release date is on or before `nowUtc - offset` (define precisely in schema)
4. If no row survives: **fail closed** with a message listing skipped versions, vendor release dates, and remaining cooling time. **Do not** silently fall back to the newest authored row.

---

## Schema sketch (draft)

Not final wire names; finalize during schema pass.

| Location | Field | Notes |
|----------|--------|--------|
| `artifacts.releases[].upstreamRelease` | `upstreamReleasedAtUtc` | ISO-8601 UTC; required when the target uses an age-aware strategy |
| `artifacts.targets[].versionSelection` | `minReleaseAge` | Duration string (syntax TBD, e.g. `7d` or `P7D`) |
| `artifacts.targets[].versionSelection.strategy` | enum extension | Keep `latestByVersion`; add `previousByVersion` to schema; add offset strategies such as `currentMinusOneWeek` |
| `package.selectionDefaults` | `minReleaseAge` | Global default cooling window |

`definitionPublication.publishedAtUtc` remains catalog publication time only; do not reuse it for release-age policy.

---

## Future implementation checklist

Reference only — not started by this document.

1. **Wire / policy validation** — `DefinitionSchema.Wire1_8.ps1` (or 1.9 sibling): require `upstreamReleasedAtUtc` when age-aware strategies are used; validate duration fields.
2. **Version selection** — `Package.VersionSelection.ps1`: age filter, strategy extensions, `SkippedCandidates` audit on the selection result.
3. **Config aggregation** — merge global `selectionDefaults` with per-target `versionSelection` per precedence table; attach effective policy to `PackageConfig`.
4. **Projection / messages** — `Package.Selection.ps1`, `Write-PackageExecutionMessage`: explain picked vs skipped versions.
5. **Catalog backfill** — shipped Eigenverft definitions: populate `upstreamReleasedAtUtc` (GitHub API or manual for baseUri sources); bump revisions and re-sign.
6. **Tests** — selection tests for cooling window, pin bypass, fail-closed when all rows too new, precedence of global vs target.
7. **Optional maintainer tooling** — command to fill `upstreamReleasedAtUtc` from `Get-GitHubRelease` when authoring (maintain-time only).

### Explainability phases

- **Phase 1:** `SkippedCandidates[]` on selection result plus `[STATE]` log lines (aligns with PRODUCT-BOUNDARY: release selection should be explainable).
- **Phase 2:** surface the same audit on `PackageResult` / operation history / a future planning mode — **do not** block release-age policy on a full dry-run product.

---

## Implementation phases

| Phase | Deliverable |
|-------|-------------|
| 1 | Schema + wire validation for `upstreamReleasedAtUtc` and `minReleaseAge` |
| 2 | Age-aware filter in version selection + skipped-version explainability |
| 3 | Global and per-target precedence in config aggregation |
| 4 | Shipped catalog backfill and signing |
| 5 | Optional maintain-time command to populate dates from GitHub |

---

## Resolved open questions

- **Policy clock** — vendor/upstream release time per `artifacts.releases[]` row, not definition publication time.
- **Delayed auto-update** — small default cooling window before a version becomes eligible for automatic selection.
- **Integration path** — Option C: authored dates at selection time; GitHub at maintain time only.
- **Pin bypass** — explicit `-Version` / exact selector skips age filtering.
- **Precedence** — per-target overrides global; engine default when unset.
- **Fail closed** — if every candidate is too new, error with detail; no silent pick of the newest row.
- **Explainability v1** — selection audit in logs before any full dry-run command exists.

---

## Still open

- Exact syntax for `minReleaseAge` duration strings and parsing rules.
- Whether `previousByVersion` applies age policy to the “second” slot the same way as `latestByVersion` (recommended: yes, both operate on the age-filtered set).
- Final names for offset strategies (`currentMinusOneWeek` vs `latestReleasedBefore` / similar).
- Agent and maintainer workflow for populating `upstreamReleasedAtUtc` on every new release row (validation rules, signing, CI).
- Shape of a future planning / dry-run command vs log-only explainability (see PROJECT-TODO backlog; not required for phase 1).

---

## Out of scope

- Fleet-wide hold, skip, or rollout orchestration (manager product).
- Network “latest upstream” lookup as a version **selection** strategy (selection stays authored-catalog-local).
- Using `definitionPublication.publishedAtUtc` as a proxy for vendor release age.
