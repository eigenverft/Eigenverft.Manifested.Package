# TODO COMMANDS

## Purpose

Design scratchpad for **new or extended public commands** and **richer operator-facing output** from existing commands — discovery, reporting, and presentation of package state without reading raw JSON inventories.

Promotion to [`PROJECT-TODO.md`](PROJECT-TODO.md) happens when implementation is scheduled. **No cmdlets or formatting changes are implied by this document alone.**

**Related (not duplicate):**

| Topic | Where |
|-------|--------|
| HTTPS catalog manifest (feeds search data) | PROJECT-TODO P5 package endpoints |
| In-depth documentation | [`TODO-DOCUMENTATION.md`](TODO-DOCUMENTATION.md) |
| Assignment rerun messaging (reuse vs upgrade) | PROJECT-TODO P6 run explainability |

---

## Product goals (from PROJECT-TODO)

| Goal | User story (short) | Desired outcome |
|------|-------------------|-----------------|
| **Search packages** | Find tools by friendly name, command, tag, or publisher without knowing `DefinitionId` | Results include definition id, publisher, summary, platform availability, current selected version — enough to run `Invoke-Package` confidently |
| **Readable package state** | Day-to-day troubleshooting without opening inventory JSON | Assigned packages, reused/adopted installs, failed operations, pending restart signals in concise tables or summaries |

**Requester perspectives:** first-time user, team endpoint member, demo operator, support helper, onboarding maintainer.

---

## Current engine facts

| Area | Today | Gap |
|------|--------|-----|
| `Get-PackageState` | Exported; returns structured object with `PackageRecords`, `OperationRecords`, path existence flags; `-Raw` dumps nested config/inventories | Not optimized as human-readable tables; users may still drill into JSON-like lists |
| Package search command | **None** — discovery is by known `DefinitionId` on `Invoke-Package` or scanning endpoint folders manually | No `Search-Package` / `Find-PackageDefinition` style cmdlet |
| Endpoint scan | Definitions loaded per invoke from `PackageEndpointInventory` search order | Search would aggregate across enabled endpoints (and optionally local materialized copies) |
| Display metadata | `display.default` (name, summary), `discovery.presence.commands`, `definitionPublication` | Tags not a first-class field today — search scope TBD |
| Operation history | `Get-PackageOperationHistory` internal; surfaced via `Get-PackageState.OperationRecords` | Formatting and “last run outcome” summary not polished |

---

## Search packages — integration options (not locked)

### Option A — `Search-Package` cmdlet (lean)

- Parameters (draft): `-Query`, `-PublisherId`, `-EndpointName`, `-Tag` (if added to schema later), `-MachinePlatform` (filter targets).
- Implementation: scan enabled endpoint roots (reuse `Get-PackageDefinitionJsonPathsUnderDirectory` / definition resolution helpers); match query against display name, summary, `definitionId`, command names from discovery.
- **Pros:** Clear discoverability; fits module command family.  
- **Cons:** Performance on large catalogs; needs trust/unsigned policy when loading definitions for search only.

### Option B — Search via catalog manifest (depends on P5)

- HTTPS catalog publishes `index.json`; search reads manifest first, loads only matching definitions.
- **Pros:** Scales for Eigenverft online catalog.  
- **Cons:** Depends on PROJECT-TODO P5 manifest; filesystem endpoints still need scan or local index.

### Option C — Documentation-only workaround

- Document `Get-ChildItem` + `Select-String` on endpoint folder until A or B ships.
- **Pros:** Zero code.  
- **Cons:** Not product-quality UX.

**Soft lean:** **Option A** for team filesystem endpoints; **Option B** as accelerator when manifest exists.

---

## Package state — integration options (not locked)

### Option A — Format `Get-PackageState` default output

- Add formatted view (tables via `Format-Table` / custom view scriptblock) as default; keep structured object with `-PassThru` or `-Raw`.
- Highlight: install slot, version, ownership kind, last operation status, restart required.

### Option B — Separate `Show-PackageState` wrapper

- Pretty printer only; `Get-PackageState` stays data-centric.
- **Risk:** Two commands for one concept.

**Soft lean:** improve **default experience of `Get-PackageState`** (Option A) without breaking automation that consumes objects today.

---

## Future implementation checklist

Reference only.

1. Agree search cmdlet name and parameters (`Search-Package` vs `Find-PackageDefinition`).
2. Define match rules (case-insensitive substring; which fields).
3. Implement endpoint scan + trust policy for load-only-search path.
4. Design default formatted output for `Get-PackageState` (and document `-Raw`).
5. Align with P5 catalog manifest when available.
6. Tests: search hit/miss; formatted state snapshot tests.
7. README + TODO-DOCUMENTATION: document search and state commands in “First assignment” / concepts chapters.

### Phased delivery

| Phase | Deliverable |
|-------|-------------|
| 1 | `Search-Package` over filesystem endpoints |
| 2 | Formatted default `Get-PackageState` |
| 3 | Manifest-backed search (with P5) |
| 4 | Optional tags / full-text index (schema + catalog) |

---

## Resolved (facts about today)

- `Get-PackageState` and `Invoke-Package` are the primary public package commands today.
- Search is a **new command surface**, not an extension of `Invoke-Package`.

---

## Still open

- Whether search loads full schema validation per file or lighter “display-only” parse.
- Include assigned inventory version in search results vs catalog-only.
- PowerShell 5.1 table width / encoding for localized display names.
- Relation to future package profile / manager product (out of scope for base engine).

---

## Out of scope

- Changing assignment engine behavior (install, trust, dependencies).
- Fleet-wide search across machines (manager product).
- Replacing `Get-PackageState -Raw` for advanced debugging.
