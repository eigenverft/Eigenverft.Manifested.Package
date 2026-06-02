# Work index — Eigenverft.Manifested.Package

**Source of truth:** one open issue per topic in `TODO-<topic>.md` below. Issue format: [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6).

**Removed rollup:** `PROJECT-TODO.md` duplicated domain files and listed stale/done work; do not restore it.

**Scope:** `src/prj/Eigenverft.Manifested.Package` · also [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md)

---

## Duplicate audit (2026-05-30)

`PROJECT-TODO.md` (uncommitted delete) vs domain `TODO-*.md`:

| Issue in `PROJECT-TODO.md` | Authoritative location | Status |
|----------------------------|------------------------|--------|
| Publish ownership / adoption guide | [TODO-OWNERSHIP.md](TODO-OWNERSHIP.md) | **Duplicate** — keep domain file |
| Keep `artifacts` / `targetArtifacts` | [DECISION-SCHEMA-ARTIFACTS-VOCABULARY.md](DECISION-SCHEMA-ARTIFACTS-VOCABULARY.md) | **Draft decision only** — not a TODO; needs your sign-off |
| Define catalog manifest contract | [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md) | **Duplicate** |
| Implement `httpsCatalog` | [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md) | **Duplicate** |
| Read-only HTTP/HTTPS depots | [TODO-DEPOTS-HTTP.md](TODO-DEPOTS-HTTP.md) | **Duplicate** |
| Depot layout hygiene | [TODO-DEPOTS-HYGIENE.md](TODO-DEPOTS-HYGIENE.md) | **Duplicate** |
| ExecutionCore header comments | [DECISIONS.md](DECISIONS.md) (shipped) | **Stale** — done in code |
| Scannability / help / state / catalog docs | [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) + shipped state/outcome | **Stale / split** — use documentation TODO; state/outcome shipped |
| `[OUTCOME]` version-change story | [DECISIONS.md](DECISIONS.md) (shipped) | **Stale** — done in code |

**Only in domain files (missing from `PROJECT-TODO.md` rollup):**

| File | Issue |
|------|--------|
| [TODO-CATALOG-VALIDATION.md](TODO-CATALOG-VALIDATION.md) | Catalog validation without install |
| [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) | Vendor release-age policy on version selection |
| [TODO-DEPENDENCY-A.md](TODO-DEPENDENCY-A.md) | Selected Option A dependency planner track |
| [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) | Hybrid product documentation |
| [TODO-CATALOG-AGENT.md](TODO-CATALOG-AGENT.md) | `PackageDefinitionAuthoring` agent skill |

**Cross-file duplicates among `TODO-*.md`:** none — each 📌 title appears in exactly one domain file.

**Deleted split parent:** `TODO-COMMANDS.md` (state/outcome/search polish shipped — see [DECISIONS.md](DECISIONS.md)).

---

## Open backlog (by priority)

| P | File | Topic |
|---|------|--------|
| 2 | [TODO-CATALOG-VALIDATION.md](TODO-CATALOG-VALIDATION.md) | Validate definitions / endpoint folders without install |
| 2 | [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) | Release-age / cooling window on version selection |
| 2 | [TODO-DEPENDENCY-A.md](TODO-DEPENDENCY-A.md) | Dependency graph, peer policy, batch planning |
| 3 | [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) | Hybrid docs (repo → module HTML → command) |
| 3 | [TODO-CATALOG-AGENT.md](TODO-CATALOG-AGENT.md) | Agent authoring skill |
| 4 | [TODO-OWNERSHIP.md](TODO-OWNERSHIP.md) | Ownership / adoption guide |
| 5 | [TODO-ENDPOINTS-MANIFEST.md](TODO-ENDPOINTS-MANIFEST.md) | Catalog manifest contract |
| 5 | [TODO-ENDPOINTS-HTTPS.md](TODO-ENDPOINTS-HTTPS.md) | `httpsCatalog` endpoint kind |
| 5 | [TODO-DEPOTS-HTTP.md](TODO-DEPOTS-HTTP.md) | HTTP(S) depot fetch |
| 5 | [TODO-DEPOTS-HYGIENE.md](TODO-DEPOTS-HYGIENE.md) | Depot layout hygiene |

---

## Draft decisions (not product sign-off)

Agent-written; confirm or edit before treating as binding:

- [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md)
- [DECISION-SCHEMA-ARTIFACTS-VOCABULARY.md](DECISION-SCHEMA-ARTIFACTS-VOCABULARY.md)

Shipped polish (code): [DECISIONS.md](DECISIONS.md).
