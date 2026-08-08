# Onboarding profiles

**Status:** Open
**Priority:** 3/7 Low
**Recommendation:** Start with reviewable profile artifacts; keep execution on `Invoke-Package`.

## Gap

Teams describe roles such as backend developer or local-AI workstation, while the product exposes individual `DefinitionId` values. Multi-root invocation and dependency expansion already work; the missing capability is a named, reviewable bundle with rationale and ownership.

## Reuse the shipped engine

- `Invoke-Package -DefinitionId <string[]>`;
- the shared dependency planner and conflict checks;
- `Search-Package` and catalog validation for referenced definitions;
- per-definition signing and catalog trust.

Profiles are sibling artifacts, not package-definition schema entries and not a second install engine.

## Remaining contract

1. Choose a small profile format containing `profileId`, title, audience, rationale, revision, and top-level `definitionIds`.
2. Ship two reviewed examples and validate their root sets against the current catalog and dependency planner.
3. Document that transitive dependencies are normally omitted because the planner expands them.
4. Produce an explicit `Invoke-Package -DefinitionId ...` command; do not add background application.
5. Keep trust on each resolved package definition; profile naming does not confer package trust.

## Open decisions

- JSON versus structured markdown.
- Repository/docs/team-endpoint storage convention.
- Whether examples record the expected expanded dependency graph for review.
- When a read-only `Get-PackageOnboardingProfile` command becomes worthwhile.

## Guardrails

- Do not combine conflicting roots such as `VSCodeRuntime` and `VSCodeUser`.
- A global `-PackageVersion` applies to every root; profiles must not imply per-package pins unless the invocation model changes.
- Separate profile signing or `Invoke-PackageProfile` remains deferred until a concrete tamper/compliance need exists.
- Organization-wide mandate, rollout, drift, and compliance belong to the future Manager product.

## Acceptance

A user can select a named profile, review its package roots and rationale, validate it, and run the generated explicit `Invoke-Package` command without introducing another trust or execution path.
