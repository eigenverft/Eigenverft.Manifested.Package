# Decision — Endpoint discovery model for v1

**Status:** Draft — not product sign-off
**Recorded:** 2026-05-30; reconciled with source 2026-07-17

## Decision

- `Search-Package` and definition resolution use recursive `*.json` scans for enabled `moduleLocal` and `filesystem` endpoints.
- A small future `httpsCatalog` may use a simple read-side listing/fetch contract.
- Define a manifest before relying on remote catalogs around 200+ definitions or where measured scan latency becomes material.
- Discovery never changes definition trust: schema validation, signed-definition verification, and configured catalog trust remain mandatory.
- HTTPS create/update authoring is a separate write API and authorization decision. A readable endpoint is not automatically writable.

## Current implementation

- Local search is shipped for the 21 schema-2.0 definitions.
- `httpsCatalog` remains inventory-reserved and throws when resolved.
- No catalog manifest exists.
- `Get-PackageDefinitionAuthoringGuide` must continue to exclude HTTPS authoring until an authorized create/update surface exists.

## Reopen when

- A concrete HTTPS catalog is selected, or
- a filesystem/HTTPS catalog reaches the scale or latency trigger.

Open work: [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md) and [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md).
