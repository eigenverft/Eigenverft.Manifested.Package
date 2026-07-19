# PackageDefinitionAuthoring

This guide is the schema 2.0 authoring contract for Eigenverft.Manifested.Package. Read it completely before editing a package definition. Package authoring is declarative JSON work; do not execute a vendor installer or `Invoke-Package` to discover behavior.

## 1. Start Here: Task and output location

1. Read the prepended Task, Authoring mode, and Runtime endpoint status.
2. Read this complete guide and the focused schema material listed below.
3. Resolve the task identity and authoring path, research every artifact, then follow sections 3 through 9 in order.

The Task normally supplies `definitionPublication.definitionId`. Use the user's `publisherId`; otherwise infer it from the selected catalog only when unambiguous. Write to the Runtime endpoint `Selection`, normally:

```text
<Selection>\<publisherId>\<definitionId>.json
```

Use the endpoint's existing flat layout only when the endpoint or user requires it. `definitionPublication.publisherId` and `definitionPublication.definitionId` are authoritative.

### Authoring Targets And Endpoints

Only a `Ready` endpoint marked `authoringTarget: true` is a valid output location. If Runtime endpoint status is absent, run `Get-PackageEndpoint`. Do not guess a repository or installed-module path.

### Troubleshooting for agents

- `NoMarkedTarget`: stop edits and explain how to mark or add an authoring target.
- `AllMarkedBlocked`: stop edits; report the path and reason for each blocked target.
- `Selection: (none)`: do not write JSON until the user supplies or enables a writable target.

Before editing, read:

- this complete guide;
- the root instructions in `Schema/PackageDefinition/eigenverft-module-package-definition-2.0.schema.json`;
- the schema definitions for the root, target, release, `artifactFiles`, one artifact file, one acquisition candidate, and the selected installer kind;
- one shipped definition matching that installer kind.

Read the relevant `description`, `$comment`, and `x-eigenverftAgentHint` text. Do not read the entire large schema blindly, but do not partially read any selected definition. For an update, also read the complete current JSON.

## 2. Five-line package mental model

```text
target = distribution suitable for the machine
release = selected version
artifactFiles = every required file in that distribution
acquisitionCandidates = fallback ways to obtain one file
artifactFileId = file consumed by the install operation
```

The target chooses machine suitability and reusable file rules. The release contributes exact version facts and trust evidence. A selected distribution is complete only when every declared artifact file is verified.

Version identity rules:

- `releases[].version` is the selectable artifact identity: `latestByVersion`, `-PackageVersion` pins, dependency ranges, install/depot path segments, inventory `currentVersion`, and replace-vs-reuse decisions.
- Any payload change that must upgrade already-owned installs requires a **new release row with a new `version`**. Never silently overwrite `releaseTag`, hashes, or paths under an existing selectable version.
- Use optional `reportedVersion` only when the installed program reports text that differs from the selectable `version` (for readiness `{reportedVersion}` tokens). It is not a selector.
- `releaseTag` and release `relativePath` are source facts. A filename that does not equal `version` is not automatically malformed when templates or overrides resolve correctly.

Version sanity check: before updating a release, compare `version`, `releaseTag`, every exact artifact filename, and the value captured and expected by readiness side by side. If a numeric component or rebuild marker appears in only some of them, stop the mechanical update and decide explicitly whether it belongs in the unique selectable `version`, in `reportedVersion`, or only in source naming; never leave a payload-changing rebuild visible only in tag, path, or hash.

## 3. Hard stop conditions

Stop and ask the user or report the blocker when:

- no writable `Selection` exists, required source evidence is unavailable, or the requested behavior is not expressible by schema 2.0;
- installer kind, silent arguments, scope, elevation, or removal behavior cannot be established from vendor documentation plus a trustworthy corroborating source;
- any required file lacks a resolvable source or its own trust boundary;
- target and release artifact file IDs differ, a path is rooted/unsafe/colliding, or an `archiveEntry` reference is missing or cyclic;
- install readiness and removed-state absence checks do not align with what install and removal actually do;
- validation, signing, or required trust verification fails.

Never run `setup.exe`, `msiexec`, a vendor bootstrapper, repair/uninstall commands, or `Invoke-Package` during authoring. Downloading without execution is allowed only to resolve URLs and calculate or verify hashes/signatures. Never fabricate hashes, signatures, installer arguments, or trust.

## 4. Authoring sequence

1. Confirm `definitionPublication`, display metadata, dependencies, target constraints, `releaseTrack`, and `artifactDistributionVariant`.
2. Research the latest requested release and every file in the distribution. Record the resolved source URL/path, version evidence, hash/signature evidence, and installer evidence per file.
3. Define stable file IDs under target `artifactFiles`. Put reusable `relativePathTemplate` and ordered `acquisitionCandidates` there.
4. Define the exact same IDs under each release target's `artifactFiles`. Put exact `relativePath`, source overrides, `contentHash`, and `publisherSignature` facts there.
5. Select the install input with `packageOperations.assigned.install.artifactFileId`.
6. Align discovery, readiness, removal, absence verification, dependencies, and ownership policy.
7. Increment `definitionPublication.definitionRevision`; keep `definitionSignature.kind` as `unsigned` until signing.
8. Validate, review every warning, sign when required, then validate trust.

For a version update, research the requested upstream version independently of `versionSelection`, add a new release row when the selectable artifact identity changes (including rebuilds that must replace owned installs), refresh every artifact file's source and trust facts, set `reportedVersion` when readiness must match a different installed report string, retain older releases when the package's history policy requires them, and re-sign only after validation.

## 5. Artifact file-set rules

- Every declared artifact file is mandatory. There are no optional, primary, or sidecar roles.
- The object key is the stable file ID. A filename may change between releases without changing the ID.
- Target and release file-ID sets must match exactly.
- `relativePathTemplate` and release `relativePath` must be relative, traversal-free, and unique case-insensitively after resolution.
- `acquisitionCandidates` are ordered fallbacks for one file, not a list of files.
- A static file-backed target declares at least one file. npm materialization is the explicit dynamic exception.
- Each file needs its own resolved source evidence and its own `contentHash` or `publisherSignature` trust evidence when policy requires verification.
- `archiveEntry` creates one declared file from another declared file. Set `sourceArtifactFileId`, exact `entryPath`, `searchOrder`, and `verification`; independently hash or signature-verify the extracted output.
- Never use absolute paths, `..`, normalization escapes, duplicate destinations, missing references, or dependency cycles.

## 6. Install-operation decision table

| Artifact behavior | `packageOperations.assigned.install.kind` | Required selection |
| --- | --- | --- |
| Expand an archive into an install directory | `expandArchive` | `artifactFileId` |
| Place one declared file | `placePackageFile` | `artifactFileId` |
| Install a `.nupkg` as a PowerShell module | `powershellModuleInstaller` | `artifactFileId` |
| Execute an MSI | `msiInstaller` | `artifactFileId` |
| Execute NSIS | `nsisInstaller` | `artifactFileId` |
| Execute Inno Setup | `innoSetupInstaller` | `artifactFileId` |
| Execute another file-backed installer | `runInstaller` | `artifactFileId` |
| Dynamically materialize npm tarballs | npm materialization kind | no static selection |
| Reuse an already installed product | `reuseExisting` | no static selection unless another operation requires files |

The complete artifact set is staged with its sibling and nested layout intact. `artifactFileId` chooses only the file consumed or executed by the adapter. For split installers, select the executable and declare every `.001`, `.002`, or equivalent part so they are present beside it.

`installerKind` and arguments require evidence; they are not guesses. Prefer vendor documentation, then corroborate with a reputable package-manager manifest or equivalent source. Do not use unofficial mirrors as the source of truth.

## 7. Discovery/removal alignment

`discovery.presence` describes the installed state, not downloaded artifacts. `packageOperations.assigned.readyStateCheck` must require signals the install operation creates. `packageOperations.removed.operation` must be capable of removing every signal required by `packageOperations.removed.absenceVerification`.

Review these together:

- install directory and target-relative paths;
- files, directories, commands, apps, registry entries, metadata, signatures, and PowerShell modules;
- path registration and generated shims;
- installer-owned uninstall commands versus tracked-directory deletion;
- machine prerequisites or PowerShell modules that have no install directory;
- `ownershipPolicy` and allowed inventory ownership kinds.

If removal cannot make required presence signals absent, stop. For machine/admin installers, prefer the vendor-owned default location unless the user or vendor documentation explicitly requires a custom target.

## 8. Validation and signing

Resolve the installed module root rather than guessing it:

```powershell
$moduleBase = (Get-Module -ListAvailable Eigenverft.Manifested.Package |
    Sort-Object Version -Descending |
    Select-Object -First 1).ModuleBase
$schemaPath = Join-Path $moduleBase 'Schema\PackageDefinition\eigenverft-module-package-definition-2.0.schema.json'
Test-Json -Json (Get-Content -Raw -LiteralPath '<definition.json>') `
    -Schema (Get-Content -Raw -LiteralPath $schemaPath) -ErrorAction Stop
Test-PackageDefinitionCatalog -Path '<definition.json>' -ErrorOnFailure
```

Review and explain every catalog warning. For draft-only mode, keep `definitionPublication.definitionSignature.kind` as `unsigned` and stop after successful draft validation.

For a trusted definition, discover the signing profile with `Get-PackageSigningProfile -PublisherId '<publisherId>'`. If exactly one approved profile exists, sign or re-sign and verify:

```powershell
Resign-PackageDefinition -Path '<definition.json>' -Cert '<approved-profile>' -KeepSchemaVersion
Test-PackageDefinitionCatalog -Path '<definition.json>' -RequireTrusted -ErrorOnFailure
Verify-PackageDefinitionSignature -Path '<definition.json>' -RequireTrusted -ErrorOnFailure
```

Use `Sign-PackageDefinition` for a first signature. Never edit `signatureValue` by hand, use `.cer`/`.pem` as a private signing key, auto-trust an unknown signer, or bypass trust for publication. If the output is in Git, run `git status --short` so a new file is not forgotten.

## 9. Compact Check Result

Every handoff must include `Check Result`. Use `Passed`, `Failed`, `Not run`, or `Not applicable`, and include evidence plus command/source for:

- definition path, schema version, and revision;
- target/release selection facts;
- installer kind, arguments, scope, elevation, and target behavior;
- every artifact file ID with resolved source and independent hash/signature evidence;
- target/release ID-set match and safe unique relative paths;
- `artifactFileId` and complete sibling-layout reasoning;
- discovery/readiness/removal alignment;
- raw schema validation, catalog validation, and warning review;
- signing profile, signing result, and trusted verification, or draft-only status;
- repository status when applicable;
- known runtime blockers.

Mark a check `Passed` only when its command ran or its source was read in the current task. Do not call a definition complete while a required check is failed or not run.

## 10. Canonical examples and common mistakes

These are focused fragments to merge into a complete schema 2.0 definition. Keep file IDs unchanged between the target and release.

### Single archive

```json
{
  "artifacts": {
    "targets": [{
      "id": "tool-win-x64-stable",
      "artifactFiles": {
        "package": {
          "relativePathTemplate": "tool-{version}.zip",
          "acquisitionCandidates": [
            { "kind": "packageDepot", "searchOrder": 100, "verification": { "mode": "required" } },
            { "kind": "vendorDownload", "url": "https://vendor.example/tool-{version}.zip", "searchOrder": 900, "verification": { "mode": "required" } }
          ]
        }
      }
    }],
    "releases": [{
      "version": "2.0.0",
      "targetArtifacts": {
        "tool-win-x64-stable": {
          "artifactId": "tool-win-x64-stable",
          "artifactFiles": {
            "package": { "contentHash": { "algorithm": "sha256", "value": "<64-lowercase-hex>" } }
          }
        }
      }
    }]
  },
  "packageOperations": {
    "assigned": {
      "install": { "kind": "expandArchive", "artifactFileId": "package", "installDirectory": "tool/{version}", "expandedRoot": "auto" }
    }
  }
}
```

### Split installer

```json
{
  "artifacts": {
    "targets": [{
      "id": "suite-win-x64-stable",
      "artifactFiles": {
        "setup": {
          "relativePathTemplate": "setup-{version}.exe",
          "acquisitionCandidates": [{ "kind": "vendorDownload", "url": "https://vendor.example/{version}/setup.exe", "searchOrder": 900, "verification": { "mode": "required" } }]
        },
        "part001": {
          "relativePathTemplate": "setup-{version}.001",
          "acquisitionCandidates": [{ "kind": "vendorDownload", "url": "https://vendor.example/{version}/setup.001", "searchOrder": 900, "verification": { "mode": "required" } }]
        }
      }
    }],
    "releases": [{
      "version": "4.2.0",
      "targetArtifacts": {
        "suite-win-x64-stable": {
          "artifactId": "suite-win-x64-stable",
          "artifactFiles": {
            "setup": { "contentHash": { "algorithm": "sha256", "value": "<setup-hash>" } },
            "part001": { "contentHash": { "algorithm": "sha256", "value": "<part-hash>" } }
          }
        }
      }
    }]
  },
  "packageOperations": {
    "assigned": {
      "install": { "kind": "runInstaller", "artifactFileId": "setup", "targetKind": "directory", "installerKind": "customExe", "installDirectory": "suite/{version}", "uiMode": "silent", "elevation": "none", "commandArguments": ["/S"], "successExitCodes": [0], "restartExitCodes": [] }
    }
  }
}
```

### Archive-derived bootstrap files

```json
{
  "artifactFiles": {
    "modulePackage": {
      "relativePathTemplate": "Eigenverft.Manifested.Package.{version}.nupkg",
      "acquisitionCandidates": [{ "kind": "vendorDownload", "url": "https://gallery.example/Eigenverft.Manifested.Package/{version}", "searchOrder": 900, "verification": { "mode": "required" } }]
    },
    "bootstrapPowerShell": {
      "relativePathTemplate": "Bootstrap/Eigenverft.Manifested.Package.Bootstrap.ps1",
      "acquisitionCandidates": [
        { "kind": "packageDepot", "searchOrder": 100, "verification": { "mode": "required" } },
        { "kind": "archiveEntry", "sourceArtifactFileId": "modulePackage", "entryPath": "Bootstrap/Eigenverft.Manifested.Package.Bootstrap.ps1", "searchOrder": 900, "verification": { "mode": "required" } }
      ]
    },
    "bootstrapCommand": {
      "relativePathTemplate": "Bootstrap/Eigenverft.Manifested.Package.Bootstrap.cmd",
      "acquisitionCandidates": [
        { "kind": "packageDepot", "searchOrder": 100, "verification": { "mode": "required" } },
        { "kind": "archiveEntry", "sourceArtifactFileId": "modulePackage", "entryPath": "Bootstrap/Eigenverft.Manifested.Package.Bootstrap.cmd", "searchOrder": 900, "verification": { "mode": "required" } }
      ]
    }
  }
}
```

The matching release declares all three IDs and independently records `contentHash` or `publisherSignature` for each. The PowerShell module install operation uses `"artifactFileId": "modulePackage"`.

Common mistakes:

- placing `relativePathTemplate` or reusable candidates on the release instead of the target;
- placing exact hashes only on candidates instead of the matching release file entry;
- changing file IDs between releases because a filename changed;
- omitting a split part or treating a required file as optional;
- pointing `artifactFileId` at an undeclared file or confusing it with a filename;
- using one candidate per file as if candidates were members of the set;
- forgetting independent trust evidence for an extracted file;
- allowing rooted, traversal, or case-colliding paths;
- running an installer to discover switches;
- skipping revision bump, warning review, signing, trusted verification, or the final Check Result.
