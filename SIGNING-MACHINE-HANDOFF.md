# EigenverftManifestedPackage definition repair handoff

## Purpose

This repository branch contains the package-depot diagnostics and a prepared repair for the acute `EigenverftManifestedPackage` definition problem. The signed JSON itself is intentionally not modified on the MCP workspace because the private catalog-signing key is not available here.

The remaining operation must be performed on a machine that can use the `Eigenverft Package Catalog Signing` certificate/private key.

## Confirmed root cause

Commit `eba7268` changed the Bootstrap PowerShell payload by adding `-DisableNameChecking` to an owned `Import-Module` call. The definition was updated from revision 12 to revision 13 and signed again, but the package release version remained `1.20264.5748`.

The authored Bootstrap PowerShell hash therefore changed under the same versioned depot path:

- revision 12 / original release content: `f89ecd624ee437b37dbb9b99d9a8e23ab9e830d3c6473bc1f52d95a2327b04e3`
- revision 13 / changed release content: `da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e`

The path did not change:

```text
evf/EigenverftManifestedPackage/stable/1.20264.5748/psmodule-any/Eigenverft.Manifested.Package.Bootstrap.ps1
```

The resilient copy layer correctly treats a versioned final file as immutable. When the team depot contained the earlier valid bytes and the newly signed definition requested the later bytes, the transport:

1. rejected the existing final as non-identical;
2. wrote and verified a writer-owned `.partial.<contentIdentity>.<writerToken>` file;
3. refused to overwrite the existing final;
4. retained the verified partial for diagnosis/recovery.

This explains why deleting only the local package-depot directory rebuilt the local depot successfully while the unchanged team depot gained another partial file.

## Other findings

### The SHA comparison was not an empty-value loop

The transport computes the exact source SHA-256 before creating a partial. If the existing final has the same size and SHA-256, it returns `AlreadyPresent` before opening a new partial. A new partial therefore means the final did not match the verified source at the exact comparison, could not be read consistently, or the observed partial predated the run and its cleanup was blocked.

The old error text was misleading when source and final lengths differed because the final SHA was intentionally not calculated in that case. The diagnostic branch now distinguishes `Computed` from `NotComputedLengthMismatch` and logs actual/expected lengths.

### Mutable branch URLs amplified the problem

The release entries referenced Bootstrap files through `refs/heads/main`. That URL is mutable and conflicts with an immutable versioned depot layout. A signed definition can therefore change the bytes associated with an existing release version even when the release version and depot path stay unchanged.

### LF/CRLF was investigated but is not the strongest incident cause

The Windows checkout can produce different hashes for the same text because `core.autocrlf=true` changes LF to CRLF. The diagnostic branch adds canonical LF rules for both signed Bootstrap files and can report line-ending-only differences.

However, the inspected team-depot files both displayed LF in Notepad++, and the Git history independently proves the same-version payload mutation. LF/CRLF remains valid hardening, but the release mutation is the strongest explanation for this incident.

### Historical release references were also mutable

The existing `1.20264.4323` and `1.20264.5748` entries both referenced `main`. The repair pins their Bootstrap artifacts to immutable commit `6f95fefe409fd5b26116fb672a1f947919253ef8`, whose Bootstrap PowerShell SHA-256 is exactly the already authored historical value `f89ecd...`.

The `v1.20264.4323` tag itself cannot be used for that historical entry because its Bootstrap payload has SHA-256 `edd6c462a45b1122061219cd4ab3fd8cb7180d41482f1263a0fbbefb16420948`, which does not match the later authored `f89ecd...` value.

## Prepared repair

Run this script from the repository root on the signing machine:

```powershell
$certificatePassword = Read-Host 'Catalog signing password' -AsSecureString

.\Repair-EigenverftManifestedPackageDefinition.ps1 -Cert 'Eigenverft Package Catalog Signing' -Password $certificatePassword
```

If the local signing descriptor already supplies the password, omit `-Password`:

```powershell
.\Repair-EigenverftManifestedPackageDefinition.ps1 -Cert 'Eigenverft Package Catalog Signing'
```

The script performs the following guarded steps:

1. Downloads `Eigenverft.Manifested.Package` version `1.20264.12503` from PowerShell Gallery.
2. Verifies the NUPKG SHA-256:
   `5cd195928f3a2523d6c20d6f7c968992473d8d3d8b1693a95a3ec0c030d76156`.
3. Downloads and verifies both historical and current Bootstrap files from immutable Git commit/tag URLs.
4. Requires the input definition to still be revision 13.
5. Pins releases `1.20264.4323` and `1.20264.5748` to immutable historical Bootstrap URLs and the original `f89ecd...` hash.
6. Adds new stable release `1.20264.12503` with:
   - Package NUPKG SHA-256 `5cd195928f3a2523d6c20d6f7c968992473d8d3d8b1693a95a3ec0c030d76156`
   - PackageManagement SHA-256 `7e1f8a75b6bc8a83d8abff79f6690fc1dfbd534fd3e5733d97e19bcb5954c13e`
   - PowerShellGet SHA-256 `6b8cebf2a464eaeb31b0a6d627355c30d9d1899dba0ce3bdd0d4e7afca148673`
   - Bootstrap CMD SHA-256 `1bd294dc0b6522974d069af7a8b78a0c672fb264de18e73e78a1fb6596a880ab`
   - Bootstrap PowerShell SHA-256 `da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e`
   - Bootstrap URLs pinned to tag `v1.20264.12503`.
7. Updates discovery and installer `requiredVersion` values to `1.20264.12503`.
8. Advances `definitionRevision` from 13 to 14 and updates `publishedAtUtc`.
9. Re-signs with `Resign-PackageDefinition`.
10. Runs `Verify-PackageDefinitionSignature -RequireTrusted -ErrorOnFailure`.
11. Runs `Test-PackageDefinitionCatalog -RequireTrusted -ErrorOnFailure`.
12. Restores the original JSON automatically if signing or validation fails.

A dry-run is available:

```powershell
.\Repair-EigenverftManifestedPackageDefinition.ps1 -Cert 'Eigenverft Package Catalog Signing' -WhatIf
```

## After the script succeeds

Review and commit only the expected signed JSON change:

```powershell
git diff -- src/prj/Eigenverft.Manifested.Package/Endpoint/Defaults/Eigenverft/EigenverftManifestedPackage.json
git status --short
git add src/prj/Eigenverft.Manifested.Package/Endpoint/Defaults/Eigenverft/EigenverftManifestedPackage.json
git commit -m "Repair immutable EigenverftManifestedPackage release"
git push
```

The repair script itself is already committed on the handoff branch and should normally remain in the repository until the incident is closed and the release-immutability validation is implemented.

## Team-depot recovery after the signed definition is deployed

The new release uses a new versioned path:

```text
evf/EigenverftManifestedPackage/stable/1.20264.12503/psmodule-any/
```

Therefore it no longer needs to overwrite the conflicting `1.20264.5748` final file.

After ensuring no materialization process is running:

1. Deploy or expose the newly signed revision 14 definition through the package endpoint.
2. Run:

```powershell
Invoke-Package -DefinitionId EigenverftManifestedPackage -MaterializeOnly
```

3. Confirm local and team depots contain the complete `1.20264.12503` artifact set.
4. Verify exact hashes before deleting any old partials.
5. Remove only orphaned `*.partial.*` files from the old `1.20264.5748` directory when no writer owns them.
6. Keep the old final artifact unless an explicit retirement policy removes the complete old release directory.

The read-only helper `Analyze-PackageDepotArtifact.ps1` can compare a local source/final with the team-depot final and partials before cleanup.

## Changes already present on this branch

- richer exact-hash and length diagnostics before partial creation;
- explicit `HashStatus` values;
- original `File.Move` exception type, HResult, and message in promotion errors;
- structured peer-partial cleanup results and SMB cleanup warnings;
- read-only depot artifact analysis;
- LF/CRLF-only comparison detection;
- canonical LF checkout rules for signed Bootstrap `.ps1` and `.cmd` files;
- focused regression tests for copy conflict and cleanup behavior;
- detailed incident analysis in `ISSUE-PACKAGE-DEPOT-STALE-FINAL.md`.

No CI workflow change is part of this repair.
