# PackageDefinitionAuthoring

Use this skill when creating or editing Eigenverft package-definition JSON for an endpoint catalog. This skill is for package-definition artifacts only; it is not for changing the package engine, dependency planner, trust model, schema, or runtime install code.

## When To Use

- Create a new package-definition JSON file.
- Update an existing package-definition JSON file.
- Prepare a catalog change for validation, signing, review, and publication.
- Review agent-authored package JSON before it can be trusted or installed.

## Product Boundary

Read `PRODUCT-BOUNDARY.md` before changing package JSON. Package definitions are declarative, reviewable artifacts. Agents may draft and validate JSON, but production trust/install requires human review and trusted signing or endpoint policy.

Do not add arbitrary hook systems, engine behavior, fleet orchestration, or resolver design while authoring package JSON. If the requested package cannot be represented declaratively, stop and ask for a maintainer decision.

## Inputs To Read First

- `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json`
- The schema root `description` and `x-eigenverftAgentHint`
- Shipped examples under `Endpoint/Defaults/Eigenverft`
- Nearby package definitions from the same publisher or endpoint
- The issue, request, or maintainer instructions that define the package intent

## Authoring Workflow

1. Start from schema 1.9 and a nearby shipped example.
2. Author drafts as unsigned: `definitionPublication.definitionSignature.kind = unsigned`.
3. Never fabricate, copy, or hand-edit `signatureValue`.
4. Keep endpoint layout as `<publisherId>/<definitionId>.json`.
5. Bump `definitionRevision` for every definition content change.
6. Keep scripts and acquisition behavior minimal, declarative, and reviewable.
7. Run `Test-PackageDefinitionCatalog` before signing or publishing.
8. Sign or re-sign only after content is stable.
9. Verify signature or catalog trust.
10. Require human review before production trust, endpoint publication, or production `Invoke-Package`.

## Self-Check Checklist

- `publisherId`, `definitionId`, display metadata, and revision match the requested package.
- `schemaVersion` is `1.9`.
- Deprecated top-level `dependencies` and `dependencyPolicy` are not used.
- Dependencies use `dependency.requires[]`.
- Coexistence policy uses `dependency.policy.conflictsWith[]` or `dependency.policy.requiresAbsent[]` only when the maintainer intent is explicit.
- Download URLs, checksums, installer arguments, and materialization paths are reviewable.
- No credentials, tokens, local private paths, or machine-specific secrets are embedded.
- `definitionSignature.kind` is `unsigned` until signing is intentionally performed.

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
- Skipping `Test-PackageDefinitionCatalog`.
- Inventing `conflictsWith` pairs without maintainer intent.
- Trusting unknown signing keys as a shortcut.
- Embedding secrets or local machine paths in package JSON.

## Out Of Scope

- Package engine changes.
- Schema changes.
- Dependency planner or resolver architecture changes.
- Fleet management or orchestration.
- Lockfile models inside materialized packages.
- New signing or trust commands.
- Shipped Eigenverft catalog JSON changes or re-signing unless explicitly requested.
