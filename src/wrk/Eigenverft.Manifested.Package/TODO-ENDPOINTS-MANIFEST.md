# Catalog manifest contract

**Status:** Open when a concrete large-catalog target exists
**Priority:** 2/7 Backlog
**Recommendation:** Do not design the contract without a measured consumer; use a full versioned manifest before large HTTPS/search deployment.

## Gap

Local discovery scans definition JSON directly. No manifest document, schema, parser, or cache exists. This is acceptable for the current 21-definition catalog but not necessarily for large remote catalogs.

## Trigger

Start this work when a selected filesystem/HTTPS catalog approaches roughly 200 definitions, produces multi-second scans, or needs index-first remote fetch.

## Remaining contract

The manifest must define:

- schema/version and compatibility policy;
- one canonical entry per publisher/definition/revision;
- definition URI/path and content hash;
- minimum metadata required for query/platform filtering before fetching full JSON;
- fetch/cache order and stale-manifest behavior;
- trust order: manifest metadata narrows discovery but never replaces full definition signature and schema validation;
- collision, duplicate, rollback, and partial-fetch handling.

## Open decisions

- Static file versus generated API response.
- Manifest signing in addition to per-definition signatures.
- Required search metadata versus a path-only first version.
- Whether endpoint capabilities live in the manifest or only endpoint inventory.

## Out of scope

- HTTPS transport implementation itself.
- Full-text ranking.
- Package-definition create/update APIs or write authorization.

## Acceptance

Large-catalog clients can discover a bounded candidate set without fetching every definition while preserving the existing winner and trust semantics.
