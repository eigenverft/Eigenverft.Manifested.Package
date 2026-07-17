# Idea — Scale the catalog with agents

**Status:** Product direction, not scheduled work

> The agent creates reviewable artifacts. The deterministic local engine validates and executes trusted artifacts.

This direction fits [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md): agents may accelerate catalog maintenance, onboarding curation, validation, and diagnosis without becoming a background fleet controller.

## Shipped foundation

- schema-2.0 package definitions and catalog validation;
- signed definitions and explicit trust management;
- `Get-PackageDefinitionAuthoringGuide` plus the packaged authoring guide;
- local state, operation-history summaries, endpoints, and depots.

## Remaining ideas

### Catalog maintenance workbench

Produce update drafts, hashes, trust evidence, and review summaries. Do not silently sign semantic changes or accept unknown signing keys.

### Onboarding profiles

Produce named, reviewable `DefinitionId` bundles. Execution remains explicit `Invoke-Package`; see [ISSUE-ONBOARDING-PROFILES.md](ISSUE-ONBOARDING-PROFILES.md).

### Failure explanation

Persist the ordered execution narrative and expose it to humans and agents before considering higher-level explanation or repair proposals; see [ISSUE-AGENT-OPERABILITY.md](ISSUE-AGENT-OPERABILITY.md).

### Repair planning

After durable logs exist, an agent may propose numbered repair commands. The module must not auto-run repairs, trust changes, or background assignments.

## Guardrails

- No fleet orchestrator or background updater in this module.
- No automatic trust or signing.
- No opaque generated setup scripts.
- No live upstream metadata in deterministic selection unless separately designed and approved.

Next step: keep dogfooding the authoring guide and file only recurring, source-backed maintenance pain.
