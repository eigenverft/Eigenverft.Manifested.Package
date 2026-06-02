---
---

# Implementation Decision - Dependency wire top-level consolidation

Source Issue:
- Title: Consolidate dependency wire shape into one top-level object
- Issue File: `ISSUE-SCHEMA-DEPENDENCY-TOPLEVEL.md`
- Issue Recommendation: Choose Option A - Single `dependency` object with nested edges and policy

Output Artifact:
- Document Type: Implementation Decision
- File Name: `implementation-schema-dependency-toplevel.md`
- Rule: This document is separate from the issue document and must not be appended to it.
- Framework: `PROJECT-IMPLEMENTATION-FRAMEWORK.md` V0.7

## Implementation Rating

- Workflow State: Ready To Implement
- Churn: 3/4 Structural
- Assessment Depth: 3/4 Broad Mapping
- Reuse Need: 3/4 Broad Reuse Map
- Helper / Generalization Need: 3/4 Strong Candidate
- Repetition Risk: 3/4 High
- Placement Risk: 3/4 High
- Codebase Alignment: 3/4 Compatible
- Growth Pressure: 2/4 Noticeable
- Stakeholder Technical Lens: Maintainer / Test / Compatibility / Security / Trust
- Agent Suitability: 3/4 Strong
- Implementation Readiness: Ready

## Implementation Statement

Replace the split dependency authoring surface with one top-level `dependency` object in package-definition wire `1.9`. This is an intentional breaking wire replacement before public release.

Final authoring shape:

```json
{
  "schemaVersion": "1.9",
  "dependency": {
    "requires": [
      {
        "publisherId": "Eigenverft",
        "definitionId": "NodeRuntime",
        "versionRange": ">=16.0.0"
      }
    ],
    "policy": {
      "conflictsWith": [
        {
          "publisherId": "Eigenverft",
          "definitionId": "VSCodeUser"
        }
      ],
      "requiresAbsent": []
    }
  }
}
```

Required outcome:
- Package-definition JSON exposes exactly one dependency top-level object: `dependency`.
- Dependency edges move from top-level `dependencies[]` to `dependency.requires[]`.
- Peer policy moves from top-level `dependencyPolicy` to `dependency.policy`.
- Package definitions use `schemaVersion: "1.9"` and the 1.9 JSON schema path.
- Runtime validation supports 1.9 and rejects 1.8 package definitions.
- Top-level `dependencies[]` and top-level `dependencyPolicy` are invalid in the final implementation.
- Shipped Eigenverft definitions are migrated, revision-bumped, and re-signed.
- Dependency planning, direct recursion fallback, removal scanning, and schema validation all read the unified model.

Non-goals:
- Do not change dependency version-range grammar.
- Do not change dependency planning semantics or failure reason labels.
- Do not add persisted dependency plan artifacts, lockfiles, dry-run command surface, fleet orchestration, or `mutexGroup`.
- Do not fix unrelated ScriptAnalyzer warnings.
- Do not modify unrelated TODO/index/framework files.

## Stakeholder Technical Requirements

Maintainer / Structure:
- Dependency shape parsing must have one owner so schema validation, planner traversal, direct recursion fallback, and removal scanning do not each invent object checks.
- The final shape must read naturally in shipped JSON and schema descriptions.

Developer Experience:
- Catalog authors should find all dependency edge and policy fields in one place.
- Existing edge fields (`publisherId`, `definitionId`, `versionRange`) and policy reference fields keep their meaning under the new nesting.

Test / QA:
- Tests must prove 1.9 unified-shape schema acceptance, 1.8 rejection, old split-shape rejection, planner behavior, removal scanning, and signed shipped catalog verification.
- Shipped examples should be tested as real package-definition documents, not only synthetic fixtures.

Compatibility / Migration:
- Existing 1.8 package-definition documents are intentionally unsupported after this wire replacement.
- Documents using top-level `dependencies[]` or top-level `dependencyPolicy` must fail early with clear messages.
- No compatibility shim, alias reader, or post-release cleanup task is retained for the old split shape.

Security / Trust:
- Any changed shipped package-definition JSON must be signed with `Resign-PackageDefinition -Cert Eigenverft -KeepSchemaVersion`.
- Fresh-profile `Verify-PackageDefinitionCatalog -RequireTrusted` must pass after migration.

Release / Rollout:
- This is a breaking schema/wire cleanup before public release of the new dependency planner vocabulary.
- Bump package-definition schema to `1.9` before release because dependency-planning fields changed the public wire.

## Codebase Assessment

Assessment Depth:
- Broad Mapping.

Areas Inspected:
- `Schema/PackageDefinition/eigenverft-module-package-definition-1.8.schema.json`
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.ps1`
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_8.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.Dependencies.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.Remove.ps1`
- `Endpoint/Defaults/Eigenverft/*.json`
- `Eigenverft.Manifested.Package.Package.ConfigAndDefinitions.Tests.ps1`

Ownership Signals:
- JSON Schema is the authoring/editor contract and currently lists top-level `dependencies` plus `dependencyPolicy`.
- Runtime validation is PowerShell-only and owned by `DefinitionSchema.ps1` plus the wire helper file.
- Planner traversal currently reads `definition.dependencies`.
- Peer policy currently reads `definition.dependencyPolicy`.
- Direct recursion fallback and removal dependency scanning also read `definition.dependencies`.
- Shipped examples are signed package-definition documents and must remain catalog-trust valid after semantic edits.

Constraints:
- JSON schema uses `additionalProperties: false`, so top-level field changes must be precise.
- `definitionPublication.definitionSignature.signatureValue` is invalidated by JSON content changes.
- The module currently supports only package-definition schema `1.8`; this issue replaces that runtime support with `1.9`.

Assessment Judgement:
The change crosses schema, runtime normalization, planner traversal, removal scanning, shipped catalog examples, signing, and tests. A focused dependency-model helper is the main safeguard against duplicate wire-shape logic.

## Reuse Map

Reuse Directly:
- Existing dependency reference fields: `publisherId`, `definitionId`, `versionRange`.
- Existing policy reference fields: `publisherId`, `definitionId`, `versionRange`.
- Existing version-range parser and validator.
- Existing planner graph, version selection, and policy enforcement logic.
- Existing signing and catalog verification commands.

Extend:
- Create schema 1.9 authoring schema with one top-level `dependency` object.
- Rename or replace the wire helper path for schema 1.9.
- Update planner and executor reads to use a normalized dependency model.
- Update shipped catalog tests to assert unified dependency shape.

Avoid Duplicating:
- Do not repeat dependency-shape parsing in planner, executor, and removal files.
- Do not reimplement version-range grammar.
- Do not reimplement policy reference validation differently from edge validation.
- Do not sign JSON by editing `signatureValue` manually.

## Shared Helper / Generalization Check

Helper Candidate:
- `Get-PackageDefinitionDependencyModel_1_9`

Proposed Owner:
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_9.ps1`

Expected Output:

```powershell
[pscustomobject]@{
    Shape          = 'Unified'
    Requires       = @(...)
    Policy         = $policyObjectOrNull
    ConflictsWith  = @(...)
    RequiresAbsent = @(...)
}
```

Required Behavior:
- Read only `dependency.requires[]` and `dependency.policy`.
- Throw when top-level `dependencies` exists.
- Throw when top-level `dependencyPolicy` exists.
- Treat missing `dependency` or missing `dependency.requires` as invalid.
- Treat `dependency.requires: []` as valid.

## Repetition Check

Likely Repetition Points:
- Required property validation in `DefinitionSchema.ps1`.
- Detailed wire validation in `DefinitionSchema.Wire1_9.ps1`.
- Planner traversal in `Resolve-PackageDependencyPlanNode`.
- Peer-policy scan in `Test-PackageDependencyPlanPeerPolicy`.
- Direct recursion fallback in `Resolve-PackageDependencies`.
- Removal parent dependency scanning in `Package.Remove.ps1`.
- Test fixture creation and shipped JSON assertions.

Control:
- Introduce one dependency-model helper and call it from all runtime readers.
- Keep all authoring-shape error messages consistent around `dependency`, `dependency.requires`, and `dependency.policy`.
- Update test helpers to emit unified shape by default.

## Implementation Options

Option A1 - Breaking schema 1.9 unified dependency object:
- Resolution: Full.
- Description: Replace schema 1.8 support with schema 1.9 support, migrate shipped JSON to `dependency.requires[]` and `dependency.policy`, and reject all old split-shape documents.
- Fit: Recommended. It matches the release intent and leaves no compatibility cleanup behind.

Option B1 - Corrective schema 1.8 unified object with compatibility:
- Resolution: Partial.
- Description: Patch 1.8 and keep a legacy `dependencies[]` reader.
- Fit: Rejected. It contradicts the release decision to bump the wire and avoid compatibility debt.

Option C1 - Defer schema bump:
- Resolution: Deferred.
- Description: Leave 1.8 and schedule the cleanup later.
- Fit: Rejected. The split shape would remain visible before release.

## Implementation Fit Assessment

Option A1 is the strongest fit because dependency-planning fields already changed the public wire, the catalog is still pre-release enough to accept a breaking cleanup, and the strict 1.9 path prevents old split-shape compatibility from becoming durable debt.

## Implementation Recommendation

- Recommendation: Choose Option A1 - Breaking schema 1.9 unified dependency object.
- Support: 3/3 Well Supported.

Required Checks:
- Confirm final JSON shape is `dependency.requires[]` and `dependency.policy`.
- Confirm shipped definitions contain no top-level `dependencies` or `dependencyPolicy`.
- Confirm schema 1.8 is rejected as unsupported.
- Confirm old split-shape 1.9 fixtures fail clearly.
- Confirm changed shipped definitions are re-signed and trusted in a fresh profile.

## Final Placement Decision

Primary Placement:
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_9.ps1`

Supporting Placement:
- `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json`
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.DefinitionSchema.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.DependencyPlan.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.Dependencies.ps1`
- `Support/Package/Lifecycle/Eigenverft.Manifested.Package.Package.Remove.ps1`
- `Endpoint/Defaults/Eigenverft/*.json`
- `Eigenverft.Manifested.Package.Package.ConfigAndDefinitions.Tests.ps1`

Do Not Place:
- Do not put shape normalization in `Cmd.InvokePackage.ps1`.
- Do not put shape normalization only in `Package.DependencyPlan.ps1`.
- Do not add a persisted schema/artifact file.

## Churn and Growth Control

Churn Control:
- Keep the change limited to schema/wire validation, dependency-model consumers, shipped definitions, signing, and tests.
- Do not alter planner graph semantics.
- Do not alter version-range parser.
- Do not change package selection or catalog trust logic beyond schema-version defaults.

Growth Control:
- Add one helper for dependency model extraction instead of repeated conditionals.
- Keep policy-reference validation small and reuse existing validation loops.
- Review changed shipped JSON diff before signing.

Release Control:
- Re-sign only changed shipped package-definition JSON files.
- Verify in a fresh local profile because stale user trust inventory can make direct checks report valid-but-untrusted.

## Implementation Plan

1. Replace this implementation document with the strict 1.9 recommendation.
2. Create or rename the package-definition schema from `1.8` to `1.9`.
3. Replace schema/runtime support so `1.9` is the only supported package-definition version.
4. Add `Get-PackageDefinitionDependencyModel_1_9` and make all dependency readers use it.
5. Update wire validation to require `dependency.requires[]`, validate `dependency.policy`, reject top-level `dependencies`, and reject top-level `dependencyPolicy`.
6. Migrate shipped package definitions to schema `1.9` and the unified dependency object.
7. Update test helpers and focused fixtures to emit 1.9 unified dependency shape.
8. Update tests to prove 1.8 rejection, split-shape rejection, unified-shape acceptance, planner behavior, removal scanning, and catalog trust.
9. Re-sign changed shipped definitions with `Resign-PackageDefinition -Cert Eigenverft -KeepSchemaVersion`.
10. Run targeted/full verification and ScriptAnalyzer assessment.

## Verification Plan

Targeted Pester:
- `Eigenverft.Manifested.Package.Package.ConfigAndDefinitions.Tests.ps1`

Required test cases:
- Unified `dependency.requires[]` and `dependency.policy` schema validates under schema `1.9`.
- Missing `dependency` fails.
- Missing `dependency.requires` fails.
- Empty `dependency.requires: []` validates.
- Top-level `dependencies` fails.
- Top-level `dependencyPolicy` fails.
- Schema `1.8` fails as unsupported.
- Planner resolves shipped `CodexCli` through `dependency.requires[]` to `NodeRuntime`.
- Planner resolves shipped `Qwen35_9B_Q6_K_Model` through `dependency.requires[]` to `LlamaCppRuntime`.
- Planner rejects shipped `VSCodeRuntime, VSCodeUser` through `dependency.policy.conflictsWith[]`.
- Direct dependency fallback still works when no approved plan is passed.
- Removal dependency scanning still finds parent dependencies through the normalized model.
- Signed shipped catalog verifies after migration and signing.

Commands:

```powershell
pwsh -NoLogo -NoProfile -File 'src/prj/Eigenverft.Manifested.Package.Test/Invoke-ModuleTests.ps1' -Path 'src/prj/Eigenverft.Manifested.Package.Test/Eigenverft.Manifested.Package.Package.ConfigAndDefinitions.Tests.ps1' -Mode Detailed
pwsh -NoLogo -NoProfile -File 'src/prj/Eigenverft.Manifested.Package.Test/Invoke-ModuleTests.ps1' -Mode Detailed
Get-Content -Raw 'src/prj/Eigenverft.Manifested.Package/Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json' | ConvertFrom-Json | Out-Null
git diff --check
```

Fresh-profile trust verification:

```powershell
$env:LOCALAPPDATA = Join-Path $env:TEMP ('evf-fresh-localappdata-' + [guid]::NewGuid().ToString('N'))
Import-Module '.\src\prj\Eigenverft.Manifested.Package\Eigenverft.Manifested.Package.psd1' -Force
Verify-PackageDefinitionCatalog -Path '.\src\prj\Eigenverft.Manifested.Package\Endpoint\Defaults\Eigenverft' -RequireTrusted
```

ScriptAnalyzer:
- Run `Invoke-ModuleScriptAnalyzer.ps1` for assessment.
- Do not fix unrelated warnings in this scope.
- If new scoped warnings appear, fix them before release assessment.

## Agent Instructions

- Start by reading this document and `ISSUE-SCHEMA-DEPENDENCY-TOPLEVEL.md`.
- Do not implement a different wire shape without updating this document first.
- Keep scope limited to dependency top-level consolidation and the schema 1.9 breaking migration.
- Use structured JSON helpers for shipped definition edits.
- Do not manually edit `definitionSignature.signatureValue`.
- Re-sign after all JSON edits, not before.
- Do not preserve old `dependencies[]` or `dependencyPolicy` runtime compatibility.
- Keep planner semantics unchanged except for reading the normalized dependency model.
- Do not touch unrelated ScriptAnalyzer issues, TODO/index files, or search command work.
- After implementation, create `post-implementation-schema-dependency-toplevel.md` using this framework.

## Extracted Work

Optional:
- [ ] Update catalog authoring guidance after the unified dependency shape lands.
  Reason: Agent and maintainer docs should point at `dependency.requires[]` and `dependency.policy` once the implementation is complete.
