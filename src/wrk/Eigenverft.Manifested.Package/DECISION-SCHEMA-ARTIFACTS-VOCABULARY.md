# Decision — Keep `artifacts` / `targetArtifacts` vocabulary

**Status:** Implemented in schema 2.0
**Recorded:** 2026-05-30; reconciled with source 2026-07-17

Schema 2.0 retains:

- top-level `artifacts` for targets and sources;
- per-release `targetArtifacts` keyed by target ID;
- target/release `artifactFiles` keyed by stable file ID.

The schema 2.0 breaking change replaced the singular package-file model with artifact file sets without renaming these established containers. `artifactsByTarget` remains invalid.

Reopen only if a future package kind cannot be represented clearly or another deliberate schema break is scheduled.
