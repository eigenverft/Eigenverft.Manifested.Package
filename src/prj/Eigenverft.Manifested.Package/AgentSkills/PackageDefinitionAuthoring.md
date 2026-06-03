# PackageDefinitionAuthoring

Use this skill when creating or editing Eigenverft package-definition JSON for an endpoint catalog. This skill is for package-definition artifacts only; it is not for changing the package engine, dependency planner, trust model, schema, or runtime install code.

This file is the agent skill. It is normally shown after a prepended **Runtime endpoint status** section (machine-specific paths and selection). The same file also lives in the git repository for contributors who clone and extend the module.

## Start Here

Read the **Runtime endpoint status** section at the top of this text first (if it is present).

1. If `Selection` is `(none)` or `TroubleshootingKind` is set, read **Troubleshooting for agents** under **Authoring Targets And Endpoints** and explain the endpoint situation to the user. Do not edit package-definition JSON until a usable authoring root exists or the user chooses a different target.
2. If `Selection` names an endpoint and path, author at `<Selection-path>\<publisherId>\<definitionId>.json` (use the task or maintainer request for `publisherId` and `definitionId`).
3. Complete **Required First Step** (schema and task inputs) before any JSON edit.
4. Follow **Authoring Workflow** through validate, sign, verify, and handoff.

If there is no **Runtime endpoint status** section at the top, you are reading the repository copy: use `Get-PackageEndpoint`, or load this skill through the installed module so runtime status is prepended.

## Required First Step

Before making any JSON edit, read the complete task/request instructions and the complete package-definition schema file:

- `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json` under the installed module root (`(Get-Module Eigenverft.Manifested.Package).ModuleBase`)
- the schema root `description` and `x-eigenverftAgentHint`
- every maintainer instruction, issue, or request that defines the package intent

Do not skim these inputs or infer missing rules from nearby JSON alone. If the instructions and schema disagree, or if either cannot be read fully, stop and ask the maintainer before editing.

## Authoring Targets And Endpoints

Package definitions live under endpoint catalog roots. Scanning, trust, and `Invoke-Package` use all enabled endpoints in `PackageEndpointInventory.json`. **Authoring** uses only endpoints marked `authoringTarget: true`. That flag is maintainer intent only; it does not grant trust, bypass signing, or prove the path is writable.

The authoring path is whatever **Runtime endpoint status** shows in `Selection` (or `Get-PackageEndpoint` when the runtime block is absent). Any endpoint with `authoringTarget: true` can be valid when writable—including `moduleDefaults`, which usually resolves to the module's `Endpoint/Defaults` tree, and team `filesystem` shares when those are marked. Do not assume a path without checking `Selection`; do not treat `Endpoint/Defaults` as excluded from authoring when it is the selected target.

### Status values

| Status | Meaning |
|--------|---------|
| `Ready` | Marked, writable, enabled, and effective for package scans. Preferred selection. |
| `DraftOnly` | Marked and writable, but disabled or not effective. Usable for draft storage; `Invoke-Package` will not scan there until enabled. |
| `Blocked` | Marked but path missing, unreachable, or not writable. Skipped for selection. |
| `Unsupported` | Marked but kind is not `moduleLocal` or `filesystem` (for example `httpsCatalog` in v1). Skipped for selection. |

Selection prefers `Ready` over `DraftOnly`, then applies `searchOrder` (`First` = lowest order, `Last` = highest). `authoringTarget` is not inferred from writability alone.

### Managing authoring intent

```powershell
Get-PackageEndpoint
Add-PackageEndpoint -EndpointName 'teamCatalog' -BasePath '\\share\PackageEndpoint' -AuthoringTarget
Set-PackageEndpoint -EndpointName 'teamCatalog' -AuthoringTarget
Set-PackageEndpoint -EndpointName 'teamCatalog' -NoAuthoringTarget
```

Or set `"authoringTarget": true` on an endpoint object in `PackageEndpointInventory.json`.

### Troubleshooting for agents

Explain endpoint configuration to the user when runtime status shows:

- **NoMarkedTarget** — No endpoint has `authoringTarget: true`. Name the inventory file, summarize configured endpoints from `Get-PackageEndpoint`, and describe how to mark or add an authoring target.
- **AllMarkedBlocked** — Targets are marked but none are writable or supported. List each skipped endpoint with resolved path (if any) and skip reason; suggest fixing permissions, creating the folder or share, enabling the endpoint, or choosing another marked endpoint.

Do not silently continue as if a usable authoring root exists.

### Definition layout under a target root

`<publisherId>/<definitionId>.json` under the resolved authoring path from **Runtime endpoint status** or `Get-PackageEndpoint`.

### Publication finalization

Before final handoff for definitions intended for trusted catalog use on an enabled scan endpoint:

1. Finish all JSON edits under the selected authoring root using the layout above.
2. Run `Test-PackageDefinitionCatalog` on the changed file.
3. Sign or re-sign with the maintainer-approved profile, commonly:

```powershell
Resign-PackageDefinition -Path '<definition.json>' -Cert Eigenverft -KeepSchemaVersion
```

4. Run `Test-PackageDefinitionCatalog -RequireTrusted` on the changed file or endpoint folder.
5. Run `Verify-PackageDefinitionSignature -RequireTrusted` for the file, or `Verify-PackageDefinitionCatalog -RequireTrusted` for the folder.
6. Check `git status --short` when working in a repository so new JSON files are not forgotten.
7. In the handoff, state whether validation, signing, and trust verification passed, or name the blocker.

Do not leave a definition unsigned when it is meant for a trusted, enabled scan endpoint, unless the maintainer explicitly asked for draft-only unsigned work. A `DraftOnly` authoring target is for drafts until the endpoint is enabled and effective.

## When To Use

- Create a new package-definition JSON file.
- Update an existing package-definition JSON file.
- Prepare a catalog change for validation, signing, review, and publication.
- Review agent-authored package JSON before it can be trusted or installed.

## Product Boundary

Package definitions are declarative, reviewable artifacts for a Windows-focused local package-assignment engine. Agents may draft and validate JSON, but production trust and install require human review and trusted signing or endpoint policy.

Do not add arbitrary hook systems, engine behavior, fleet orchestration, or resolver design while authoring package JSON. If the requested package cannot be represented declaratively, stop and ask for a maintainer decision. The module is not a fleet manager, lockfile system, or open-ended script runner.

## Inputs To Read First

- `Selection` path from **Runtime endpoint status**, or `Get-PackageEndpoint` when the runtime block is absent
- Nearby definitions under the same `publisherId` at that root
- Nearby signed examples under `Endpoint/Defaults/Eigenverft` when `Selection` is `moduleDefaults` (same catalog tree as that target root)
- Command help for validation, signing, or trust when usage is unclear

## PowerShell Host Check

Do not assume the current shell can import the module. Some agents run commands in PowerShell 7 (`pwsh`) while the module may be installed only for Windows PowerShell 5.1 (`powershell.exe`), or the reverse. Check both hosts before running validation, signing, or trust commands.

Check the current host:

```powershell
$PSVersionTable.PSEdition
$PSVersionTable.PSVersion
Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name, Version, ModuleBase
```

Check Windows PowerShell 5.1 from an agent shell:

```powershell
powershell.exe -NoProfile -Command "$PSVersionTable.PSEdition; $PSVersionTable.PSVersion; Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name,Version,ModuleBase"
```

Check PowerShell 7 from Windows PowerShell:

```powershell
pwsh -NoProfile -Command "$PSVersionTable.PSEdition; $PSVersionTable.PSVersion; Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name,Version,ModuleBase"
```

Run `Test-PackageDefinitionCatalog`, signing, and trust commands in the host where `Eigenverft.Manifested.Package` is available, or import the repo/module path explicitly when working inside the source tree. If the module is available in only Windows PowerShell 5.1, call `powershell.exe`. If it is available in only PowerShell 7, call `pwsh`. If neither host can see the module, stop and ask for installation or an explicit module path.

## Authoring Workflow

1. Use **Start Here** and **Runtime endpoint status** when present; otherwise obtain paths with `Get-PackageEndpoint` or prepend runtime status via the module authoring guide entry point.
2. Start from schema 1.9 and a nearby example under the resolved authoring target.
3. Author drafts as unsigned: `definitionPublication.definitionSignature.kind = unsigned`.
4. Never fabricate, copy, or hand-edit `signatureValue`.
5. Keep endpoint layout as `<publisherId>/<definitionId>.json`.
6. Bump `definitionRevision` for every definition content change.
7. Keep scripts and acquisition behavior minimal, declarative, and reviewable.
8. Run `Test-PackageDefinitionCatalog` before signing or publishing.
9. Sign or re-sign only after content is stable.
10. Verify signature or catalog trust.
11. Check `git status --short` before handoff when using git so new JSON files are not accidentally left untracked.
12. Require human review before production trust, endpoint publication, or production `Invoke-Package`.

## Installer Kind Discovery

When the installer kind, silent arguments, extraction behavior, or package format is unclear, search the web first. Prefer official vendor documentation, release notes, package manager manifests, installer docs, and existing trusted package definitions. Do not start by analyzing the downloaded binary.

Discover whether the vendor ships multiple artifact kinds for the same product, such as portable archives, user installers, machine/admin installers, MSI packages, app-store packages, or architecture-specific builds. Prefer a vendor-published portable archive when it fits the package intent. Otherwise prefer a user-scoped installer over a machine/admin installer. Use admin or machine-wide installers only when the package definition explicitly targets that behavior or no suitable portable/user artifact exists.

Do not mix artifact kinds by accident. If the existing definition is for a user installer, update from the user-installer source. If it is for a portable/runtime package, update from the matching portable/runtime source. If the package intent is unclear, stop and ask the maintainer before switching installer kind.

Use binary inspection only as a fallback after documentation and reputable metadata sources are unavailable or contradictory. If the installer format still cannot be established confidently, stop and ask for maintainer guidance instead of guessing.

## Existing Definition Latest Version Update

Use this workflow when asked to check or update an existing package definition to the latest upstream version. This is an authoring/update task and is independent of the definition's install-time `versionSelection` policy.

1. Read the full existing definition before changing it.
2. Identify every target artifact that belongs to the definition's release, for example x64 and arm64 entries.
3. Search official vendor release channels, update services, release notes, download pages, package metadata, and package-manager manifests for the latest stable version. Some vendors expose multiple official "latest" sources, and they can disagree temporarily.
4. Compare all discovered official sources. Record which source matches the package's artifact kind and whether any other official source disagrees. Do not use unofficial mirrors as the source of truth.
5. If official sources disagree, verify the concrete artifact endpoint, version text, hash, and publisher signature for the intended artifact kind before editing. If the newest valid artifact cannot be proven, stop and report the ambiguity.
6. If the definition already contains the latest stable version and all hashes still match the upstream artifacts, do not edit or re-sign the JSON. Report that it is current.
7. If a newer stable version exists, update the release entry or add a new release following the existing file's retention pattern. If retention is unclear, add the new release and leave older releases unchanged.
8. Refresh every target artifact for that release together. Do not update only one architecture when the definition contains multiple stable targets.
9. Download each upstream artifact through the source model declared in the definition, compute the declared `contentHash`, and verify any declared `publisherSignature`.
10. Bump `definitionRevision`, refresh `publishedAtUtc`, then sign or re-sign after all semantic JSON edits are finished.
11. Run **Publication finalization** before handoff.

Stop if the latest version cannot be proven from official sources, an artifact for any required target is missing, a hash cannot be verified, or an expected publisher signature no longer matches.

## Self-Check Checklist

- `publisherId`, `definitionId`, display metadata, and revision match the requested package.
- `schemaVersion` is `1.9`.
- Deprecated top-level `dependencies` and `dependencyPolicy` are not used.
- Dependencies use `dependency.requires[]`.
- Coexistence policy uses `dependency.policy.conflictsWith[]` or `dependency.policy.requiresAbsent[]` only when the maintainer intent is explicit.
- Download URLs, checksums, installer arguments, and materialization paths are reviewable.
- No credentials, tokens, local private paths, or machine-specific secrets are embedded.
- `definitionSignature.kind` is `unsigned` only while drafting or when explicitly requested.

## Catalog Validation

Validate a single draft file while authoring:

```powershell
Test-PackageDefinitionCatalog -Path '<definition.json>'
```

Validate an endpoint folder before publication:

```powershell
Test-PackageDefinitionCatalog -Path '<endpoint-root>' -RequireTrusted -ErrorOnFailure
```

Treat validation issues as blockers until a maintainer says otherwise. Do not use `Verify-PackageDefinitionCatalog` as a replacement for schema and reference validation; it checks signature and trust summary, while `Test-PackageDefinitionCatalog` checks parse, schema, signature/trust status, duplicate identities, and static dependency references.

## Signing And Signing-Profile Discovery

Use `Sign-PackageDefinition` for first signing and `Resign-PackageDefinition` for changed signed definitions. Use `-KeepSchemaVersion` when re-signing a stable schema version.

If signing is required and no explicit `-Cert` was supplied by the maintainer, discover existing signing profiles first:

```powershell
Get-PackageSigningProfile -PublisherId '<publisherId>'
```

Selection rules:

- Zero matching profiles: stop and ask the maintainer to create a profile with `New-PackageSigningCertificate` or provide an explicit signing certificate/profile.
- Exactly one matching profile: use `SigningDescriptorPath` when present; otherwise use `PfxPath`.
- Multiple matching profiles: stop and ask the maintainer to choose the exact profile or certificate.
- Public `.cer` and `.pem` files are trust/verification material, not signing certificates. Do not pass them as signing certs.

Example re-sign after one unambiguous profile was selected:

```powershell
Resign-PackageDefinition -Path '<definition.json>' -Cert '<SigningDescriptorPath-or-PfxPath>' -KeepSchemaVersion
```

Do not fabricate signatures, edit `signatureValue` by hand, auto-trust unknown keys, or use runtime trust bypasses as a publication workflow.

## Signature And Catalog Verification

Verify one signed file:

```powershell
Verify-PackageDefinitionSignature -Path '<definition.json>' -RequireTrusted -ErrorOnFailure
```

Verify a signed endpoint catalog:

```powershell
Verify-PackageDefinitionCatalog -Path '<endpoint-root>' -RequireTrusted
```

If trust verification fails, stop. A maintainer must decide whether to import, trust, replace, or block a signing certificate with `Import-PackageTrust`, `Trust-PackageSigningCertificate`, or related trust commands.

## Human Review And Publish Gate

Before production publication or production install, a human reviewer must approve:

- package identity and revision;
- acquisition source and integrity checks;
- install/materialization behavior;
- dependency and policy intent;
- validation report;
- signing profile/certificate choice;
- signature and catalog trust verification.

Only after human review should the definition be published to an endpoint. Optional `Invoke-Package` testing should happen on a disposable machine or isolated test environment first.

## Common Mistakes

- Using retired top-level `dependencies` instead of `dependency.requires`.
- Using retired top-level `dependencyPolicy` instead of `dependency.policy`.
- Forgetting to bump `definitionRevision`.
- Hand-editing `signatureValue`.
- Treating `.cer` or `.pem` files as signing certificates.
- Authoring under a path without matching **Runtime endpoint status** `Selection` (for example using `Endpoint/Defaults` while a team share is selected, or the reverse).
- Leaving a definition unsigned when it is meant for a trusted, enabled scan endpoint.
- Skipping `Test-PackageDefinitionCatalog` or trust verification.
- Inventing `conflictsWith` pairs without maintainer intent.
- Trusting unknown signing keys as a shortcut.
- Embedding secrets or local machine paths in package JSON.
- Reporting work as done without validation, signing status, and `git status --short` when applicable.

## Out Of Scope

- Package engine changes.
- Schema changes.
- Dependency planner or resolver architecture changes.
- Fleet management or orchestration.
- Lockfile models inside materialized packages.
- New signing or trust commands.
- Re-signing or changing Eigenverft's shipped `Endpoint/Defaults` catalog JSON in the module package unless the maintainer explicitly requested that work (authoring there is in scope when it is the selected target).
