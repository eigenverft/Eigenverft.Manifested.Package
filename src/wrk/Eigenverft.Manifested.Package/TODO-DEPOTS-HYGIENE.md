# Filesystem depot hygiene

**Status:** Open, reduced after artifact-file-set implementation
**Priority:** 2/7 Backlog
**Recommendation:** Add an on-demand `Test-PackageDepot` audit; do not scan every depot during every assignment.

## Already shipped

- Artifact files have safe, unique relative paths.
- Acquisition uses temporary staging files and independently verifies every required member.
- Existing valid depot members are reused; missing or invalid members are reacquired.
- Materialize-only succeeds only when a complete verified artifact set exists in a durable depot.
- Distribution compares known source/target files and repairs mismatches.

These behaviors close the former "partial artifact set is durable" gap. They do not identify unrelated or interrupted files elsewhere in a depot.

## Remaining gap

There is no standalone depot-wide audit for:

- orphaned files outside known package layouts;
- interrupted `.partial`/`.tmp` or malformed paths;
- duplicate case-insensitive paths;
- invalid known artifacts not currently selected by an invocation;
- incomplete package-version directories;
- unsafe or unexpected links/reparse points.

## Remaining contract

1. Export `Test-PackageDepot` for selected or all configured filesystem depots.
2. Return structured findings with depot ID, path, severity, rule, and remediation.
3. Default to read-only inspection; never delete automatically.
4. Derive expected layout and verification facts from package definitions/depot conventions rather than hard-coded filenames.
5. Decide separately whether mirror writes need temp-then-rename protection against interrupted copies.

## Open decisions

- Audit only reachable/current catalog versions or all physical depot content.
- Which reparse-point and orphan rules are warnings versus errors.
- Whether a later explicit repair command quarantines files; deletion must never be implicit.

## Acceptance

Maintainers can distinguish a complete verified package directory from stray, interrupted, unsafe, or corrupt depot content without running an installation.
