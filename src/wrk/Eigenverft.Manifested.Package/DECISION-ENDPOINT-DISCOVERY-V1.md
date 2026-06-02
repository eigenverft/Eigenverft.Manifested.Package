# Decision — Endpoint discovery model for v1 (search, manifest, HTTPS)

**Status:** Draft — not product sign-off (see [TODO-INDEX.md](TODO-INDEX.md))   (scale spike recorded)  
**Date:** 2026-05-30  
**Recorded from:** closed wrk issue (Option C spike → **Option A for v1**, manifest before large remote catalogs) — see [DECISIONS.md](DECISIONS.md)

## Facts recorded (2026-05-30)

| Fact | Value |
|------|--------|
| Shipped signed definitions | **18** under `Endpoint/Defaults/Eigenverft/` |
| Enabled endpoint today | `moduleLocal` (`moduleDefaults`) |
| `httpsCatalog` runtime | Not implemented (inventory reserved; resolve throws) |
| `filesystem` sample endpoint | Present in inventory, **disabled** |
| Search cmdlet | `Search-Package` local scan shipped 2026-06-01 |

## Decision

1. **v1 search (shipped `Search-Package`):** Use the same **live recursive `*.json` scan** as `Invoke-Package` discovery on enabled endpoint roots (`moduleLocal`, `filesystem`). No manifest prerequisite for the first search version.
2. **`moduleLocal` / small `filesystem` endpoints:** Continue **live scan** (current behavior).
3. **`httpsCatalog` v1 (when implemented):** May use **live scan** only while the remote catalog stays **small** (initial target: same order of magnitude as today’s module catalog — **under ~200 definitions** and acceptable scan latency on a warm client).
4. **Manifest contract:** Design and implement **before** relying on `httpsCatalog` or search for **large** catalogs (team/corp scale — treat **~200+ definitions** or multi-second scan latency as the trigger to require an index/manifest). Sequencing: [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md) then HTTPS/search at scale — not before small-catalog v1 paths.
5. **Trust/signing:** Unchanged — signed definitions and `catalogTrust` apply regardless of discovery mechanism.

## Sequencing

| Work | Depends on |
|------|------------|
| `Search-Package` local scan | Shipped 2026-06-01 (see [DECISIONS.md](DECISIONS.md)) |
| `httpsCatalog` small-catalog v1 | Priority 3/6 decision (this doc); trust inventory already prepared |
| Manifest contract + parser | Large-catalog / HTTPS-at-scale path |
| Search at scale (optional manifest-backed) | Manifest contract when trigger met |

## Reopen when

- First production `filesystem` or `httpsCatalog` endpoint has a confirmed definition count and measured scan latency.
- Scan latency or operator feedback exceeds the **~200 definition** / multi-second threshold.

## Out of scope

- Implementing search, manifest parser, or HTTPS transport (separate delivery issues).
