---
---

# Post-Implementation - Dependency wire top-level consolidation

Source Issue:
- Title: Consolidate dependency wire shape into one top-level object
- Issue File: `ISSUE-SCHEMA-DEPENDENCY-TOPLEVEL.md`
- Implementation File: `implementation-schema-dependency-toplevel.md`
- Framework: `PROJECT-IMPLEMENTATION-FRAMEWORK.md` V0.7

## Implementation Summary

Implemented the recommended breaking schema `1.9` migration. Package-definition JSON now uses one top-level `dependency` object, with dependency edges under `dependency.requires[]` and peer policy under `dependency.policy`.

The old split top-level wire is intentionally not preserved:
- top-level `dependencies[]` is rejected
- top-level `dependencyPolicy` is rejected
- schema `1.8` is no longer a supported package-definition version

## Key Changes

- Replaced package-definition schema `1.8` with `eigenverft-module-package-definition-1.9.schema.json`.
- Replaced runtime schema support with schema `1.9` dispatch and wire helper naming.
- Added `Get-PackageDefinitionDependencyModel_1_9` as the shared dependency model projection.
- Updated planner, direct dependency recursion, and removal dependency scanning to consume the unified dependency model.
- Updated signing defaults so non-`-KeepSchemaVersion` signing/removal normalizes to schema `1.9`.
- Migrated all shipped Eigenverft definitions to schema `1.9` and `dependency.requires[]` / `dependency.policy`.
- Re-signed all 18 shipped Eigenverft definitions with `Resign-PackageDefinition -Cert Eigenverft -KeepSchemaVersion`.
- Updated tests and fixtures to emit and assert the strict 1.9 wire.

## Verification Results

- Targeted config/definition Pester: passed, 108 tests.
- Full module Pester: passed, 276 tests.
- Schema JSON parse check: passed.
- Fresh-profile `Verify-PackageDefinitionCatalog -RequireTrusted`: passed, 18 checked, 18 valid, 18 trusted.
- `git diff --check`: passed; Git reported line-ending warnings only.
- ScriptAnalyzer assessment: issues found, 18 warning-level issues across 7 files.

## Release Assessment

Dependency feature and signed shipped catalog verdict:
- Ready for public release.

Repository-level release risk:
- ScriptAnalyzer still reports warning-level issues in existing module files. These were not fixed because this pass was scoped to dependency wire/schema/catalog work.

## Follow-Up

- Update public authoring documentation to describe schema `1.9` and `dependency.requires[]` / `dependency.policy`.
