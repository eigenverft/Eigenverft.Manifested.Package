# HTTPS catalog endpoints

**Status:** Open
**Priority:** 2/7 Backlog
**Recommendation:** Implement a small-catalog, read-only `httpsCatalog` first; require a manifest for measured large-catalog needs.

## Gap

Endpoint inventory validates `httpsCatalog` entries, but `Resolve-PackageEndpointRootPath` still rejects them as reserved. Local `moduleLocal` and `filesystem` discovery, search, schema validation, and catalog trust are already shipped.

## Remaining contract

1. Define a concrete remote listing/fetch shape for `baseUri` and `catalogPath`.
2. Fetch package-definition JSON into a bounded cache/staging area.
3. Reuse the existing candidate winner, schema, signature, trust, publisher-conflict, and revision/hash rules.
4. Make `Search-Package` and `Invoke-Package` consume the same remote candidates.
5. Specify proxy, TLS, timeout, cache, and failure behavior.
6. Keep the endpoint read-only.

## Scale boundary

A simple small-catalog listing is acceptable initially. Before relying on roughly 200+ definitions or multi-second discovery latency, implement the contract in [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md).

## Open decisions

- Remote list format and cache lifetime.
- Proxy/TLS defaults for the first real consumer.
- Whether network endpoint failure is warning-and-continue or fatal under each command.

## Out of scope

- Creating or updating definitions over HTTPS.
- Inferring write permission from successful GET access.
- Changing catalog trust or accepting unsigned remote content implicitly.

Any future HTTPS authoring requires a separate authenticated/authorized create/update API and corresponding authoring-guide checks.
