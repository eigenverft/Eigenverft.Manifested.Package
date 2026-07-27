# Depot materialization hygiene

Status: **core work complete** (2026-07-21).

This file records the completed contract and keeps optional follow-up work separate. It is no longer an implementation plan.

## Completed contract

- `Invoke-PackageDepotMaterialize` is the sole public trusted-catalog fill command; the old sync alias is removed.
- `depotNamespace` separates publication groups in depot layout. Missing or blank values use `default`; shipped Eigenverft definitions use `evf`.
- Static artifact file sets and npm tarballs use one shared depot-distribution path with an explicit transport seam.
- Filesystem distribution uses `Copy-ResilientDirectoryTree` with size/timestamp comparison for already-current destinations, full-hash partial identity for actual copies, writer-owned partials, verified promotion, peer-win reconciliation, retries, and no `MirrorMode` cleanup.
- Several clients may publish the same bytes to one local or UNC destination concurrently. Matching final content is success for every writer.
- Distribution returns per-depot and per-file `Copied`, `Skipped`, or `Failed` results plus `AllMirrorsComplete`.
- `Invoke-Package -MaterializeOnly` succeeds when the complete file set is durable in any readable depot. Incomplete writable mirrors remain visible as warnings and per-file results.
- A normal Assigned run keeps the softer policy: it reports an incomplete secondary mirror but may continue when installation itself remains possible.
- No configured mirror targets and no default local depot are valid; a fully verified read-only share can be the durable source.
- `Invoke-PackageDepotMaterialize` tries all selected trusted packages by default and reports one result per package. `-FailFast` stops after the first failed package.
- Catalog fill does not change trust or depot configuration, install packages, delete old versions, or synchronize arbitrary depot trees.

## Verification

- Real multi-process filesystem tests cover same-content writers, different-content writers, final-file locks, and redundant-partial cleanup.
- Acquisition tests cover multi-file sets, different sources per file, partial-depot repair, idempotency, archive-derived files, a share-only configuration, and incomplete secondary mirrors.
- Flow tests pin durable-anywhere MaterializeOnly behavior and soft Assigned behavior.
- npm materialization uses the same shared file-set distribution transport.
- Depot-management tests prove default continue-on-error and opt-in `-FailFast` behavior.

## Intentionally not added

- **No catalog-fill `-Offline` switch.** Materialization exists to fill missing content. Authored candidates determine lookup order; shipped definitions check package depots before vendor fallbacks. Use `Get-PackageAssignmentPlan -Offline` or a selected `Invoke-Package -Offline` when the question is whether a package can run without network access.
- **No catalog-fill `-DepotId` switch.** Depot roles already select publish targets (`Writable` + `MirrorTarget`). Temporarily change the depot configuration when an operator intentionally wants a different target set.
- **No depot-to-depot sync command.** Package materialization resolves, verifies, stages, and distributes package file sets; it does not mirror arbitrary directory contents.

## Optional follow-up

1. Add a read-only whole-catalog/whole-mirror health report if operators need a single audit command beyond `Get-PackageDepot`, `Get-PackageAssignmentPlan`, and `Get-PackageState`.
2. Add non-filesystem publish transports, such as authenticated HTTP upload, behind the existing transport seam.
3. Design explicit old-version/orphan cleanup with dry-run output and safe retention rules. Normal materialization deliberately never deletes depot files.
4. Consider an opt-in strict all-mirrors mode for normal Assigned installs; the default remains soft.
5. If operators later need directional replication, add an explicit topology policy. Do not overload `searchOrder`, which remains read preference while `mirrorTarget` remains write intent.

These follow-ups are enhancements, not blockers for releasing the completed filesystem depot-materialization contract.
