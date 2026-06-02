# Shipped polish (no open TODO)

Changes landed in `src/prj/Eigenverft.Manifested.Package` without a remaining scratchpad:

| Change | Date |
|--------|------|
| ExecutionCore module headers (`ExecutionEngine` → `ExecutionCore` in comments) | 2026-05-30 |
| `Get-PackageState` default formatted tables (`-Raw` unchanged) | 2026-05-30 |
| `[OUTCOME]` version-change vocabulary in `Get-PackageOutcomeSummary` | 2026-05-30 |
| `Search-Package` over enabled `moduleLocal` / `filesystem` endpoints | 2026-06-01 |

Removed scratchpads: `TODO-MAINTENANCE.md`, `TODO-COMMANDS-STATE.md`, `TODO-COMMANDS-OUTCOME.md`, `TODO-SCHEMA.md`, `TODO-ENDPOINTS-DISCOVERY.md`, `TODO-COMMANDS.md`, `TODO-COMMANDS-SEARCH.md`, `PROJECT-TODO.md`.

---
---

## 🔁 Post-Issue Review — Search-Package endpoint scan implementation

Framework: Project Implementation / Post-Issue Framework V0.3.

- 🏷 Post-Issue Review Rating
  - ✅ Outcome Fit: 4/4 Complete ▰▰▰▰
  - 🧩 Option Match: 4/4 Exact ▰▰▰▰
  - ♻️ Reuse Fit: 3/4 Good ▰▰▰▱
  - 📍 Placement Fit: 4/4 Native ▰▰▰▰
  - 📏 Growth Impact: 2/4 Noticeable ▰▰▱▱
  - 👥 Stakeholder Fit: 🟢 Satisfied
  - 🧪 Verification Strength: 4/4 Strong ▰▰▰▰
  - 🧹 Adjustment Need: 🟢 None

### 📖 Reread Pass

Issue Reread:
- The original issue asked for package discovery without a known `DefinitionId`, returning enough metadata to confidently run `Invoke-Package`.
- The implemented result satisfies the Phase 1 scope: enabled `moduleLocal` / `filesystem` endpoint scan, trust-aware results, query matching, selected version, and platform availability.
- The original issue intentionally left large/remote catalog acceleration to the manifest and `httpsCatalog` tracks; those remain separate.

Implementation Decision Reread:
- No separate pre-coding implementation decision document existed when this implementation started; this framework was applied after coding.
- The chosen issue option was Option A: `Search-Package` over enabled endpoint scan.
- The implementation followed Option A and intentionally deferred manifest-backed search.

Code Reread:
- Reread the new command file, module load/export wiring, test imports, export tests, behavior tests, README changes, and the resolved scratchpad.
- Nearby existing patterns reread included `Invoke-Package`, definition reference scanning, endpoint inventory helpers, trust eligibility, and 1.8 package selection.

Behavior Reread:
- `Search-Package` now scans enabled endpoint roots, filters by query/publisher/endpoint/platform, applies catalog trust eligibility, validates matching definitions, and returns invoke-ready rows.
- Assignment, removal, dependency resolution, endpoint materialization, and `httpsCatalog` behavior did not change.

### ✅ Implementation Result

Changed:
- Added `Search-Package` to `FunctionsToExport`.
- Dot-sourced the command in the module and test imports.
- Added README discovery examples and current-state wording.
- Moved the resolved search scratchpad record into this shipped decisions log.

Added:
- `Commands/Package/Eigenverft.Manifested.Package.Cmd.SearchPackage.ps1`.
- Tests for search hits, trust filtering, current-platform filtering, exported parameters, and command file placement.

Removed:
- No runtime behavior or public command was removed.

Not Changed:
- `Invoke-Package` remains the assignment/removal entry point.
- `httpsCatalog` still remains future work.
- Search does not materialize candidate definitions into the local endpoint store.

### 👥 Stakeholder Technical Review

Maintainer / Structure:
- The new command lives beside package command surfaces, and helper functions stay local to the command file.
- Reuse of existing endpoint scan, schema validation, trust, and selection helpers keeps ownership clear enough for this churn level.

Developer Experience:
- Operators can search by friendly text or command name and get a ready `InvokeCommand`.
- README now exposes `Search-Package` early in quick start/current state.

Test / QA:
- Focused tests cover hit behavior, trust rejection, `-IncludeIneligible`, `-CurrentPlatformOnly`, export shape, and command placement.
- Full suite passed after implementation.

Support / Diagnostics:
- Search rows include trust status/reason, signature status, endpoint name, endpoint source kind, definition path, selection error, and selected target metadata.

Release / Rollout:
- The public command is explicitly exported and covered by export tests.
- No persisted schema or inventory migration is introduced.

Compatibility / Migration:
- Existing commands and endpoint inventory shape are preserved.
- Search honors existing catalog-trust policy instead of inventing a parallel trust path.

Security / Trust:
- Ineligible catalog rows are hidden by default and visible only with `-IncludeIneligible`.
- Search reuses existing trust eligibility semantics and schema validation.

Performance / Cost:
- Phase 1 uses live scan, matching the discovery decision for small catalogs.
- Large-catalog performance remains tracked under manifest/HTTPS work.

User-Facing Behavior:
- Users can discover packages without opening raw JSON or memorizing `DefinitionId`.

Stakeholder Fit Judgement:
The implementation satisfies the maintainer, developer-experience, test, compatibility, security/trust, and user-facing requirements for the scoped Phase 1 search command.

### ♻️ Reuse Review

Reused:
- `Get-PackageEnabledEndpointSources`
- `Resolve-PackageEndpointRootPath`
- `Select-PackageDefinitionCandidatesFromEndpointScanRoot`
- `Resolve-PackageDefinitionCandidateTrustEligibility`
- `Read-PackageJsonDocument`
- `Assert-PackageDefinitionSchema`
- `Resolve-PackageEffectivePackage_1_8`
- Existing test fixture helpers such as `New-TestPackageGlobalDocument`, `New-TestVSCodeDefinitionDocument`, `New-TestPackageRelease`, and `Write-TestPackageDocuments`.

Extended:
- Public package command surface via a new command file.
- Export and command placement tests.
- Config/definition test suite around endpoint scan behavior.

Possibly Missed:
- No existing aggregate search command existed to extend.
- Some config parsing duplicates `Get-PackageConfig` trust/default extraction; acceptable for now, but a shared read-only settings helper could be considered if more catalog-inspection commands appear.

Reinvented:
- No endpoint scanning, trust validation, or selection algorithm was reimplemented.

Reuse Judgement:
Reuse is good for normal churn. The only notable duplication is small settings extraction inside the command, which avoids expanding shared config APIs before another caller proves the need.

### 📍 Placement Review

Current Placement:
- Runtime command: `Commands/Package/Eigenverft.Manifested.Package.Cmd.SearchPackage.ps1`.
- Wiring: module `.psm1`, manifest `.psd1`, and test import file.
- Tests: package config/definition behavior suite and exports/state suite.

Why It Fits:
- Search is a public package command, not endpoint management, depot management, or trust management.
- Package command folder already owns `Invoke-Package` and `Get-PackageState`.
- Tests sit next to existing endpoint/config/export behavior coverage.

Why It May Not Fit:
- If search grows manifest parsing or remote indexing, some helper logic may need to move into package schema/endpoint support modules.

Alternative Placement:
- Support-layer search service module could be justified later if `httpsCatalog` or manifest-backed search needs shared internals.

Placement Judgement:
Accept placement. The command file is the native public surface for Phase 1 and can later delegate to support helpers if search broadens.

### 📏 Growth Review

Files Affected:
- `Cmd.SearchPackage.ps1`: new focused command file; noticeable but contained growth.
- `.psm1`, `.psd1`, and test imports: one-line wiring changes.
- Config/definition tests: added focused behavior tests.
- Exports/state tests: added parameter/export coverage.
- README/docs: updated shipped status and user-facing discoverability.

Functions / Classes Affected:
- Existing runtime functions were not expanded.
- New helper functions are local to the command file and named around search responsibilities.

Growth Accepted:
- A new public command file is acceptable because it avoids growing `Invoke-Package` or endpoint-management files.

Growth Concern:
- The search command file mixes settings read, candidate scan, matching, projection, and selection summary. It is still coherent, but future manifest search should not simply append remote-index logic here.

Extraction Triggered:
- No.

Growth Judgement:
Growth is acceptable for Phase 1. Extract only when a second search path or another read-only catalog command needs shared internals.

### 🧩 Structure Review

Structure Fit:
- Compatible and native for a public command addition.

Coupling:
- Coupling increases only to existing package schema, endpoint, trust, and selection helpers; this is intentional reuse.

Responsibility:
- Responsibilities remain clear: search command coordinates read-only catalog discovery; existing helpers still own scan, trust, schema, and selection.

Abstraction:
- No new shared abstraction was added.
- Local helper functions clarify command flow without creating cross-module API surface.

Testability:
- The command is testable through existing filesystem endpoint fixtures and Pester mocks for config/inventory paths.

Structure Judgement:
Accept. Defer any support-layer extraction until manifest-backed search or another caller creates real pressure.

### 🧪 Verification Review

Checks Performed:
- Full Pester suite: `Passed=264 Failed=0`.
- ScriptAnalyzer Pester test: passed as part of full suite and targeted run.
- Static content Pester test: passed as part of full suite and targeted run.
- `git diff --check`: no whitespace errors; only CRLF normalization warnings.
- Manual smoke: imported module and `Search-Package -Query code -Platform windows -Architecture x64 -ReleaseTrack stable` returned results.

Checks Missing:
- No performance benchmark on large filesystem catalogs.
- No `httpsCatalog` behavior test, because that endpoint kind remains reserved/future.

Regression Risk:
- Low for existing package assignment behavior; medium-low for new search behavior until real team catalogs exercise it.

Verification Judgement:
Verification is strong for the shipped Phase 1 scope.

### 🧹 Adjustments

Required Before Acceptance:
- [x] None.

Recommended:
- [ ] Keep manifest-backed search under [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md) and [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md), not as hidden growth in this command.

Optional:
- [ ] Consider a shared read-only package settings helper if another command needs the same trust/default extraction.
- [ ] Consider installed-state enrichment only if operators ask for search results to show assigned/current state.

No Adjustment Needed:
- The Phase 1 implementation itself needs no adjustment before acceptance.

### 🌱 Extracted Work

Required:
- [ ] None.

Optional:
- [ ] Manifest-backed search for large/remote catalogs.
  Reason: Already belongs to manifest and `httpsCatalog` TODO tracks; it is separate from Phase 1 local scan.
- [ ] Optional tags/full-text index.
  Reason: Requires schema/catalog support before implementation.
- [ ] Assigned-inventory enrichment.
  Reason: Useful only if user workflows need installed-state-aware search results.

### 🏁 Acceptance Decision

- [2026-06-01 15:27 | Author: Codex | Decision: Accept | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
The implementation matches the selected Option A, reuses existing endpoint/trust/schema/selection machinery, lives in the package command surface, has focused behavior tests plus full-suite verification, and keeps future manifest-scale work separate.

Final Condition:
Phase 1 `Search-Package` is considered done when the current code and docs remain as implemented, the full Pester suite stays green, and future manifest/index work remains tracked separately rather than folded into this accepted scope.

**Backlog index:** [TODO-INDEX.md](TODO-INDEX.md) · **Draft decisions** (need your sign-off): linked from that index.
