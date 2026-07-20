# Better Sync into mirror depots

**Status:** Open
**Priority:** 2/7
**One-line goal:** When a depot is marked as a mirror, Sync must actually put complete package files there — or fail clearly.

---

## What a depot is (today)

A **depot** is a folder on disk that can hold downloaded package files (zips, installers, etc.).

The list of depots is stored in **`PackageDepotInventory.json`** (not in `PackageConfig.json`).
`PackageConfig.json` holds general Package settings; **depot paths and flags live only in the depot inventory**. A local copy of that inventory is created under the Package app-data/config root on first use.

That inventory file only stores **settings** for each depot. It does **not** store “we already downloaded GitRuntime 2.55.0.3”. That only exists as files under the depot path.

Package **definitions** (what GitRuntime is, hashes, versions) come from **endpoints**, not from the depot inventory. Sync picks packages from whatever endpoints you have enabled.

---

## Flags people mix up (`readable` / `writable` / `mirrorTarget`)

These four booleans are the usual confusion. Read them as **roles**, not as Windows folder ACLs:

| Flag | Plain meaning | Used when |
|---|---|---|
| `readable` | Package may **search/reuse** files already in this folder | Looking for an existing zip before downloading |
| `writable` | Package is **allowed to create/overwrite** files in this folder | Required before anything is written here |
| `mirrorTarget` | After a successful acquire, **also copy** the finished files into this folder | Sync / Materialize distribution step |
| `ensureExists` | Create the depot **root folder** if missing | Only when Package is allowed to write |

### Legal combinations (engine enforces this)

| `writable` | `mirrorTarget` | `ensureExists` | Meaning |
|---|---|---|---|
| `false` | `false` | `false` | **Read-only source.** Use existing files; never write. Typical for site/corp shares someone else fills. |
| `true` | `false` | true/false | Writable but **not** a Sync mirror. Rare; Package will not publish Materialize results here unless `mirrorTarget` is also true. |
| `true` | `true` | usually `true` | **Local/team mirror.** Sync/Materialize copies completed packages here. Default `defaultPackageDepot`. |
| `false` | `true` | anything | **Illegal.** Config validation throws: cannot use `mirrorTarget=true` with `writable=false`. |
| `false` | anything | `true` | **Illegal.** Cannot `ensureExists` on a non-writable depot. |

So for the shipped corp/site examples:

```json
"writable": false,
"mirrorTarget": false
```

means: “If enabled, I may **read** packages from this share. I will **not** try to fill it.” That is intentional. A corp share is a **source**, not a mirror target, until an admin both enables it and (if they want Package to publish into it) sets `writable` + `mirrorTarget` to true.

**Rule of thumb:**

- Want Package to **consume** a share → `readable: true`, usually `writable: false`, `mirrorTarget: false`.
- Want Sync to **fill** a folder → `writable: true` **and** `mirrorTarget: true`.
- `mirrorTarget` without `writable` is nonsense and is rejected.

Default shipped setup: `defaultPackageDepot` is `readable` + `writable` + `mirrorTarget` + `ensureExists`. Site/corp templates are disabled read-only sources.

---

## Commands you can use today

### Look at depots

```powershell
Get-PackageDepot
Get-PackageDepot -DepotId defaultPackageDepot
```

Shows each depot id, path, enabled/effective, readable/writable/mirror flags.

`Get-PackageState` also shows where the depot inventory file lives.

### Change depot config (does not move package files)

```powershell
Add-PackageDepot -DepotId 'teamShare' -BasePath '\\server\share\PkgDepot' -Writable -MirrorTarget -EnsureExists
Add-TeamPackageDepot ...   # helper that defaults to writable + mirror + ensureExists

Set-PackageDepot -DepotId 'teamShare' -BasePath 'D:\PkgDepot'   # or enable/disable, flags, order, site codes

Remove-PackageDepot -DepotId 'teamShare'
```

**Important:** `Remove-PackageDepot` only removes the **config entry**. Files already on disk stay.

### Put package files into depots

**One package (or a few):**

```powershell
Invoke-Package -DefinitionId 'GitRuntime' -MaterializeOnly
```

Downloads/verifies that package’s files, then copies them into every depot that is **writable + mirrorTarget**. Does **not** install/assign the package into the profile.

**Many packages (catalog fill):**

```powershell
Invoke-PackageDepotMaterialize -AllTrusted
Invoke-PackageDepotMaterialize -AllTrusted -WhatIf
Invoke-PackageDepotMaterialize -AllTrusted -FailFast
Invoke-PackageDepotMaterialize -AllTrusted -PublisherId Eigenverft -Tag cli

# Deprecated alias (soft warning):
Sync-PackageDepot -AllTrusted
```

For each already-trusted, current-platform definition from your endpoints, this runs **`Invoke-Package -MaterializeOnly`** (plus dependencies). `-WhatIf` plans without writing. It **never deletes** anything from a depot.

#### Naming: catalog materialize (not “sync a depot”)

Primary command: **`Invoke-PackageDepotMaterialize`**.
`Sync-PackageDepot` remains a **deprecated alias** with a soft warning. The old name sounded like depot↔depot sync; it only batch-materializes the trusted catalog (and as a side effect copies into `mirrorTarget` depots).

| What people hear | What it actually does |
|---|---|
| Sync my depot folder | Batch MaterializeOnly over the trusted catalog |
| Sync depot A → depot B | No. No dedicated depot-to-depot copy command |
| Refresh inventory JSON | No. Config is unchanged |

Do **not** invent a second “publish mirrors” command — honesty lives in the distribute / transport step.

**Preview without writing:**

```powershell
Get-PackageAssignmentPlan -DefinitionId 'GitRuntime' -MaterializeOnly -Raw
Get-PackageAssignmentPlan -DefinitionId 'GitRuntime' -MaterializeOnly -VerifyDepotContent -Raw
```

Shows whether artifacts look obtainable / already present for that package. Still not a full “is my mirror folder healthy?” report.

---

## What happens step by step (Materialize / Sync)

For each package:

1. Resolve which version and which files the definition needs.
2. Try to get those files (often: already in a readable depot, else download).
3. Files land first in a **staging** folder (careful write + verify).
4. Package **copies** each verified file into every `writable` + `mirrorTarget` depot, under something like:
   - `PkgDepot\GitRuntime\stable\2.55.0.3\64-bit\MinGit-….zip`
5. If size+hash already match in the mirror, copy is skipped.
6. Materialize is treated as OK when the full file set exists in **at least one** durable depot path.
7. Staging folders are cleaned after a **successful** run.

That is the whole “sync into mirror” story today.

---

## What goes wrong today (the real bug for mirrors)

Operators turn on `mirrorTarget` expecting: “after Sync, **this** folder has complete copies.”

Actual behavior:

1. **Mirror copy can fail and still look like success.** Copy errors are often warnings. If another depot already had the files, Materialize/Sync can still say Materialized while your mirror share is incomplete.
2. **Mirror writes are a normal overwrite copy**, not temp-then-rename. A crash mid-copy can leave a truncated file sitting in the mirror path.
3. **You do not get a clear per-depot result** like: `defaultPackageDepot=OK`, `teamShare=FAILED path=…`.
4. Sync never repairs “this mirror is missing file X” as its own job beyond that soft copy step.
5. Sync never removes old versions or junk (fine — but also no honest “mirror incomplete” signal).

So the markdown problem was earlier: talking about trust/orphans instead of this Sync/mirror publish gap.

---

## What we should build

**Goal:** When you mark a depot as a mirror (`writable` + `mirrorTarget`), Materialize / catalog fill either fills that folder completely or fails clearly. Normal install stays usable if a secondary share is down.

### Architecture first (transport vs logic)

Depot inventory may grow beyond local folders. Future kinds could include HTTP upload, web POST, or other remote “put this package here” endpoints. Do **not** bury “copy files with Copy-Item” inside Materialize success logic as if filesystem were the only world.

Split early:

| Layer | Job | Stays stable when |
|---|---|---|
| **Logic** | Which package/version/files, which depot targets, Materialize vs Assigned fail/warn policy, per-depot completeness results | New transport kinds appear |
| **Transport selection** | From depot kind / inventory shape, pick how to publish (filesystem tree, later HTTP upload, …) | New kinds register here |
| **Transport execution** | Actually move bytes safely (filesystem transport helpers; later: upload APIs) | Logic calls the same “publish these artifacts to this target” contract |

`Invoke-PackageDepotDistribution` (and Materialize honesty) belong in the **logic** layer: plan targets, call the selected transport, interpret results. Filesystem-safe write lives in **ExecutionCore transport helpers**, not sprinkled into assignment-plan / catalog-command code.

**Preferred filesystem transport (locked):** use / evolve **`Copy-ResilientDirectoryTree`** in
`Support/ExecutionCore/Eigenverft.Manifested.Package.ExecutionCore.ResilientDirectoryTree.ps1`.
It covers resumable writer-owned `.partial` files, verified no-clobber promotion, peer reconciliation, directory preflight, retries, and progress. Phase 1 adapts distribute **to** this proven base layer. Do **not** grow forever-raw `Copy-Item` inside Package.Source. Phase 0 does **not** wire it into `Invoke-PackageDepotDistribution` yet.

Phase 1 must keep an explicit transport seam (select filesystem → execute) even while only filesystem exists. Do not wait until HTTP upload lands to invent the split.

### Multi-client writers on one share (required, not optional)

Many clients will Materialize / catalog-fill into the **same** `mirrorTarget` UNC at once. That cannot be designed away. “Prefer one writer” is **not** the product rule.

The ExecutionCore transport candidate is now multi-writer safe for the same final path and proven separately from depot distribution. Distribution still uses its old path until the later transport-seam wiring is implemented.

**Filesystem transport contract for Phase 1 (adapt the helper):**

1. **Own your partial.** Name = `final.partial.<contentIdentity>.<writerToken>` (GUID per selected file, stable across retries). Never resume another writer’s partial. Once the final is hash-verified, a later run may remove only unlocked/exclusively claimable redundant partials of that same content identity; active and different-content partials remain untouched.
2. **Skip if final already good.** Before copy: if final exists and size+hash match source → AlreadyPresent.
3. **Promote, then reconcile.** After verify, rename/move own partial → final. If promote loses the race (exists / sharing / access denied): **re-check final**. Matching hash → success (AlreadyPresent / peer won). Mismatch → retry once or Failed with clear reason.
4. **Same content = success whoever finishes.** Two clients publishing the same package version must both end “OK” when the share holds the verified bytes — not Failed because the peer’s rename won.
5. **Do not use share-wide MirrorMode cleanup** for multi-client depot fill (deleting “extras” while peers write is unsafe). Depot publish is add/replace verified leaves, not tree reconcile.
6. **No mandatory global lock file** as the primary design (SMB locks are flaky). Optional short exclusive create for niche sites later; default path is cooperative unique-partial + peer-win.

Logic layer still decides Materialize vs Assigned fail/warn from per-depot results. Transport reports honest Copied / AlreadyPresent / Failed; “peer already wrote the same bytes” is **not** Failed.

### The idea in one paragraph

Do not invent a new “publish mirrors” command. First do simple prep (rename + tests that pin today’s soft behavior). Then harden **filesystem transport** via an evolved `Copy-ResilientDirectoryTree` that is **safe under concurrent clients on slow shares**, and keep distribute as **logic** that selects/calls it. Then make Materialize / catalog fill treat a truly incomplete mirror as failure. Keep normal Assigned install softer (warn, continue).

### When a missing mirror fails the package

| What you ran | Incomplete mirror? |
|---|---|
| `Invoke-Package -MaterializeOnly` or catalog fill (`Invoke-PackageDepotMaterialize` / Sync alias) | **Fail** the package |
| Normal Assigned install | **Warn**, continue if the install can still use a good copy elsewhere |

Never run catalog fill automatically on every `Invoke-Package`.

### How we build it (simple first)

Order: **prep → transport seam + safe filesystem write → logic honesty**. Rename is not blocked on the copy fix.

**0 — Prep (active checklist)**

- [x] Rename catalog command to **`Invoke-PackageDepotMaterialize`**; `Sync-PackageDepot` deprecated alias + soft warning; docs / OfflineBootstrap / export allowlist. Behavior unchanged.
- [x] Characterization / Materialize tests that pin today’s soft success when a secondary mirror fails but another readable depot has the files. Phase 2 flips those expectations.
- [x] Docs: catalog fill is materialize-into-mirrors, not depot↔depot sync; filesystem Phase 1 should use `Copy-ResilientDirectoryTree`.

**1 — Filesystem transport + distribute logic seam (test transport alone first)**

- Keep **logic** in distribute: resolve targets, call transport, aggregate Copied / AlreadyPresent / Failed, expose “all mirrors complete?”
- [x] Evolve **`Copy-ResilientDirectoryTree` / its raw-copy path** for **multi-client shares**: writer-unique partials (`final.partial.<contentId>.<writerToken>`), stable retry ownership, full partial verification, no-overwrite promote, peer-win re-hash, and safe same-identity orphan cleanup. Sibling of final path on the share — not `%TEMP%`→UNC. Not wired into distribute yet.
- [x] Prove the transport with real processes: three staggered same-content writers all succeed with exactly one promoter; different-content writers cannot overwrite; transient final locks retry; active partials are preserved and unlocked redundant same-content partials are cleaned.
- Transport selection today: filesystem only. Leave an explicit hook so a later `httpUpload` / `webPost` depot kind does not rewrite Materialize policy.
- Do **not** change Materialize success yet in this phase.
- Prove with TestImports / `Acquisition.Tests`. Public export of distribute can wait.
- npm softer path: same honesty bar here or immediate follow-up after Phase 2.
- Do **not** turn on MirrorMode tree cleanup for depot publish.
- **Definition `depotNamespace`:** optional under `definitionPublication`. First depot subdir. Missing/blank → neutral `default`. Eigenverft shipped defs use `evf`. Not an endpoint-inventory field.

**2 — Make Materialize / catalog fill honest (logic)**

- Flip Phase 0 characterization tests: MaterializeOnly **fails** if any configured mirror transport reports incomplete.
- Assigned stays soft-warn. Own check — do not redefine “enough to install” as all-mirrors.
- Fail before wiping staging when mirrors incomplete.
- No mirrors → OK. Mirrors configured and one bad → fail.
- Catalog command inherits once MaterializeOnly is honest.

### Things we must get right (short list)

1. **Logic vs transport split early** — future non-filesystem depot kinds must not force a rewrite of Materialize policy.
2. **Success must mean every mirror is complete** for Materialize / catalog fill — not “some other folder already had the zip.”
3. **Safe filesystem write under concurrent clients** — unique partials; no truncated finals; peer already-good = success.
4. **Readable-only shares** are sources, not mirrors.
5. **Broken targets** must fail visibly, not vanish from the plan.
6. **Normal install** should not die because a secondary UNC is offline.
7. **No second publish command**, no auto-delete, no depot inventory download ledger.

### Later (not required for the first cut)

- New depot kinds (HTTP upload, web POST, …) and their transport executors.
- Read-only “is this mirror healthy?” / richer verify.
- Optional strict install mode that requires all mirrors.
- Catalog fill `-Offline` / `-DepotId`.
- Optional cleanup with `-WhatIf`.

### Still open

1. Whether distribute / transport helpers stay internal or become public later.
2. Exact single-artifact staging shape when calling the resilient copy path (one-file tree vs shared raw-copy helper).
3. Whether a future administrative sweep should report or expire different-content partials; normal publish deliberately does not remove them.
4. npm mirror honesty timing.
5. `depotDistributionMode = disabled` vs MaterializeOnly.
6. Assigned strict all-mirrors switch later.

### Out of scope here

- Turning `PackageDepotInventory.json` into a download ledger.
- Auto-deleting old packages during fill.
- Redesigning endpoint trust.
- Scanning or filling the whole catalog on every normal install.
- Depot-to-depot fleet sync / a separate repair product.
- Inventing a second publish verb next to Materialize.
- Implementing HTTP/webPost transports in this TODO’s first cut (only reserve the seam).

---

*Design reviews live under `%TEMP%\evf-depot-*` if needed. This section is the working plan.*
