# TODO DEPOT

## Purpose

Refine the depot, package-acquisition, and offline/materialization model outside the main project backlog until the design is clear enough to promote concrete implementation work back into `PROJECT-TODO.md`.

No engine, schema, or catalog changes are implied by this file. It is a locked design note and TODO scratchpad for future work.

## Source Facts

- `PackageEndpointInventory.json` is for package-definition discovery, not package artifact acquisition.
- Endpoint inventory currently supports `moduleLocal` and `filesystem`; `httpsCatalog` is reserved and not implemented.
- A filesystem endpoint is a catalog/definition share such as `\\corp-share\PackageEndpoint`, not a package artifact depot.
- `PackageDepotInventory.json` is the artifact acquisition environment for `packageDepot`.
- Depot inventory currently uses `environmentSources` with `kind: filesystem`; examples include the default local depot and disabled site/corp UNC shares.
- Current depot source capabilities are `readable`, `writable`, `mirrorTarget`, and `ensureExists`.
- Current package-definition acquisition candidates are `packageDepot`, `download`, and `filesystem`.
- Current artifact source resolvers inside package definitions are `download` and `githubRelease`; both ultimately resolve to vendor/upstream network downloads when used outside a depot.
- `VSCodeUser` is currently download-only while most shipped raw-file packages are depot-first with download fallback.
- Shipped definitions currently do not use package-definition `filesystem` acquisition candidates, so removing that acquisition kind should not require a shipped catalog migration.

## Locked Decisions

- The next minimal package-definition schema version should be `1.8`.
- Package-definition acquisition vocabulary should hard-converge on `packageDepot` and `vendorDownload` in `1.8`.
- `download` should be replaced by `vendorDownload` in `1.8`; do not add a compatibility alias in the new schema.
- Package-definition `filesystem` acquisition should be removed from `1.8`; file shares, NAS paths, and local folders belong in depot inventory when they provide depot layout.
- Existing `1.7` compatibility may remain while `1.8` uses the cleaned vocabulary.
- `githubRelease` should remain an artifact source resolver used by vendor acquisition, not become a depot or internal mirror concept.
- `VSCodeUser` should be brought in line with the other shipped packages if it remains in the shipped catalog: `packageDepot` first, `vendorDownload` fallback.
- Package definitions should stay topology-neutral. They should describe whether an artifact may come from the prepared depot layer or from the original vendor/upstream layer.
- Internal organization mirrors belong under `PackageDepotInventory.json`, not as separate package-definition acquisition candidate kinds.
- `PackageDepotInventory.json` should keep depot source `kind: filesystem` for local folders, UNC shares, NAS paths, and team file shares; do not split it into `filesystemLocal` and `filesystemShare`.
- A future internal HTTP/HTTPS artifact mirror should be a read-only depot source transport, tracked in `PROJECT-TODO.md`, and kept out of the current TODO-DEPOT implementation scope.
- Do not introduce `internalDownload` or `filesystemArtifact` as normal package-definition acquisition kinds.

## Runtime Switch Model

Two future command switches should be independent axes:

- `Invoke-Package -Offline`: run the normal package lifecycle, but ignore `vendorDownload`; only configured depot sources are valid artifact sources. A depot miss fails closed instead of falling back to the vendor.
- `Invoke-Package -MaterializeOnly`: resolve, acquire, and materialize package artifacts and depot mirrors, but skip install/remove/package-operation effects.

Combined behavior:

- `Invoke-Package -MaterializeOnly -Offline`: perform depot-only staging or depot-to-depot sync from existing depot artifacts; do not use `vendorDownload`, and do not install or remove packages.

Not in current scope:

- Report-only readiness or preflight command design.
- `Invoke-Package -WhatIf` planning semantics.

## Candidate Work Items

- Add package-definition schema `1.8` with `packageDepot` and `vendorDownload` acquisition candidates only.
- Remove package-definition `filesystem` acquisition from the `1.8` schema and runtime projection.
- Keep `githubRelease` as a vendor source resolver behind `vendorDownload`.
- Bring `VSCodeUser` acquisition behavior in line with the other shipped packages.
- Add `Invoke-Package -Offline` as a fail-closed depot-only acquisition policy.
- Add `Invoke-Package -MaterializeOnly` as a no-install/remove artifact materialization mode.
- Define and test combined `-MaterializeOnly -Offline` depot-only staging/sync behavior.
- Add depot hygiene checks for incomplete files, unexpected sidecars, and stale materialization artifacts.

## Future Implementation Tests

- `1.8` accepts `packageDepot` and `vendorDownload`.
- `1.8` rejects package-definition `download` and `filesystem` acquisition candidates.
- `1.8` keeps `githubRelease` usable as a vendor source resolver.
- `Invoke-Package -Offline` uses depot sources only and fails on depot misses without trying vendor acquisition.
- `Invoke-Package -MaterializeOnly` skips install/remove/package-operation effects while still materializing artifacts.
- `Invoke-Package -MaterializeOnly -Offline` only stages or syncs from existing depot artifacts.
