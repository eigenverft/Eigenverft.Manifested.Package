# Vendor release-age policy

**Status:** Open
**Priority:** 5/7 High
**Recommendation:** Select only from signed, authored release timestamps; never query upstream during version selection.

## Gap

Automatic selection currently chooses the highest compatible authored version immediately. Schema 2.0 supports `latestByVersion` on targets, and `previousByVersion` or exact versions through command override, but it has no vendor release timestamp, cooling window, or skipped-for-age audit.

Definition signing and hash verification establish authority and integrity; they do not provide a delay after a vendor publishes a new release.

## Decisions already made

- Store `upstreamReleasedAtUtc` directly on each `artifacts.releases[]` row.
- Use an authored, signed timestamp as the policy clock; `definitionPublication.publishedAtUtc` remains catalog publication time.
- Do not call GitHub or another vendor while selecting a version.
- Exact `Invoke-Package -PackageVersion` pins bypass the cooling filter.
- Apply version ordering after age filtering and fail closed if no candidate is eligible.
- Project skipped candidates and remaining cooling time into results/messages.
- Keep acquisition-time network behavior independent from selection-time policy.

## Remaining implementation

1. Extend schema 2.0 and wire validation with `upstreamReleasedAtUtc` and a cooling-duration field such as `minReleaseAge`.
2. Resolve one effective policy from command override, target settings, global defaults, and engine defaults.
3. Implement prerelease behavior explicitly instead of leaving `allowPrerelease` as nonfunctional metadata.
4. Filter candidates by age, then apply `latestByVersion`/`previousByVersion` ordering.
5. Add `SkippedCandidates` (or equivalent) to selection/result/history projection and log why each row was excluded.
6. Backfill all applicable releases in the 21-definition catalog, bump revisions, and re-sign.
7. Update the authoring guide and catalog validation so age-aware targets cannot omit required timestamps.
8. Test cooling, exact-pin bypass, fail-closed behavior, precedence, prerelease handling, dependency-node selection, and clock boundaries.

## Open decisions

- Duration syntax (`7d`, ISO-8601, or another strict format).
- Global-only default versus per-target override in the first version.
- Default duration; seven days remains an example, not a confirmed constant.
- Whether `previousByVersion` becomes authorable on targets in the same schema pass.
- Whether a maintain-time GitHub helper populates timestamps or authors/agents do so directly.

## Out of scope

- Runtime “fetch latest” selection.
- Fleet-wide holds, rollout rings, or background updates.
- Replacing definition trust or artifact verification.
- Using catalog publication time as vendor release time.

## Acceptance

Automatic selection deterministically excludes too-new releases from signed catalog data, exact pins remain available for deliberate overrides, and operators can see every age-based skip without network access during selection.
