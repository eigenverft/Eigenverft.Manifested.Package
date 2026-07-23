# Package depot materialization leaves a team-share partial

## Status

The signed JSON definition is valid, and its authored SHA-256 `da40bff7...` correctly identifies the LF byte form of the Bootstrap script. However, byte canonicalization is now directly implicated: the repository index stores LF while a Windows checkout with `core.autocrlf=true` produces CRLF bytes with SHA-256 `5e15297b...`.

The transport behavior remains narrowed to two distinguishable states:

1. the team-share final differed from the verified LF source during the run, including the newly identified possibility that the final contains the CRLF checkout form, so no-clobber promotion retained a verified partial; or
2. the team-share final was already byte-identical and an older peer partial could not be cleaned on SMB.

A read-only root diagnostic is available to prove which state exists on the affected machine and now reports whether a mismatch disappears after CR/LF normalization. Logging improvements for exact final-file mismatches and peer-partial cleanup are implemented locally.

## Corrected observed sequence

The relevant reproduction is:

1. Delete only the local `EigenverftManifestedPackage` depot directory.
2. Leave the existing team-share directory unchanged.
3. Run `Invoke-Package -DefinitionId EigenverftManifestedPackage -MaterializeOnly`.
4. Observe that the local depot is populated correctly.
5. Observe an additional `Eigenverft.Manifested.Package.Bootstrap.ps1.partial.<contentIdentity>.<writerToken>` file in the team share.

The verified source artifact has expected SHA-256:

```text
da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e
```

The content-identity component visible in the partial filename is derived from that source hash. It therefore identifies a writer attempt for exactly this Bootstrap artifact, not an unrelated file.

### Signed definition versus checkout byte canonicalization

The definition is accepted as signed and trusted, and its `da40bff7...` hash matches the LF form committed to Git and served by the raw source. No JSON edit or catalog re-signing is required. What is not ruled out is a Windows checkout publishing the CRLF form (`5e15297b...`) to a depot path that is later compared against the verified LF artifact.

The definition is accepted as signed and trusted, and materialization reaches a verified staged source. No JSON edit or catalog re-signing is required for this incident.

### Failure to write the local depot

The deleted local directory is rebuilt successfully. The unresolved state is specific to the team-share final or team-share partial cleanup.

## Transport decision that matters

`CopyFileRaw` computes the exact source SHA-256 and checks the existing final before opening or creating its writer-owned partial.

- If the team-share final has the same length and SHA-256, the function returns `AlreadyPresent`, creates no new partial, and attempts to remove older peer partials.
- If the final differs, the function writes and verifies a writer-owned partial, then attempts a no-overwrite `File.Move` promotion.
- If the conflicting final still differs, promotion fails and the verified partial is intentionally retained.

Therefore, a partial proven to have been created by the current run is strong evidence that the final did not match the verified source at the initial exact comparison, or that the final could not be read consistently during the operation.

A partial that predates the run instead indicates cleanup residue. Peer cleanup uses an exclusive `DeleteOnClose` claim and deliberately suppresses sharing and access exceptions so an active concurrent writer is never removed. On SMB this can leave an old partial without a visible warning.


## Implemented diagnostic improvement

### Resilient promotion error

Promotion failures now report:

- actual existing final length;
- expected source length;
- whether SHA-256 was skipped due to length mismatch;
- original `File.Move` exception type;
- original exception HResult and message;
- destination path;
- retained partial path.

Expected shape:

```text
Writer-owned partial promotion failed: existing final length '<actual>' bytes differs from source length '<expected>' bytes; SHA-256 was not computed. File.Move error '<type>' (HResult <value>): '<message>'. Destination: '<path>'. Partial retained: '<partial>'.
```

### Depot verification result

`Test-PackageDepotDistributionFileMatches` now returns observed metadata for all outcomes:

- `SourceLength`
- `TargetLength`
- `SourceLastWriteTimeUtc`
- `TargetLastWriteTimeUtc`

A `SizeMismatch` can therefore be logged as:

```text
Mirror verification failed with 'SizeMismatch': source length '<expected>' bytes, target length '<actual>' bytes.
```

## Recovery for the affected machine

The invalid final files must be removed or quarantined before retrying materialization. The retained `.partial.<contentHash>.<writerToken>` file is content-verified and can be reused by a retry with the same writer identity only; normal command-level retries may use a new writer identity.

Before deleting anything, record the existing final file metadata and confirm the path is the failed versioned artifact path. Then remove only the invalid `Eigenverft.Manifested.Package.Bootstrap.ps1` final in each affected mirror and rerun materialization.

The module currently does not auto-delete the invalid final because the generic resilient transport deliberately avoids overwriting different destination content. Automatic repair should be a separate, explicit policy decision.

## Follow-up design decision

A package depot uses immutable, versioned, hash-verified paths. At that higher semantic layer it may be safe to offer an explicit repair policy such as:

```text
InvalidFinalPolicy = Fail | QuarantineAndReplace
```

`Fail` should remain the generic transport default. `QuarantineAndReplace` could be enabled only by the package-depot adapter after it has verified the source against the signed package definition. A safe implementation would need:

1. an exclusive claim on the invalid final;
2. a uniquely named quarantine move in the same directory;
3. no-overwrite promotion of the verified partial;
4. final SHA-256 verification;
5. structured reporting of the quarantined file;
6. concurrent-writer tests for wrong-size and equal-size/wrong-hash finals.

## Acceptance criteria for a later repair feature

- Invalid versioned depot files can be repaired without editing or re-signing package definitions.
- Valid peer-published final files are never overwritten.
- Different legitimate content identities remain protected by default.
- Wrong-size and wrong-hash finals produce distinct, actionable diagnostics.
- Local and UNC depot paths are covered.
- PowerShell 5.1 and PowerShell 7 behavior is covered.
- Repair leaves enough evidence for post-incident inspection.

## Complete materialization and mirror flow

`Invoke-PackageDepotMaterialize` is not a bidirectional folder synchronization command. For each selected trusted package it invokes the normal package engine in `MaterializeOnly` mode. The effective flow is:

1. Resolve the package release, target artifact, dependencies, and complete authored artifact file set.
2. Search readable acquisition candidates in authored order.
3. Copy or download each selected source into the operation staging directory.
4. Verify the staged source against the authored hash or signature.
5. Build one distribution target for every configured source with `writable=true` and `mirrorTarget=true`.
6. Independently distribute the same verified staging directory to each target. The local depot is not blindly copied to the team depot, and the team depot is not blindly copied back to the local depot.
7. Verify each mirror action and finally require the complete file set to be durable in at least one readable depot.

A readable depot can be the acquisition source for staging, but distribution still runs from the verified staging directory to every writable mirror target.

For the reported package, the two failing writes therefore happened independently:

```text
verified FileStage source
  -> defaultPackageDepot
  -> teamPackageDepot
```

The different writer tokens in the log confirm independent target transports.

## How the resilient copy currently works

The depot adapter invokes `Copy-ResilientDirectoryTree` with:

```text
ComparisonMode     = LengthAndLastWriteTime
PartialIdentityMode = FullHash
FlushPolicy         = EndOfCopy
RetryCount          = 6
WaitSeconds         = 1
```

For every selected destination file:

1. A new writer token is generated once for that file operation.
2. The token stays stable for all retries inside the same command invocation.
3. The partial path has this shape:

```text
<final>.partial.<content-identity-hash>.<writer-token>
```

4. `FullHash` content identity is calculated as:

```text
SHA256("fullhash|" + <source SHA-256>)
```

5. The source is streamed into that writer-owned partial.
6. The completed partial is checked against the source SHA-256.
7. Source timestamp metadata is applied to the partial.
8. The partial is promoted with the non-overwriting two-argument `File.Move(partial, final)`.
9. If a peer already published identical bytes, the peer final is accepted and redundant unlocked same-content partials are deleted.
10. If the existing final differs, the final is preserved and the writer-owned verified partial is retained.

The observed identity proves that the retained partial belongs to the expected source:

```text
source SHA-256:
da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e

SHA256("fullhash|" + source SHA-256):
84a5042043c9897bb719abf1fc4136c5feb3def439aeabc83129ff874922d58c
```

This exactly matches the middle identity segment in the reported partial filenames.

## Why partial files accumulate across materialize runs

The current retry model is resilient inside one process run, but deliberately isolates different writers:

- retries inside one file operation reuse the same writer token and partial;
- a later `Invoke-PackageDepotMaterialize` invocation creates a new writer token;
- a later invocation therefore does not resume or promote an older writer's partial;
- old peer partials are cleaned only after a valid final for the same content identity has been verified.

A wrong-size final creates a permanent blocker:

1. the verified partial cannot be promoted because the final exists;
2. the existing final cannot be accepted because its content differs;
3. all six retries encounter the same deterministic state;
4. the partial is retained intentionally;
5. the next command invocation creates another writer token and another partial;
6. cleanup never runs because no valid final exists.

This explains the accumulating `.partial.<same-content-identity>.<different-writer-token>` files. The behavior is safe against clobbering but is not self-healing for an invalid immutable final.

## High-confidence LF/CRLF origin candidate

Commit `eba7268` changed the Bootstrap script and refreshed the signed definition to SHA-256 `da40bff7...`. The signed value is not stale: it matches the LF bytes stored in the Git index and served by the raw source.

The repository had no `.gitattributes` rule for this signed payload. On the Windows checkout used for analysis:

```text
core.autocrlf = true
git ls-files --eol = i/lf w/crlf
LF SHA-256   = da40bff7b27a56a74ac7ddc340b21032604399cfbcde12119cec02cfbe6e1b3e
CRLF SHA-256 = 5e15297b0c07899a9e2a73e3fc1b81b921cf6cb4e1516b2567429d2ce6a76e5a
```

This supports a direct incident sequence:

1. a Windows publisher materialized or distributed the CRLF checkout form to the immutable depot final;
2. a later materialization acquired and verified the canonical LF form against the signed definition;
3. the hardened transport correctly detected different raw bytes and created a verified LF partial;
4. no-clobber promotion preserved the CRLF final and retained the LF partial;
5. later runs repeated the same deterministic conflict with new writer tokens.

The reported partial identity is derived from `da40bff7...`, proving that the retained partial contains the canonical LF source. The affected final must be hashed to confirm whether it is the CRLF form `5e15297b...`. If its normalized line-ending hash equals the source normalized hash, this mechanism is proven for the incident.

Targeted `.gitattributes` rules now pin both signed Bootstrap payloads (`.ps1` and `.cmd`) to `eol=lf`, preventing future Windows publishers from producing different bytes. The incident concerns the `.ps1`; the `.cmd` was found to have the same checkout-dependent hash problem during validation.

## Alternative historical origin: interrupted direct-final copy

Release `1.20264.5748` was produced by commit `06c420b` on 2026-07-18.

The depot distribution hardening was added later by commit `f18e6bf` on 2026-07-21. Before that hardening, depot publication called:

```powershell
Copy-FileToPath -SourcePath $action.SourcePath -TargetPath $action.TargetPath -Overwrite
```

`Copy-FileToPath -Overwrite` is a thin wrapper over:

```powershell
Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
```

That older path wrote directly to the final depot filename. A process termination, network interruption, share disconnect, or synchronization interruption could therefore also expose a truncated final file. This remains a viable alternative when the affected final is neither the LF source nor its CRLF-only equivalent.

The hardened implementation later encounters either kind of differing final and correctly refuses to overwrite it. Each later run then retains a new verified partial because cross-run writer adoption is not implemented.

An external folder synchronization tool can amplify the issue if it copies live `*.partial.*` files or propagates the stale final between depot roots. Such tools should exclude transport-internal files. The built-in materialization command itself does not copy partial files from one depot to another; each target creates its own partial from staging.

## Immediate safe recovery

Stop materialization and any external synchronization touching the affected depot directories before repair.

For each affected depot:

1. Record the final file length, timestamp, and hash when readable.
2. Move the invalid final to a uniquely named quarantine file in the same directory instead of deleting it immediately.
3. Leave the same-content partials in place for evidence.
4. Rerun only the affected package:

```powershell
Invoke-Package -DefinitionId EigenverftManifestedPackage -MaterializeOnly
```

5. Verify the new final against the authored SHA-256.
6. Confirm that unlocked same-content partials were removed after successful publication.
7. If an external synchronization product is used, exclude at minimum:

```text
*.partial.*
*.invalid.*
*.quarantine.*
```

The current implementation will create a new writer partial rather than adopting an older one. After it publishes a valid final, its existing cleanup logic should remove unlocked partials with the same content identity. Locked files or externally reintroduced files may still need explicit cleanup.

## Recommended implementation design

The generic `Copy-ResilientDirectoryTree` default should remain no-clobber. It does not know whether the destination path is immutable, signed, or safe to replace.

Repair belongs in the package-depot adapter, because that layer knows all of the following:

- the release path is immutable and versioned;
- the staged source was verified against the signed definition;
- the target is a configured writable mirror;
- a mismatching final cannot be a valid representation of that authored artifact.

### Phase 1: deterministic conflict repair

Add a package-depot policy such as:

```text
InvalidFinalPolicy = Fail | QuarantineAndReplace
```

For `QuarantineAndReplace`:

1. Verify the staging source against the authored content hash.
2. Re-read the target final immediately before repair.
3. If it now matches, accept the peer result.
4. If it still differs, atomically move it to a unique same-directory quarantine path.
5. If another process wins the quarantine race, re-read the final and continue from the new state.
6. Run the existing no-overwrite partial promotion.
7. Verify the published final against the authored hash.
8. Record the quarantine path and previous metadata in structured output.

A same-directory move is important because it avoids copying invalid bytes and provides post-incident evidence. Automatic deletion should be a separate retention policy.

### Phase 2: complete orphan-partial adoption

Before copying source bytes again, scan:

```text
<final>.partial.<current-content-identity>.*
```

For each candidate that can be exclusively opened:

1. check its length;
2. calculate its SHA-256;
3. if it is complete and matches the verified source, use it as the promotion candidate;
4. otherwise leave an active candidate untouched or quarantine an invalid stale candidate according to policy.

Adopting only complete, fully verified orphan partials is substantially safer than attempting cross-process resume of incomplete partials. Prefix-based cross-run resume can be considered later, but it requires stronger ownership and stale-writer rules.

### Phase 3: retry classification and garbage collection

A mismatching existing final is deterministic, not transient. The copy engine should not repeat six identical promotion attempts unless the error indicates a sharing or lock race.

Recommended classifications:

```text
TransientIoConflict
MatchingPeerWon
InvalidFinalConflict
SourceChanged
PartialVerificationFailed
```

For `InvalidFinalConflict`, return immediately to the package adapter so it can apply `Fail` or `QuarantineAndReplace`.

Add explicit orphan cleanup with these constraints:

- never delete a locked partial;
- remove same-content partials after a valid final is verified;
- optionally quarantine old invalid partials after a configurable age;
- never infer validity from the filename alone;
- log writer token, content identity, age, length, and cleanup outcome.

## Additional acceptance criteria

- A truncated final created by the old direct-copy implementation is automatically recoverable under explicit package-depot repair policy.
- A complete verified partial from a previous process can be adopted without re-copying the source.
- Separate local and team targets remain independent and concurrency safe.
- Two clients racing to quarantine the same invalid final converge on one valid final.
- Live writer partials are never removed.
- External synchronization guidance explicitly excludes transport-internal partial and quarantine files.
- Deterministic invalid-final conflicts do not consume the full transient retry budget.

## Cross-run evidence from the reported writer tokens

The team-depot partial named by the operator ends with writer token prefix:

```text
6c1b66...
```

The failing run captured in the incident log used a different team-depot writer token:

```text
2bd01f...
```

The local target in that same run used another token:

```text
f1374e...
```

This proves both relevant design properties from real data:

- local and team targets are independent writers created from the same staging source;
- the team depot contains partials from more than one command invocation.

The retained files are therefore cross-run orphan partials caused by the persistent invalid final, not multiple retry files from one run. Retries within one run keep one stable writer token and reuse one partial path.

## Corrected reproduction sequence: local depot rebuilt, team share gains a partial

The observed sequence is more specific than the original incident reconstruction:

1. The local `EigenverftManifestedPackage` depot directory was deleted.
2. The existing team-share directory remained in place and appeared complete.
3. `Invoke-Package -DefinitionId EigenverftManifestedPackage -MaterializeOnly` was executed.
4. The local depot was rebuilt successfully.
5. The team share then contained an additional `Eigenverft.Manifested.Package.Bootstrap.ps1.partial.<contentIdentity>.<writerToken>` file.

This sequence does not by itself prove that the team-share final was invalid. It narrows the explanation to two code paths.

### Path A: the team-share final did not match the verified source during the run

The outer distribution comparison uses size and `LastWriteTimeUtc` only. If those metadata differ, `CopyFileRaw` is entered. `CopyFileRaw` then performs an exact SHA-256 comparison before it opens or creates its writer-owned partial.

If the exact hash matches, it returns `AlreadyPresent` and creates no new partial. Therefore a newly created current-run partial is strong evidence that the team-share final did not match the verified source at the initial exact comparison, or that the final could not be read consistently while the operation was running.

This can happen even when the file appears correct in Explorer. Same name, plausible size and a normal icon do not prove equal bytes. If the team-share file was rejected as an acquisition candidate, the command can download or obtain a verified source elsewhere, rebuild the deleted local depot correctly, and then retain a verified partial beside the conflicting team-share final because publication is no-clobber.

### Path B: the observed partial predated the run and cleanup did not remove it

If the final exact hash already matches, `CopyFileRaw` does not write another partial. It does attempt to remove older peer partials for the same content identity. Peer cleanup uses an exclusive `FileStream` with `DeleteOnClose` and deliberately suppresses `IOException` and `UnauthorizedAccessException`, because an active concurrent writer must not be deleted.

On an SMB share, an old partial can therefore remain silently when:

- another process, scanner, sync client or SMB lease still holds it;
- share or file ACLs allow creation/writing but not deletion of that file;
- the server does not complete the requested delete-on-close operation;
- the file was observed after the run but its writer token or timestamp actually belongs to an earlier run.

The writer token and file timestamps are required to distinguish Path A from Path B.

## Read-only proof script

`Analyze-PackageDepotArtifact.ps1` was added to the repository root. It performs no deletion and no depot mutation. It compares a known-good local source file against the team-share final and every matching partial.

Example:

```powershell
$relativePath = 'evf\EigenverftManifestedPackage\stable\1.20264.5748\psmodule-any\Eigenverft.Manifested.Package.Bootstrap.ps1'
$localPath = Join-Path "$env:LOCALAPPDATA\Programs\Evf.Package\PkgDepot" $relativePath
$teamPath = Join-Path '\\si0vmc3667.de.bosch.com\UserShare\rlc5hi\Depot' $relativePath

.\Analyze-PackageDepotArtifact.ps1 -SourcePath $localPath -DestinationPath $teamPath -TestExclusiveClaim
```

The result answers:

- whether the team-share final exists;
- whether its raw SHA-256 equals the rebuilt local file;
- each file's line-ending style and LF-normalized SHA-256;
- whether a raw mismatch is explained completely by CRLF versus LF bytes;
- which partials contain the same complete bytes;
- their timestamps, content identities and writer tokens;
- whether each file can currently be opened exclusively without modifying it.

Interpretation:

- `FinalDifferenceIsLineEndingOnly = True`: the final and verified source are logically the same text but have different raw bytes; the depot final was likely published from a text-normalizing or Windows CRLF checkout.
- `FinalMatchesSource = False` and normalized hashes also differ: the final is a different or truncated artifact; the partial is expected no-clobber evidence.
- `FinalMatchesSource = True` with partials: the final is valid and the remaining files are cleanup residue.
- `ExclusiveClaim = False`: another handle or permission policy currently prevents safe cleanup.
- `ExclusiveClaim = True`: the file is currently claimable; inspect the structured cleanup result from the materialization run.

## Implemented logging and cleanup telemetry

The transport now records, without failing an otherwise successful materialization:

- source SHA-256 and exact initial-final hash status;
- source/final lengths, UTC timestamps and final attributes;
- writer token and writer-owned partial path before copying;
- peer partial path;
- cleanup outcome through removed/skipped counts;
- exception type, HResult and message for skipped cleanup;
- `DeleteOnCloseDidNotRemove` when an exclusive cleanup handle closes but the file remains.

This telemetry is returned in each file result and also emits actionable warnings for exact-final mismatches and skipped cleanup.
