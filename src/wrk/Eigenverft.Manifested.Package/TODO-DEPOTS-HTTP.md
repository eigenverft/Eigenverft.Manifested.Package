# Read-only HTTP(S) depots

**Status:** Open
**Priority:** 2/7 Backlog
**Recommendation:** Record the first consumer's fetch requirements before choosing the inventory contract.

## Gap

Package depots currently support only filesystem sources. Definitions may download directly from vendors, but a centrally hosted HTTP artifact mirror is not a depot and cannot participate in depot ordering today.

## Shipped foundation

- ordered acquisition candidates per artifact file;
- required hash/signature verification;
- complete multi-file materialization and nested relative paths;
- filesystem depot reuse and distribution;
- proxy-aware web requests used by existing download sources.

The new transport should reuse these behaviors rather than add another artifact model.

## Remaining contract

1. Add a read-only HTTP(S) depot inventory kind with base URI, ordering, enabled state, and optional site constraints.
2. Map each expected artifact depot path to a GET URI without allowing path escape or URI ambiguity.
3. Download to staging and apply the artifact file's existing verification before reuse or redistribution.
4. Preserve offline semantics: HTTP depots are unavailable in `-Offline` mode unless a future policy explicitly says otherwise.
5. Return per-file source attempts and failures like filesystem and vendor candidates.

## Decide before implementation

- Anonymous HTTPS-only first versus authentication.
- Full-file GET only versus range/resume for large models.
- Cache/ETag behavior and corporate proxy requirements.
- One URI-based kind versus separate HTTP and HTTPS kinds.

## Out of scope

- Writable HTTP mirroring or uploads.
- Changing `vendorDownload` behavior.
- Treating HTTP availability as artifact trust.

## Acceptance

A verified artifact file set can be materialized from an ordered HTTP depot exactly as from a filesystem depot, with no bypass of existing verification or offline policy.
