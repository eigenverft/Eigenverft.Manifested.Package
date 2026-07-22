# Work index — Eigenverft.Manifested.Package

Only genuine remaining work is listed here. Shipped behavior is summarized in [DECISIONS.md](DECISIONS.md); Git and tests retain implementation history. General framework files are reference-only.

**Scope:** `src/prj/Eigenverft.Manifested.Package` and [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md).

## Open backlog

| Priority | Topic | Remaining outcome |
|---|---|---|
| 5/7 | [Release-age policy](TODO-SUPPLY-CHAIN.md) | Filter automatic selection using authored upstream release dates and explain skipped versions. |
| 4/7 | [Unapproved verb warning](ISSUE-UNAPPROVED-VERB-WARNING.md) | Replace or compatibly map exported unapproved verbs so normal module import is warning-free without hiding unrelated warnings. |
| 4/7 | [Copy progress readability](ISSUE-RESILIENT-COPY-PROGRESS-READABILITY.md) | Use adaptive IEC throughput units, fix composite status formatting, and clarify pending-versus-active queue semantics. |
| 3/7 | [Ownership guide](TODO-OWNERSHIP.md) | Explain adoption/removal policy and add focused author guidance. |
| 3/7 | [Onboarding profiles](ISSUE-ONBOARDING-PROFILES.md) | Define reviewable named `DefinitionId` bundles and examples. |
| 3/7 | [Agent operability](ISSUE-AGENT-OPERABILITY.md) | Persist execution-step logs and expose a read/guide surface. |
| 2/7 | [Catalog manifest](TODO-ENDPOINTS-MANIFEST.md) | Define large-catalog discovery contract when a concrete scale target exists. |
| 2/7 | [HTTPS catalog](TODO-ENDPOINTS-HTTPS.md) | Implement read-only `httpsCatalog` transport. |
| 2/7 | [HTTP depots](TODO-DEPOTS-HTTP.md) | Add read-only HTTP(S) artifact acquisition after fetch requirements are known. |
| 2/7 | [Depot mirror sync](TODO-DEPOTS-HYGIENE.md) | Make Sync publish complete, crash-safe copies into `mirrorTarget` depots; report honestly on failure. |

## Decisions and boundaries

- [Endpoint discovery](DECISION-ENDPOINT-DISCOVERY-V1.md)
- [Artifact vocabulary](DECISION-SCHEMA-ARTIFACTS-VOCABULARY.md)
- [Product boundary](PRODUCT-BOUNDARY.md)

## Reconciliation facts

- Catalog: 21 signed schema-2.0 definitions.
- Exported command surface: 42 functions.
- Search, trust, dependency and assignment planning, artifact file sets, complete depot materialization, authoring guidance, and the offline bootstrap are shipped and are not backlog items.
